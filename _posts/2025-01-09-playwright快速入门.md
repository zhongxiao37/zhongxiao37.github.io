---
layout: default
title: PlayWright快速入门
date: 2025-01-09 17:19 +0800
categories: playwright
---

在上家公司看见过`nightwatch`之后，就很久没有碰过测试框架了。最近找了个机会完了一会儿`PlayWright`。

### 安装

```bash
yarn create playwright
```

### 执行测试

根据`playwright.config.ts`文件中配置的`testDir`，`PlayWright`会扫描`tests`文件夹下面的测试文件。

```bash
yarn playwright test
```

### 查看报告

```bash
yarn playwright show-report
```

### 失败的时候截图和视频

修改`playwright.config.ts`文件，加入下面的配置即可。


```javascript
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
```

### UI模式下debug

```bash
yarn playwright test --ui
```

### 录制脚本

```bash
npx playwright codegen demo.playwright.dev/todomvc
```

### VS Code 插件

安装[Playwright Test for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright)，在左侧的测试按钮地方就可以看到所有的测试脚本，可以在UI上执行测试用例。

<img src="/images/playwright_extension.png" style="width: 800px" />


### 指定标签执行

```bash
yarn test --grep @pws
```


### 切片执行测试

看了一下Python，发现基本不支持分布式执行测试。之前Selenium上有Selenium Grid，PlayWright上就直接分片测试，这样就可以在多个容器上执行。

```bash
yarn test --reporter=blob --shard=1/3
```

然后再合并一下report

```bash
npx playwright merge-reports --reporter=html,github ./blob-reports
```

### 本地Docker compose

在本地启3个容器，执行分片测试，并将测试报个合并测试结果。

```bash
docker compose up worker-1 worker-2 worker-3
docker compose up merge-reports
```

```yaml
version: '3.8'

services:
  worker-1:
    image: playwright-worker:latest
    ipc: host
    environment:
      - SHARD_TOTAL=3
      - SHARD_INDEX=0
    volumes:
      - ./blob-report/worker-1:/app/blob-report
      - ./tests:/app/tests
    command: npx playwright test --reporter=line,blob --shard=1/3

  worker-2:
    image: playwright-worker:latest
    ipc: host
    environment:
      - SHARD_TOTAL=3
      - SHARD_INDEX=1
    volumes:
      - ./blob-report/worker-2:/app/blob-report
      - ./tests:/app/tests
    command: npx playwright test --reporter=line,blob --shard=2/3

  worker-3:
    image: playwright-worker:latest
    ipc: host
    environment:
      - SHARD_TOTAL=3
      - SHARD_INDEX=2
    volumes:
      - ./blob-report/worker-3:/app/blob-report
      - ./tests:/app/tests
    command: npx playwright test --reporter=line,blob --shard=3/3

  merge-reports:
    image: playwright-worker:latest
    volumes:
      - ./blob-report/worker-1:/app/blob-report/worker-1
      - ./blob-report/worker-2:/app/blob-report/worker-2
      - ./blob-report/worker-3:/app/blob-report/worker-3
      - ./allure-results:/app/allure-results
    command: bash -c "cp ./blob-report/*/* blob-report/ && npx playwright merge-reports ./blob-report/ --reporter allure-playwright ./allure-results"

  allure-report:
    image: allure-report:latest
    environment:
      - NODE_ENV=production
    volumes:
      - ./allure-report:/app/public
    ports:
      - 8080:8080
    expose:
      - 8080
```