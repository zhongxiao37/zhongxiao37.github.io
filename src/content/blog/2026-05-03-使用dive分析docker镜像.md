---
title: 使用Dive分析Docker镜像
date: 2026-05-19 11:04 +0800
categories: docker
---

## 什么是 Dive？

Dive 就像是 Docker 镜像的“X 光机”。当你构建完一个镜像后，它能帮你一层一层地透视进去，看看每一层到底增加了什么文件、浪费了多少空间。

## 为什么我们需要 Dive？

最近我遇到了一个让人头疼的情况：在 Bamboo Agent 上，我发现自己的一个 Node.js 前端项目 Docker 镜像居然膨胀到了 **6GB**！对于一个普通的 Web 应用来说，这简直是个“存储黑洞”。

如果没有合适的工具，排查这种问题就像大海捞针——你只知道镜像很大，却不知道到底是哪一行 `Dockerfile` 指令把垃圾带了进去。这时候，AI 和同事都不约而同地向我推荐了 Dive。

## Dive 是如何工作的？

Dive 通过解析 Docker 镜像的层级结构（Layers），将终端分成了左右两个直观的面板：

1. **左侧面板**：展示了镜像的每一层（Layer）大小、对应的 Dockerfile 命令，以及镜像的整体详情（如总大小、浪费的空间比例）。
2. **右侧面板**：展示了当前选中层的文件系统树。最棒的是，它会高亮显示这一层**新增**、**修改**或**删除**的文件。

## 优缺点

**优点：**
- **直观的终端 UI**：无需复杂的命令，直接在终端里用方向键就能浏览文件树。
- **精准定位**：能直接告诉你哪一层浪费了多少空间，甚至列出具体的文件路径。
- **CI 集成**：支持在 CI/CD 流程中设置阈值，比如“空间浪费超过 10% 就让构建失败”。

**缺点：**
- **性能瓶颈**：对于极其庞大的镜像（比如我那个 6GB 的），Dive 在解析文件树时可能会卡死。

## 真实世界的验证

首先，安装并运行 Dive：

```bash
# macOS 安装
brew install dive

# 分析指定的镜像
dive <image_id_or_name>
```

运行后，你会看到类似这样的界面：

![img](/images/dive_demo.gif)

虽然由于我的镜像太大导致 Dive 卡死了，但仅仅是通过左侧每一层的大小，我已经发现了端倪：

![img](/images/dive_issue.png)

通过观察，我发现两次 `yarn` 操作导致镜像多出了近 4GB 的空间，而后面的 `COPY` 操作又带进去了 800MB。

让我们看看原来的 `Dockerfile`：

```dockerfile
FROM node:18.19.0

WORKDIR /usr/src/app
COPY package.json yarn.lock .

# 罪魁祸首 1：第一次 yarn
RUN yarn install --frozen-lockfile
# 罪魁祸首 2：第二次 yarn
RUN yarn add miniprogram-ci
# 罪魁祸首 3：COPY 进去了不该进的东西
COPY . .
RUN yarn build
```

这里暴露了三个致命问题：

1. **Yarn 缓存机制**：`yarn` 会在用户级别（`~/.cache/yarn`）保留 package 的缓存，同时在项目的 `node_modules` 中又安装了一次。如果不清理，这些缓存会一直留在镜像里。
2. **层级冗余**：两次 `RUN yarn` 指令创建了两个独立的镜像层。后一层又修改了 `node_modules`，导致许多文件被重复打包。
3. **缺少 `.dockerignore`**：`COPY . .` 会把本地的 `node_modules`、日志文件等垃圾全塞进镜像。

**第一步优化：合并指令与清理缓存**

加上 `.dockerignore` 后，我们将多次 `RUN` 合并，并在最后清理缓存：

```dockerfile
RUN yarn install --frozen-lockfile && \
    yarn add miniprogram-ci && \
    yarn cache clean
```

仅仅这两步，镜像就从 6GB 暴降到了 **2.6GB**！

## 进阶排错与极致优化

**使用 BuildKit 缓存挂载**

每次都 `yarn cache clean` 还是有点傻乎乎的，而且下次构建依然很慢。我们可以使用 Docker BuildKit 的 `--mount=type=cache` 特性，把宿主机的缓存“借”给容器用，构建完就还回去，根本不会打进最终镜像。

```dockerfile
# 挂载 yarn 缓存目录，加速安装且不增加镜像体积
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,id=yarn-cache \
    yarn install --frozen-lockfile && \
    yarn add miniprogram-ci
```

*注意：`--mount=type=cache` 和 `--mount=type=bind` 的区别在于，`bind` 通常用于只读挂载（如密钥、源代码），而 `cache` 是可读写的，专门用于包管理器的缓存。*

**极致压缩：鱼和熊掌兼得**

如果你的目标是极致的镜像大小，你甚至可以把 `node_modules` 也作为缓存挂载。这样，最终的镜像里只保留 Node 基础环境和 `build` 产物，连 `node_modules` 都不带！

```dockerfile
# 将 yarn 缓存和 node_modules 都作为缓存挂载
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,id=yarn-cache \
    --mount=type=cache,target=/usr/src/app/node_modules,id=node_modules-cache \
    yarn install --frozen-lockfile && \
    yarn add miniprogram-ci

COPY . .

# build 时再次挂载 node_modules 缓存
RUN --mount=type=cache,target=/usr/src/app/node_modules,id=node_modules-cache \
    yarn build
```

通过 Dive 的透视和 BuildKit 的加持，我们不仅找出了镜像膨胀的元凶，还掌握了更优雅的 Dockerfile 编写姿势。下次再遇到“体积焦虑”，记得先用 Dive 照一照！