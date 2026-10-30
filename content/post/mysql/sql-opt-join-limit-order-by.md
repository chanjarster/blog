---
title: "SQL优化:一个含有JOIN+LIMIT+ORDER BY的SQL(上)"
author: "颇忒脱"
tags: ["mysql", "性能调优"]
date: 2021-09-27T11:39:00+08:00
---

<!--more-->

有一条SQL语句执行比较慢，在并发情况下存在瓶颈：

```sql
select account.ID                  as id,
       account.GENDER_ID           as genderId,
       userGender.CODE             as genderCode,
       userGender.NAME             as genderName,
       account.NATION_ID           as nationId,
       userNation.CODE             as nationCode,
       userNation.NAME             as nationName,
       account.COUNTRY_ID          as countryId,
       userCountry.CODE            as countryCode,
       userCountry.NAME            as countryName,
       account.ADDRESS_ID          as addressId,
       userAddress.CODE            as addressCode,
       userAddress.NAME            as addressName,
       account.USER_ID             as userId,
       account.USER_NAME           as userName,
       account.USER_UID            as userUid,
       account.ACCOUNT_NAME        as accountName,
       account.IDENTITY_TYPE_ID    as identityTypeId,
       accountIdentity.CODE        as identityTypeCode,
       accountIdentity.NAME        as identityTypeName,
       account.ORGANIZATION_ID     as organizationId,
       accountOrganization.CODE    as organizationCode,
       accountOrganization.NAME    as organizationName,
       account.IS_DATA_CENTER      as isDataCenter,
       account.ACTIVATION          as activation,
       account.STATE               as state,
       account.ACCOUNT_EXPIRY_DATE as accountExpiryDate,
       account.ACCOUNT_LOCKED      as accountLocked,
       account.PHONE_NUMBER        as phoneNumber,
       account.EMAIL               as email,
       user.IMAGE_URL              as imageUrl
from TB_B_ACCOUNT account
         inner join TB_B_ORGANIZATION accountOrganization
                    on account.ORGANIZATION_ID = accountOrganization.ID AND accountOrganization.DELETED = 0
         inner join TB_B_IDENTITY_TYPE accountIdentity on account.IDENTITY_TYPE_ID = accountIdentity.ID
         inner join TB_B_DICTIONARY userCertificateType on account.certificate_type_id = userCertificateType.ID
         left join TB_B_DICTIONARY userGender on account.GENDER_ID = userGender.ID
         left join TB_B_DICTIONARY userNation on account.NATION_ID = userNation.ID
         left join TB_B_DICTIONARY userCountry on account.COUNTRY_ID = userCountry.ID
         left join TB_B_DICTIONARY userAddress on account.ADDRESS_ID = userAddress.ID
         left join TB_B_USER user on account.USER_ID = user.ID
where 1 = 1
  and (
        account.ACCOUNT_NAME like '%user%'
        OR account.USER_NAME like '%user%'
        OR accountIdentity.NAME like '%user%'
        OR accountOrganization.NAME like '%user%'
    )
  and account.USER_NAME like '%user%'
  and account.ACCOUNT_NAME like '%user%'
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
limit 20;
```

在优化之前先刷新相关表的统计数据：

```SQL
ANALYZE TABLE TB_B_ACCOUNT;
ANALYZE TABLE TB_B_ORGANIZATION;
ANALYZE TABLE TB_B_IDENTITY_TYPE;
ANALYZE TABLE TB_B_DICTIONARY;
ANALYZE TABLE TB_B_USER;
```

## 1）排除ORDER BY和LIMIT

#### 检查字段索引

检查查询条件中的相关字段，把相关字段的索引加上。

EXPLAIN结果：

