---
layout: default
title: 通过Terraform搭建VPC+TGW互通
date: 2023-12-11 22:27 +0800
categories: terraform
---

目标是，在两个 VPC 上搭建两个 EC2，然后通过 TGW 将两个 VPC 打通。

![transit-gateway-overview.png](/images/transit-gateway-overview.png)

## 构建 ec2 module

首先创建`modules/ec2/main.tf`文件，分别通过参数创建 VPC，并允许 SSH 和 ICMP 协议。再在 VPC 上起一个 EC2。

```tf
# modules/ec2/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "vpc_cidr_block" {
  type = string
}

variable "vpc_subnets" {
  type = set(string)
}


resource "aws_vpc" "vpc-ics-ml" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"
}

resource "aws_subnet" "sub-webapp" {
  vpc_id = aws_vpc.vpc-ics-ml.id
  cidr_block = var.vpc_cidr_block
  availability_zone = "cn-north-1a"
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_vpc.vpc-ics-ml.default_security_group_id
  ip_protocol = "icmp"
  cidr_ipv4 = "10.247.37.0/28"
  from_port = -1
  to_port = -1
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_vpc.vpc-ics-ml.default_security_group_id
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  to_port = 22
}

resource "aws_instance" "webapp-1" {
  ami = "ami-02e4ecee6f0e4bfbb"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.sub-webapp.id
  associate_public_ip_address = true
}

output "aws_subnet_id" {
  value = aws_subnet.sub-webapp.id
}

output "aws_vpc_id" {
  value = aws_vpc.vpc-ics-ml.id
}

output "default_route_table_id" {
  value = aws_vpc.vpc-ics-ml.default_route_table_id
}
```

## 构建 igw module

加上 igw module 之后，就可以从互联网访问 EC2，也可以从 EC2 访问互联网了。

```tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "vpc_id" {
  type = string
}

variable "route_table_id" {
  type = string
}

resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id
}

resource "aws_route" "r" {
  route_table_id = var.route_table_id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
```

## 构建 tgw module

这里的 tgw 是将两个 VPC 网络打通。

```tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "route_table_id" {
  type = string
}

variable "destination_cidr_block" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = set(string)
}

variable "tgw_id" {
  type = string
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgwa-webapp" {
  subnet_ids         = var.subnet_ids
  transit_gateway_id = var.tgw_id
  vpc_id             = var.vpc_id
}

resource "aws_route" "r-eci-1" {
  route_table_id         = var.route_table_id
  destination_cidr_block =  var.destination_cidr_block
  transit_gateway_id     = var.tgw_id
}
```

## 最后

最后，把上面的 module 串起来。

```tf
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

# 创建TGW
resource "aws_ec2_transit_gateway" "tgw" {
  amazon_side_asn = 64512
  transit_gateway_cidr_blocks = [
    "10.0.0.0/24",
  ]
}

# 创建EC2和VPC
module "eci-1" {
  source = "./modules/ec2"

  vpc_cidr_block = "10.247.37.0/28"
  vpc_subnets    = ["10.247.37.0/28"]
}

module "eci-2" {
  source = "./modules/ec2"

  vpc_cidr_block = "10.247.37.16/28"
  vpc_subnets    = ["10.247.37.16/28"]
}

# 为上面创建的VPC绑定IGW
module "igw-1" {
  source = "./modules/igw"

  vpc_id = module.eci-1.aws_vpc_id
  route_table_id = module.eci-1.default_route_table_id
}

module "igw-2" {
  source = "./modules/igw"

  vpc_id = module.eci-2.aws_vpc_id
  route_table_id = module.eci-2.default_route_table_id
}

# 将上面的VPC绑定TGW
module "tgwa-1" {
  source = "./modules/transit_gateway"

  route_table_id = module.eci-1.default_route_table_id
  subnet_ids = [module.eci-1.aws_subnet_id]
  destination_cidr_block = "10.247.37.16/28"
  vpc_id = module.eci-1.aws_vpc_id
  tgw_id = aws_ec2_transit_gateway.tgw.id
}

module "tgwa-2" {
  source = "./modules/transit_gateway"

  route_table_id = module.eci-2.default_route_table_id
  subnet_ids = [module.eci-2.aws_subnet_id]
  destination_cidr_block = "10.247.37.0/28"
  vpc_id = module.eci-2.aws_vpc_id
  tgw_id = aws_ec2_transit_gateway.tgw.id
}

```

## Reference

[https://docs.aws.amazon.com/zh_cn/vpc/latest/tgw/how-transit-gateways-work.html](https://docs.aws.amazon.com/zh_cn/vpc/latest/tgw/how-transit-gateways-work.html)
