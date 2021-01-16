---
layout: default
title: mysql_config_editor快速设置
date: 2021-01-15 11:41 +0800
categories: mysql
---

不想每次连接mysql数据库的时候都输入密码，可以通过这种方式提前配置好，直接命令行连接。

### 新增连接配置

```bash
mysql_config_editor set --login-path=nbachina --host=127.0.0.1 --port=3309 --user=username --password
```

### 连接数据库

```bash
mysql --login-path=nbachina
```

### 查看所有连接配置

```bash
mysql_config_editor print --all
```