---
layout: default
title: 搭了一个Kubernetes Dashboard
date: 2024-11-29 21:04 +0800
categories: kubernetes
---

我搭了一个Kubernetes Dashboard。

<img src="/images/kubernetes_dashboard.png" style="width=800px" />

## Problem

无法快速查看多个Kubernetes集群的Deployment版本号，以及环境变量。

虽然我们可以用`kubectl`通过切换集群的方式查看版本，但是这就意味着我需要切换多个集群。这样非常重复，繁琐。


## 思路


### 网页 V.S. 脚本

最简单的方法就是自己写一个脚本，切换多个集群，查看版本号，和环境变量。但这就意味着大家都需要安装你的脚本，对于非开发人员来说，他们还需要熟悉对应的编程语言，也不利于新版本的更新。所以，想法就是做一个网页。

### KubeConfig V.S. Service Account

最开始的时候，自己把自己的`kubeconfig`放到镜像里面去，这样的弊端很显然，如果有人做镜像里面credentials的扫描，就和repo扫描一样，会被安全团队邮件通报的。

我想到了用Service Account，我可以通过下面的ServiceAccount，而不是把自己的credentials放到镜像里面去。

但是问题还是没有解决，用service account只是解决了自己的credentials不被泄露，但是service account的credentials会被泄露。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-api-role
rules:
  - apiGroups:
      - "apps"
    resources:
      - deployments
      - deployments/scale
      - replicasets
    verbs:
      - get
      - list
      - patch
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: k8s-api
  namespace: devops
  labels:
    tier: devops
secrets:
  - name: secret-k8s-api
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: k8s-api-rolebinding
  labels:
    tier: k8s-api
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-api-role
subjects:
  - kind: ServiceAccount
    name: k8s-api
    namespace: devops
---
kind: Secret
apiVersion: v1
metadata:
  name: secret-k8s-api
  namespace: devops
  annotations:
    kubernetes.io/service-account.name: k8s-api
type: kubernetes.io/service-account-token
```


### 将Service Account的token通过Secrets挂载进去

将Credentials通过Secrets的方式挂载进去，可以解决这个泄露Service Account泄露的问题，至少镜像里面没有credentials了，repo里面也没有credentials了。

### 多个project/namespaces

后来随着集群的扩展，项目的增多，需要不定期更新集群信息和Project信息。如果通过ConfigMap挂载进去的方式，很显然每次都要重启Pod。所以，我们需要一个数据库持久化这些配置。我们就建一个数据库，然后只存不到几KB的信息？就算是SQLite，我都觉得有些重，你还得引入其他包，建bucket保存数据库文件。

可以考虑极简的方式，配置信息依旧保存在ConfigMap，只是不要挂载进去，而是每次都读取ConfigMap。Kubernetes的ConfigMap，背后本来就是一个数据库。

我甚至想过用CRD去实现Pod的自动重启，但是，这感觉简直是核武打蚊子。

### SSO

因为环境变量涉及敏感的信息，我做了SSO，针对敏感页面和API，做了SSO限制。


### Next.JS vs Express

我的第一版是用Express作为后端，Next.JS作为前端。但是，我只是将Next.JS作为打包成为JS的工具，现在想想，Vite应该是更适合干这样的事情。

后来，Next.JS的全栈功能吸引了我。有过Rails开发经验的我，想看看Next.JS是如何实现的。用一个语言实现前后端还是觉得有点纠结：

1. 对于纯前端开发来说，后端不是单纯的HTML + CSS，需要和数据库，网络，多个微服务打交道。
2. 有些包只能够在NodeJS环境中运行，如果在前端引入会报错。尤其是Next.JS默认是Server Side Component，除非自己显示写`use client`。
3. Next.JS做了SEO优化，在build是时候，会尝试去缓存这些页面/API的结果。我不希望它去缓存API的结果，因为这样会导致每次API的结果都是一样的。

