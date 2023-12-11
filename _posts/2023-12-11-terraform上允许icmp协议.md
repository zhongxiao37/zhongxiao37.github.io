---
layout: default
title: Terraform上允许ICMP协议
date: 2023-12-11 23:04 +0800
categories: terraform
---

在 Terraform 上创建 security group 的时候，允许 TCP 和 UDP 协议都比较直接，但是 ICMP 的时候，就没有那么直接了。如果想要允许 ping，需要按照下面配置。

```tf
from_port = 8
to_port = 0
protocol = "icmp"
```

### 继续深入

这里的 8 和 0 是来自 [https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml](https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml)。

你也可以是 -1，那就意味着 ALL。

## Reference

1. [https://blog.jwr.io/terraform/icmp/ping/security/groups/2018/02/02/terraform-icmp-rules.html](https://blog.jwr.io/terraform/icmp/ping/security/groups/2018/02/02/terraform-icmp-rules.html)
