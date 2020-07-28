---
layout: default
title: Database isolation levels
date: 2020-07-28 16:01 +0800
categories: database
---

数据库有4种隔离级别：Read Uncommited, Read Committed, Repeatable Read, Serializable.

隔离级别之前，先将一下脏读，不可重复读，幻读。

### 脏读
只会出现在Read Uncommitted下面，就像所有事务都不会加锁一样，没有提交的改动也会读到。

### 不可重复读
在RU和RC下会出现。比如，第一次读完之后，另外一个事务提交了修改，第二次读的时候，就不一样了。

### 幻读
不可重复读的特殊场景。即第一次在*指定范围内*查询没有查到ID=1记录，正要准备插入的时候，失败了。因为在两个操作中间，刚好有一条ID=1的记录插入进来。

## Read Uncommitted
最低的隔离级别，别人还没有提交的事务都可以读到，妥妥可以出现脏读。也会出现不可重复读，幻读的情况。

## Read Comitted
只读取别人已提交的改动。那问题就是第一次和第二次读到不一样了。

## Repeatable Read
试图保证第一次和第二次读的是一样的，那就是看不见别人的改动，直至提交事务。

## Serializable
全程加锁，包括范围锁。可以避免上述三种情况。

![img](/images/isolation_level_locks.png)