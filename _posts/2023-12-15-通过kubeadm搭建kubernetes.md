---
layout: default
title: 通过kubeadm搭建kubernetes
date: 2023-12-15 17:52 +0800
categories: kubernetes
---

最近在《深入剖析 Kubernetes》，顺手搭建一个 K8S。

## 搭建 EC2

首先起 3 台 EC2，如下图所示。

1. 新建一个 VPC。
2. 两个子网，public 子网连接 IGW，可以访问互联网，private 子网可以通过 NAT 访问互联网。
3. 开启 ssh，加上 keypair，master 节点还兼职堡垒机。
4. 可以临时把私钥放到堡垒机上，做完最后操作之后删掉即可。

<img src="/images/AWS_k8s.png" width="800" />

```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "cn-north-1"
  profile = "ids-ml-data"
}


resource "aws_vpc" "vpc_ics_ml" {
  cidr_block       = "10.247.36.0/23"
  instance_tenancy = "default"
}

resource "aws_subnet" "sub_pub" {
  vpc_id = aws_vpc.vpc_ics_ml.id
  cidr_block = "10.247.36.0/24"
  availability_zone = "cn-north-1a"
}

resource "aws_route_table" "rtb_pub" {
  vpc_id = aws_vpc.vpc_ics_ml.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_ics_ml.id
}

resource "aws_route" "route_pub" {
  route_table_id = aws_route_table.rtb_pub.id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rta_pub" {
  subnet_id = aws_subnet.sub_pub.id
  route_table_id = aws_route_table.rtb_pub.id
}


resource "aws_subnet" "sub_pri" {
  vpc_id = aws_vpc.vpc_ics_ml.id
  cidr_block = "10.247.37.0/24"
  availability_zone = "cn-north-1a"
}

resource "aws_route_table" "rtb_pri" {
  vpc_id = aws_vpc.vpc_ics_ml.id
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "eipalloc-xxx" # replace this with your EIP
  subnet_id = aws_subnet.sub_pub.id # nat gateway should be in public subnet
  depends_on = [aws_route.route_pub]
}

resource "aws_route" "to_nat_gateway" {
  route_table_id         = aws_route_table.rtb_pri.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

resource "aws_route_table_association" "rta_pri" {
  subnet_id = aws_subnet.sub_pri.id
  route_table_id = aws_route_table.rtb_pri.id
}


# allow ping from VPC nodes
resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_vpc.vpc_ics_ml.default_security_group_id
  ip_protocol = "icmp"
  cidr_ipv4 = "10.247.36.0/23"
  from_port = -1
  to_port = -1
}

# allow ssh from specific IP
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_vpc.vpc_ics_ml.default_security_group_id
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0" # 换成你的电脑的公网IP，避免当个肉鸡
  from_port = 22
  to_port = 22
}

resource "aws_vpc_security_group_ingress_rule" "tcp_6443" {
  security_group_id = aws_vpc.vpc_ics_ml.default_security_group_id
  ip_protocol = -1
  cidr_ipv4 = "10.247.36.0/23"
  from_port = -1
  to_port = -1
}



resource "aws_instance" "master" {
  ami = "ami-053dc158fc11748a4"
  instance_type = "t3.large"
  subnet_id = aws_subnet.sub_pub.id
  associate_public_ip_address = true
  key_name = "webapp-keypair"

  tags = {
    Name = "master server"
  }
}

resource "aws_instance" "node" {
  count = 2
  ami = "ami-053dc158fc11748a4"
  instance_type = "t3.large"
  subnet_id = aws_subnet.sub_pri.id
  key_name = "webapp-keypair"

  tags = {
    Name = "node server ${count.index}"
  }
}

```

## 搭建 k8s

本文是按照[B 站视频](https://www.bilibili.com/video/BV1ou4y1a7LR/)搭建的，文字版可以看[文章](https://learn-k8s-from-scratch.readthedocs.io/en/latest/k8s-install/kubeadm-cn.html#fix-node-internal-ip-issue)。虽然说已经有了文章了，但是里面还是有些小坑需要注意。

### 安装 kubeadm kubelet

按照文章安装 kubeadm kubelet containerd kubectl。

### enp0s8 网卡

像我这种新拉起来的 EC2 是没有 enp0s8 网卡的，所以可以跳过 enp0s8 的改动。

### containerd 没有启动

在安装完`containerd`之后，发现`containerd`没有跑起来，进而导致`kuberlet`也没有跑起来。运行`systemctl status kubelet`，发现是`containerd`在拉取 pause 镜像的时候报错。国内的环境，导致网络超时。鉴于之前已经通过 mirror 拉取过一次镜像了，可以修改`/etc/containerd/config.toml`文件中的镜像地址，然后再`systemctl restart containerd`和`systemctl enable containerd`。

### crictl 报错

因为现在 k8s 的 runtime 都切换成 containerd 了，所以通过`docker images`就不可能了，替代是通过`crictl`。我遇到报错`Error while dialing dial unix /var/run/dockershim.sock: connect: no such file or directory`，需要修改`/etc/crictl.yaml`文件中如下。最后再执行`crictl images`查看所有镜像。

```yml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: true
pull-image-on-create: false
```

### 检查节点

最后执行`kubectl get nodes -o wide` `kubectl get pods -A`查看所有的节点和 Pod，确保所有的状态是 running。

<img src="/images/k8s_nodes.png" width="800" />