| id | select\_type | table | partitions | type | possible\_keys | key | key\_len | ref | rows | filtered | Extra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | SIMPLE | accountOrganization | NULL | ALL | PRIMARY | NULL | NULL | NULL | 84 | 10 | Using where |
| 1 | SIMPLE | account | NULL | ref | ORGANIZATION\_ID,IDENTITY\_TYPE\_ID,TB\_B\_ACCOUNT\_fk3 | ORGANIZATION\_ID | 194 | user\_new.accountOrganization.ID | 3637 | 1.23 | Using where |
| 1 | SIMPLE | accountIdentity | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.IDENTITY\_TYPE\_ID | 1 | 100 | Using where |
| 1 | SIMPLE | userCertificateType | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.CERTIFICATE\_TYPE\_ID | 1 | 100 | Using index |
| 1 | SIMPLE | userGender | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.GENDER\_ID | 1 | 100 | NULL |
| 1 | SIMPLE | userNation | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.NATION\_ID | 1 | 100 | NULL |
| 1 | SIMPLE | userCountry | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.COUNTRY\_ID | 1 | 100 | NULL |
| 1 | SIMPLE | userAddress | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.ADDRESS\_ID | 1 | 100 | NULL |
| 1 | SIMPLE | user | NULL | eq\_ref | PRIMARY | PRIMARY | 194 | user\_new.account.USER\_ID | 1 | 100 | NULL |

### 去掉JOIN

根据业务逻辑，把查询分成两部分，第一步先查ACCOUNT_NAME，第二步查其他字段，第一步SQL：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
        account.ACCOUNT_NAME like '%user%'
        OR account.USER_NAME like '%user%'
        OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like '%user%')
        OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like '%user%')
    )
  and account.USER_NAME like '%user%'
  and account.ACCOUNT_NAME like '%user%'
  and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0);
```

EXPLAIN如下：

| id | select\_type | table | partitions | type | possible\_keys | key | key\_len | ref | rows | filtered | Extra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | PRIMARY | accountOrganization | NULL | ALL | PRIMARY | NULL | NULL | NULL | 84 | 10 | Using where |
| 1 | PRIMARY | account | NULL | ref | ORGANIZATION\_ID | ORGANIZATION\_ID | 194 | user\_new.accountOrganization.ID | 3637 | 1.23 | Using where |
| 3 | SUBQUERY | accountOrganization | NULL | index | PRIMARY | IDX\_ORG\_NAME | 602 | NULL | 84 | 11.11 | Using where; Using index |
| 2 | SUBQUERY | accountIdentity | NULL | index | PRIMARY | IDX\_ID\_TYPE\_NAME | 602 | NULL | 49 | 11.11 | Using where; Using index |

### 优化LIKE

看到LIKE用的是中间匹配`%...%`，这种是无法利用索引的，遂改成前缀匹配，所以做出以下优化：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
        account.ACCOUNT_NAME like 'user%'
        OR account.USER_NAME like 'user%'
        OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like 'user%')
        OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like 'user%')
    )
  and account.USER_NAME like 'user%'
  and account.ACCOUNT_NAME like 'user%'
  and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0);
```

EXPLAIN结果：

| id | select\_type | table | partitions | type | possible\_keys | key | key\_len | ref | rows | filtered | Extra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | PRIMARY | accountOrganization | NULL | ALL | PRIMARY | NULL | NULL | NULL | 84 | 10 | Using where |
| 1 | PRIMARY | account | NULL | ref | UQ\_ACCOUNT\_NAME,ORGANIZATION\_ID,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | ORGANIZATION\_ID | 194 | user\_new.accountOrganization.ID | 3637 | 25 | Using where |
| 3 | SUBQUERY | accountOrganization | NULL | range | PRIMARY,IDX\_ORG\_NAME | IDX\_ORG\_NAME | 602 | NULL | 1 | 100 | Using where; Using index |
| 2 | SUBQUERY | accountIdentity | NULL | range | PRIMARY,IDX\_ID\_TYPE\_NAME | IDX\_ID\_TYPE\_NAME | 602 | NULL | 1 | 100 | Using where; Using index |

## 2）考虑ORDER BY优化

