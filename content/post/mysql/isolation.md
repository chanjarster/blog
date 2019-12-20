---
title: "MySQL - 事务隔离"
author: "颇忒脱"
tags: ["mysql"]
date: 2019-12-19T16:15:00+08:00
---

<!--more-->

## 隔离级别

在[事务 - 本地事务](../../d-transactions/local-transaction)中已经讲过4种事务隔离级别，这里补充一些别的方面。

| 事务A                     | 事务B       |
| ------------------------- | ----------- |
| 启动事务<br />查询得到值1 | 启动事务    |
|                           | 查询得到值1 |
|                           | 将1改成2    |
| 查询得到值V1              |             |
|                           | 提交事务B   |
| 查询得到值V2              |             |
| 提交事务A                 |             |
| 查询得到值V3              |             |

在不同隔离级别下，V1、V2、V3得到的是什么值：

* read uncommitted：V1=2、V2=2、V3=2。
* read committed：V1=1、V2=2、V3=2。
* repeatable read：V1=1、V2=1、V3=2。
* serializable：V1=1、V2=1，同时“提交事务将1改成2时”会被锁住，事务A提交后才能继续，然后V3=2。

repeatable read的试用场景，你希望两次读得到的结果都一样，即使期间有其他事务在修改这个值。比如：

> 假设你在管理一个个人银行账户表。一个表存了每个月月底的余额，一个表存了账单明细。这时候你要做数据校对，也就是判断上个月的余额和当前余额的差额，是否与本月的账单明细一致。你一定希望在校对过程中，即使有用户发生了一笔新的交易，也不影响你的校对结果。

## 事务隔离的实现

在 MySQL 中，实际上每条记录在更新的时候都会同时记录一条回滚操作。记录上的最新值，通过回滚操作，都可以得到前一个状态的值。

假设一个值从 1 被按顺序改成了 2、3、4，在回滚日志里面就会有类似下面的记录。

<img src="rollback-segment.png" style="zoom:50%;" />

从“read-view A、B、C”看到的值分别是1、2、4。**MySQL通过MVCC（多版本并发控制）来实现的**。read-view A得到的1实际上是从read-view C（当前值）一路回退得到的。

回滚日志什么时候删除？当没有比它更早的read-view的时候，比如只要上面的read-view A存在，那么上面3个回滚日志都必须存在。

**长事务会导致大量回滚日志**，因为只要事务没提交，MySQL就要保留可能会被这个事务用到的所有回滚日志，从而占用大量空间，回滚日志是保存在文件中的。

## 启动事务的方式

* 显式的：begin / start transaction, commit / rollback。
* 隐式的：你执行select也会开启一个事务。

什么时候关闭事务：

* 显式的：commit / rollback。
* 隐式的：`set autocommit=1`。

**所以如果`set autocommit=0`，则会让你无意当中开启了一个事务而不提交结果就造成了长事务。**

`commit work and chain`可以让你提交事务之后立即再开启一个事务：

```sql
begin;

select 1 from dual;

commit work and chain;

select 1 from dual;

commit;
```

下面语句可以查询出超过60秒的长事务：

```sql
select * from information_schema.innodb_trx where TIME_TO_SEC(timediff(now(),trx_started))>60
```

## 避免长事务

* 确保客户端设置了`autocommit=1`
* 如果是只读事务（只有select），那么就不需要begin/commit
* 设置`SET MAX_EXECUTION_TIME`控制单个语句（只针对Select）的最大执行时长