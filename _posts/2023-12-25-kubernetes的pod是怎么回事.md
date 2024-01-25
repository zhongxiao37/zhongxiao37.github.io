---
layout: default
title: Kubernetes的若干问题
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

下面是我本地执行`kubectl exec`时候的输出

```bash
k -v=7 exec -n default nginx-64df649984-bzlzz -- env
I0125 10:40:53.922218   20776 loader.go:395] Config loaded from file:  /Users/admin/.kube/config
I0125 10:40:53.946960   20776 round_trippers.go:463] GET https://127.0.0.1:6443/api/v1/namespaces/default/pods/nginx-64df649984-bzlzz
I0125 10:40:53.946987   20776 round_trippers.go:469] Request Headers:
I0125 10:40:53.947019   20776 round_trippers.go:473]     Accept: application/json, */*
I0125 10:40:53.947027   20776 round_trippers.go:473]     User-Agent: kubectl/v1.28.4 (darwin/amd64) kubernetes/bae2c62
I0125 10:40:54.076624   20776 round_trippers.go:574] Response Status: 200 OK in 129 milliseconds
I0125 10:40:54.081344   20776 podcmd.go:88] Defaulting container name to nginx
I0125 10:40:54.081751   20776 round_trippers.go:463] POST https://127.0.0.1:6443/api/v1/namespaces/default/pods/nginx-64df649984-bzlzz/exec?command=env&container=nginx&stderr=true&stdout=true
I0125 10:40:54.081763   20776 round_trippers.go:469] Request Headers:
I0125 10:40:54.081771   20776 round_trippers.go:473]     X-Stream-Protocol-Version: v4.channel.k8s.io
I0125 10:40:54.081778   20776 round_trippers.go:473]     X-Stream-Protocol-Version: v3.channel.k8s.io
I0125 10:40:54.081784   20776 round_trippers.go:473]     X-Stream-Protocol-Version: v2.channel.k8s.io
I0125 10:40:54.081790   20776 round_trippers.go:473]     X-Stream-Protocol-Version: channel.k8s.io
I0125 10:40:54.081797   20776 round_trippers.go:473]     User-Agent: kubectl/v1.28.4 (darwin/amd64) kubernetes/bae2c62
I0125 10:40:54.218743   20776 round_trippers.go:574] Response Status: 101 Switching Protocols in 136 milliseconds
```

如果 verbose 模式改成`v=9`，可以看到 101 通信协议改成了 SPDY 了。

```bash
I0125 10:40:23.219950   20677 round_trippers.go:553] POST https://127.0.0.1:6443/api/v1/namespaces/default/pods/nginx-64df649984-bzlzz/exec?command=env&container=nginx&stderr=true&stdout=true 101 Switching Protocols in 132 milliseconds
I0125 10:40:23.219972   20677 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 132 ms
I0125 10:40:23.219981   20677 round_trippers.go:577] Response Headers:
I0125 10:40:23.219988   20677 round_trippers.go:580]     X-Stream-Protocol-Version: v4.channel.k8s.io
I0125 10:40:23.219995   20677 round_trippers.go:580]     Connection: Upgrade
I0125 10:40:23.220001   20677 round_trippers.go:580]     Upgrade: SPDY/3.1
```

SPDY 是一个被遗弃的协议，Kubernetes 团队在计划 1.30.0 版本中将 SPDY 升级为 websockets，[https://github.com/kubernetes/enhancements/issues/4006](https://github.com/kubernetes/enhancements/issues/4006)

### Service Account Token

按照 Kubernetes 的[官网](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#manually-create-an-api-token-for-a-serviceaccount)，我们可以创建自定义的 serviceaccount，并绑定指定的权限，就可以调 Kubernetes 的 API server 进行操作了。

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
EOF
```

可以通过`kubectl create token build-robot`获取一个短期的 Token，默认一个小时有效。

```jwt
eyJhbGciOiJSUzI1NiIsImtpZCI6Ild0UXhFelBad0VYa2F3N1VDU2hoSUI5bGpQOGdSTE9QZGZKMVFiZXprUmsifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjIl0sImV4cCI6MTcwNjE2MzA1MSwiaWF0IjoxNzA2MTU5NDUxLCJpc3MiOiJodHRwczovL2t1YmVybmV0ZXMuZGVmYXVsdC5zdmMiLCJrdWJlcm5ldGVzLmlvIjp7Im5hbWVzcGFjZSI6ImljcyIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJzYS1pY3MiLCJ1aWQiOiIyOGE1NGNmYS01MWM1LTQ5OWQtODVjZS0wZTczODJjZDliYzkifX0sIm5iZiI6MTcwNjE1OTQ1MSwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmljczpzYS1pY3MifQ.BWJqUF6sfK44HNtTY7M6tZYPHziEiADrVyk6b-XSHka8DdztM1-_6eQMmljFLiW2Dv0QWZMOMqMDNw1pFe-QGjh6KphcpBq1eJfv8rcpKU3blBE3f0NusxhgSScWXIkju_BmSA0j82OSprLmpbrAXmtocgV1LEhF4hrrbPz_FErqva6yTaUp1lbiFZ5x7CLzvmdZKqnI6rzzjyBcUalXhRAot26qNmKaFsWAI4mi5h5uvOiyaSe6l-kNRqhoLKueQzINF963IJenzy62Xmr-4e4BxbGX5tm2fNj6gtDJMCaCWiq-NNW_rMSrNjDqJSmE9krCCILThd39t2jk6zxviw
```

你也可以通过创建 Secret 的方式，创建一个长期有效的 token。ArgoCD 就是利用这个长期的 Token 进行自动部署的。

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: build-robot-secret
  annotations:
    kubernetes.io/service-account.name: build-robot
type: kubernetes.io/service-account-token
EOF
```

此外，还可以给 Deployment 指定的 serviceaccount，这个 token 就会自动挂载到对应的 pod 里面去，使得该 Pod 也可以访问自己的集群 API。

## Reference

1. [https://llussy.github.io/2019/12/12/kube-proxy-IPVS/](https://llussy.github.io/2019/12/12/kube-proxy-IPVS/)
