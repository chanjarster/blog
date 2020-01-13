---
title: "MySQL - 给字符串加索引"
author: "颇忒脱"
tags: ["mysql"]
date: 2020-01-13T13:03:02+08:00
---

<!--more-->

在[索引](../indices/)里提到了索引占用的空间和索引占用值的关系。并提到了字符串可以使用最左N个字符作为索引值（最左前缀）。

在[数据库选错索引怎么办](../force-index)里提到基数（cardinality）是选择使用哪个索引的很重要的指标。

## 前缀索引

下面举个例子：

```sql
-- 使用整个字段做索引
mysql> alter table SUser add index index1(email);
-- 使用前6个字符做索引
mysql> alter table SUser add index index2(email(6));
```

**如果使用的是 index1**（即 email 整个字符串的索引结构），执行顺序是这样的：

1. 从 index1 索引树找到满足索引值是`zhangssxyz@xxx.com`的这条记录，取得 ID2 的值；
2. 到主键上查到主键值是 ID2 的行，判断 email 的值是正确的，将这行记录加入结果集；
3. 取 index1 索引树上刚刚查到的位置的下一条记录，发现已经不满足 email=`zhangssxyz@xxx.com`的条件了，循环结束。

**如果使用的是 index2**（即 email(6) 索引结构），执行顺序是这样的：

1. 从 index2 索引树找到满足索引值是’zhangs’的记录，找到的第一个是 ID1；
2. 到主键上查到主键值是 ID1 的行，判断出 email 的值不是’zhangssxyz@xxx.com’，这行记录丢弃；**（回表）**
3. 取 index2 上刚刚查到的位置的下一条记录，发现仍然是’zhangs’，取出 ID2，再到 ID 索引上取整行然后判断，这次值对了，将这行记录加入结果集；
4. 重复上一步，直到在 idxe2 上取到的值不是’zhangs’时，循环结束。



可以看到使用第二种方式建索引会导致回表，那么覆盖索引也用不上了。

**所以，如何给字符串建索引就成了空间（占用空间）和效率（基数）的权衡。前缀索引使用的好，就可以做到既节省空间，又不用额外增加太多的查询成本。**



## 如何确定前缀索引的长度

首先，你可以使用下面这个语句，算出这个列上有多少个不同的值：

```sql
mysql> select count(distinct email) as L from SUser;
```

然后，依次选取不同长度的前缀来看这个值，比如我们要看一下 4~7 个字节的前缀索引，可以用这个语句：

```sql
mysql> select 
  count(distinct left(email,4)）as L4,
  count(distinct left(email,5)）as L5,
  count(distinct left(email,6)）as L6,
  count(distinct left(email,7)）as L7,
from SUser;
```

使用前缀索引很可能会损失区分度，所以你需要预先设定一个可以接受的损失比例，比如 5%。然后，在返回的 L4~L7 中，找出不小于 L * 95% 的值，假设这里 L6、L7 都满足，你就可以选择前缀长度为 6。

## 前缀区分度不够怎么办

比如身份证号，字符串很长，前缀部分区分度很低，有两个方法：

* 倒序存储：把身份证倒过来存，因为身份证前几位区分度太低，但是后几位区分度很高：

```sql
mysql> alter table t add index id_card_i(id_card(6));
mysql> select field_list from t where id_card = reverse('input_id_card_string');
```

* 添加一个身份证的hash字段

```sql
mysql> alter table t add id_card_crc int unsigned, add index(id_card_crc);
mysql> select field_list from t where id_card_crc=crc32('input_id_card_string') and id_card='input_id_card_string'
```

这两个方法有个共同的缺点，不支持范围查询，只支持等值查询。