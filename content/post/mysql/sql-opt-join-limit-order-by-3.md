---

title: "SQL优化:一个含有JOIN+LIMIT+ORDER BY的SQL(下)"
author: "颇忒脱"
tags: ["mysql", "性能调优"]
date: 2021-09-28T17:39:00+08:00
---

<!--more-->

在[上一篇文章][2] 里我们对一条SQL语句做了新的优化，在项目上做了性能测试对比新优化的效果。

## 压测

压测试方案：

* 测试三个版本：未优化版本，优化版本v1，优化版本v2
* 测试三种情况：无where clause，where clause 1，where clause 2

未优化SQL：

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
  and <condition>
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
limit 20;
```

优化版本v1 SQL，先查出ACCOUNT_NAME，然后再查出详细信息：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and <condition>
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
LIMIT 20;
```

优化版本v2 SQL，先查出ACCOUNT_NAME，然后再查出详细信息：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and <condition>
ORDER BY account.ACCOUNT_NAME_PAD
LIMIT 20;
```

压测命令：

```bash
wrk2 -c 100 -d 60 -R 2000 -B <url>
```

### 无where clause

| 未优化   | v1         | v2          |
| -------- | ---------- | ----------- |
| 0.83 QPS | 145.18 QPS | 1547.37 QPS |

这个结果符合预期，v2版本的因为扫描时直接走了索引省去了排序动作，同时又没有JOIN，所以吞吐量特别高。

这个可以从两者的执行计划看出来，v1执行计划：

|  id  | select_type |  table  | partitions | type  | possible_keys |       key       | key_len |  ref   |  rows  | filtered |            Extra            |
| :--: | :---------: | :-----: | :--------: | :---: | :-----------: | :-------------: | :-----: | :----: | :----: | :------: | :-------------------------: |
|  1   |   SIMPLE    | account |   *NULL*   | index |    *NULL*     | UQ_ACCOUNT_NAME |   362   | *NULL* | 163505 |  100.00  | Using index; Using filesort |

v2执行计划：

|  id  | select_type |  table  | partitions | type  | possible_keys |       key        | key_len |  ref   | rows | filtered | Extra  |
| :--: | :---------: | :-----: | :--------: | :---: | :-----------: | :--------------: | :-----: | :----: | :--: | :------: | :----: |
|  1   |   SIMPLE    | account |   *NULL*   | index |    *NULL*     | ACCOUNT_NAME_PAD |   767   | *NULL* |  20  |  100.00  | *NULL* |

### where clause 1压测结果

```sql
(
   account.ACCOUNT_NAME like ?
   OR account.USER_NAME like ?
   OR account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like ?)
   OR account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like ?)
)
```

压测结果：

| 查询参数/吞吐量              | 未优化   | v1        | v2        |
| ---------------------------- | -------- | --------- | --------- |
| `LIKE 20%` ，预估140,000行   | 0.83 QPS | 60.59 QPS | 64.76 QPS |
| `LIKE 202%` ，预估26,000行   | 2.39 QPS | 58.36 QPS | 7.11 QPS  |
| `LIKE 2021%` ，预估12,000 行 | 3.18 QPS | 55.59 QPS | 6.37 QPS  |
| `LIKE 20211%`，预估1,200行   | 2.31 QPS | 57.38 QPS | 8.03 QPS  |

#### 为何v2性能的急剧下降？

看到了异常现象，v2版本在 `LIKE 20%`时吞吐量64.76 QPS，`LIKE 202%`时吞吐量在7.11 QPS，下降了很多，两者的执行计划都是一样的，都是走了`ACCOUNT_NAME_PAD`索引：

|  id  | select_type |        table        | partitions | type  |               possible_keys               |       key        | key_len |  ref   | rows | filtered |             Extra             |
| :--: | :---------: | :-----------------: | :--------: | :---: | :---------------------------------------: | :--------------: | :-----: | :----: | :--: | :------: | :---------------------------: |
|  1   |   PRIMARY   |       account       |   *NULL*   | index | UQ_ACCOUNT_NAME,<br/>IDX_ACCOUNT_USERNAME | ACCOUNT_NAME_PAD |   767   | *NULL* |  20  |  100.00  |          Using where          |
|  3   |  SUBQUERY   | accountOrganization |   *NULL*   | range |           PRIMARY,IDX_ORG_NAME            |   IDX_ORG_NAME   |   602   | *NULL* |  1   |  100.00  | Using where;<br/> Using index |
|  2   |  SUBQUERY   |   accountIdentity   |   *NULL*   | range |         PRIMARY,IDX_ID_TYPE_NAME          | IDX_ID_TYPE_NAME |   602   | *NULL* |  1   |  100.00  | Using where;<br/> Using index |

虽然扫描`ACCOUNT_NAME_PAD`索引避免了排序，但是对于where clause来说，还是一行行过滤的，`LIKE 20%`的扫描行数少，因为目标数据比较靠前，`LIKE 202%`的扫描行数多，因为目标数据比较靠后。

通过`EXPLAIN ANALYZE`来分析`LIKE 20%`时的SQL执行情况，可以看到实际扫描26,566行：

```java
-> Limit: 20 row(s)  (actual time=2.201..479.425 rows=20 loops=1)
    -> Filter: ((`account`.ACCOUNT_NAME like '20%') or ...)  (cost=0.33 rows=20) (actual time=2.199..479.417 rows=20 loops=1)
        -> Index scan on account using ACCOUNT_NAME_PAD  (cost=0.33 rows=20) (actual time=0.368..462.221 rows=26566 loops=1)
        -> Select #2 (subquery in condition; run only once)
            -> Filter: (accountIdentity.`NAME` like '20%')  (cost=1.21 rows=1) (actual time=0.026..0.026 rows=0 loops=1)
                -> Index range scan on accountIdentity using IDX_ID_TYPE_NAME  (cost=1.21 rows=1) (actual time=0.026..0.026 rows=0 loops=1)
        -> Select #3 (subquery in condition; run only once)
            -> Filter: (accountOrganization.`NAME` like '20%')  (cost=1.21 rows=1) (actual time=0.033..0.033 rows=0 loops=1)
                -> Index range scan on accountOrganization using IDX_ORG_NAME  (cost=1.21 rows=1) (actual time=0.032..0.032 rows=0 loops=1)
