---
title: "SQL优化:一个超大表的GROUP BY"
author: "颇忒脱"
tags: ["mysql", "性能调优"]
date: 2021-10-11T11:39:00+08:00
---

<!--more-->

有一条SQL语句执行比较慢，在并发情况下存在瓶颈：

```sql
select 
  t.APP_ID,
  t.API_VERSION_MANAGEMENT as API_ID, 
  max(t.QUERY_NUM)as DATA_COUNT 
from data_statistics_log t 
group by t.APP_ID,t.API_VERSION_MANAGEMENT
```

这张表的数据量在60w左右，查看这张表的执行计划：

| id   | select\_type | table | partitions | type | possible\_keys | key  | key\_len | ref  | rows   | filtered | Extra           |
| :--- | :----------- | :---- | :--------- | :--- | :------------- | :--- | :------- | :--- | :----- | :------- | :-------------- |
| 1    | SIMPLE       | t     | NULL       | ALL  | NULL           | NULL | NULL     | NULL | 608731 | 100      | Using temporary |

可以看到使用了全表扫描和临时表。

根据[MySQL GROUP BY优化][1]的要义，对此次查询的3个字段做联合索引：

```sql
alter table data_statistics_log add index query_max(APP_ID,API_VERSION_MANAGEMENT,QUERY_NUM);
```

再看执行计划：

| id   | select\_type | table | partitions | type  | possible\_keys | key        | key\_len | ref  | rows | filtered | Extra                    |
| :--- | :----------- | :---- | :--------- | :---- | :------------- | :--------- | :------- | :--- | :--- | :------- | :----------------------- |
| 1    | SIMPLE       | t     | NULL       | range | query\_max     | query\_max | 497      | NULL | 5854 | 100      | Using index for group-by |

在Extra可以看到`Using index for group-by`，说明使用了优化。

对比之前的查询速度有了显著提升 2秒244毫秒 -> 17毫秒。

[1]: https://dev.mysql.com/doc/refman/8.0/en/group-by-optimization.html