加上原先的ORDER BY之后，SQL如下：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
        account.ACCOUNT_NAME like 'user%'
        OR account.USER_NAME like 'user%'
        OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like 'user%')
        OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like 'user%')
    )
  and account.USER_NAME like 'user%'
  and account.ACCOUNT_NAME like 'user%'
  and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0)
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME;
```

EXPLAIN结果：

| id | select\_type | table | partitions | type | possible\_keys | key | key\_len | ref | rows | filtered | Extra |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | PRIMARY | accountOrganization | NULL | ALL | PRIMARY | NULL | NULL | NULL | 84 | 10 | Using where; Using temporary; Using filesort |
| 1 | PRIMARY | account | NULL | ref | UQ\_ACCOUNT\_NAME,ORGANIZATION\_ID,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | ORGANIZATION\_ID | 194 | user\_new.accountOrganization.ID | 3637 | 25 | Using where |
| 3 | SUBQUERY | accountOrganization | NULL | range | PRIMARY,IDX\_ORG\_NAME | IDX\_ORG\_NAME | 602 | NULL | 1 | 100 | Using where; Using index |
| 2 | SUBQUERY | accountIdentity | NULL | range | PRIMARY,IDX\_ID\_TYPE\_NAME | IDX\_ID\_TYPE\_NAME | 602 | NULL | 1 | 100 | Using where; Using index |

第一行可以看到 `Using temporary; Using filesort`。

* Using temporary意思是为了排序，使用了临时表hold住结果。
* Using filesort意思是无法使用索引直接得到排好序的数据，需要利用内存或者磁盘文件排序。

### 三种方案评估

那么对于这个SQL有三种做法，下面分析它们的复杂度。

先汇总一下基本情况：

* A表 `accountOrganization`表有N行

* B表 `account`表有M行
* JOIN条件`A.ID = B.ORGANIZATION_ID`
* `B.ORGANIZATION`上有索引。

列出基本算法复杂度

* B+树查找复杂度 Log2(n)
* 排序复杂度是 n * Log2(n)
* 堆插入复杂度 Log2(n)

#### 原方案

A做驱动表 N=500，B是被驱动表 M=14w，对结果做普通排序。

算法复杂度分析：

扫描A表 + A表每一行利用B表索引查找 + B表每条记录查找主键索引（回表） + B表记录的排序。

```bash
  N + N * Log2(M) + M * Log2(M) + M * Log2(M)
= 500 + 500 * Log2(14w) + 14w * Log2(14w) + 14w * Log2(14w)
= 4,372,745
```

#### 优化方案一

A做驱动表 N=500，B是被驱动表 M=14w，利用[filesort with small LIMIT optimization](http://mysql.taobao.org/monthly/2014/11/10/)优化，即利用一个尺寸20的堆（LIMIT 20）来取前20条数据，前提是数据能够在`sort_buffer_size`里放得下。

算法复杂度分析：

扫描A表 + A表每一行利用B表索引查找 + B表每行查找主键索引（回表） + B表每行过一遍堆。

```bash
  N + N * Log2(M) + M * Log2(M) + M * Log2(20)
= 500 + 500 * Log2(14w) + 14w * Log2(14w) + 14w * Log2(20)
= 2,612,945
```

#### 优化方案二

B做驱动表 M=14w，A是被驱动表 N=500，在B表新建字段`ACCOUNT_NAME_LEN`，并建立索引`ACCOUNT_NAME_LEN,ACCOUNT_NAME`，查询时**强制**走`ACCOUNT_LEN_NAME`索引从而达避免排序。

算法复杂度分析：

扫描B表索引 + B表每一行利用A表主键查找。

```bash
  M + M * Log2(N)
= 14w + 14w * Log2(500)
= 1,394,400
```

#### 方案抉择

虽然从分析结果看，方案二更好，但是方案二强制使用了某个索引。而方案一看上去不好，但是MySQL可能会根据查询条件使用合适的索引来过滤数据避免全表扫描，所以选择方案一。

### 实现优化方案一

实现优化方案一的关键是让filesort在内存中发生，然后配合LIMIT，我们需要跟踪优化器来查看原始SQL执行情况：

```SQL
SET optimizer_trace="enabled=on";
SET OPTIMIZER_TRACE_MAX_MEM_SIZE=10485760; 
SELECT ...; # your query here
SELECT * FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE;
# possibly more queries...
# When done with tracing, disable it:
SET optimizer_trace="enabled=off";
```

 得到结果：

```json
"filesort_priority_queue_optimization": {
  "limit": 1000,
  "chosen": false,
  "cause": "sort_is_cheaper"
},
"filesort_summary": {
  "memory_available": 262144,
  "key_size": 248,
  "row_size": 622,
  "max_rows_per_buffer": 421,
  "num_rows_estimate": 15,
  "num_rows_found": 131072,
  "num_initial_chunks_spilled_to_disk": 141,
  "peak_memory_used": 262144,
  "sort_algorithm": "std::stable_sort",
  "sort_mode": "<fixed_sort_key, packed_additional_fields>"
}
```

可以看到`num_initial_chunks_spilled_to_disk:141`，写了141个临时文件。

让filesort在内存中发生的相关系统参数有：

* [sort_buffer_size](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_sort_buffer_size)，规定了用于排序的缓存大小（字节），默认262144=256K。如果排序的数据在此buffer中能hold住，那么就会避免写磁盘。
* [`max_sort_length`](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_max_sort_length)，规定了排序时，每行最多取前多少个字节，如果行的尺寸超出该值，MySQL也就只会使用前多少个字节进行比较，该参数默认1024=1K。
* [Sort_merge_passes](https://dev.mysql.com/doc/refman/8.0/en/server-status-variables.html#statvar_Sort_merge_passes)，是一个状态变量，表示了排序合并的次数。

我们先设置`sort_buffer_size`到1M（默认256K）

```sql
set sort_buffer_size=1048576;         # 只针对当前session有效
set persist sort_buffer_size=1048576; # 全局有效
```

执行SQL，注意添加了LIMIT：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
        account.ACCOUNT_NAME like 'user%'
        OR account.USER_NAME like 'user%'
        OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like 'user%')
        OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like 'user%')
    )
  and account.USER_NAME like 'user%'
  and account.ACCOUNT_NAME like 'user%'
  and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0)
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
LIMIT 20;
```

