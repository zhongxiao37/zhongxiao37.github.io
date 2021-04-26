---
layout: default
title: Check if MYSQL connection is using SSL
date: 2021-04-26 16:00 +0800
categories: mysql
---

最近几天发现bitbucket上面的pipeline失败了,后来发现是因为上周JDK 8升级到292,禁用了TLSv1.0 和 TLSv1.1. 将pipeline的版本强制回滚到openjdk:8u282-jdk以后,暂时可以用了. 进而引出一些关于MYSQL SSL的问题.

一般SSL的常规方法都需要安全证书,即服务器和客户端都需要证书,才可以加密. 但自己在尝试的时候,发现情况不是这样的,默认的MYSQL也可以通过SSL和非SSL连接。


```yaml
# docker-compose.yml
version: '2'
services:
  mysql:
    image: mysql:5.7
    restart: always
    environment:
      - MYSQL_DATABASE=test
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    ports:
      - 3306:3306
    expose:
      - 3306
    volumes:
      - ./tmp/master_my.cnf:/etc/mysql/my.cnf
      - ./tmp/mysql:/var/lib/mysql

  ubuntu:
    image: ubuntu:latest
```

创建一个用户

```sql
CREATE USER 'username'@'%' IDENTIFIED BY 'pas4word';
GRANT ALL PRIVILEGES ON * . * TO 'username'@'%';
FLUSH PRIVILEGES;
```

### 远程连接

运行ubuntu镜像`docker-compose run ubuntu`，然后安装mysql-client `apt-get update && apt-get install mariadb-client`，连接数据库 `mysql -h mysql -u username -p`，执行`status`，显示`SSL:      Not in use`。没有使用TLS。

### 本地连接

本地连接 `mysql -h 127.0.0.1 -u username -p`，然后执行`status`,显示`SSL:     Cipher in use is ECDHE-RSA-AES128-GCM-SHA256`。同时还可以运行`show  status like 'Ssl_version';` 和 `show  status like 'Ssl_cipher';`来查看TLS 版本。


### 查看general.log

通过`SET GLOBAL general_log = 'ON';`开启日志，`show variables like 'general_log%';`找到日志路径，再tail日志文件，就可以看到连接过程。

```bash
2021-04-26T07:54:38.709245Z     6 Connect username@172.18.0.4 on  using TCP/IP
2021-04-26T07:54:38.717263Z     6 Query select @@version_comment limit 1
2021-04-26T07:55:04.360133Z     7 Connect username@172.18.0.1 on  using SSL/TLS
2021-04-26T07:55:04.366380Z     7 Query SELECT version()
```

### 查看所有连接

也可以通过下面的方法查看所有连接

```sql
SELECT sbt.variable_value AS tls_version,  t2.variable_value AS cipher, 
              processlist_user AS user, processlist_host AS host 
       FROM performance_schema.status_by_thread  AS sbt 
       JOIN performance_schema.threads AS t ON t.thread_id = sbt.thread_id 
       JOIN performance_schema.status_by_thread AS t2 ON t2.thread_id = t.thread_id 
      WHERE sbt.variable_name = 'Ssl_version' and t2.variable_name = 'Ssl_cipher' ORDER BY tls_version;
```

### 回到最开始的问题

既然[JDK8U291][2]明确要禁用TLSv1.0和TLSv1.1，那么就要两个选择，一个就是不用SSL，那么就可以用`sslMode=DISABLED`或者`useSSL=false`。另外一个就是继续用SSL，但是明确使用TLSv1.2，比如`enabledTLSProtocols=TLSv1.2`。


[1]: https://dev.mysql.com/doc/connector-j/8.0/en/connector-j-connp-props-security.html
[2]: https://www.oracle.com/java/technologies/javase/8u291-relnotes.html