```

但是在`LIKE 202%`时，实际扫描14,1377行，已经接近于全表行数了（16.8w行）：

```java
-> Limit: 20 row(s)  (actual time=99.352..1137.270 rows=20 loops=1)
    -> Filter: ((`account`.ACCOUNT_NAME like '202%') or ...)  (cost=0.33 rows=20) (actual time=99.351..1137.265 rows=20 loops=1)
        -> Index scan on account using ACCOUNT_NAME_PAD  (cost=0.33 rows=20) (actual time=0.779..1057.634 rows=141377 loops=1)
        -> Select #2 (subquery in condition; run only once)
            -> Filter: (accountIdentity.`NAME` like '202%')  (cost=1.21 rows=1) (actual time=0.016..0.016 rows=0 loops=1)
                -> Index range scan on accountIdentity using IDX_ID_TYPE_NAME  (cost=1.21 rows=1) (actual time=0.016..0.016 rows=0 loops=1)
        -> Select #3 (subquery in condition; run only once)
            -> Filter: (accountOrganization.`NAME` like '202%')  (cost=1.21 rows=1) (actual time=0.012..0.012 rows=0 loops=1)
                -> Index range scan on accountOrganization using IDX_ORG_NAME  (cost=1.21 rows=1) (actual time=0.012..0.012 rows=0 loops=1)
