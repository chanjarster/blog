---
title: "MySQL - 字符集简介"
author: "颇忒脱"
tags: ["mysql"]
date: 2023-11-29T12:44:52+08:00
---

<!--more-->

数据库字符集，是一个经常被人忽略的东西，但配置不正确又容易发生意想不到的bug。

事情的起因是有一个字符串字段上加了 Unique 索引，在插入 `foo` 和 `Foo` 两条记录的时候被报告违反唯一索引。

## 简介字符集和排序规则

在 MySQL 中，字符集（Charset）不是孤立使用的，它常常搭配字符集排序规则（Collation）一起存在。

字符集大家都知道，而排序规则则比较陌生，实际上排序规则定义了 MySQL 在比较字符串时的行为，比大小、判断是否相等都会影响到。

你可以通过下列命令查看支持的字符集，可以看到每个字符集有默认的排序规则：

```sql
-- 查看 MySQL 支持的字符集
SHOW CHARACTER SET LIKE 'utf%';
+---------+------------------+--------------------+--------+
| Charset | Description      | Default collation  | Maxlen |
+---------+------------------+--------------------+--------+
| utf16   | UTF-16 Unicode   | utf16_general_ci   |      4 |
| utf16le | UTF-16LE Unicode | utf16le_general_ci |      4 |
| utf32   | UTF-32 Unicode   | utf32_general_ci   |      4 |
| utf8mb3 | UTF-8 Unicode    | utf8mb3_general_ci |      3 |
| utf8mb4 | UTF-8 Unicode    | utf8mb4_0900_ai_ci |      4 |
+---------+------------------+--------------------+--------+
```

以及支持的排序规则：

```sql
-- 查看 MySQL 支持的字符集排序规则
SHOW COLLATION WHERE Charset = 'utf8mb4';
+----------------------------+---------+-----+---------+----------+---------+---------------+
| Collation                  | Charset | Id  | Default | Compiled | Sortlen | Pad_attribute |
+----------------------------+---------+-----+---------+----------+---------+---------------+
| utf8mb4_0900_ai_ci         | utf8mb4 | 255 | Yes     | Yes      |       0 | NO PAD        |
| utf8mb4_0900_as_ci         | utf8mb4 | 305 |         | Yes      |       0 | NO PAD        |
...
| utf8mb4_general_ci         | utf8mb4 |  45 |         | Yes      |       1 | PAD SPACE     |
...
```

在使用的时候也是配合使用的，比如定义表的字符集和排序规则：

