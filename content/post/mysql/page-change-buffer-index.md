---
title: "MySQL - 数据页、change buffer和索引"
author: "颇忒脱"
tags: ["mysql"]
date: 2020-01-07T13:03:02+08:00
---

<!--more-->

## 数据页

在[redo log和binlog —— 日志的2PC](../redo-log-binlog)里提到过：

> 如果该行所在数据页已经在内存中，则直接返回，如果不在则从磁盘中加载数据页，然后返回。这里很重要的信息是，更新操作首先是在内存中进行的，之后才会同步到磁盘。

这里提到了两个很重要的信息：

* 更新操作操作的是数据页
* 如果数据页不在内存中，那么要从磁盘中加载到内存中。

InnoDB的数据页默认大小是16K（由`innodb_page_size`控制），InnoDB不会只加载你想要的row，而是把附近的连带加载进来（有点像CPU的cache line）。下图中的第二行就是一个一个数据页：

{{< figure src="page.png" width="100%">}}

那么问题来了，如果你每次更新的row所在的数据页不在内存中，那么每次都要从磁盘加载是极其低效的，因此change buffer来救你了。

## change buffer

change buffer顾名思义是更新操作的缓冲，它是buffer pool的一部分（由`innodb_change_buffer_max_size`控制占用百分比）。当你要更新的row所在的数据页不在内存中时，InnoDB把更新操作保存在change buffer中。PS. change buffer是持久化的。

**change buffer不是万能的**，如果你的更新操作能够利用change buffer（比如下面讲到的普通索引），但是每次更新之后都有查询，即加载数据页，那么change buffer带来的效益就没有了，反而增加了开销。

change buffer对于那些写多读少的表特别有用，比如订单表、日志表。

## 索引

分别对普通索引和唯一索引的两种操作对比性能。

### 查询操作

* 对于普通索引来说，查找到满足条件的第一个记录 (5,500) 后，需要查找下一个记录，直到碰到第一个不满足 k=5 条件的记录。
* 对于唯一索引来说，由于索引定义了唯一性，查找到第一个满足条件的记录后，就会停止继续检索。

两者性能差别微乎其微。

### 更新操作和change buffer

* 给普通索引insert记录时，可以直接将更新缓存在change buffer中。
* 给唯一索引insert记录时，必须判断插入值是否重复，那么就要加载数据页，然后判断，然后直接在数据页中更新。

所以，唯一索引的insert操作必须要求数据页已经在内存中，如果没有则要加载，它用不了change buffer，因此代价是很高的。

### 如何选择索引

可以看到普通索引可以利用change buffer能够得到性能好处，你会倾向于使用普通索引，但是如果业务一定要求唯一索引，那你还是得用唯一索引。

另一个场景是，如果你要把线上表做一个归档，你会建一个和线上表结构一样的归档表，然后把线上表的数据copy到归档表中，此时你可以**把归档表中的唯一索引改成普通索引**，这样能够极大的提高归档效率（因为可以利用change buffer）。

## change buffer和redo log

### 更新过程

现在，我们要在表上执行这个插入语句：

```sql
mysql> insert into t(id,k) values(id1,k1),(id2,k2);
```

我们假设当前 k 索引树的状态，查找到位置后，k1 所在的数据页在内存 (InnoDB buffer pool) 中，k2 所在的数据页不在内存中。下图 所示是带 change buffer 的更新状态图。

{{< figure src="change-buffer-update.png" width="100%">}}

这条更新语句涉及了四个部分：内存、redo log（ib_log_fileX）、 数据表空间（t.ibd）、系统表空间（ibdata1）。

这条更新语句做了如下的操作（按照图中的数字顺序）：

1. Page 1 在内存中，直接更新内存；
2. Page 2 没有在内存中，就在内存的 change buffer 区域，记录下“我要往 Page 2 插入一行”这个信息
3. 将上述两个动作记入 redo log 中（图中 3 和 4）。

同时，图中的两个虚线箭头，是后台操作，不影响更新的响应时间。

### 读过程

我们现在要执行 `select * from t where k in (k1, k2)`流程如下：

{{< figure src="change-buffer-read.png" width="100%">}}

1. 读 Page 1 的时候，直接从内存返回。
2. 要读 Page 2 的时候，需要把 Page 2 从磁盘读入内存中，然后应用 change buffer 里面的操作日志，生成一个正确的版本并返回结果。这个动作称为merge。

可以看到，直到需要读 Page 2 的时候，这个数据页才会被读入内存。

将change buffer应用到数据页，该操作称为merge，它的时机：

* 当下次数据页从磁盘加载到内存中时，会执行merge
* 系统后台定时触发merge
* 数据库shutdown时（正常关闭）会执行merge

merge 的执行流程是这样的：

1. 从磁盘读入数据页到内存（老版本的数据页）；
2. 从 change buffer 里找出这个数据页的 change buffer 记录 (可能有多个），依次应用，得到新版数据页；
3. 写 redo log。这个 redo log 包含了数据的变更和 change buffer 的变更。

**redo log 主要节省的是随机写磁盘的 IO 消耗（转成顺序写），而 change buffer 主要节省的则是随机读磁盘的 IO 消耗。**

## 思考题

change buffer写入后断电了，数据会不会丢失。

按照前面merge的执行流程，它的最后一步是写redo log，而按照redo log的约定，只有commit的redo log才选真正写入。因此只要redo log写了，且commit了，断电后数据会丢失的。如果没有写redo log，或者redo log没有commit，这个时候断电，数据会丢失的。

不过好像具体情况更复杂，上面只是一个大概的意思。