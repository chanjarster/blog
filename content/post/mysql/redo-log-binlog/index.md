---
title: "MySQL - redo log和binlog"
author: "颇忒脱"
tags: ["mysql"]
date: 2019-12-18T21:39:00+08:00
---

<!--more-->

MySQL有两个日志模块，redo log和binlog。

## redo log

redo log属于InnoDB存储引擎。实际上就是WAL（Write-Ahead Log），在写磁盘前（数据页）先写日志。

并且写好日志之后先更新内存，直到一下两种情况时才同步到磁盘：

* 系统闲的时候
* redo log写满的时候

InnoDB的redo log大小是固定的，4个文件每个文件1G。逻辑上可以认为是一个环。write pos是当前写到的位置，checkpoint则是已经同步到数据库的位置，在write pos和checkpoint之间的空白的可写日志区域，checkpoint之后的则是还未同步到磁盘的内容，每次同步一点内容，checkpoint都会往后移动。

{{< figure src="redo-log.png" width="100%">}}

## binlog

属于Server层（见[MySQL - 基础架构](../basic-arch)），在InnoDB出现之前，MySQL一直依赖于binlog。

binlog的作用是用来归档。存储引擎可以使用binlog。

## 两者区别

* redo log是InnoDB引擎特有的，binlog则是属于Server的。
* redo log记录的是物理操作，即怎么写“在某个数据页上做了什么修改“，很符合存储引擎的特点。binlog记录的是逻辑操作，比如某行数据的某个字段变成了什么值。
* redo log记录的内容有限，前面说了4G内容。binlog则是无限的。

## 日志的2PC

举例说明redo log和binlog在`update T set c=c+1 where ID=2;`时是怎么工作的。

1. 【执行器】问【存储引擎】要ID=2的行，如果该行所在数据页已经在内存中，则直接返回，如果不在则从磁盘中加载数据页，然后返回。这里很重要的信息是，更新操作首先是在内存中进行的，之后才会同步到磁盘。
2. 【执行器】更新字段的值，调用【存储引擎】写入新值
3. 【存储引擎】更新内存中的数据，把这个更新记录到redo log中，记录的是一条prepare日志，写到磁盘。
4. 【执行器】生成这个操作的binlog，并写到磁盘。
5. 【执行器】调用事务提交接口，把之前prepare日志改成commit状态。
6. 结束

这个都是为了保证【服务层】和【存储引擎】的数据一致性。

## 为何还要binlog？

binlog看似多余落后，为何redo log没有取代呢？

* redo log存储空间有限，binlog则无限。
* redo log只有InnoDB可用，其他引擎不能用
* 历史原因，很多机制比如Master-Slave的数据复制使用的是binlog

## 数据库备份周期？

是一天一备还是一周一备？根据什么来选择？

根据你能承受的系统挂机时间来选择，备份的时间越近就能越快的恢复，反之则时间越长。这个很好理解，距离上次备份到现在所产生的binlog的大小决定了所要恢复的时间。