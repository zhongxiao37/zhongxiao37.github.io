---
title: 使用Dive分析Docker镜像
date: 2026-05-19 11:04 +0800
categories: docker
---

## 问题

最近遇到一个问题，在 Bamboo Agent 上面发现自己的 Docker 镜像居然有 6 个 G。自己怎么也觉得不应该这么大的啊？

## 解决

印象中之前公司有人推荐过一个 Dive 的工具，顺手也问问 AI 看有什么工具推荐，结果 AI 也推荐 Dive，那就说干就干！

直接`brew install dive`之后， `dive <image_id>`就可以看到下面的 terminal 界面。
左侧分别是 Layer 的大小，每一层的命令，以及镜像详情。右侧则是文件详情，包括每一个文件夹的大小，这一层新增文件高亮。

![img](/images/dive_demo.gif)

不过由于我的镜像太大，Dive 直接卡死了。但从每一层的大小可以发现一丝端倪，就是两次`yarn`操作导致镜像多次 4 个 G，后面的`COPY`操作又带进来`800MB`。

![img](/images/dive_issue.png)

原来的 Dockerfile

```dockerfile
FROM node:18.19.0

WORKDIR /usr/src/app
COPY package.json yarn.lock .

RUN yarn install --frozen-lockfile
RUN yarn add miniprogram-ci
COPY . .
RUN yarn build
```

进一步发现这里有 3 个问题:

1. `yarn`会在用户级别保留 package 的缓存，在 project 的 node_modules 又安装了一次。最后应该用 yarn cache clean 清理用户级别的缓存。据说`yarn`在 v2 里面做了硬链接的优化，不过后来大家都倾向使用`pnpm`了。
2. 两次`yarn`导致先创建了一个 node_modules 层，后面又创建了一个 node_modules 层，重复了许多文件。
3. 忘记 .dockerignore 了。

```dockerfile
RUN yarn install --frozen-lockfile && \
    yarn add miniprogram-ci && \
    yarn cache clean
```

直到问题就好解决了。加上 .dockerignore，然后把两次 `yarn`合并在一起，最后`yarn cache clean`就好了，镜像压缩到了 2.6G。

## 这样就完了？

前不久同事安利过`--mount=type=cache`来加速 yarn install。我这里就把用户级别的 yarn cache 挂载进去，这样最后的时候都不需要`yarn cache clean`了。

```dockerfile
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,id=yarn-cache \
    yarn install --frozen-lockfile && \
    yarn add miniprogram-ci
```

问题又来了，`--mount=type=cache`和`--mount=type=bind`有什么区别呢？`bind`一般用来替代 COPY 操作，只读，又不会把这个打进最终的镜像，比如一些 credentials 之类的。`cache`一般就是各种包的缓存，像这里就把`yarn cache`挂载进去，是可以读写的。所以这里使用`cache`。

最后的效果依旧还是 2.6G。

## 鱼和熊掌

如果还想极致压缩镜像，还是可以如下。`yarn`的时候写入缓存，复制完项目代码之后，又挂载一次缓存`yarn build`，这样就会仅仅保留 node 镜像和 build 的产物。

```dockerfile
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,id=yarn-cache \
    --mount=type=cache,target=/usr/src/app/node_modules,id=node_modules-cache \
    yarn install --frozen-lockfile && \
    yarn add miniprogram-ci

COPY . .

RUN --mount=type=cache,target=/usr/src/app/node_modules,id=node_modules-cache \
    yarn build
```
