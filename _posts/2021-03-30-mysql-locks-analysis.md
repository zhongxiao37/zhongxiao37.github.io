---
layout: default
title: mysql locks analysis
date: 2021-03-30 22:23 +0800
categories: mysql
---



## Case One


| Session 1(RR) | Session 2(RR) |
|-----------|-----------|
|start transaction; | |
| | start transaction; |
|insert into large_table_1 select * from large_table where id < 100;||
||insert into large_table (k, dt) values ('kkk', now());|
|| update large_table set dt = date_add(dt, interval 1 second) where id = 1;|


### Locks

Session 1 holds the locks on `large_table` records and it prevents further `update`. `insert` is allowed.

```sql
---TRANSACTION 1007619, ACTIVE 7 sec starting index read
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 3, OS thread handle 139734616581888, query id 913 172.21.0.1 root updating
update large_table set dt = date_add(dt, interval 1 second) where id = 1
------- TRX HAS BEEN WAITING 7 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 79 page no 4 n bits 288 index PRIMARY of table `test`.`large_table` trx id 1007619 lock_mode X locks rec but not gap waiting
Record lock, heap no 2 PHYSICAL RECORD: n_fields 5; compact format; info bits 0
 0: len 8; hex 8000000000000001; asc         ;;
 1: len 6; hex 000000001924; asc      $;;
 2: len 7; hex b80000012c0110; asc     ,  ;;
 3: len 30; hex 41434b2d3830663861616137346466643236626138643631353766343036; asc ACK-80f8aaa74dfd26ba8d6157f406; (total 36 bytes);
 4: len 5; hex 99a69e17e1; asc      ;;

------------------
---TRANSACTION 1007618, ACTIVE 15 sec
3 lock struct(s), heap size 1136, 100 row lock(s), undo log entries 99
MySQL thread id 28, OS thread handle 139734616041216, query id 911 172.21.0.1 root

```


## Case Two

| Session 1(RR) | Session 2(RR) |
|-----------|-----------|
|start transaction; | |
| | start transaction; |
|insert into large_table_1 select * from large_table where id > 9999900;||
|| update large_table set dt = date_add(dt, interval 1 second) where id = 1;|
|| insert into large_table (k, dt) values ('kkk', now());|


### Locks
No blocking on `update` but `insert` is blocked.

```sql
---TRANSACTION 1007629, ACTIVE 5 sec inserting
mysql tables in use 1, locked 1
LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
MySQL thread id 3, OS thread handle 139734616581888, query id 935 172.21.0.1 root update
insert into large_table (k, dt) values ('kkk', now())
------- TRX HAS BEEN WAITING 5 SEC FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 79 page no 45886 n bits 200 index PRIMARY of table `test`.`large_table` trx id 1007629 lock_mode X insert intention waiting
Record lock, heap no 1 PHYSICAL RECORD: n_fields 1; compact format; info bits 0
 0: len 8; hex 73757072656d756d; asc supremum;;

------------------
---TRANSACTION 1007620, ACTIVE 30 sec
1256 lock struct(s), heap size 155856, 275739 row lock(s), undo log entries 274485
MySQL thread id 28, OS thread handle 139734616041216, query id 932 172.21.0.1 root
```


## Case Three


| Session 1(RC) | Session 2(RR) |
|-----------|-----------|
|start transaction; | |
| | start transaction; |
|insert into large_table_1 select * from large_table where id < 100;||
|| update large_table set dt = date_add(dt, interval 1 second) where id = 1;|


### locks
Session 1 不会block Session 2。除非显示写上 `LOCK IN SHARE MODE`. 这里仅仅会保证读已提交，不保证可重复读，所以很快就把锁释放掉了。


```sql
---TRANSACTION 1007648, ACTIVE 42 sec
4 lock struct(s), heap size 1136, 3 row lock(s), undo log entries 2
MySQL thread id 3, OS thread handle 139734616581888, query id 1092 172.21.0.1 root
---TRANSACTION 1007647, ACTIVE 53 sec
1 lock struct(s), heap size 1136, 0 row lock(s), undo log entries 1
MySQL thread id 28, OS thread handle 139734616041216, query id 1081 172.21.0.1 root
```