```

后面的情况其实也一样。

#### 为何v1比较稳定，而且还比v2快？

从v1的执行计划上看，v1实际上对`account`的扫描行数和全表总行数相当，同时还有排序动作：

|  id  | select_type |        table        | partitions | type  |            possible_keys             |       key        | key_len |  ref   |  rows  | filtered |            Extra            |
| :--: | :---------: | :-----------------: | :--------: | :---: | :----------------------------------: | :--------------: | :-----: | :----: | :----: | :------: | :-------------------------: |
|  1   |   PRIMARY   |       account       |   *NULL*   |  ALL  | UQ_ACCOUNT_NAME,IDX_ACCOUNT_USERNAME |      *NULL*      | *NULL*  | *NULL* | 163505 |  100.00  | Using where; Using filesort |
|  3   |  SUBQUERY   | accountOrganization |   *NULL*   | range |         PRIMARY,IDX_ORG_NAME         |   IDX_ORG_NAME   |   602   | *NULL* |   1    |  100.00  |  Using where; Using index   |
|  2   |  SUBQUERY   |   accountIdentity   |   *NULL*   | range |       PRIMARY,IDX_ID_TYPE_NAME       | IDX_ID_TYPE_NAME |   602   | *NULL* |   1    |  100.00  |  Using where; Using index   |

看`EXPLAIN ANALYZE`结果：

```java
-> Limit: 20 row(s)  (actual time=1542.761..1542.765 rows=20 loops=1)
    -> Sort: <temporary>.tmp_field_0, <temporary>.ACCOUNT_NAME, limit input to 20 row(s) per chunk  (actual time=1542.759..1542.763 rows=20 loops=1)
        -> Stream results  (actual time=2.586..1533.389 rows=26224 loops=1)
            -> Nested loop inner join  (cost=55023.35 rows=49960) (actual time=2.583..1528.278 rows=26224 loops=1)
                -> Filter: (accountOrganization.DELETED = 0)  (cost=67.50 rows=61) (actual time=0.161..1.679 rows=599 loops=1)
                    -> Table scan on accountOrganization  (cost=67.50 rows=605) (actual time=0.160..1.441 rows=605 loops=1)
                -> Filter: ((`account`.ACCOUNT_NAME like '202%') or (`account`.USER_NAME like '202%') or <in_optimizer>(`account`.IDENTITY_TYPE_ID,`account`.IDENTITY_TYPE_ID in (select #2)) or <in_optimizer>(`account`.ORGANIZATION_ID,`account`.ORGANIZATION_ID in (select #3)))  (cost=827.15 rows=826) (actual time=0.319..2.545 rows=44 loops=599)
                    -> Index lookup on account using ORGANIZATION_ID (ORGANIZATION_ID=accountOrganization.ID)  (cost=827.15 rows=826) (actual time=0.086..2.398 rows=281 loops=599)
                    -> Select #2 (subquery in condition; run only once)
                        -> Filter: (accountIdentity.`NAME` like '202%')  (cost=1.21 rows=1) (actual time=0.016..0.016 rows=0 loops=1)
                            -> Index range scan on accountIdentity using IDX_ID_TYPE_NAME  (cost=1.21 rows=1) (actual time=0.015..0.015 rows=0 loops=1)
                    -> Select #3 (subquery in condition; run only once)
                        -> Filter: (accountOrganization.`NAME` like '202%')  (cost=1.21 rows=1) (actual time=0.012..0.012 rows=0 loops=1)
                            -> Index range scan on accountOrganization using IDX_ORG_NAME  (cost=1.21 rows=1) (actual time=0.012..0.012 rows=0 loops=1)
```

也可以看到，SQL执行过程中，通过`acccount.ORGANIZATION_ID`索引查找`account`记录，总共查了599次，每次平均281行，总共16.8w行：

```java
Index lookup on account using ORGANIZATION_ID (ORGANIZATION_ID=accountOrganization.ID)  (cost=827.15 rows=826) (actual time=0.086..2.398 rows=281 loops=599)
```

那为何v1总是比较稳定，而且还比v2快呢？

因为v1扫描的是主键索引，不需要回表，而v2扫描的是`ACCOUNT_NAME_PAD`索引，在判断条件的时候需要回表，时间复杂度是 14w * log2(14w)。

### where clause 2压测结果

```sql
(
   account.ACCOUNT_NAME like ?
   OR account.USER_NAME like ?
)
```

压测结果

| 查询参数/吞吐量              | 未优化 | v1         | v2         |
| ---------------------------- | ------ | ---------- | ---------- |
| `LIKE 20%` ，预估140,000行   |        | 84.71 QPS  | 67.61 QPS  |
| `LIKE 202%` ，预估26,000行   |        | 96.93 QPS  | 5.76 QPS   |
| `LIKE 2021%` ，预估12,000 行 |        | 96.98 QPS  | 5.18 QPS   |
| `LIKE 20211%`，预估1,200行   |        | 585.31 QPS | 456.99 QPS |

#### 为何v2突然又行了？

v2的 `LIKE 202%`和`LIKE 2021%`比`LIKE 20%`吞吐量低这个在之前已经分析过了，但是为何v2的`LIKE 20211%`吞吐量突然提升6倍？

看一下`LIKE 20211%`的执行计划：

|  id  | select_type |  table  | partitions |    type     |            possible_keys             |                 key                  | key_len |  ref   | rows | filtered |                            Extra                             |
| :--: | :---------: | :-----: | :--------: | :---------: | :----------------------------------: | :----------------------------------: | :-----: | :----: | :--: | :------: | :----------------------------------------------------------: |
|  1   |   SIMPLE    | account |   *NULL*   | index_merge | UQ_ACCOUNT_NAME,IDX_ACCOUNT_USERNAME | UQ_ACCOUNT_NAME,IDX_ACCOUNT_USERNAME | 362,767 | *NULL* | 1255 |  100.00  | Using sort_union(UQ_ACCOUNT_NAME,IDX_ACCOUNT_USERNAME); Using where; Using filesort |

也就是说，当条件的预期结果集很少的时候，就会优先使用索引，而且还使用了[Index Merge 优化][3]。

那么为何在where clause 1中没有启用Index Merge 优化？这是因为当查询语句复杂的时候，MySQL不会启用该优化。

## 优化方向

经过一系列测试，发现OR查询条件是影响索引使用的罪魁祸首，尝试用UNION修改：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
   account.ACCOUNT_NAME like '20211%'
 )
union
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
   account.USER_NAME like '20211%'
 )
union
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
   account.IDENTITY_TYPE_ID in (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like '202%')
 )
union
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  and (
   account.ORGANIZATION_ID in  (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like '202%')
 )
ORDER BY length(ACCOUNT_NAME), ACCOUNT_NAME 
LIMIT 20
```

执行计划：

|   id   | select_type  |        table        | partitions | type  |      possible_keys       |         key          | key_len |               ref                |  rows  | filtered |              Extra              |
| :----: | :----------: | :-----------------: | :--------: | :---: | :----------------------: | :------------------: | :-----: | :------------------------------: | :----: | :------: | :-----------------------------: |
|   1    |   PRIMARY    |       account       |   *NULL*   | range |     UQ_ACCOUNT_NAME      |   UQ_ACCOUNT_NAME    |   362   |              *NULL*              | 52208  |  100.00  |    Using where; Using index     |
|   2    |    UNION     |       account       |   *NULL*   | range |   IDX_ACCOUNT_USERNAME   | IDX_ACCOUNT_USERNAME |   767   |              *NULL*              |   1    |  100.00  |      Using index condition      |
|   3    |    UNION     |   accountIdentity   |   *NULL*   | range | PRIMARY,IDX_ID_TYPE_NAME |   IDX_ID_TYPE_NAME   |   602   |              *NULL*              |   1    |  100.00  |    Using where; Using index     |
|   3    |    UNION     |       account       |   *NULL*   |  ref  |     IDENTITY_TYPE_ID     |   IDENTITY_TYPE_ID   |   194   |   user_test.accountIdentity.ID   | 14864  |  100.00  |             *NULL*              |
|   5    |    UNION     | accountOrganization |   *NULL*   | range |   PRIMARY,IDX_ORG_NAME   |     IDX_ORG_NAME     |   602   |              *NULL*              |   1    |  100.00  |    Using where; Using index     |
|   5    |    UNION     |       account       |   *NULL*   |  ref  |     ORGANIZATION_ID      |   ORGANIZATION_ID    |   194   | user_test.accountOrganization.ID |  825   |  100.00  |             *NULL*              |
| *NULL* | UNION RESULT |   <union1,2,3,5>    |   *NULL*   |  ALL  |          *NULL*          |        *NULL*        | *NULL*  |              *NULL*              | *NULL* |  *NULL*  | Using temporary; Using filesort |

可以看到所有的查询都用到了正确的索引。

## 优化方案

所以针对不同的情况有三种形式：

* 无条件时，ORDER BY ACCOUNT_NAME_PAD，这样可以走 ACCOUNT_NAME_PAD 索引：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
ORDER BY account.ACCOUNT_NAME_PAD
LIMIT 20
```

* 有条件时，ORDER BY length(ACCOUNT_NAME), ACCOUNT_NAME：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where <condition>
ORDER BY length(ACCOUNT_NAME), ACCOUNT_NAME
LIMIT 20
```

* 有OR条件时，改成UNION形式：

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where <OR condition-1>
  and <other condition>
union
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where <OR condition-2>
  and <other condition>
<other union>
ORDER BY length(ACCOUNT_NAME), ACCOUNT_NAME
LIMIT 20
```

## 压测验证

命令：

```sql
wrk2 -c 100 -d 60 -R 2000 -B ...
```

### 无条件

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
ORDER BY account.ACCOUNT_NAME_PAD
LIMIT 20 
```

结果：1636.14 QPS

### 一个条件

```sql
select account.ACCOUNT_NAME
from TB_B_ACCOUNT account
where 1 = 1
  AND ACCOUNT_NAME LIKE ?
ORDER BY length(ACCOUNT_NAME), ACCOUNT_NAME
LIMIT 20
```

结果

| 查询参数/吞吐量              | 吞吐量      |
| ---------------------------- | ----------- |
| `LIKE 20%` ，预估140,000行   | 100 QPS     |
| `LIKE 202%` ，预估26,000行   | 460.81 QPS  |
| `LIKE 2021%` ，预估12,000 行 | 776.09 QPS  |
| `LIKE 20211%`，预估1,200行   | 1451.60 QPS |

### 两个UNION

```sql
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.ACCOUNT_NAME like ?
union
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.USER_NAME like ?
ORDER BY length(accountName), accountName
limit 20
```

结果

| 查询参数/吞吐量              | 吞吐量      |
| ---------------------------- | ----------- |
| `LIKE 20%` ，预估140,000行   | 20.65 QPS   |
| `LIKE 202%` ，预估26,000行   | 97.70 QPS   |
| `LIKE 2021%` ，预估12,000 行 | 221.69 QPS  |
| `LIKE 20211%`，预估1,200行   | 1651.56 QPS |

### 4个UNION

```sql
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.ACCOUNT_NAME like ?
union
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.USER_NAME like ?
union
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.IDENTITY_TYPE_ID IN
      (select accountIdentity.ID from TB_B_IDENTITY_TYPE accountIdentity where accountIdentity.NAME like ?)
union
select account.ACCOUNT_NAME as accountName
from TB_B_ACCOUNT account
where 1 = 1
  and account.ORGANIZATION_ID IN
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where accountOrganization.NAME like ?)
ORDER BY length(accountName), accountName
limit 20
```

结果：

| 查询参数/吞吐量              | 吞吐量      |
| ---------------------------- | ----------- |
| `LIKE 20%` ，预估140,000行   | 20.48 QPS   |
| `LIKE 202%` ，预估26,000行   | 97.43 QPS   |
| `LIKE 2021%` ，预估12,000 行 | 238.63 QPS  |
| `LIKE 20211%`，预估1,200行   | 1638.49 QPS |

[2]: ../sql-opt-join-limit-order-by-2
[3]: https://dev.mysql.com/doc/refman/8.0/en/index-merge-optimization.html
