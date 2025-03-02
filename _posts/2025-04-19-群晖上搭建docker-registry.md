---
layout: default
title: 群晖上搭建Docker Registry
date: 2025-04-19 19:24 +0800
categories: docker registry
---

我想要在局域网内搭建自己的Docker Registry


## 搭配群晖的反向代理和证书搭建Docker Registry

我在群晖上跑了Docker Registry，这样本地搭好进行就直接局域网里面推送，然后Mac Mini上就会拉起最新的镜像了。


首先创建cr.ds220plus的记录

<img src="/images/nas_reverse_proxy.png" style="width: 800px" />


<img src="/images/nas_cr_ds220plus.png"  style="width: 800px" />

然后创建一个自签证书

```bash
 openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/cr.ds220plus.key -x509 -days 365 -out certs/cr.ds220plus.crt -subj "/CN=*.ds220plus" -addext "subjectAltName=DNS:*.ds220plus,DNS:cr.ds220plus"
 ```

 然后安装上面的证书到群晖服务器上，并且绑定`cr.ds220plus`服务。

<img src="/images/nas_cr_certs.png"  style="width: 800px" />

最后在所有机子上信任该证书的公钥，具体可以查看Mac的Keychain。


再在NAS上拉起Docker Registry服务，将NAS上的`docker/registry`目录挂进容器的`/var/lib/registry`目录。

<img src="/images/nas_docker_registry.png"  style="width: 800px" />

本地随便推送一个镜像，就可以把镜像推送到服务器上了。

```bash
docker push cr.ds220plus/rsbuild:latest
```

可以通过下面的命令，验证镜像已经成功推送到了Docker Registry上。

```bash
curl -s https://cr.ds220plus/v2/_catalog | jq .
{
  "repositories": [
    "nginx",
    "rsbuild"
  ]
}

curl -s https://cr.ds220plus/v2/rsbuild/tags/list | jq .
{
  "name": "rsbuild",
  "tags": [
    "latest"
  ]
}
```