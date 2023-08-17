---
layout: default
title: Postgres插件pglogical
date: 2023-08-17 13:57 +0800
categories: postgres
---

## 背景

我们需要在Postgres开启CDC功能，但是standby server上不能够开始logical replication，需要等到PG 16。目前在PG 14上，我们只能够在主库上开启logical replication，这样才可以实现CDC。

## 准备工作

需要两台数据库。我直接用Postgres App开启了两个instance，Primary端口是5414，Slave是5424。

## 主数据库创建表和数据

```sql
CREATE TABLE table_with_pk (a SERIAL, b VARCHAR(30), c TIMESTAMP NOT NULL, PRIMARY KEY(a, c));

BEGIN;
INSERT INTO table_with_pk (b, c) VALUES('Backup and Restore', now());
INSERT INTO table_with_pk (b, c) VALUES('Tuning', now());
INSERT INTO table_with_pk (b, c) VALUES('Replication', now());
UPDATE table_with_pk SET b = 'Update' WHERE 1 = 1;
DELETE FROM table_with_pk WHERE a < 3;
COMMIT;
```

## 从库创建空表

```sql
CREATE TABLE table_with_pk (a SERIAL, b VARCHAR(30), c TIMESTAMP NOT NULL, PRIMARY KEY(a, c));
```

## 主库开启插件并创建Node

```sql
CREATE EXTENSION pglogical;

SELECT pglogical.create_node(
    node_name := 'provider',
    dsn := 'host=127.0.0.1 port=5414 dbname=pzhong'
);


SELECT pglogical.replication_set_add_table('default', 'public.table_with_pk');
```

## 从库上开启插件并订阅

```sql
CREATE EXTENSION pglogical;

SELECT pglogical.create_node(
    node_name := 'subscriber',
    dsn := 'host=127.0.0.1 port=5424 dbname=pzhong'
);


SELECT pglogical.create_subscription(
    subscription_name := 'subscription',
    provider_dsn := 'host=127.0.0.1 port=5414 dbname=pzhong'
);
```

## 从库上查看replication状态

```sql
select pglogical.show_subscription_status();
```

## 主库上查看replication status

```sql
SELECT * FROM pg_replication_slots;
```


## 清理从库

```sql
select pglogical.alter_subscription_disable('subscription');
select pglogical.drop_subscription('subscription');
DROP EXTENSION pglogical;
```


## 清理主库

```sql
DROP EXTENSION pglogical;
```


## 从库无法创建subscription - Could not open relation with OID

需要断开连接，再重新连一次数据库。


## 从库无法replication

首先查看replication 状态是否是down了。如果down了，那可能是那里有问题了。比如我这里是从库上面表已经有数据了，产生了冲突。我重新drop了表，再重新创建表，再enable subscription就好了。

```sql

select pglogical.alter_subscription_enable('subscription');

```

## 主库修改表结构

修改之后会导致replication down，需要从库也apply相同的DDL，再enable subscription。


## 主库在订阅暂停后插入的新数据

因为replication slot会导致WAL保留slave未消费的日志，所以不用担心数据丢失，但是要担心主库磁盘爆满。我们在从库上disable subscription之后，主库上会保留后续的DML操作，直到我们再次enable subscription。

## 主库有大量数据写入

这些数据会写入wal log，直到slave消费掉这些日志之后，过一会儿才会重新下降到默认的wal_size(1GB)。




