---
layout: default
title: SQL Server | MySQL | Postgresql
date: 2021-05-30 20:37 +0800
categories: sqlserver mysql postgresql
---



# From SQL Server, MySQL & Postgresql
{: .-row}

{: .col-4}
## SQL Server

{: .col-4}
## MySQL

{: .col-4}
## Postresql


## Database

### Use database
{: .-row}

{: .col-4}
```sql
use db;
```

{: .col-4}
```sql
use db;
```

{: .col-4}
```sql
-- Postgresql could not switch databases. You have to disconnect and reconnect to the new database.
```




## Table

### Create table like
{: .-row}

{: .col-4}
```sql
-- table with same column attributes but no PK/FK, constraints and index
-- pure heap
SELECT * INTO TBL_2 FROM TBL_1 WHERE 1 <> 1;
```

{: .col-4}
```sql
-- table definition including column attributes and indexes
CREATE TABLE TBL_2 LIKE TBL_1
```

{: .col-4}
```sql
CREATE TABLE old_table_name (
  id serial,
  my_data text,
  primary key (id)
);

CREATE TABLE new_table_name ( 
  like old_table_name including all,
  new_col1 integer, 
  new_col2 text

);
```

### Table size
{: .-row}

{: .col-4}
```
```

{: .col-4}
```
```

{: .col-4}
```sql
DROP TABLE IF EXISTS table_seq;
 
CREATE TEMP TABLE table_seq(
                table_name VARCHAR(100),
                column_default VARCHAR(100),
                table_rows INT,
                max_id INT
);
 

INSERT INTO table_seq(table_name)
SELECT 'salesforce.' || t.table_name
FROM information_schema."tables" t
WHERE t.table_schema = 'salesforce';

 
DO
$$
DECLARE
    tbl   regclass;
    nbrow bigint;
    mid bigint;
BEGIN
   FOR tbl IN
      SELECT table_name
      FROM   table_seq
   LOOP
      EXECUTE 'SELECT count(1) FROM ' || tbl INTO nbrow;

      raise notice '%: %', tbl, nbrow;

      EXECUTE 'UPDATE table_seq SET table_rows = ' || nbrow || ' WHERE table_name = ''' || tbl || ''';';
      IF mid > 0 THEN
          EXECUTE 'UPDATE table_seq SET max_id = ' || mid || ' WHERE table_name = ''' || tbl || ''';';
      END IF;
   END LOOP;
END
$$;
 
select * from table_seq;
```



### Index
{: .-row}

{: .col-4}
```sql
 SELECT '[' + s.NAME + '].[' + o.NAME + ']' AS 'table_name'
    ,+ i.NAME AS 'index_name'
    ,LOWER(i.type_desc) + CASE 
        WHEN i.is_unique = 1
            THEN ', unique'
        ELSE ''
        END + CASE 
        WHEN i.is_primary_key = 1
            THEN ', primary key'
        ELSE ''
        END AS 'index_description'
    ,STUFF((
            SELECT ', [' + sc.NAME + ']' AS "text()"
            FROM syscolumns AS sc
            INNER JOIN sys.index_columns AS ic ON ic.object_id = sc.id
                AND ic.column_id = sc.colid
            WHERE sc.id = so.object_id
                AND ic.index_id = i1.indid
                AND ic.is_included_column = 0
            ORDER BY key_ordinal
            FOR XML PATH('')
            ), 1, 2, '') AS 'indexed_columns'
    ,STUFF((
            SELECT ', [' + sc.NAME + ']' AS "text()"
            FROM syscolumns AS sc
            INNER JOIN sys.index_columns AS ic ON ic.object_id = sc.id
                AND ic.column_id = sc.colid
            WHERE sc.id = so.object_id
                AND ic.index_id = i1.indid
                AND ic.is_included_column = 1
            FOR XML PATH('')
            ), 1, 2, '') AS 'included_columns'
FROM sysindexes AS i1
INNER JOIN sys.indexes AS i ON i.object_id = i1.id
    AND i.index_id = i1.indid
INNER JOIN sysobjects AS o ON o.id = i1.id
INNER JOIN sys.objects AS so ON so.object_id = o.id
    AND is_ms_shipped = 0
INNER JOIN sys.schemas AS s ON s.schema_id = so.schema_id
WHERE so.type = 'U'
    AND i1.indid < 255
    AND i1.STATUS & 64 = 0 --index with duplicates
    AND i1.STATUS & 8388608 = 0 --auto created index
    AND i1.STATUS & 16777216 = 0 --stats no recompute
    AND i.type_desc <> 'heap'
    AND so.NAME <> 'sysdiagrams'
ORDER BY table_name
    ,index_name;
```


{: .col-4}
```sql
SELECT a.TABLE_SCHEMA,
a.TABLE_NAME,
a.index_name,
GROUP_CONCAT(column_name ORDER BY seq_in_index) AS `Columns`
FROM information_schema.statistics a
GROUP BY a.TABLE_SCHEMA,a.TABLE_NAME,a.index_name;
```


{: .col-4}
```sql
SELECT * FROM pg_indexes WHERE tablename = 'mytable';
```



