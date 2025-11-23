---
layout: default
title: Vault中使用AppRole
date: 2025-11-15 21:44 +0800
categories: vault
---

很久之前就使用过了 Vault，最近尝试使用 Vault 保存一些配置和 Token，所以使用 AppRole 这种认证方式。

首先创建一个`airflow`的 policy，指定拥有这个 policy 的 token 可以有哪些权限。

```json
path "kv/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
```

然后创建一个`airflow`的 approle，绑定上面的`airflow` policy。AppRole 会有一个`role-id`和多个`secret-id`。

```bash
vault write auth/approle/role/airflow token_policies="airflow" secret_id_ttl=8760h token_ttl=1h token_max_ttl=4h secret_id_num_uses=0
```

查看创建的`airflow`的`role-id`。

```bash
vault read auth/approle/role/airflow/role-id
```

创建一个新的`secret-id`。注意，这个`secret-id`只会显示一次，如果忘记了就需要创建新的。

```bash
vault write -f auth/approle/role/airflow/secret-id
```

查看所有的`secret-id`，出于安全性，这里只会显示`secret-id-accessor`，而不会明文显示`secret-id`。

```bash
vault list auth/approle/role/airflow/secret-id
```

## 更多

使用 unwrap 获取`secret-id`
可以显示 CIDR 访问 Vault 获取 token
可以定期轮换`secret-id`
