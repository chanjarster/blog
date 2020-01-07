---
title: "MySQL - MVCC和事务隔离"
author: "颇忒脱"
tags: ["mysql"]
date: 2019-12-30T20:03:02+08:00
---

<!--more-->

前面提到过MySQL通过MVCC来实现事务隔离（准确的说是InnoDB引擎实现了MVCC）。那么接下来详细讲讲这个MVCC。

## 先思考一下

下面是一个例子，这个例子中的数据库事务隔离级别是RR（Repeatable Read），并且auto commit=1。

有一张表，且有(1,1)和(2,2)两条数据：

```sql
CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `k` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
insert into t(id, k) values(1,1),(2,2);
```

下面是三个事务的执行语句的情况，自上而下代表时间的先后。

|                   事务A                    |                   事务B                    |             事务C             |
| :----------------------------------------: | :----------------------------------------: | :---------------------------: |
| start transaction with consistent snapshot |                                            |                               |
|                                            | start transaction with consistent snapshot |                               |
|                                            |                                            | update t set k=k+1 where id=1 |
|                                            |       update t set k=k+1 where id=1        |                               |
|                                            |         select k from t where id=1         |                               |
|         select k from t where id=1         |                                            |                               |
|                  commit;                   |                                            |                               |
|                                            |                  commit;                   |                               |

`start transaction with consistent snapshot`代表了在开启一个事务的时候同时开启一个一致性视图，事务C因为开启了auto commit的关系，所以虽然只有一条语句但是也自成一个事务。

现在问事务A的select得到的值是什么？事务B的select得到的又是什么？

解答这个问题就要回答所谓的“一致性视图”到底是怎么实现的。

## 一致性视图

一致性视图就相当于给数据库拍了一个快照，当然这个快照是逻辑的不是物理的。在[MySQL - 事务隔离](../isolation)里我们提到了可以通过undo log来得到read view，那么关键问题就变成了：如何能够得到所有表属于这个快照的read view。那先讲三点：

1. 开启事务的时候，会得到一个全局唯一且单调递增的transaction id
2. 每次更新行的时候，都会把这个transaciton id一并保存，并且将其记为row trx_id
3. 每行都有多个read view，可以理解为多个版本，read view里记录了row trx_id

那么，如果你现在的transaction id是100，那么你在读一张表的时候就能够规定，只取row trx_id <= 100的read view，这样不就是相当于给数据库打了快照了吗？

下面这张图就是一行有4个版本（read view）V1、V2、V3、V4，通过undo log U1、U2、U3能够得到它们，还有事务id。

<img src="row-trx-id.png" style="zoom:50%;" />

### InnoDB的实现

在实现上InnoDB 为每个事务构造了一个数组，用来保存这个事务启动瞬间，当前正在“活跃”的所有事务 ID。“活跃”指的就是，启动了但还没提交。

数组里面事务 ID 的最小值记为低水位，当前系统里面已经创建过的事务 ID 的最大值加 1 记为高水位。这个视图数组和高水位，就组成了当前事务的一致性视图（read-view）。

而数据版本的可见性规则，就是基于数据的 row trx_id 和这个一致性视图的对比结果得到的。

<img src="hi-lo.png" style="zoom:50%;" />

这样，对于当前事务的启动瞬间来说，一个数据版本的 row trx_id，有以下几种可能：

1. 如果落在绿色部分，表示这个版本是已提交的事务或者是当前事务自己生成的，这个数据是可见的；
2. 如果落在红色部分，表示这个版本是由将来启动的事务生成的，是肯定不可见的；
3. 如果落在黄色部分，那就包括两种情况
   1. 若 row trx_id 在数组中，表示这个版本是由还没提交的事务生成的，不可见；
   2. 若 row trx_id 不在数组中，表示这个版本是已经提交了的事务生成的，可见。

## 回过头来看例子

现在问事务A的select得到的值是什么？事务B的select得到的又是什么？

假设：

