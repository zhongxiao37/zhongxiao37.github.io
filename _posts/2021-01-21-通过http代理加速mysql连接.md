---
layout: default
title: 通过http代理加速MySQL连接
date: 2021-01-21 10:08 +0800
categories: proxy mysql
---

自己买的是HTTP代理，本地9900开启了HTTP Proxy端口。

docker-compose.yml
```yml
version: '2'
services:
  mysql:
    image: socat
    ports: 
      - 3329:3329
    restart: always
    command: >
      TCP4-LISTEN:3329,reuseaddr,fork
      PROXY:host.docker.internal:{mysql_host}:3306,proxyport=9800
```

然后本地连接3329端口即可。之前是有ssh作为跳板，所以可以加速ssh连接。这次没有ssh跳板，MySQL连接用的是TCP/IP，所以需要做一次TCP的端口转发。

至此，无论有没有ssh跳板，都可以通过HTTP Proxy进行加速。