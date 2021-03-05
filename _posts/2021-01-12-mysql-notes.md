---
layout: default
title: MySQL notes
date: 2021-01-12 17:33 +0800
categories: mysql
---

From SQL Server To MySQL

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Table](#table)
  - [select into](#select-into)
  - [all index](#all-index)
  - [table size](#table-size)
  - [table status](#table-status)
- [Procedure](#procedure)
  - [获取SP的修改时间](#%E8%8E%B7%E5%8F%96sp%E7%9A%84%E4%BF%AE%E6%94%B9%E6%97%B6%E9%97%B4)
- [View](#view)
  - [视图修改时间](#%E8%A7%86%E5%9B%BE%E4%BF%AE%E6%94%B9%E6%97%B6%E9%97%B4)
- [Security](#security)
  - [login permissions](#login-permissions)
- [SQL scripts](#sql-scripts)
  - [Outer apply](#outer-apply)
  - [Row_number()](#row_number)
  - [extend the `group_concat()` length limitation](#extend-the-group_concat-length-limitation)
  - [CAST AS VARCHAR](#cast-as-varchar)
  - [user defined variable @var will cause bad query plan](#user-defined-variable-var-will-cause-bad-query-plan)
  - [Tipping point?](#tipping-point)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



## Table

### select into
同样不会复制表结构的索引，主键。

```sql
CREATE TABLE new_tbl [AS] SELECT * FROM orig_tbl;
```

### all index

```sql
SELECT a.TABLE_SCHEMA,
a.TABLE_NAME,
a.index_name,
GROUP_CONCAT(column_name ORDER BY seq_in_index) AS `Columns`
FROM information_schema.statistics a
GROUP BY a.TABLE_SCHEMA,a.TABLE_NAME,a.index_name;
```


### table size

```sql
SELECT 
    table_name AS `Table`, 
    round(((data_length + index_length) / 1024 / 1024), 2) `Size in MB` 
FROM information_schema.TABLES 
WHERE table_schema = "db"
    AND table_name = "tbl";
```

### table status
```sql
show table status like 'tbl';
show index from tbl;
show columns from tbl;
```


## Procedure

### 获取SP的修改时间

```sql
SHOW PROCEDURE STATUS LIKE 'sp1'\G
```


## View

### 视图修改时间

没法。视图只是一个定义，最多从`show create view vw`中看到谁创建的。


## Security

### login permissions
```sql
show grants for `phoenix.zhong`;
```




## SQL scripts

### Outer apply

SQL Server里面有个OUTER APPLY，可以针对一条记录生成对应的记录（可以是TOP 1，也可以是COUNT(1))，而且性能还不错。

举个例子

```sql
SELECT pr.name,
       pa.cnt as parameters_count
FROM   sys.procedures pr
       OUTER APPLY (SELECT COUNT(*) cnt
                    FROM   sys.parameters pa
                    WHERE  pa.object_id = pr.object_id
                    ) pa
ORDER  BY pr.name
```

在MySQL 5.7中没有这样的实现，只能够通过其他方式来实现。比如下面[这种方式][1]。

```sql
SELECT
   ORD.ID
  ,ORD.NAME
  ,ORD.DATE
  ,ORD_HISTORY.VALUE
FROM
  ORD
INNER JOIN
  ORD_HISTORY
    ON  ORD_HISTORY.<PRIMARY_KEY>
        =
        (SELECT ORD_HISTORY.<PRIMARY_KEY>
           FROM ORD_HISTORY
          WHERE ORD.ID = ORD_HISTORY.ID
            AND ORD.DATE <= ORD_HISTORY.DATE
       ORDER BY ORD_HISTORY.DATE DESC
          LIMIT 1
        )
```

或者MySQL 8中的`LATERAL`。

```sql
SELECT ORD.ID
    ,ORD.NAME
    ,ORD.DATE
    ,ORD_HIST.VALUE
FROM ORD,
LATERAL (
    SELECT ORD_HISTORY.VALUE
    FROM ORD_HISTORY
    WHERE ORD.ID = ORD_HISTORY.ID
        AND ORD.DATE <= ORD_HISTORY.DATE
    ORDER BY ORD_HISTORY.DATE DESC
    LIMIT 1
    ) ORD_HIST;
```


### Row_number()

SQL Server里面的Row_number非常好用，不只是给每条记录赋一个行号，还可以根据某一列进行分区，单独计算每个区里面行号。

```sql
SELECT 
    col1, col2, 
    ROW_NUMBER() OVER (PARTITION BY col1, col2 ORDER BY col3 DESC) AS intRow
FROM Table1
```

又一次，这个在MySQL 8里面才实现了。在5.7里面，你可以用[这种方式][2]。

```sql
SELECT
  t.*, 
  @r := CASE 
    WHEN col = @prevcol THEN @r + 1 
    WHEN (@prevcol := col) = null THEN null
    ELSE 1 END AS rn
FROM
  t, 
  (SELECT @r := 0, @prevcol := null) x
ORDER BY col
```

需要留意几点

1. 针对col分区的第一条记录，第一个WHEN会返回false，第二个WHEN永远都是false，最后就返回1，同时更新@r和@prevcol
2. 针对col分区的第二条记录，第一个WHEN会返回true，这个时候就@r就会增加1
3. 最最关键的地方，就是第二个WHEN。当第一个WHEN返回false的时候，即用来分区的col发生了变化，这个时候会执行第二个WHEN。但是无论@prevcol是任何值，` = null`永远都是false。这里是SQL里面的一个语法点。`null = null`是`false`，而`null is null`才是`true`。所以，这里THEN后面的null永远不会出现。这行的作用就只是用来更新@prevcol

### extend the `group_concat()` length limitation

```sql
SET SESSION group_concat_max_len = 1000000;
select GROUP_CONCAT(COLUMN_NAME)
from information_schema.columns
where TABLE_NAME = 'tbl' AND TABLE_SCHEMA = 'db';
```

### CAST AS VARCHAR

VARCHAR is not supported. Following is the supported data types.

 - BINARY[(N)]
 - CHAR[(N)]
 - DATE
 - DATETIME
 - DECIMAL[(M[,D])]
 - SIGNED [INTEGER]
 - TIME
 - UNSIGNED [INTEGER]

### 隐式转换的坑

隐式转换有些问题，如果对索引列用函数，就无法使用索引；如果对查询值用函数，就可以正确使用索引。字符集也会影响索引的使用，不同的字符集在底层存储上是不一样的，无论在JOIN还是WHERE都需要先统一转换类型，才可以进行下一步操作。

[SQL SERVER](http://zhongxiao37.blogspot.com/2016/08/the-conversion-of-varchar-value.html) 里面会有隐式转换的问题，在MySQL里面也有类似问题。

```sql
CREATE TABLE `tmp` (
  `id` varchar(50) DEFAULT NULL
);

INSERT INTO tmp (ID) VALUES (10), (10000000000000), (18446744073709551616);
-- 这里不会有任何问题，数字会被转换成为varchar(50)

select * from tmp;
select * from tmp where id = 10;
select * from tmp where id = 10000000000000;
select * from tmp where id = 18446744073709551616;
```
以上也都可以正常查找。

但是，如果用`>`，就会出问题了。也就是说，虽然比较字符串和数字的时候，会把字符串转换成数字，但还是会有这样或者那样的隐藏的坑。比如，下面4个select都不会返回结果。

```sql
select * from tmp where id > 18446744073709551616; -- no records
select * from tmp where id > 18446744073709551615; -- no records
select * from tmp where id > 18446744073709551614; -- no records
select * from tmp where id > 18446744073709551613; -- no records
```

直到你用小于`18446744073709550592`的数字去比较的时候，才会有结果。有趣的是，`18446744073709550592`的二进制是`1111111111111111111111111111111111111111111111111111110000000000`，最后10位为0。
```sql
select * from tmp where id > 18446744073709550592; -- no records
select * from tmp where id > 18446744073709550591; -- one records
```

### user defined variable @var will cause bad query plan

Per [https://stackoverflow.com/a/53462860][3], the data type of `@var` could be anything. Query optimizer will ignore the index on col `id` in this scenario. 

```sql
SET @id = "test1234567";
select @id;

EXPLAIN SELECT *
FROM TBL
WHERE id = @id;
```

You have two options. One is to use local variable in SP. Or you could explictly specify the data type for the user defined variable, like below.

```sql
SET @id = CONVERT(CAST("test1234567" AS CHAR(255)) USING ASCII);
select @id;

EXPLAIN SELECT *
FROM TBL
WHERE id = @id;
```

### Tipping point?




[1]: https://stackoverflow.com/a/36869589
[2]: https://stackoverflow.com/a/54997037/835239
[3]: https://stackoverflow.com/a/53462860

