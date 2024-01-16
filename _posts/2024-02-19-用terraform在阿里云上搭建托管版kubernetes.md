---
layout: default
title: 用Terraform在阿里云上搭建托管版Kubernetes
date: 2024-02-19 18:05 +0800
categories: terraform aliyun kubernetes
---

继上次用 Terraform 把环境对齐之后，终于可以开始用 Terraform 在阿里云上搭建 Kubernetes 了。不过为了方便理解，还是从零开始搭建。

## VPC

第一件事情肯定是指定 VPC 网段。

```json
// dev/terraform.tfvars.json
"vpc": {
    "name": "dev-vpc",
    "cidr": "10.127.8.0/23"
  },
```

对应的 VPC module

```terraform
<!-- modules/vpc/main.tf -->
variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "alicloud_vpc" "vpc" {
  vpc_name   = var.vpc_name
  cidr_block = var.vpc_cidr
  tags       = var.tags
}
```

## 交换机 VSW

接下来是规划网段，将上面的 VPC 分割成几个网段，分别是数据库，负载均衡，k8s 和 pod 使用。其中 k8s 和 pod 要在相同的两个可用区。

```json
// dev/terraform.tfvars.json
"vsws": {
    "dev-slb-j": {
      "name": "dev-slb",
      "zone_id": "j",
      "cidr": "10.127.8.0/28"
    },
    "dev-slb-k": {
      "name": "dev-slb",
      "zone_id": "k",
      "cidr": "10.127.8.16/28"
    },
    "dev-postgres-g": {
      "name": "dev-postgres",
      "zone_id": "g",
      "cidr": "10.127.8.32/28"
    },
    "dev-postgres-h": {
      "name": "dev-postgres",
      "zone_id": "h",
      "cidr": "10.127.8.48/28"
    },
    "dev-k8s-j": {
      "name": "dev-k8s",
      "zone_id": "j",
      "cidr": "10.127.8.64/28"
    },
    "dev-k8s-l": {
      "name": "dev-k8s",
      "zone_id": "l",
      "cidr": "10.127.8.80/28"
    },
    "dev-pod-j": {
      "name": "dev-pod",
      "zone_id": "j",
      "cidr": "10.127.9.0/25"
    },
    "dev-pod-l": {
      "name": "dev-pod",
      "zone_id": "l",
      "cidr": "10.127.9.128/25"
    }
  },
```

```terraform
<!-- modules/vswitch/main.tf -->
resource "alicloud_vswitch" "vswitch" {
  vpc_id            = var.vpc_id
  cidr_block        = var.cidr_block
  zone_id           = var.zone_id
  vswitch_name      = var.vswitch_name
  tags = var.tags
}
```

## NAT

VPC 需要访问 Internet，所以需要一个 NAT，并绑定了 EIP 和交换机。这样，这些网段就可以访问 Internet 了。

```json
// dev/terraform.tfvars.json
"ngws": {
    "dev-ngw": {
      "nat_gateway_name": "dev-ngw",
      "payment_type": "PayAsYouGo",
      "vswitch_name": "dev-slb-k",
      "nat_type": "Enhanced",
      "eip_name": "dev-ngw-eip",
      "eip_bandwidth": "200",
      "eip_internet_charge_type": "PayByTraffic",
      "eip_isp": "BGP",
      "snat_vsws": [
        "dev-postgres-g",
        "dev-postgres-h",
        "dev-pod-j",
        "dev-pod-l",
        "dev-slb-j",
        "dev-slb-k",
        "dev-k8s-j",
        "dev-k8s-l"
      ]
    }
  },
```

```terraform
<!-- modules/ngw/main.tf -->
resource "alicloud_nat_gateway" "nat" {
  vpc_id           = var.vpc_id
  nat_gateway_name = var.nat_gateway_name
  payment_type     = var.payment_type
  vswitch_id       = var.vswitch_id
  nat_type         = var.nat_type
  tags             = var.tags
}

resource "alicloud_eip_address" "eip_ngw" {
  address_name         = var.eip_name
  bandwidth            = var.eip_bandwidth
  internet_charge_type = var.eip_internet_charge_type
  isp                  = var.eip_isp
  tags                 = var.tags
}

resource "alicloud_eip_association" "eip_asso" {
  allocation_id = alicloud_eip_address.eip_ngw.id
  instance_id   = alicloud_nat_gateway.nat.id
  force         = false
}

resource "alicloud_snat_entry" "snat-vsw" {
  for_each = {for s in var.snat_vsws : s => lookup(var.vsws, s, { "vsw_id" : "" }).vsw_id}

  snat_table_id     = alicloud_nat_gateway.nat.snat_table_ids
  source_vswitch_id = each.value
  snat_ip           = join(",", alicloud_eip_address.eip_ngw.*.ip_address)

  depends_on        = [alicloud_eip_association.eip_asso]
}
```