1. 事务 A 开始前，系统里面只有一个活跃事务 ID 是 99；
2. 事务 A、B、C 的版本号分别是 100、101、102，且当前系统里只有这四个事务；
3. 三个事务开始前，(1,1）这一行数据的 row trx_id 是 90。

那么，事务 A 的视图数组就是 [99,100], 事务 B 的视图数组是 [99,100,101], 事务 C 的视图数组是 [99,100,101,102]

下面是时间线：

<img src="tx-timeline.png" style="zoom:50%;" />

### 查询逻辑

可以看到事务A得到的结果是1，也就是row trx_id=90的那个版本，因为它处于低水位之下。

### 更新逻辑

可以看到事务B把结果从2变成了3，按照道理说事务C[102]处于高水位之外，应该看不到才对啊。这是因为**更新数据都是先读后写的，而这个读，只能读当前的值，称为“当前读”（current read）**。因为如果不这么做事务C的更新就会被冲掉。

从而，事务B后面的select得到的是3。

## 开启事务的两种方式

前面已经看到了，可以使用`start transaction with consistent snapshot`来开启事务，同时它还会创建一个一致性视图。但是这个语句只有当事务隔离级别是RR的时候才有用，否则它和下面的`begin/start transaction`效果是一样的。

`begin/start transaction`也可以开启一个事务，但是它不会创建一个一致性视图，只有当后面执行第一条操作InnoDB表的语句才会创建一致性视图。

下面是RC（Read Commit）级别下的时间线：

<img src="tx-timeline.png" style="zoom:50%;" />

考虑到执行第一条快照读语句时才会创建一致性视图（也就是那个数组），那么可得出：

* A能够读到C提交的结果，2
* B因为更新的时候当前读，所以得到结果3

## 小节

InnoDB 的行数据有多个版本，每个数据版本有自己的 row trx_id，每个事务或者语句有自己的一致性视图。普通查询语句是一致性读，一致性读会根据 row trx_id 和一致性视图确定数据版本的可见性。

* 对于可重复读（RR），查询只承认在事务启动前就已经提交完成的数据；
* 对于读提交（RC），查询只承认在语句启动前就已经提交完成的数据；而当前读，总是读取已经提交完成的最新版本。

## 题目

下面描述了一个场景：数据明明没有变，为何却无法更新。

```sql
mysql> CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `c` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
insert into t(id, c) values(1,1),(2,2),(3,3),(4,4);
```



```bash
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from t;
+----+------+
| id | c    |
+----+------+
| 1  | 1    |
| 2  | 2    |
| 3  | 3    |
| 4  | 4    |
+----+------+
4 rows in set (0.00 sec)

mysql> update t set c=0 where id=c;
Query OK, 0 rows affected (0.00 sec)
Rows matched: 0 Changed: 0 Warnings: 0

mysql> select * from t;
+----+------+
| id | c    |
+----+------+
| 1  | 1    |
| 2  | 2    |
| 3  | 3    |
| 4  | 4    |
+----+------+
4 rows in set (0.00 sec)
```

要怎样做才能产生这种情况呢？回顾这张图：

<img src="hi-lo.png" style="zoom:50%;" />

* 当row tx_id 在 红色区域里，对当前事务不可见
* 当row tx_id 在 黄色区域里，且在数组中时，对当前事务不可见

那么就有两种做法能够产生这个效果，第一种：

|            事务A            |       事务B        |
| :-------------------------: | :----------------: |
|            begin            |                    |
|       select * from t       |                    |
|                             | update t set c=c+1 |
| update t set c=0 where id=c |                    |
|       select * from t       |                    |

* 事务A的select产生transaction id 100
* 事务B在事务A之后开始，transaction id 101，更新行，row trx_id=101
* 事务A的update是当前读，所以没有行被更新
* 事务A的select看row tx_id（101）是在红色区域，那么对当前事务不可见，所以得到的结果还是没变的

第二种：

|            事务A            |       事务B        |
| :-------------------------: | :----------------: |
|                             |       begin        |
|            begin            | update t set c=c+1 |
|       select * from t       |                    |
|                             |       commit       |
| update t set c=0 where id=c |                    |
|       select * from t       |                    |

* 事务B产生transaction id 100
* 事务B update，row tx_id=100
* 事务A产生transaction id 101，发现目前**活跃事务**100，形成数组[100, 101]
* 事务B commit（如果没有commit，后面的事务A的操作会阻塞住的）
* 事务A update，当前读，所以没有行被更新
* 事务A select，发现row trx_id(101)在数组内，是活跃事务提交的，因此不可见，得到的结果还是没变的