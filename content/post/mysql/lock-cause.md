---
title: "MySQL - 诊断锁的方法"
author: "颇忒脱"
tags: ["mysql"]
date: 2021-10-09T14:03:02+08:00
---

<!--more-->

## 等MDL锁

下面语句长时间不返回，被锁住了：

```sql
select * from t where id=1;
```

先用`show processlist`查看：

![](mdl-1.webp)

可以看到`Waiting for table metadata lock`，但是没法看到另一个线程在干什么，值看到Command是Sleep。

MySQL启动时设置performance_schema=on，相比于设置为 off 会有 10% 左右的性能损失，然后：

```sql
select blocking_pid from sys.schema_table_lock_waits;
```

找到造成阻塞的process id，把这个连接用 kill 命令断开即可。

## 等flush

下面语句长时间不返回：

```sql
select * from t where id=1;
```

用`select * from information_schema.processlist where id=?;`查看：

![](flush-wait.webp)

看到状态是`Waiting for table flush`，表示的是现在有一个线程**正要**对表 t 做 flush 操作。MySQL 里面对表做 flush 操作的用法，一般有以下两个：

```sql
flush tables t with read lock;
flush tables with read lock;
```

注意，这都是读锁，应该是不会阻塞我们的SQL的，除非它们也被别的线程堵住了。

我们用`show processlist`查看：

![](flush-wait-2.webp)

`select sleep(1) from t`把表t打开，但是`flush table ...`需要把表t关闭，于是就这么阻塞了。

## 等行锁

下列语句对某行记录添加了读锁：

```sql
select * from t where id=1 lock in share mode; 
```

如果此时这行记录上已经持有了一个写锁，这条sql就会阻塞，比如：

![](row-wait-1.webp)

但是`show processlist`看不出来：

![](row-wait-2.webp)

所以要通过`sys.innodb_lock_waits`查询谁占着写锁：

```sql
select * from sys.innodb_lock_waits where locked_table='`test`.`t`';
```

得到结果：

![](row-wait-3.webp)

可以看到，4 号线程是造成堵塞的罪魁祸首，干掉它的方式 KILL QUERY 4 或 KILL 4。

其实KILL QUERY 4是不对的，因为`update`语句已经执行完毕了，只是事务没有提交，这也是为什么blocking_query: NULL的原因。

