---
layout: default
title: Postgres开启Logical Replication
date: 2023-07-06 09:58 +0800
categories: postgres
---

Postgres有Physical replication和Logical replication。Logical replication有个好处就是可以很直观地看到已经提交的SQL语句，用来实现CDC(Change Data Capture)。


测试脚本

```sql
CREATE TABLE table2_with_pk (a SERIAL, b VARCHAR(30), c TIMESTAMP NOT NULL, PRIMARY KEY(a, c));
CREATE TABLE table2_without_pk (a SERIAL, b NUMERIC(5,2), c TEXT);

SELECT 'init' FROM pg_create_logical_replication_slot('test_slot', 'wal2json');

BEGIN;
INSERT INTO table2_with_pk (b, c) VALUES('Backup and Restore', now());
INSERT INTO table2_with_pk (b, c) VALUES('Tuning', now());
INSERT INTO table2_with_pk (b, c) VALUES('Replication', now());
UPDATE table2_with_pk SET b = 'Update' WHERE a = 2;
SELECT pg_logical_emit_message(true, 'wal2json', 'this message will be delivered');
SELECT pg_logical_emit_message(true, 'pgoutput', 'this message will be filtered');
DELETE FROM table2_with_pk WHERE a < 3;
SELECT pg_logical_emit_message(false, 'wal2json', 'this non-transactional message will be delivered even if you rollback the transaction');

INSERT INTO table2_without_pk (b, c) VALUES(2.34, 'Tapir');
-- it is not added to stream because there isn't a pk or a replica identity
UPDATE table2_without_pk SET c = 'Anta' WHERE c = 'Tapir';
COMMIT;

SELECT * FROM pg_logical_slot_get_changes('test_slot', NULL, NULL, 'pretty-print', '1', 'add-msg-prefixes', 'wal2json');
SELECT 'stop' FROM pg_drop_replication_slot('test_slot');

SELECT * FROM pg_replication_slots;

DROP TABLE table2_with_pk;
DROP TABLE table2_without_pk;
```

输出

```json
{
	"change": [
		{
			"kind": "insert",
			"schema": "public",
			"table": "table2_with_pk",
			"columnnames": ["a", "b", "c"],
			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
			"columnvalues": [1, "Backup and Restore", "2023-07-06 09:55:00.119931"]
		}
		,{
			"kind": "insert",
			"schema": "public",
			"table": "table2_with_pk",
			"columnnames": ["a", "b", "c"],
			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
			"columnvalues": [2, "Tuning", "2023-07-06 09:55:00.119931"]
		}
		,{
			"kind": "insert",
			"schema": "public",
			"table": "table2_with_pk",
			"columnnames": ["a", "b", "c"],
			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
			"columnvalues": [3, "Replication", "2023-07-06 09:55:00.119931"]
		}
		,{
			"kind": "update",
			"schema": "public",
			"table": "table2_with_pk",
			"columnnames": ["a", "b", "c"],
			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
			"columnvalues": [2, "Update", "2023-07-06 09:55:00.119931"],
			"oldkeys": {
				"keynames": ["a", "c"],
				"keytypes": ["integer", "timestamp without time zone"],
				"keyvalues": [2, "2023-07-06 09:55:00.119931"]
			}
		}
		,{
			"kind": "message",
			"transactional": true,
			"prefix": "wal2json",
			"content": "this message will be delivered"
		}
		,{
			"kind": "delete",
			"schema": "public",
			"table": "table2_with_pk",
			"oldkeys": {
				"keynames": ["a", "c"],
				"keytypes": ["integer", "timestamp without time zone"],
				"keyvalues": [1, "2023-07-06 09:55:00.119931"]
			}
		}
		,{
			"kind": "delete",
			"schema": "public",
			"table": "table2_with_pk",
			"oldkeys": {
				"keynames": ["a", "c"],
				"keytypes": ["integer", "timestamp without time zone"],
				"keyvalues": [2, "2023-07-06 09:55:00.119931"]
			}
		}
		,{
			"kind": "insert",
			"schema": "public",
			"table": "table2_without_pk",
			"columnnames": ["a", "b", "c"],
			"columntypes": ["integer", "numeric(5,2)", "text"],
			"columnvalues": [1, 2.34, "Tapir"]
		}
	]
}
```