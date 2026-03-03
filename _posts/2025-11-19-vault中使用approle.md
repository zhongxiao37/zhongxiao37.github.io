---
layout: default
title: Vault 中使用 AppRole
date: 2025-11-15 21:44 +0800
categories: vault
---

很久之前就接触过 HashiCorp Vault，最近在项目中需要使用 Vault 来安全地保存一些敏感配置和 Token。对于这种机器对机器（Machine-to-Machine）的场景，最推荐的认证方式就是 **AppRole**。

本文将演示如何在 Vault 中配置并使用 AppRole 进行身份验证。

## 1. 创建 Policy

首先，我们需要创建一个名为 `airflow` 的 Policy，用于定义后续生成的 Token 可以拥有哪些权限。

以下 Policy 允许对 `kv/` 路径下的凭据进行增删改查及列表操作：

```hcl
path "kv/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
```

## 2. 创建 AppRole

接下来，创建一个名为 `airflow` 的 AppRole，并将其与上一步创建的 Policy 绑定。

在 AppRole 机制中，身份凭证主要由两部分组成：`role-id`（相当于用户名）和 `secret-id`（相当于密码）。

执行以下命令创建 AppRole 并配置相关参数：

```bash
vault write auth/approle/role/airflow \
    token_policies="airflow" \
    secret_id_ttl=8760h \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_num_uses=0
```

**核心参数说明：**
- `token_policies`: 绑定的权限策略名称。
- `secret_id_ttl`: `secret-id` 的有效时间（本例中 `8760h` 为 1 年）。
- `token_ttl`: 颁发出的 Token 的初始有效时间（1 小时）。
- `token_max_ttl`: Token 的最大允许续期时间（4 小时）。
- `secret_id_num_uses`: `secret-id` 的使用次数限制（`0` 表示无限制）。

## 3. 获取 Role ID 和 Secret ID

为了让应用程序（如 Airflow）能够成功登录 Vault，我们需要为它提供对应的 `role-id` 和 `secret-id`。

### 查看 Role ID

可以通过以下命令获取该角色的 `role-id`：

```bash
vault read auth/approle/role/airflow/role-id
```

### 生成 Secret ID

接下来生成一个新的 `secret-id`。**请注意，`secret-id` 的明文仅在创建时显示一次**。如果忘记或丢失，就需要重新生成一个新的。

```bash
vault write -f auth/approle/role/airflow/secret-id
```

### 查看已有的 Secret ID

出于安全性考虑，列出 `secret-id` 时只会显示 `secret-id-accessor`（访问器），而不会明文显示实际的 Token。这有助于我们在不泄露密码的情况下，对凭证进行审计和撤销操作。

```bash
vault list auth/approle/role/airflow/secret-id
```

## 进阶与安全性考量

在生产环境中，我们还可以结合以下特性进一步提升 AppRole 的安全性：

- **使用 Response Wrapping（Unwrap）获取 Secret ID**：通过封装机制安全地将 `secret-id` 传递给目标机器，防止在传递过程中被中间人窃取。
- **限制访问来源 (CIDR)**：可以配置 `secret_id_bound_cidrs` 等参数，只允许特定 IP 段的机器访问 Vault 获取 Token。
- **定期轮换 Secret ID**：养成定期废弃旧 `secret-id` 并生成新 `secret-id` 的习惯，以降低凭据泄露带来的安全风险。
