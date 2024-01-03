---
layout: default
title: Kubernetes的Pod是怎么回事
date: 2023-12-25 22:06 +0800
categories: kubernetes
---

从问题的角度去理解 Kubernetes

### Kubernetes 里面的 Pod 是如何通信的

Pod 不是简单的容器，一个 Pod 里面可以跑两个 Container，那这两个 container 是如何通信的呢？看上去好像是一台虚拟机上跑了两个应用而已，但实际上只是一个 container 加入了另外一个 container 的 Namespace，共享了 net 和 ipc。

Pod 背后实际上是有一个 pause 镜像跑起来的 infra 容器，提供了 parent Namespace，这样用户的 container 就可以加入这个 infra 容器的 Namespace，再利用 IPC 进行互相的通信了。

Pod 实际上是在扮演传统基础设拖里'虚拟机'的角色，容器则是这个虚拟机里运行的用户程序。

### kubectl attach v.s. kubectl exec

attach 是连接到 container 里面的主进程，而 exec 是可以指定任何运行程序。

### Deployment yaml 里面哪些是 Pod 级别的属性，哪些是 Container 级别的属性

网络，存储，安全，调度相关的，都是 Pod 级别的，因为它们都和'虚拟机'相关。

### Kubernetes 是如何控制伸缩的

Kubernetes 是通过 ReplicaSet API 来控制 Pod 的伸缩和滚动发布的。
