---
layout: default
title: 如何通过Argo Rollouts实现金丝雀部署(1)
date: 2024-03-29 23:12 +0800
categories: argo
---

Argo 家简直是在 Kubernetes 上实现 GitOps 的大杀器，本来 ArgoCD 搭配 Kubernetes 原生的 Rollout 就够用了，但不行，还要实践蓝绿部署，金丝雀部署。

## 什么是 Rollouts

其实和 Deployment 类似，也是控制 Pod 的，看具体的 yaml 也会发现差不多，但是却多了一个[渐进性部署](https://argoproj.github.io/argo-rollouts/)的功能。

## 什么是金丝雀部署

“金丝雀” 一词是指 “煤矿中的金丝雀” 的做法，即把金丝雀带入煤矿以保证矿工的安全。 如果出现无味的有害气体，鸟就会死亡，而矿工们知道他们必须迅速撤离。 同样，如果更新后的代码出了问题，新版本就会被 “疏散” 回原来的版本。

金丝雀部署是一种部署策略，开始时有两个环境：一个有实时流量，另一个包含没有实时流量的更新代码。 流量逐渐从应用程序的原始版本转移到更新版本。 它可以从移动 1% 的实时流量开始，然后是 10%，25%，以此类推，直到所有流量都通过更新的版本运行。 企业可以在生产中测试新版本的软件，获得反馈，诊断错误，并在必要时快速回滚到稳定版本。

## 安装

先按照官网，安装 Argo Rollouts，其实就是 CRD、SA 和 Controller 那一套。

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

## 创建 Demo

创建 demo Rollout。第一次部署不会有什么惊喜，但是它会像创建 Deployment 一样，拉起 Pod。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-demo
spec:
  replicas: 2
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {}
        - setWeight: 40
        - pause: { duration: 10 }
        - setWeight: 60
        - pause: { duration: 10 }
        - setWeight: 80
        - pause: { duration: 10 }
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollouts-demo
  template:
    metadata:
      labels:
        app: rollouts-demo
    spec:
      containers:
        - name: rollouts-demo
          image: argoproj/rollouts-demo:blue
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          resources:
            requests:
              memory: 32Mi
              cpu: 5m
---
apiVersion: v1
kind: Service
metadata:
  name: rollouts-demo
spec:
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: rollouts-demo
```

## 升级版本

用命令更新 image 的 tag，触发 Rollout 更新。

```bash
kubectl argo rollouts set image rollouts-demo \
  rollouts-demo=argoproj/rollouts-demo:yellow
```

watch 一下，发现拉起了一个新的 pod。根据之前的设置，会有 20%的流量打到金丝雀部署里面了。

```bash
Name:            rollouts-demo
Namespace:       default
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/2
  SetWeight:     0
  ActualWeight:  0
Images:          argoproj/rollouts-demo:blue (stable)
                 argoproj/rollouts-demo:yellow (canary)
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3

NAME                                       KIND        STATUS        AGE    INFO
⟳ rollouts-demo                            Rollout     ॥ Paused      12h
├──# revision:22
│  └──⧉ rollouts-demo-6cf78c66c5           ReplicaSet  ✔ Healthy     12h    canary
│     └──□ rollouts-demo-6cf78c66c5-lrp7n  Pod         ✔ Running     66m    ready:1/1
├──# revision:21
│  └──⧉ rollouts-demo-5747959bdb           ReplicaSet  ✔ Healthy     6h57m  stable
│     ├──□ rollouts-demo-5747959bdb-drwf5  Pod         ✔ Running     6h56m  ready:1/1
│     └──□ rollouts-demo-5747959bdb-tmdrn  Pod         ✔ Running     6h56m  ready:1/1
└──# revision:9
   └──⧉ rollouts-demo-687d76d795           ReplicaSet  • ScaledDown  12h
```

## 查看 ArgoCD

搭配 ArgoCD，效果更好。可以看到，新的 ReplicaSet 被创建，同时有了新的 pod。

创建一个新的 kustomize.yml 文件，并创建 ArgoCD application，就可以看到下面的图。

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: rollouts-demo
  namespace: ics

resources:
  - rollouts-demo.yml
  - service-demo.yml

images:
  - name: argoproj/rollouts-demo:blue
    newTag: yellow
```

<img src="/images/argo_rollouts.png" width="800px">

## 手动部署或者回滚

```bash
kubectl argo rollouts promote rollouts-demo
kubectl argo rollouts abort rollouts-demo
```

## 自动部署或者回滚

可以在 steps 中加入 Analysis 步骤，触发测试脚本，确认一切 ok 之后，自动部署。

如果测试失败，版本会被回滚。相应的代码也要回滚，否则 ArgoCD 上会一直显示 Degraded 的状态。

## 流量控制

一般来说，金丝雀就是要把一丢丢流量丢给新版本进行测试，但是我不想这样做，我更希望等我测试完毕之后再切流量过去。这点也可以按照[文档的配置](https://argoproj.github.io/argo-rollouts/features/specification/)实现。

按照下面的配置，新版本来了之后，会有一个新的 pod 拉起来，并且通过 Header/Cookie 来切流量到新的 Pod。

```yaml
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
        - pause: {}
      trafficRouting:
        nginx:
          stableIngress: user-profile-ingress
          additionalIngressAnnotations:
            canary-by-header: X-Canary
            canary-by-header-value: iwantsit
            canary-by-cookie: Canary
```

## 背后的原因

其实 Kubernetes 的 Ingress-Nginx controller 是支持[金丝雀部署](https://kubernetes.github.io/ingress-nginx/examples/canary/)的。这里会创建和原来 Ingress 一样的 Ingress，只是多了几个 Canary 相关的注解，从而在 Ingress-Nginx Controller 上实现分流。

需要注意的是，在上面的例子中，我们不要设置 weight，否则会导致按照 weight 拆分的流量才会打到新版本。按照[文档](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#canary)的解释，weight 和 http header 是有优先级关系，需要多测试一下。我自己测试的结果是 weight 的优先级更高，会直接把一部分流量分给新版本。如果 weight 设置为 0，则会验证 http header 进行分流。