## 安全组

安装组可以理解为防火墙，用来控制那些网络请求可以通过。比如，我这里创建了两个规则，允许 VPC 里面的所有 IP 和端口互通。另外一个规则就是允许通过 NAT 访问互联网。

```json
// dev/terraform.tfvars.json
"sgs": {
  "dev-sg-ack": {
      "name": "dev-sg-ack",
      "description": "Security group for dev-sg-ack within VPC",
      "rules": {
        "allow_internal_vpc": {
          "cidr_block": "10.127.8.0/23",
          "description": "allow aliyun internal VPC network",
          "nic_type": "intranet",
          "policy": "accept",
          "port_range": "-1/-1",
          "priority": "1",
          "protocol": "all",
          "rule_id": "1",
          "type": "ingress"
        },
        "allow_dev_nat_gateway": {
          "cidr_block": "99.99.99.99/32",
          "description": "allow aliyun DEV NAT gateway",
          "nic_type": "intranet",
          "policy": "accept",
          "port_range": "-1/-1",
          "priority": "1",
          "protocol": "all",
          "rule_id": "2",
          "type": "ingress"
        }
      }
    },
}
```

## ACK

ACK 就比较简单了，把上面的交换机，安全组填进去，拉起 ACK master 节点和节点池就行了。需要注意的是，`worker_instance_type`需要是可用区里面有的机型，比如我第一次用`ecs.c7.2xlarge`就没有对应的机型，换成`ecs.c6.2xlarge`就可以了。

当然，你也可以用 Terraform 的`data_source`查看支持的机型有哪些。

最后测试了一下，拉起 ACK 大概要 5 分钟左右就可以了。想想自己搭建 Kubernetes 集群，不花个 2、3 个小时弄不完的。

```json
// dev/terraform.tfvars.json
"ack": {
    "k8s_name": "dev",
    "cluster_spec": "ack.pro.small",
    "k8s_version": "1.28.3-aliyun.1",
    "worker_vswitch_names": ["dev-k8s-j", "dev-k8s-l"],
    "pod_vswitch_names": ["dev-pod-j", "dev-pod-l"],
    "worker_instance_type": "ecs.c6.2xlarge",
    "worker_system_disk_category": "cloud_efficiency",
    "worker_system_disk_size": 40,
    "worker_size": 2,
    "security_group_name": "dev-sg-ack",
    "worker_image_id": "aliyun_2_1903_x64_20G_alibase_20231008.vhd"
  },
```

```terraform
<!-- modules/ack/main.tf -->
resource "alicloud_cs_managed_kubernetes" "k8s" {
  name = var.k8s_name
  cluster_spec = var.cluster_spec
  version      = var.k8s_version
  # worker switches
  worker_vswitch_ids = var.worker_vswitch_ids

  # pod switches
  pod_vswitch_ids = var.pod_vswitch_ids

  # using existing nat gateway from switch
  new_nat_gateway = false
  service_cidr = var.service_cidr
  slb_internet_enabled = true

  dynamic "addons" {
    for_each = var.cluster_addons
    content {
      name   = lookup(addons.value, "name", var.cluster_addons)
      config = lookup(addons.value, "config", var.cluster_addons)
    }
  }
}

resource "alicloud_cs_kubernetes_node_pool" "default" {
  name                 = var.k8s_name
  cluster_id           = alicloud_cs_managed_kubernetes.k8s.id
  vswitch_ids          = var.worker_vswitch_ids
  instance_types       = [var.worker_instance_type]
  image_id             = var.worker_image_id
  system_disk_category = var.worker_system_disk_category
  system_disk_size     = var.worker_system_disk_size
  desired_size         = var.worker_size
}
```
