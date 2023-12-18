---
layout: default
title: Graph database Neo4j quick start
date: 2023-12-18 13:33 +0800
categories: neo4j
---

本地想搭一个 Neo4j 来学习一下图数据库，但是 Neo4j 的官网老是让我去创建一个云数据库，不是很喜欢留下个人信息，就打算本地起一个 Neo4j。参考官网[文章](https://neo4j.com/developer/docker-run-neo4j/)，执行下面的命令就可以启动 Neo4j 数据库了。

```bash
docker run \
    --name testneo4j \
    -p7474:7474 -p7687:7687 \
    -d \
    -v $HOME/neo4j/data:/data \
    -v $HOME/neo4j/logs:/logs \
    -v $HOME/neo4j/import:/var/lib/neo4j/import \
    -v $HOME/neo4j/plugins:/plugins \
    --env NEO4J_AUTH=neo4j/password \
    neo4j:latest
```

浏览器访问 [http://localhost:7474/browser/](http://localhost:7474/browser/)，账号密码`neo4j/password`，就可以连上数据库了。

点击左侧的 Favorites，选择 Examples 下面的

<img src="/images/neo4j-example.png" style="width: 800px" />

尝试找到与 Kevin bacon 相关的人或者电影（最多 4 层关系）。

```sql
MATCH (bacon:Person {name:"Kevin Bacon"})-[*1..4]-(hollywood)
RETURN DISTINCT hollywood
```

<img src="/images/neo4j_query.png" style="width: 800px" />
