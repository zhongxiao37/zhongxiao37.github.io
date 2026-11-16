---
title: 用 Clash Verge 的 SSH 隧道访问 Airflow
date: 2026-11-16 22:12 +0800
categories: airflow ssh
---

<img src="/images/clash_verge_ssh_tunnel.png" alt="Clash Verge 的 SSH 隧道" style="width: 100%;" />


Airflow 跑在腾讯云 CVM 上，Web 界面只监听服务器的 `127.0.0.1:8080`。平时通过 `ssh -L` 看 DAG 和日志。两个人要一起看，家里和办公室的出口 IP 又经常变，把 Airflow 登录页挂到公网会增加一个需要保护的入口。

两台电脑各自开 SSH 隧道时，可以用同一个本地端口。令人困惑的是两个 `127.0.0.1` 指向不同的机器。浏览器连的是自己电脑上的地址，SSH 服务端连的是 CVM 上的地址。两边的 `8080` 和 `18080` 分别由 Airflow 和本地转发器监听。 [OpenSSH 端口转发说明](https://man.openbsd.org/ssh.1)

既然本机常开 Clash Verge，可以让它的 Mihomo 内核负责这条转发。`type: ssh` 定义怎么连接服务器，`tunnels` 定义本机监听端口和远端目标。浏览器只需收藏 `http://127.0.0.1:18080`，这条固定的 TCP 转发无需额外的 VPN 客户端或虚拟网卡。 [Mihomo SSH 节点](https://wiki.metacubex.one/config/proxies/ssh/) · [Mihomo 流量隧道](https://wiki.metacubex.one/config/tunnels/)

```text
电脑上的浏览器 → 本机 127.0.0.1:18080（Clash Verge）
               → CVM 公网 IP:22（SSH）
               → CVM 上的 127.0.0.1:8080（Airflow）
```

## 确认 Airflow 监听的地址

在 Ubuntu CVM 上进入 Airflow 的 Compose 项目目录，先确认宿主机地址和端口。

```bash
docker compose port airflow 8080
curl -fsS http://127.0.0.1:8080/api/v2/monitor/health
```

本例的端口映射是 `127.0.0.1:8080`，健康检查会返回 JSON。Compose 用下面的写法将 Airflow 的 Web 入口限定在宿主机本地。宿主机端口如果改过，后面 `PermitOpen`、测试命令和 Clash 的**远端**目标都要填实际端口。安全组这条访问路径只需要放行已有的 SSH 端口，示例是 `TCP 22`。 [腾讯云安全组配置](https://cloud.tencent.com/document/product/213/112626)

```yaml
services:
  airflow:
    ports:
      - "127.0.0.1:8080:8080"
```

## 给同事一个只转发 Airflow 的 SSH 账号

如果自己的账号已经能用公钥执行 `ssh -L`，可以直接用。给只看 Airflow 的同事建一个专用账号，每人使用自己的密钥。

同事在自己电脑上打开 **Clash Verge → 设置 → 配置目录**，在该目录生成密钥。这里也可以使用已有的专用密钥，并在后面的脚本中填入文件名。

```bash
ssh-keygen -t ed25519 -f ./airflow_ssh_key
```

`airflow_ssh_key.pub` 是交给服务器管理员的公钥。`airflow_ssh_key` 是留在本机的私钥，权限设为 `600`。在 **CVM** 上用管理员账号执行下列命令。

```bash
sudo adduser --disabled-password airflow-viewer
sudo install -d -m 700 -o airflow-viewer -g airflow-viewer /home/airflow-viewer/.ssh
sudo -u airflow-viewer touch /home/airflow-viewer/.ssh/authorized_keys
sudo chmod 600 /home/airflow-viewer/.ssh/authorized_keys
sudoedit /home/airflow-viewer/.ssh/authorized_keys
```

`adduser` 可以按回车跳过姓名等资料。命令里的参数是 `--disabled-password`，漏掉 `disabled` 末尾的 `d` 会报 `Unknown option`。打开 `authorized_keys` 后，把同事公钥中以 `ssh-ed25519` 开头的整行粘贴进去。 [Ubuntu OpenSSH 公钥配置](https://ubuntu.com/server/docs/how-to/security/openssh-server/#ssh-keys)

保留当前管理员 SSH 会话，备份后编辑 SSH 服务端配置。

```bash
sudo cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.before-airflow
sudoedit /etc/ssh/sshd_config
```

在文件末尾追加下面的设置。已有同名的 `Match User` 段落时，编辑现有段落。

```sshconfig
Match User airflow-viewer
    PubkeyAuthentication yes
    AuthenticationMethods publickey
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AllowTcpForwarding local
    PermitOpen 127.0.0.1:8080
    AllowStreamLocalForwarding no
    PermitTunnel no
    MaxSessions 0
```

`AllowTcpForwarding local` 允许客户端发起本地转发，`PermitOpen` 把远端目标限制在 Airflow 的端口。`MaxSessions 0` 禁止 Shell 和 SFTP 会话，同时允许端口转发。这段规则只匹配 `airflow-viewer`。如果管理员的 SSH 端口对公网开放，先用新窗口验证管理账号的公钥能登录，再关闭该账号的密码认证。 [OpenSSH 权限配置](https://man.openbsd.org/sshd_config.5)

先检查配置，再重载 SSH。通过当前已信任的 SSH 会话读取 CVM 的主机公钥和指纹。

```bash
sudo sshd -t && sudo systemctl reload ssh.service
cat /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

`cat` 输出的公钥整行交给连接者，供 Clash 核验服务器身份。下面测试中的 `203.0.113.10` 是文档示例地址，换成自己的 CVM 公网 IP。在**同事电脑的密钥目录**先用 OpenSSH 验证一次。首次连接时，将 SSH 提示的主机指纹和刚才读取的指纹核对。

```bash
ssh -i ./airflow_ssh_key -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes \
  -p 22 -N -L 127.0.0.1:18081:127.0.0.1:8080 airflow-viewer@203.0.113.10
```

保持终端打开，访问 `http://127.0.0.1:18081`。看到 Airflow 登录页才算转发成功。这里用 `18081`，这样可以和 Clash 的 `18080` 同时测试。

## 把固定转发交给 Clash Verge

在 Clash Verge 里右键当前订阅，选择 **编辑脚本**。这个脚本向现有配置追加两个条目，适合已有订阅的情况。如果编辑器里已经有 `main`，把函数里的追加逻辑合并进去。将 `server`、`port` 和 `username` 换成实际值，再把刚才从 CVM 取得的主机公钥整行放进 `host-key`。 [Clash Verge 扩展脚本](https://www.clashverge.dev/guide/extend.html)

```javascript
function main(config) {
  config.proxies = (config.proxies || []).concat({
    name: "Airflow-SSH",
    type: "ssh",
    server: "203.0.113.10",
    port: 22,
    username: "airflow-viewer",
    "private-key": "./airflow_ssh_key",
    "host-key": ["ssh-ed25519 AAAA..."],
    "host-key-algorithms": ["ssh-ed25519"]
  });

  config.tunnels = (config.tunnels || []).concat(
    "tcp,127.0.0.1:18080,127.0.0.1:8080,Airflow-SSH"
  );

  return config;
}
```

`private-key` 的相对路径从 Mihomo 的配置目录开始。如果私钥设有口令，需要在节点里填 `private-key-passphrase`。这个值会写进本地配置，配置文件也要按凭据保管。启用订阅后，在浏览器打开 `http://127.0.0.1:18080`。两个客户端都通过各自的公钥连接，同一个 Airflow 可以同时打开。 [Mihomo SSH 字段说明](https://wiki.metacubex.one/config/proxies/ssh/)

## 创建 Airflow 只读账号

SSH 公钥决定谁能连到页面，Airflow 账号决定进去能做什么。这台机器用 Airflow 3.4 的 `standalone` 和 Simple Auth Manager。这个认证管理器面向开发和测试，生产部署应选正式的认证管理器。 [Airflow 安全模型](https://airflow.apache.org/docs/apache-airflow/3.4.0/security/security_model.html#simple-auth-manager)

如果同事还没有独立的 Airflow 账号，可以在 CVM 的 Compose 项目目录创建或编辑 `compose.override.yaml`，把 `airflow-viewer:viewer` 加到现有用户列表中。

```yaml
services:
  airflow:
    environment:
      AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS: "admin:admin,airflow-viewer:viewer"
```

本例把认证目录挂载到 `/opt/airflow/auth`，并用 `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE` 将密码文件指定为该目录的 `passwords.json`。选择同步任务空闲的时段执行下面的命令。`up` 会重建容器，新用户的密码在启动时生成。

```bash
docker compose config --quiet
docker compose up -d --no-build --wait airflow
docker compose exec airflow python -c \
  'import json; print(json.load(open("/opt/airflow/auth/passwords.json"))["airflow-viewer"])'
```

最后一条只读取同事的 Airflow 密码，通过私密渠道交给本人。用两台电脑分别登录，确认都能查看 DAG 和运行日志，再用 `airflow-viewer` 检查触发任务等写操作受限。 [Compose 文件合并规则](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/) · [Airflow 3.4 账号初始化逻辑](https://github.com/apache/airflow/blob/3.4.0/airflow-core/src/airflow/api_fastapi/auth/managers/simple/simple_auth_manager.py#L172-L194)

## 连不上时先查哪一段

| 现象 | 检查 |
| --- | --- |
| `Permission denied (publickey)` | 核对 SSH 用户名、本机私钥和 CVM 上的 `authorized_keys`，确认公钥文件归该账号所有。 |
| `administratively prohibited` | 核对 `PermitOpen` 和隧道目标中的地址、端口，按配置使用 `127.0.0.1`。 |
| Clash 报 SSH 主机公钥不匹配 | 通过已信任的会话核对 CVM 的主机公钥，再更新脚本。 |
| `18081` 能打开，`18080` 连不上 | 查看 Clash 日志，确认订阅脚本生效，并检查本机 `18080` 是否已被另一条隧道占用。 |
