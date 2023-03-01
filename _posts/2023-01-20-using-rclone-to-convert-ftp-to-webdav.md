---
layout: default
title: Using rclone to convert FTP to WebDav
date: 2023-01-20 13:18 +0800
categories: rclone nas
---

入手了群辉 220+，把照片，电影都迁移了过去，还特意开通了百度云盘，用 Cloud Sync 把百度盘里面的东西都扒光清空了。但自己还有一个问题，就是如何把自己的照片做冷备份。

## 问题

家里的情况是，有一块移动硬盘，常年挂在路由器上面的，开启了 FTP 和硬盘休眠模式。所以大部分时候都是空闲的。

家里的 NAS 是一直开着，自己手机上面的照片定期备份上去。

所以方案就是，定期把 NAS 上面的照片备份到移动硬盘上去，但是 Cloud Sync 不支持 FTP 服务。

## 解决

看了一下，Cloud Sync + WebDav 是一个完美的解决方案。

1. 拉取 rclone 的 docker 镜像。
2. 创建一个配置文件。在`~/.config/rclone`下面创建一个`rclone.conf`文件，内容如下。也可以通过安装 rclone，再`rclone config`的方式创建。这个配置文件意思就是，创建了一个`asus_ftp`的远端 ftp 连接，这样就可以通过`rclone`访问这个 ftp 服务了。

```conf
[asus_ftp]
type = ftp
host = 192.168.1.1
user = username
pass = password
```

3. 创建 docker 容器，挂载配置文件，映射本地端口，创建启动命令即可。

  <img src="/images/rclone_config.png" width="800" />
  <img src="/images/rclone_port.png" width="800" />

这里解释一下这个启动命令，`rclone serve webdav asus_ftp:/ds220plus --addr :8080 --user username --pass password`是指把远端的 FTP`asus_ftp`转成 WebDav 服务，监听 8080 端口，用户名和密码是`username` `password`。

<img src="/images/rclone_cmd.png" width="800" />

详细的命令可以参考官方代码库 [代码库](https://github.com/rclone/rclone)。

这样，自己就把 FTP 转成了 WebDav，可以通过访问 http://ds220plus:8005 （这里我做了端口映射，本地是 8005，容器是 8080）尝试一下。

最后，就可以通过 Cloud Sync 创建同步任务了。

## 后记

1. 自己家里的路由是华硕的。华硕有一个 AiDisk 的功能，但那个不是不通用的 WebDav。自己折腾了很久，发现没法创建 WebDav 连接。
2. rclone 可以访问很多源，好处就是不用来回切换很多个 profile，或者各个云厂商的命令行，直接就可以把本地的文件复制上面。
