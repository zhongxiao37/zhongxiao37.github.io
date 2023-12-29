---
layout: default
title: 用Docker本地运行 Spark
date: 2023-12-29 15:28 +0800
categories: spark
---

可以利用 Docker，在本地跑 Spark + Postgres。

## 拉去 Spark 镜像

```bash
docker pull bitnami/spark:3.4
```

## 将 postgresql.jar 复制到镜像里面去

`docker run -it bitnami/spark:3.4 bash` 把 spark 跑起来，再把 postgresql.jar 复制进去，打成新的 image。

```bash
docker cp ./postgresql-42.6.0.jar f81714a5c962:/opt/bitnami/spark/
docker commit f81714a5c962 spark-pg:3.4
```

## 最后 docker compose up

创建 docker-compose.yml 文件，直接`docker compose up`，拉起两个 container。

```yaml
version: "2"

services:
  spark:
    image: spark-pg:3.4
    environment:
      - SPARK_MODE=master
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
      - SPARK_USER=spark
    ports:
      - "8080:8080"
      - 7077:7077
  spark-worker:
    image: spark-pg:3.4
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://spark:7077
      - SPARK_WORKER_MEMORY=1G
      - SPARK_WORKER_CORES=1
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
      - SPARK_USER=spark
    ports:
      - 8081:8081
```
