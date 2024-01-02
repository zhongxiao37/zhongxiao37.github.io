---
layout: default
title: 如何利用Terraform导入现有Infra
date: 2023-12-29 15:39 +0800
categories: terraform
---

需求是把现有阿里云 Infra 转为 Terraform 代码，方便以后实现 gitops。

## 创建 RAM 用户

需要先创建一个 RAM 用户，生成 AK/SK。

<img src="/images/alicloud_ram_user.png" width="800px" >

## 给用户赋予权限

暂时先给个 Admin 权限

<img src="/images/alicloud_ram_permission.png" width="800px" >

翻了[阿里云的官网](https://www.alibabacloud.com/help/zh/terraform/latest/install-and-configure-terraform-in-the-local-pc?spm=a2c63.p38356.0.0.61a02093HAB8wG)，也不告诉到底需要啥权限。

<img src="/images/alicloud_ram_doc.png" width="800px">

## 安装 Terraform

参见官网[doc](https://developer.hashicorp.com/terraform/install)

```bash
brew install terraform
```

## 查看现有 Infra 的资源

可以在阿里云的 Console 上查看所有资源，也可以通过[Terraformer](https://github.com/GoogleCloudPlatform/terraformer)导入现有的 Infra，方便后面作为参考。

```bash
terraformer import alicloud --resources="*" --regions=cn-beijing
```

## 最佳实践

根据 Google 的最佳实践，每个环境一个目录，每个应用一个 module。

[https://cloud.google.com/docs/terraform/best-practices-for-terraform?hl=zh-cn#helper-scripts](https://cloud.google.com/docs/terraform/best-practices-for-terraform?hl=zh-cn#helper-scripts)

```bash
-- SERVICE-DIRECTORY/
   -- OWNERS
   -- modules/
      -- <service-name>/
         -- main.tf
         -- variables.tf
         -- outputs.tf
         -- provider.tf
         -- README
      -- ...other…
   -- environments/
      -- dev/
         -- backend.tf
         -- main.tf

      -- qa/
         -- backend.tf
         -- main.tf

      -- prod/
         -- backend.tf
         -- main.tf
```

## 导入现有资源

### 创建 module

拿 VPC 举例，我们需要先创建好`modules/vpc/main.tf`文件。

```tf
variable "vpc_name" {}
variable "vpc_cidr" {}
variable "tags" {}

resource "alicloud_vpc" "vpc" {
  vpc_name   = var.vpc_name
  cidr_block = var.vpc_cidr
  tags       = var.tags
}
```

### 更新环境 main.tf

创建`environments/dev/main.tf` 文件。

```tf
provider "alicloud" {
  region  = "cn-beijing"
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name = var.vpc.name
  vpc_cidr = var.vpc.cidr
  tags     = var.tags
}
```

### 更新 tfvar

创建`terraform.tfvar.json`文件。

```json
{
  "region": "cn-beijing",
  "vpc": {
    "name": "dev-pzhong-vpc-cnn2",
    "cidr": "10.246.8.0/23"
  },
  "tags": {
    "ENV": "pzhong-dev",
    "Usage": "Terraform"
  }
}
```

### 导入资源

首先执行一次`terraform init && terraform plan`，可以看见 Terraform 计划创建一个新的 VPC`module.vpc.alicloud_vpc.vpc`。

```bash
  # module.vpc.alicloud_vpc.vpc will be created
  + resource "alicloud_vpc" "vpc" {
      + cidr_block            = "10.246.8.0/23"
      + create_time           = (known after apply)
      + id                    = (known after apply)
      + ipv6_cidr_block       = (known after apply)
      + ipv6_cidr_blocks      = (known after apply)
      + name                  = (known after apply)
      + resource_group_id     = (known after apply)
      + route_table_id        = (known after apply)
      + router_id             = (known after apply)
      + router_table_id       = (known after apply)
      + secondary_cidr_blocks = (known after apply)
      + status                = (known after apply)
      + tags                  = {
          + "ENV"   = "pzhong-dev"
          + "Usage" = "Terraform"
        }
      + user_cidrs            = (known after apply)
      + vpc_name              = "dev-pzhong-vpc-cnn2"
    }

Plan: 1 to add, 0 to change, 1 to destroy.

──────────
```

这个不是我们想要的，我们要的是导入现有的。在阿里云的 VPC 上找到需要导入的 VPC ID，执行下面的命令，就可以导入这个资源了。

```bash
terraform import 'module.vpc.alicloud_vpc.vpc' vpc-2zeg*************
```

### 验证导入

我们可以再次`terraform plan`，如果显示没有变化的话，就说明导入成功。

<img src="/images/terraform_import.png" width="800px">

接下来继续导入其他的 Infra 就可以了。

## 复杂的 Terraform

一般一个 VPC 下面会有多个交换机，可以创建一个`modules/vswitch`的 module，然后在`environments/dev/main.tf`里面去创建多个交换机。

比如 module 文件如下。

```tf
resource "alicloud_vswitch" "vswitch" {
  vpc_id            = var.vpc_id
  cidr_block        = var.cidr_block
  zone_id           = var.zone_id
  vswitch_name      = var.vswitch_name
  tags = var.tags
}
```

tfvar 文件里面定义两个交换机

```json
{
  "vsws": [
    {
      "name": "dev-pzhong-slb-cnn2",
      "zone_id": "j",
      "cidr": "10.246.8.0/28"
    },
    {
      "name": "dev-pzhong-slb-cnn2",
      "zone_id": "k",
      "cidr": "10.246.8.16/28"
    }
  ]
}
```

`environments/dev/main.tf` 就可以通过 Terraform 的 [meta argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count) 来实现循环。

```tf
module "vsw" {
  source       = "../modules/vswitch"
  count        = length(var.vsws)
  vpc_id       = module.vpc.vpc_id
  vswitch_name = "${var.vsws[count.index].name}-${var.vsws[count.index].zone_id}"
  zone_id      = "${var.region}-${var.vsws[count.index].zone_id}"
  cidr_block   = var.vsws[count.index].cidr
  tags         = var.tags
}
```

而导入命令也就会变成 `terraform import "module.vsw[0].alicloud_vswitch.vswitch" vsw-2ze7o***********`。需要留意中间`module.vsw`后面的`[0]`编号。

## 如何使用 terraform_remote_state

Terraform 还提供`terraform_remote_state`, 可以通过远端的 state 文件，获取 `outputs` 的 resource 信息。下面的例子就是从本地的`terraform.tfstate`文件中获取 `outputs` 是`vpc_id`的值。

```tf
data "terraform_remote_state" "vpc" {
  backend = "local"
}

module "vsw" {
  source       = "../modules/vswitch"
  ...
  # vpc_id       = module.vpc.vpc_id
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  ...
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

需要提前声明`output "vpc_id"`，并且`terraform plan`一次更新`state`文件。操作完之后，可以留意到`tfstate`文件内容多了`outputs`。

<img src="/images/terraform_outputs.png" width="800px">

通过 state 文件，可以从其他 Terraform 配置中获取到 outputs。但个人认为这样做的话，在新建环境的时候，还需要解决其他 Terraform 依赖的问题，而且这些依赖比较隐晦。

## 如何使用 data_source

有时候，自己还没有完全把其他 Infra 转为 gitops，也可以通过`data_source`引用远端的资源，以后再逐步转换。

比如这里就是找到阿里云账号下名字是`pzhong-vpc-cnn2`的 VPC 资源。

```tf

data "alicloud_vpcs" "vpcs_ds" {
  name_regex = "pzhong-vpc-cnn2"
}

```

稍后，就可以通过`data.alicloud_vpcs.vpcs_ds.vpcs.0.vpc_id`取到这个资源的`vpc_id`了。[文档](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/vpcs)

```tf
module "vsw" {
  source       = "../modules/vswitch"
  ...
  # vpc_id       = module.vpc.vpc_id
  # vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_id = data.alicloud_vpcs.vpcs_ds.vpcs.0.vpc_id
  ...
}
```

和 `terraform_remote_state`一样，在逐步转换的过程中可以这样做，但是新建环境的时候，可能会发现还缺失某些依赖。

## Reference

1. [https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/security_group_rules](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/security_group_rules)
