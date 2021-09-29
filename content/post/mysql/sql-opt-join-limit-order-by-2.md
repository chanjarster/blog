---

title: "SQL优化:一个含有JOIN+LIMIT+ORDER BY的SQL(中)"
author: "颇忒脱"
tags: ["mysql", "性能调优"]
date: 2021-09-28T08:39:00+08:00
---

<!--more-->

在[上一篇文章][1]里我们对一条SQL语句做了优化，放到项目上实际压测后，在100个数据库连接，2000并发的情况下，性能得到比较大的提升，从原来的 0.8 QPS升到了 15.94 QPS，吞吐量是原来的19.924倍！但这还是太慢了所以进行了再一次的优化，先看上次优化后的结果。

## 回顾并分析

上次优化后将SQL拆分成了2部分。

1）先查询ACCOUNT_NAME

```SQL
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

2）再拿ACCOUNT_NAME去查询记录

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
                    on account.ORGANIZATION_ID = accountOrganization.ID
         inner join TB_B_IDENTITY_TYPE accountIdentity on account.IDENTITY_TYPE_ID = accountIdentity.ID
         inner join TB_B_DICTIONARY userCertificateType on account.certificate_type_id = userCertificateType.ID
         left join TB_B_DICTIONARY userGender on account.GENDER_ID = userGender.ID
         left join TB_B_DICTIONARY userNation on account.NATION_ID = userNation.ID
         left join TB_B_DICTIONARY userCountry on account.COUNTRY_ID = userCountry.ID
         left join TB_B_DICTIONARY userAddress on account.ADDRESS_ID = userAddress.ID
         left join TB_B_USER user on account.USER_ID = user.ID
where account.ACCOUNT_NAME in ( ... );
```

在压测期间得知，绝大部分时间消耗在第一条SQL上，回顾第一条SQL的EXPLAIN：

| id   | select\_type | table               | partitions | type  | possible\_keys                                               | key                 | key\_len | ref                              | rows | filtered | Extra                                        |
| :--- | :----------- | :------------------ | :--------- | :---- | :----------------------------------------------------------- | :------------------ | :------- | :------------------------------- | :--- | :------- | :------------------------------------------- |
| 1    | PRIMARY      | accountOrganization | NULL       | ALL   | PRIMARY                                                      | NULL                | NULL     | NULL                             | 84   | 10       | Using where; Using temporary; Using filesort |
| 1    | PRIMARY      | account             | NULL       | ref   | UQ\_ACCOUNT\_NAME,ORGANIZATION\_ID,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | ORGANIZATION\_ID    | 194      | user\_new.accountOrganization.ID | 3629 | 25       | Using where                                  |
| 3    | SUBQUERY     | accountOrganization | NULL       | range | PRIMARY,IDX\_ORG\_NAME                                       | IDX\_ORG\_NAME      | 602      | NULL                             | 1    | 100      | Using where; Using index                     |
| 2    | SUBQUERY     | accountIdentity     | NULL       | range | PRIMARY,IDX\_ID\_TYPE\_NAME                                  | IDX\_ID\_TYPE\_NAME | 602      | NULL                             | 1    | 100      | Using where; Using index                     |

可以看到：

* 第一行是 accountOrganization 表，它是JOIN驱动表，但是SQL语句里没有直接的用JOIN，但是MySQL把Where翻译成JOIN了。
* 第二行是 account 表，是被驱动表，这个表实际上会被全扫描，总数据量为14w左右。
* 不论是 accountOrganization表还是 account 表，都是全表扫描来过滤记录的，压根没有用到索引。

另外补充信息，在项目实际情况中：

* where里的条件除了 accountOrganization.DELETED=0之外，其他条件可以全部没有。
* 上一条情况比较普遍，因为业务上用户的第一次查询是程序发起的，几乎都是没有查询条件的。
* accountOrganization.DELETED=1的记录很少，500条中只有1条。
* accountOrganization，accountIdentity 表的记录比较稳定，几乎不会变。

所以我们的目标是：

* 让查询用到account上的索引

## 去掉JOIN

已经可以确定EXPLAIN结果中的JOIN是因为这个WHERE条件造成的：

```SQL
and account.ORGANIZATION_ID in
      (select accountOrganization.ID FROM TB_B_ORGANIZATION accountOrganization where DELETED = 0)
```

根据项目现场的数据，accountOrganization.DELETED=1的记录很少，500条中只有1条，且数据基本稳定不怎么变动，所以我们可以做以下改动：

* 先做一个查询，把 accountOrganization.DELETED=1的数据查出来，并缓存结果。
* 修改 `account.ORGANIZATION_ID not in (id, ...)`

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
  and account.ORGANIZATION_ID not in ('6394cd50297911ebe98bc1e17e87f048')
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
LIMIT 20;
```

然后我们还可以做进一步优化，从业务上分析，去掉`ORGANIZATION.DELETED=0`也是可以的。所以进一步变成：

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
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
LIMIT 20;
```

EXPLAIN结果：

