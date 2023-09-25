---
layout: default
title: Spark中的DataFrame和SQL操作
date: 2023-09-25 10:34 +0800
categories: spark python
---

# 准备工作

```python
from pyspark.sql import SparkSession
import time

spark = SparkSession.builder.appName('Postgres').master('spark://localhost:7077').config("spark.driver.extraClassPath", "postgresql-42.6.0.jar").getOrCreate()

jdbc_url = 'jdbc:postgresql://127.0.0.1:5432/database'

properties = {
    "user": "username",
    "password": "password",
    "driver": "org.postgresql.Driver"
}

foo = spark.read.jdbc(url=jdbc_url, table="public.foo", properties=properties)

foo.createOrReplaceTempView("foo")
```

# SparkSQL 的操作

```python
query = """
    select bar, sum(sfid) qty from foo group by bar;
"""

result = spark.sql(query)
result.show()
```

# DataFrame 的操作

```python
from pyspark.sql.functions import avg, sum

avg_df = foo.groupBy("bar").agg(sum("sfid").alias("qty"))

avg_df.show()
```

# 输出

```bash
+----+---+
| bar|qty|
+----+---+
|blah|  1|
|  yo|  2|
+----+---+
```

# 建议

DataFrame 和 SQL 都提供更为高级的 API 以及更好的优化去操作数据，他们都是声明式语言，告诉 Spark 我要什么，而不是具体的怎么做，适合并行操作。
