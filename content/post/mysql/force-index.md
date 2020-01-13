---
title: "MySQL - 数据库选错索引怎么办"
author: "颇忒脱"
tags: ["mysql"]
date: 2020-01-12T20:03:02+08:00
---

<!--more-->

在[基础架构](../basic-arch)里提到在执行查询时优化器负责选择使用哪个索引。

## 实验1

建表：

```sql
CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `a` int(11) DEFAULT NULL,
  `b` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `a` (`a`),
  KEY `b` (`b`)
) ENGINE=InnoDB；
```

插入数据：

```sql
delimiter ;;
create procedure idata()
begin
  declare i int;
  set i=1;
  while(i<=100000)do
    insert into t values(i, i, i);
    set i=i+1;
  end while;
end;;
delimiter ;
call idata();
```

用explain`来观察MySQL会选择哪个索引：

```sql
mysql> explain select * from t where a between 10000 and 20000;
```

<img src="explain-1.png" />

结果表明MySQL会选择索引**a**，并且预计扫描10001行，为什么是10001行而不是10000行？这是因为在扫描的时候要扫描到第一个不满足条件的数据为止，因此会多扫一行。

## 选错索引的逻辑

优化器选择索引考虑的因素：

* cardinality（基数），基数代表区分度，基数越大区分度则越大，不同值越多则区分度越大，区分度大的索引被选择的概率大

```sql
mysql> show index from t;
```

<img src="cardinality.png" />

基数的值并非精确值而是一个估算值，InnoDB选取N个数据页统计不同值，计算基数平均值。当更新的行超过1/M时，重新计算基数。可以用`innodb_stats_persistent`来控制这个统计信息存在哪里。

* 预估执行该语句本身会扫描多少行，同时会预估回表的代价

## 纠正办法

重新统计索引信息：

```sql
ANALYZE TABLE t;
```

强制告诉使用哪个索引，`force index`：

```sql
select * from t force index(a) where ...
```

其他tricky的方法，这里不做介绍了。