| id   | select\_type | table               | partitions | type  | possible\_keys                                               | key                 | key\_len | ref  | rows   | filtered | Extra                       |
| :--- | :----------- | :------------------ | :--------- | :---- | :----------------------------------------------------------- | :------------------ | :------- | :--- | :----- | :------- | :-------------------------- |
| 1    | PRIMARY      | account             | NULL       | ALL   | UQ\_ACCOUNT\_NAME,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | NULL                | NULL     | NULL | 130679 | 25       | Using where; Using filesort |
| 3    | SUBQUERY     | accountOrganization | NULL       | range | PRIMARY,IDX\_ORG\_NAME                                       | IDX\_ORG\_NAME      | 602      | NULL | 1      | 100      | Using where; Using index    |
| 2    | SUBQUERY     | accountIdentity     | NULL       | range | PRIMARY,IDX\_ID\_TYPE\_NAME                                  | IDX\_ID\_TYPE\_NAME | 602      | NULL | 1      | 100      | Using where; Using index    |

可以看到，JOIN没有了，但是对`account`表的还是全表扫描（`Extra: Using where; Using filesort`）。

为什么会发生这个情况呢？因为查询条件`LIKE 'user%'`的查询结果几乎就是全表了，所以MySQL就说干脆全表不走索引了。如果条件换成`LIKE '20%'`实际结集是80行，就会走索引了，且使用了filesort：

| id   | select\_type | table               | partitions | type  | possible\_keys                                               | key                 | key\_len | ref  | rows | filtered | Extra                                              |
| :--- | :----------- | :------------------ | :--------- | :---- | :----------------------------------------------------------- | :------------------ | :------- | :--- | :--- | :------- | :------------------------------------------------- |
| 1    | PRIMARY      | account             | NULL       | range | UQ\_ACCOUNT\_NAME,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | UQ\_ACCOUNT\_NAME   | 362      | NULL | 80   | 100      | Using index condition; Using where; Using filesort |
| 3    | SUBQUERY     | accountOrganization | NULL       | range | PRIMARY,IDX\_ORG\_NAME                                       | IDX\_ORG\_NAME      | 602      | NULL | 1    | 100      | Using where; Using index                           |
| 2    | SUBQUERY     | accountIdentity     | NULL       | range | PRIMARY,IDX\_ID\_TYPE\_NAME                                  | IDX\_ID\_TYPE\_NAME | 602      | NULL | 1    | 100      | Using where; Using index                           |

## 使用索引走全表扫描

原始ORDER BY条件的意思是先根据长度排序，即短的放前面长的放后面，再根据字典序：

```sql
...
ORDER BY length(account.ACCOUNT_NAME), account.ACCOUNT_NAME
...
```

我们可以对`ACCOUNT_NAME`的值做填充，使其长度一致，排序后又能得到同样的效果，比如：

| 原始 | 填充   |
| ---- | ------ |
| `3`  | `__3` |
| `22` | `_22`  |

上面的`_`实际为空格。

于是添加一个字段用来存放`ACCOUNT_NAME`的填充数据，填充长度为`max(length(ACCOUNT_NAME))`，并且加上了索引，因为MySQL在走全表扫描的时候，可能会优先使用ORDER BY字段的索引：

```sql
alter table TB_B_ACCOUNT add column ACCOUNT_NAME_PAD VARCHAR(255) NOT NULL DEFAULT(LPAD(ACCOUNT_NAME, 20, ' '));
alter table TB_B_ACCOUNT add index ACCOUNT_NAME_PAD(ACCOUNT_NAME_PAD);
```

然后SQL改成：

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
ORDER BY account.ACCOUNT_NAME_PAD
LIMIT 20;
```

EXPLAIN：

| id   | select\_type | table               | partitions | type  | possible\_keys                                               | key                 | key\_len | ref  | rows | filtered | Extra                    |
| :--- | :----------- | :------------------ | :--------- | :---- | :----------------------------------------------------------- | :------------------ | :------- | :--- | :--- | :------- | :----------------------- |
| 1    | PRIMARY      | account             | NULL       | index | UQ\_ACCOUNT\_NAME,UQ\_ACCOUNT\_USRNAME,IDX\_ACCOUNT\_USERNAME | ACCOUNT\_NAME\_PAD  | 767      | NULL | 40   | 25       | Using where              |
| 3    | SUBQUERY     | accountOrganization | NULL       | range | PRIMARY,IDX\_ORG\_NAME                                       | IDX\_ORG\_NAME      | 602      | NULL | 1    | 100      | Using where; Using index |
| 2    | SUBQUERY     | accountIdentity     | NULL       | range | PRIMARY,IDX\_ID\_TYPE\_NAME                                  | IDX\_ID\_TYPE\_NAME | 602      | NULL | 1    | 100      | Using where; Using index |

可以看到使用了`ACCOUNT_NAME_PAD`索引，并且取消了filesort。

## 总结

总结一下两次优化的结论：

- `WHERE`用到的字段都加上索引。
- `LIKE`改写成前缀匹配，这样可以利用索引。
- 尽一切可能去掉`JOIN`，这样可以让MySQL选择被查表上的索引。
- 预期结果集小的时候，MySQL会选择索引匹配查询条件，然后filesort。这个时候要确保`sort_buffer_size`足够，避免`filesort`排序时写磁盘，并且利用堆+LIMIT来优化排序。
- 预期结果集大的时候，MySQL会选择全表扫描，此时就要在排序字段上添加索引，这样就会用排序字段索引全表扫描，避免了filesort。

[1]: ../sql-opt-join-limit-order-by
