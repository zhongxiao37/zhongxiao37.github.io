---
layout: default
title: Postgres中的full text search
date: 2023-09-26 13:30 +0800
categories: postgres
---

文章源于 https://xata.io/blog/postgres-full-text-search-engine(https://xata.io/blog/postgres-full-text-search-engine)

## 下载数据文件

https://www.kaggle.com/datasets/jrobischon/wikipedia-movie-plots(https://www.kaggle.com/datasets/jrobischon/wikipedia-movie-plots)

## 创建表

```sql
CREATE TABLE movies(
  ReleaseYear int,
  Title text,
  Origin text,
  Director text,
  Casting text,
  Genre text,
  WikiPage text,
  Plot text);
```

## 导入数据

```sql
\COPY movies(ReleaseYear, Title, Origin, Director, Casting, Genre, WikiPage, Plot)
  FROM 'wiki_movie_plots_deduped.csv' DELIMITER ',' CSV HEADER;
```

## tsvector

用来存储词素向量的排序列表，这里的词素已经被规范化了，比如 refuse 和 refusing 都被转成 refus。weights 是权重，从 A 到 D，默认是 D，权重最低。

```sql
 SELECT * FROM unnest(to_tsvector('english', 'I''m going to make him an offer he can''t refuse. Refusing is not an option.'));
 lexeme | positions | weights
--------+-----------+---------
 go     | {3}       | {D}
 m      | {2}       | {D}
 make   | {5}       | {D}
 offer  | {8}       | {D}
 option | {17}      | {D}
 refus  | {12,13}   | {D,D}
(6 rows)
```

## tsquery

规范化查询。通过构建规范化查询，我们就可以进行词素查询了。

```sql
SELECT websearch_to_tsquery('english', 'the darth vader');
 websearch_to_tsquery
----------------------
 'darth' & 'vader'
(1 row)

SELECT websearch_to_tsquery('english', 'darth OR vader');
 websearch_to_tsquery
----------------------
 'darth' | 'vader'

SELECT websearch_to_tsquery('english', 'darth vader -wars');
   websearch_to_tsquery
---------------------------
 'darth' & 'vader' & !'war'

SELECT websearch_to_tsquery('english', '"the darth vader son"');
     websearch_to_tsquery
------------------------------
 'darth' <-> 'vader' <-> 'son'
```

## 查询

```sql
SELECT websearch_to_tsquery('english', 'darth vader') @@
        to_tsvector('english',
                'Darth Vader is my father.');

?column?
----------
 t
```

## 构建 GIN

GIN 是广义倒排索引。数据库中的一种索引结构，用于加速文本搜索和全文搜索。GIN 索引通常用于 PostgreSQL 等数据库管理系统中，它允许在文本列中快速查找包含特定词汇或短语的行。

首先需要创建 tsvector 列，然后再创建索引.

```sql
ALTER TABLE movies ADD search tsvector GENERATED ALWAYS AS
	(to_tsvector('english', Title) || ' ' ||
   to_tsvector('english', Plot) || ' ' ||
   to_tsvector('simple', Director) || ' ' ||
	 to_tsvector('simple', Genre) || ' ' ||
   to_tsvector('simple', Origin)
) STORED;

CREATE INDEX idx_search ON movies USING GIN(search);
```

测试一下

```sql
SELECT title FROM movies WHERE search @@ websearch_to_tsquery('english','darth vader');
                      title
--------------------------------------------------
 Star Wars Episode IV: A New Hope (aka Star Wars)
 The Empire Strikes Back
 Return of the Jedi
 Meet the Fockers
 Star Wars: Episode III – Revenge of the Sith
 Rogue One: A Star Wars Story (film)
 Star Wars: The Force Unleashed
 Star Wars: The Force Unleashed II
 American Honey
(9 rows)
```

## 排序

Postgres 有 ts_rank 函数，可以查看查询结果的相关性。

```sql
SELECT title, ts_rank(search, websearch_to_tsquery('english', 'darth vader')) rank FROM movies WHERE search @@ websearch_to_tsquery('english','darth vader') order by rank desc;
                      title                       |    rank
--------------------------------------------------+-------------
 Star Wars: The Force Unleashed                   |  0.39236963
 Star Wars: The Force Unleashed II                |  0.28135812
 The Empire Strikes Back                          |  0.26263964
 Star Wars Episode IV: A New Hope (aka Star Wars) |  0.18902963
 Star Wars: Episode III – Revenge of the Sith     |  0.10292397
 Rogue One: A Star Wars Story (film)              |  0.10049681
 Return of the Jedi                               |  0.09910346
 American Honey                                   |  0.09910322
 Meet the Fockers                                 | 0.098500855
(9 rows)
```

## 相关性的调整

有时候，title 会比较重要，又或者 votes 比较重要，我们都需要修改 rank 的结果，用来提升排名。比如，可以通过对数来提升 votes 的权重。

```sql
SELECT title,
  ts_rank(search, websearch_to_tsquery('english', 'jedi')) + log(votes)*0.01
 FROM movies
 WHERE search @@ websearch_to_tsquery('english','jedi')
 ORDER BY rank DESC LIMIT 10;
```

或者我们直接提升某一列的权重，比如 title。

```sql
ALTER TABLE movies ADD search tsvector GENERATED ALWAYS AS
   (setweight(to_tsvector('english', Title), 'A') || ' ' ||
   to_tsvector('english', Plot) || ' ' ||
   to_tsvector('simple', Director) || ' ' ||
   to_tsvector('simple', Genre) || ' ' ||
   to_tsvector('simple', Origin) || ' ' ||
   to_tsvector('simple', Casting)
) STORED;
```

## 模糊查询/拼写错误

Postgres 在使用 tsvector 和 tsquery 的时候，不支持模糊查询或者拼写错误。但是拼写错误部分我们可以这样实现。

- 先索引所有的词素
- 通过相似性查询所有的单词
- 对找到的单词，再进行查询

```sql
CREATE MATERIALIZED VIEW unique_lexeme AS
   SELECT word FROM ts_stat('SELECT search FROM movies');

SELECT * FROM unique_lexeme
   WHERE levenshtein_less_equal(word, 'pregant', 2) < 2;

   word
----------
 premant
 pregrant
 pregnant
 paegant
```
