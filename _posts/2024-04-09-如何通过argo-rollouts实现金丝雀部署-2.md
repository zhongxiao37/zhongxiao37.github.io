---
layout: default
title: 如何通过Argo Rollouts实现金丝雀部署(2)
date: 2024-04-09 22:47 +0800
categories: argo
---

继上一步实现了 Argo Rollout 切分流量搭配金丝雀部署之后，我打算引入自动化测试进行版本验证，当自动化验证通过之后，则自动部署新的版本。

## Selenium 测试脚本

创建一个 Selenium 的测试脚本，

```python
from selenium import webdriver


def test_canary():
    options = webdriver.ChromeOptions()
    options.add_argument('ignore-certificate-errors')
    driver = webdriver.Remote(
      command_executor='http://selenium-hub.selenium:4444/wd/hub',
      options=options
    )
    driver.get("https://rollouts-demo.dev")
    driver.add_cookie({'name': 'Canary', 'value': 'always'})
    driver.get("https://rollouts-demo.dev")
    assert "red" in driver.page_source
    driver.quit()


def test_stable():
    options = webdriver.ChromeOptions()
    options.add_argument('ignore-certificate-errors')
    driver = webdriver.Remote(
      command_executor='http://selenium-hub.selenium:4444/wd/hub',
      options=options
    )
    driver.get("https://rollouts-demo.dev")
    driver.add_cookie({'name': 'Canary', 'value': 'never'})
    driver.get("https://rollouts-demo.dev")
    assert "yellow" in driver.page_source
    driver.quit()

```

再 build 一个 Docker 镜像

```Dockerfile
FROM python:3.10.13-slim

RUN pip install pytest selenium

WORKDIR /pytest

COPY test_bvt.py .
```

## 创建验证模版

首先创建一个 AnalysisTemplate，用来定义触发的脚本和使用的镜像。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: rollout-demo-testing
  namespace: ics
spec:
  args:
    - name: svc-name
  metrics:
    - name: selenium-test
      provider:
        job:
          metadata:
            labels:
              env: qas
          spec:
            backoffLimit: 1
            template:
              spec:
                containers:
                  - name: test
                    image: selenium-py310:latest
                    command: ["pytest", "."]
                restartPolicy: Never
```

## 更新 Rollout 步骤

更新后的 Rollout 如下，主要是在 steps 中加入了`analysis`这一步进行自动化验证。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-demo
spec:
  replicas: 2
  strategy:
    canary:
      canaryService: rollouts-demo-canary
      stableService: rollouts-demo-stable
      steps:
        # scale up to 1 pod to work with trafficeRouting
        # so that requests with specifc header will be
        # routed to canary service
        - setCanaryScale:
            replicas: 1
        - analysis:
            templates:
              - templateName: user-profile-web-testing
            args:
              - name: svc-name
                value: rollouts-demo-canary.ics.svc.cluster.local
        - pause: { duration: 15s }
```

## 验证

当新版本来了之后，rollout 会拉起新的 Pod，完成之后，会拉起一个 Job。

```bash
NAME                                                             KIND         STATUS         AGE    INFO
⟳ rollouts-demo                                                  Rollout      ◌ Progressing  2d12h
├──# revision:30
│  ├──⧉ rollouts-demo-687d76d795                                 ReplicaSet   ✔ Healthy      2d12h  canary
│  │  └──□ rollouts-demo-687d76d795-r59w5                        Pod          ✔ Running      2s     ready:1/1
│  └──α rollouts-demo-687d76d795-30-1                            AnalysisRun  ◌ Running      1s
│     └──⊞ f1d3ced9-3461-46fc-9ac9-61e1ff7d58d4.selenium-test.1  Job          ◌ Running      1s
├──# revision:29
│  └──⧉ rollouts-demo-5747959bdb                                 ReplicaSet   ✔ Healthy      2d6h   stable
│     ├──□ rollouts-demo-5747959bdb-drwf5                        Pod          ✔ Running      2d6h   ready:1/1
│     └──□ rollouts-demo-5747959bdb-tmdrn                        Pod          ✔ Running      2d6h   ready:1/1
└──# revision:22
   └──⧉ rollouts-demo-6cf78c66c5                                 ReplicaSet   • ScaledDown   2d11h  delay:passed
Name:            rollouts-demo
Namespace:       ics
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          1/3
  SetWeight:     0
  ActualWeight:  0
Images:          argoproj/rollouts-demo:blue (canary)
                 argoproj/rollouts-demo:red (stable)
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3
```

这个 Job 会执行`pytest .`命令，触发自动化测试。查看 Job 的日志，会发现自动化脚本已经执行成功，所以测试均通过。

```bash
============================= test session starts ==============================
platform linux -- Python 3.10.13, pytest-8.0.1, pluggy-1.4.0
rootdir: /pytest
collected 2 items
test_bvt.py ..                                                           [100%]
============================== 2 passed in 12.53s ==============================
```

一旦 Job completed 之后，就会 promote 新的版本。