然后跟踪优化器：

```json
"filesort_priority_queue_optimization": {
  "limit": 1000,
  "chosen": true
},
"filesort_summary": {
  "memory_available": 1048576,
  "key_size": 248,
  "row_size": 618,
  "max_rows_per_buffer": 1001,
  "num_rows_estimate": 7623,
  "num_rows_found": 131072,
  "num_initial_chunks_spilled_to_disk": 0,
  "peak_memory_used": 626626,
  "sort_algorithm": "std::stable_sort",
  "unpacked_addon_fields": "using_priority_queue",
  "sort_mode": "<fixed_sort_key, additional_fields>"
}
```

可以看到`filesort_priority_queue_optimization`启用了，同时`num_initial_chunks_spilled_to_disk`变成了0。

`filesort_priority_queue_optimization`启用意味着MySQL采用了优先级队列（堆）来从结果集中取最小的N个元素。

在业务场景下，大部分分页每页20条，极少超过10页，因此这里不考虑深分页问题，所以加上`LIMIT 200, 220`看看：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
        account.ACCOUNT_NAME like 'user%'
        OR account.USER_NAME like 'user%'
        OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like 'user%')
        OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like 'user%')
    )
  and account.USER_NAME like 'user%'
  and account.ACCOUNT_NAME like 'user%'
  and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0)
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
LIMIT 200, 220;
```

跟踪优化器结果：

```json
"filesort_priority_queue_optimization": {
  "limit": 420,
  "chosen": true
},
"filesort_summary": {
  "memory_available": 1048576,
  "key_size": 248,
  "row_size": 618,
  "max_rows_per_buffer": 421,
  "num_rows_estimate": 7623,
  "num_rows_found": 131072,
  "num_initial_chunks_spilled_to_disk": 0,
  "peak_memory_used": 263546,
  "sort_algorithm": "std::stable_sort",
  "unpacked_addon_fields": "using_priority_queue",
  "sort_mode": "<fixed_sort_key, additional_fields>"
}
```

可以看到`filesort_priority_queue_optimization`依然启用，而且`num_initial_chunks_spilled_to_disk`依然是0。

## 结论

做了以下优化：

* `WHERE`用到的字段都加上索引。
* `LIKE`改写成前缀匹配，这样可以利用索引。
* 避免`JOIN`，分两次查询，第一次先查`ACCOUNT_NAME`，第二次根据`ACCOUNT_NAME`查询想要的数据。
* 增加`sort_buffer_size`，避免`filesort`排序时写磁盘，并且利用堆+LIMIT来优化排序。

## 参考资料

* [MySQL EXPLAIN解读](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html)
* [MySQL LIMIT 优化](https://dev.mysql.com/doc/refman/8.0/en/limit-optimization.html)
* [MySQL ORDER BY 优化](https://dev.mysql.com/doc/refman/8.0/en/order-by-optimization.html)
* [MySQL filesort with small LIMIT optimization](http://mysql.taobao.org/monthly/2014/11/10/)
* [MySQL 优化器跟踪](https://dev.mysql.com/doc/internals/en/optimizer-tracing.html)