```sql
CREATE TABLE FOO
(
    NAME VARCHAR(512)
) CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

也可以不指定排序规则，那么就用字符集默认的排序规则；
也可以字符集都不指定，使用 Databse 默认的字符集和排序规则。

## 支持的字符集和排序规则

MySQL 支持的字符集和排序规则有这么几大类：

* [Unicode][c-unicode]，Unicode 字符集的[详解][c-u-c]
* [西欧][c-we]
* [中欧][c-ce]
* [南欧和中东][c-se-me]
* [波罗的海][c-b]
* [西里尔][c-c]
* [亚洲][c-a]
* [二进制][c-b]

[c-unicode]: https://dev.mysql.com/doc/refman/8.0/en/charset-unicode-sets.html
[c-we]: https://dev.mysql.com/doc/refman/8.0/en/charset-we-sets.html
[c-ce]: https://dev.mysql.com/doc/refman/8.0/en/charset-ce-sets.html
[c-se-me]: https://dev.mysql.com/doc/refman/8.0/en/charset-se-me-sets.html
[c-b]: https://dev.mysql.com/doc/refman/8.0/en/charset-baltic-sets.html
[c-c]: https://dev.mysql.com/doc/refman/8.0/en/charset-cyrillic-sets.html
[c-a]: https://dev.mysql.com/doc/refman/8.0/en/charset-asian-sets.html
[c-b]: https://dev.mysql.com/doc/refman/8.0/en/charset-binary-set.html 
[c-u-c]: https://dev.mysql.com/doc/refman/8.0/en/charset-unicode.html

## 排序规则的解读

排序规则有三个部分组成：`<charset>_<lang>_<suffix>`，下面以 `utf8mb4_general_ci` 为例说明：

* `utf8mb4` 代表字符集
* `general` 代表语言，可以是 locale 代码或者语言名称，`general` 代表通用
* `_ci` 后缀代表大小写不敏感（case-insensitive），后缀可以有多个，比如 `_ai_ci`

后缀详细表格在这里：

| Suffix | 含义                 |
|:-------|:--------------------|
| `_ai`  |	Accent-insensitive |
| `_as`  |	Accent-sensitive   |
| `_ci`  |	Case-insensitive   |
| `_cs`  |	Case-sensitive     |
| `_ks`  |	Kana-sensitive，专供日语 |
| `_bin` |	Binary，字符的二进制码排序 |

注意：如果没有 `_ai` 和 `_as`，那么：
* `_ci` 暗含 `_ai`
* `_cs` 暗含 `_as`

文章的开头提到  `foo` 和 `Foo` 两个字符串值触发了唯一索引约束，是因为表使用了 `utf8mb4` 字符集和 `utf8mb4_general_ci` 排序规则。
`_ci` 后缀代表大小写不敏感，所以触发了唯一约束。
其实字符串匹配条件也是大小写不敏感的，`WHERE col='Foo'` 和 `WHERE col='foo'` 都能查询出数据。

关于 `_bin` 二进制排序规则有另外要注意的地方，见[文档][10]。

更多内容参阅 [文档][7]。

## 指定字符集和排序规则

指定服务器 [参考][2]：

```shell
mysqld
mysqld --character-set-server=utf8mb4
mysqld --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_0900_ai_ci
```

指定 Database [参考][3]：

```sql
CREATE DATABASE db_name
    [[DEFAULT] CHARACTER SET charset_name]
    [[DEFAULT] COLLATE collation_name]

ALTER DATABASE db_name
    [[DEFAULT] CHARACTER SET charset_name]
    [[DEFAULT] COLLATE collation_name]
```

指定表格 [参考][4]：

```sql
CREATE TABLE tbl_name (column_list)
    [[DEFAULT] CHARACTER SET charset_name]
    [COLLATE collation_name]]

ALTER TABLE tbl_name
    [[DEFAULT] CHARACTER SET charset_name]
    [COLLATE collation_name]
```

指定字段 [参考][5]：

```sql
col_name {CHAR | VARCHAR | TEXT} (col_length)
    [CHARACTER SET charset_name]
    [COLLATE collation_name]

col_name {ENUM | SET} (val_list)
    [CHARACTER SET charset_name]
    [COLLATE collation_name]
```

指定 `SELECT 'string'` 字符串，不常用，见 [文档][6]。

还有其他用法，自行参阅文档。

## 字符集变换

修改一个字段的字符集也有一些坑，见[文档][8]。

## 指定连接的字符集和排序规则

见[文档][9]。

## 参考文档

* [MySQL 8.0 Chapter 10 Character Sets, Collations, Unicode][1]


[1]: https://dev.mysql.com/doc/refman/8.0/en/charset.html
[2]: https://dev.mysql.com/doc/refman/8.0/en/charset-server.html
[3]: https://dev.mysql.com/doc/refman/8.0/en/charset-database.html
[4]: https://dev.mysql.com/doc/refman/8.0/en/charset-table.html
[5]: https://dev.mysql.com/doc/refman/8.0/en/charset-column.html
[6]: https://dev.mysql.com/doc/refman/8.0/en/charset-literal.html
[7]: https://dev.mysql.com/doc/refman/8.0/en/charset-collation-names.html
[8]: https://dev.mysql.com/doc/refman/8.0/en/charset-conversion.html
[9]: https://dev.mysql.com/doc/refman/8.0/en/charset-connection.html
[10]: https://dev.mysql.com/doc/refman/8.0/en/charset-binary-collations.html