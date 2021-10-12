---
title: "SQL优化:大事务中的行锁获取超时"
author: "颇忒脱"
tags: ["mysql", "性能调优"]
date: 2021-10-11T12:39:00+08:00
---

<!--more-->

在现场发现后台频繁抛出异常：

```sql
org.springframework.dao.CannotAcquireLockException: 
### Error querying database.  Cause: com.mysql.jdbc.exceptions.jdbc4.MySQLTransactionRollbackException: Lock wait timeout exceeded; try restarting transaction 
### SQL: select serialNumber from FF_ACT_FROM_SERIALNUMBER where id = '1' for update;; 
### Cause: com.mysql.jdbc.exceptions.jdbc4.MySQLTransactionRollbackException: Lock wait timeout exceeded; try restarting transaction 
```

看上去是`select serialNumber from FF_ACT_FROM_SERIALNUMBER where id = '1' for update`条语句尝试获取行锁的时候超市导致的。

## 分析

和开发人员要到了完整的SQL语句：

```sql
select serialNumber from FF_ACT_FROM_SERIALNUMBER where id = '1' for update
update FF_ACT_FROM_SERIALNUMBER set serialNumber = #{number} where id = '1'
```

以上两条SQL语句是在一个事务中执行的。对应的Java代码如下：

```java
@Transactional(propagation = Propagation.REQUIRES_NEW)
public int updateSerialNumber(String str) {
  // 两条SQL
}
```

而这个又是在一个大事务中执行的：

```java
@Transactional
public void someOperation() {
  // 很多其他SQL
  this.updateSerialNumber(...);
  // 很多其他SQL
}
```

这里有一个烟雾弹，虽然`updateSerialNumber`方法标记了`REQUIRES_NEW`，似乎会在调用的时候开启一个新事务，从而获取一个新的数据库连接，但实际上不会，这是因为Spring AOP在调用`this`自身方法的时候，是不会经过切面的，详情见[Understanding AOP Proxies][1]。

经过开发沟通，`updateSerialNumber`的意思是刷新一个序列号，序列号的前两位是年份。

而产生`lock wait timeout exceeded` 是因为行锁的占用在一个事务里，而只有等事务结束才会释放行锁。在高并发业务下，事务执行时间很长，导致获取行锁的事务堆积，排在后面的事务自然就会等待超时了。

## 解决办法

有几个解决办法：

1. 去掉`someOperation()`的`@Transactional`，使其不要在一个事务中运行，和开发沟通后不能这么做，放弃。
2. 把`updateSerialNumber()`方法尽量放到`someOperation()`的最后执行，即放到事务的最后，和开发沟通后不能这么做，放弃。
3. 使用`sequence`代替`FF_ACT_FROM_SERIALNUMBER`表，和开发沟通后不能这么做，因为要保证序列号是年份前缀，放弃。

最后的解决办法是，预先新建10个年份的sequence，比如`seq_2021`、`seq_2022`，代码根据系统当前年份使用对应sequence。

## 如果会开启新事务

当然如果会开启一个新事务那就是另一个故事了。假设有两个线程，同时数据库连接池大小为2，那么很容易出现死锁：

|      | Thread A                                                     | Thread B                                                     |
| ---- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| T1   | begin transaction;<br/>select 1 from dual;                   |                                                              |
| T2   |                                                              | begin transaction;<br/>select 1 from dual;                   |
| T3   | begin transaction;<br/>select ... for update;<br/><font color="red">(Blocked)</font> |                                                              |
| T4   |                                                              | begin transaction;<br/>select ... for update;<br/><font color="red">(Blocked)</font> |

每一次begin transaction都会获取一个数据库连接，在T2的时候，连接池的连接已经耗尽了，所以在T3时线程A就会被阻塞等待线程B释放连接，而在T4时线程B也在等待线程A释放连接，进入死锁。

这种情况在连接池不够用的情况下（比如高并发）极易发生。

当然实际项目中不会无限等待下去，因为连接池会有一个获取连接超时，不过超时后会导致所有线程A或者线程B的所有事务回滚。



[1]: https://docs.spring.io/spring-framework/docs/current/reference/html/core.html#aop-understanding-aop-proxies