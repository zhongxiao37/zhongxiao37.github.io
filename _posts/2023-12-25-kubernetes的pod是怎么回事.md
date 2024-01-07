---
layout: default
title: Kubernetes 99问
date: 2023-12-25 22:06 +0800
categories: kubernetes
---

从问题的角度去理解 Kubernetes，我并没有列 99 个问题，只是想说，尽可能多地问

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

### Kubernetes 里面为什么要有 service

因为 Pod 是动态伸缩的，所以它们的 IP 是不固定的，为了解决这个问题，我们需要在 Pod 前面加个代理，service 就出现了。对于 Ingress 而言，service 的 IP 是一致不变的，所以 Ingress 这一套就不用动了。动的只需要是 Service 背后的 pods。

### Service 是如何访问到 Pods 的

kube-proxy。 如果看过 clash 源码的童鞋可能知道，clash 的背后其实就是设置了很多 iptables 规则，去进行包的转发。同样，在 Kubernetes 里面，kube-proxy 也是通过 iptables/ipvs 来实现代理，从而实现 service 到 pod 消息的转发。

### 为什么现在几乎都用 ipvs 了

iptables 本来是设计给防火墙用的，不是天生用来做这种负载均衡的事情。当 pods 数量超过 1000 的时候，iptables 里面的规则就非常多，即使在内核态工作，也扛不住这么玩。举个例子，单纯让一个 service 转发到 3 个 pods，就可能写上超过 7 条的规则，而且还是一个规则套另外一个规则。

此外，整个规则是放在一个链表里面的，如果要查询就只能够 table scan，效率很低。

ipvs 原生就是做负载均衡的，和 iptables 一样工作在 OSI 网络第四层（对比 Nginx 是工作 OSI 网络第 7 层，支持域名级别的负载均衡）。对于一个 service 转发到 2 个 pods，就只需要 2 条记录就行了。此外，ipvs 背后使用 hash 表，加快了查询速度。

题外话。网上问到为什么 ipvs 比 iptables 快的时候，大家简单归结为 ipvs 用的是 hash 表，查询速度快；或者说 ipvs 工作在内核态，比 iptables 快，这些都是不完整的。ipvs 和 iptables 都工作在内核态，都是 OSI 第四层，就算 iptables 把数据结构换成 hash 表，也会比 ipvs 慢，因为 iptables 的设计上会把规则一层一层套上去，导致规则太多。

### 如何在 node 上访问 service

试试 `<svc-name>.<namespace>.svc.cluster.local`就可以通过 service 访问到背后的 pods

### 怎么查看 ipvs 背后代理的 pods

```bash
ipvsadm -Ln
```

### kubectl exec 是如何工作的

`kubectl exec`的时候加上`-v=7`就可以看到，kubectl 实际上是与 Kubernetes master API 建立 SPDY，然后请求 Kubelet 在相应 Pod 中的容器上执行指定的命令。Kubelet 通过 CRI 的 API 与容器进行通信，建立连接后，加入到对应 pod 的 namespace，再返回 response 的。

<img src="/images/kubectl-exec.png" width="800px">

## Reference

1. [https://llussy.github.io/2019/12/12/kube-proxy-IPVS/](https://llussy.github.io/2019/12/12/kube-proxy-IPVS/)