```bash
NAME                                                             KIND         STATUS         AGE    INFO
⟳ rollouts-demo                                                  Rollout      ◌ Progressing  2d12h
├──# revision:30
│  ├──⧉ rollouts-demo-687d76d795                                 ReplicaSet   ✔ Healthy      2d12h  canary
│  │  └──□ rollouts-demo-687d76d795-r59w5                        Pod          ✔ Running      14s    ready:1/1
│  └──α rollouts-demo-687d76d795-30-1                            AnalysisRun  ✔ Successful   13s    ✔ 1
│     └──⊞ f1d3ced9-3461-46fc-9ac9-61e1ff7d58d4.selenium-test.1  Job          ✔ Successful   13s
├──# revision:29
│  └──⧉ rollouts-demo-5747959bdb                                 ReplicaSet   ✔ Healthy      2d6h   stable
│     ├──□ rollouts-demo-5747959bdb-drwf5                        Pod          ✔ Running      2d6h   ready:1/1
│     └──□ rollouts-demo-5747959bdb-tmdrn                        Pod          ✔ Running      2d6h   ready:1/1
└──# revision:22
   └──⧉ rollouts-demo-6cf78c66c5                                 ReplicaSet   • ScaledDown   2d11h  delay:passed
Name:            rollouts-demo
Namespace:       ics
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          2/3
  SetWeight:     0
  ActualWeight:  0
Images:          argoproj/rollouts-demo:blue (canary)
                 argoproj/rollouts-demo:red (stable)
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3
```

新的 Pod 被拉起来。

```bash
NAME                                                             KIND         STATUS               AGE    INFO
⟳ rollouts-demo                                                  Rollout      ◌ Progressing        2d12h
├──# revision:30
│  ├──⧉ rollouts-demo-687d76d795                                 ReplicaSet   ◌ Progressing        2d12h  canary
│  │  ├──□ rollouts-demo-687d76d795-r59w5                        Pod          ✔ Running            30s    ready:1/1
│  │  └──□ rollouts-demo-687d76d795-pc5lz                        Pod          ◌ ContainerCreating  1s     ready:0/1
│  └──α rollouts-demo-687d76d795-30-1                            AnalysisRun  ✔ Successful         29s    ✔ 1
│     └──⊞ f1d3ced9-3461-46fc-9ac9-61e1ff7d58d4.selenium-test.1  Job          ✔ Successful         29s
├──# revision:29
│  └──⧉ rollouts-demo-5747959bdb                                 ReplicaSet   ✔ Healthy            2d6h   stable
│     ├──□ rollouts-demo-5747959bdb-drwf5                        Pod          ✔ Running            2d6h   ready:1/1
│     └──□ rollouts-demo-5747959bdb-tmdrn                        Pod          ✔ Running            2d6h   ready:1/1
└──# revision:22
   └──⧉ rollouts-demo-6cf78c66c5                                 ReplicaSet   • ScaledDown         2d11h  delay:passed
Name:            rollouts-demo
Namespace:       ics
Status:          ◌ Progressing
Message:         waiting for all steps to complete
Strategy:        Canary
  Step:          3/3
  SetWeight:     100
  ActualWeight:  100
Images:          argoproj/rollouts-demo:blue (canary)
                 argoproj/rollouts-demo:red (stable)
Replicas:
  Desired:       2
  Current:       4
  Updated:       2
  Ready:         3
  Available:     3
```

流量全部分配到新的 Pod 之后，销毁老的 Pod。

```bash
NAME                                                             KIND         STATUS         AGE    INFO
⟳ rollouts-demo                                                  Rollout      ✔ Healthy      2d12h
├──# revision:30
│  ├──⧉ rollouts-demo-687d76d795                                 ReplicaSet   ✔ Healthy      2d12h  stable
│  │  ├──□ rollouts-demo-687d76d795-r59w5                        Pod          ✔ Running      67s    ready:1/1
│  │  └──□ rollouts-demo-687d76d795-pc5lz                        Pod          ✔ Running      38s    ready:1/1
│  └──α rollouts-demo-687d76d795-30-1                            AnalysisRun  ✔ Successful   66s    ✔ 1
│     └──⊞ f1d3ced9-3461-46fc-9ac9-61e1ff7d58d4.selenium-test.1  Job          ✔ Successful   66s
├──# revision:29
│  └──⧉ rollouts-demo-5747959bdb                                 ReplicaSet   • ScaledDown   2d6h
│     ├──□ rollouts-demo-5747959bdb-drwf5                        Pod          ◌ Terminating  2d6h   ready:1/1
│     └──□ rollouts-demo-5747959bdb-tmdrn                        Pod          ◌ Terminating  2d6h   ready:1/1
└──# revision:22
   └──⧉ rollouts-demo-6cf78c66c5                                 ReplicaSet   • ScaledDown   2d11h  delay:passed
Name:            rollouts-demo
Namespace:       ics
Status:          ✔ Healthy
Strategy:        Canary
  Step:          3/3
  SetWeight:     100
  ActualWeight:  100
Images:          argoproj/rollouts-demo:blue (stable)
Replicas:
  Desired:       2
  Current:       2
  Updated:       2
  Ready:         2
  Available:     2
```
