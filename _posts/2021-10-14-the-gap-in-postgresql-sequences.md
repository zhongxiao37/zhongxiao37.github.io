---
layout: default
title: Postgresql中主键ID不连续
date: 2021-10-14 16:32 +0800
categories: postgresql
---

Postgresql中主键ID可能是不连续，原本是为了增加并发性，但这样的话，会导致ID不连续的问题。参见[这里](https://stackoverflow.com/questions/9984196/postgresql-gapless-sequences)

下面是测试代码

```sql
DROP TABLE IF EXISTS foo;

CREATE TABLE foo (
id SERIAL,
bar varchar,
sfid int PRIMARY KEY);

INSERT INTO foo (bar, sfid) values ('blah', 1);
INSERT INTO foo (bar, sfid) values ('blah', 2);

SELECT * FROM foo;

select pg_get_serial_sequence('foo', 'id');

select LAST_VALUE from public.foo_id_seq;

```

这里可以看到上一次ID的值是2，那么下一个值就应该是3。

```sql
INSERT INTO foo (sfid, bar)
VALUES (2, 'yo')
ON CONFLICT (sfid)
DO UPDATE SET bar = EXCLUDED.bar;

select * from foo;

select LAST_VALUE from public.foo_id_seq;
```

执行到这里，就可以看到，LAST_VALUE不再是2了，虽然什么都没有插入进去。
