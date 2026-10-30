---
title: "数据库时区那些事儿 - Oracle的时区处理"
author: "颇忒脱"
tags: ["JDBC", "Oracle", "数据库时区那些事儿"]
date: 2018-09-18T10:41:33+08:00
---

当JVM时区和数据库时区不一致的时候，会发生什么？这个问题也许你从来没有注意过，但是当把Java程序容器化的时候，问题就浮现出来了，因为目前几乎所有的Docker Image的时区都是UTC。本文探究了Oracle及其JDBC驱动对于时区的处理方式，并尝试给出最佳实践。

<!--more-->

## 先给总结

* `DATE`和`TIMESTAMP`类型不支持时区转换。
* 如果应用和Oracle的时区不一致，那么应该使用`TIMESTAMP WITH LOCAL TIME ZONE`。
  * 对于JDBC程序来说，JVM时区和用户时区保持一致就行了。
* 如果应用和Oracle的时区不一致，而且需要保存时区信息，那么应该使用`TIMESTAMP WITH TIME ZONE`。
* 格式化日期时间字符串函数`TO_CHAR`：
  * 对于`TIMESTAMP WITH TIME ZONE`来说，使用`TO_CHAR`时要注意让它输出时区信息（`TZH:TZM TZR TZD`），否则结果会是截断的。
  * 对于`TIMESTAMP WITH LOCAL TIME ZONE`来说，使用`TO_CHAR`返回的结果会转换时区。
* 当前日期时间的函数：
  * 除非必要，不要使用`SYSDATE`和`SYSTIMESTAMP`，这个返回的是数据库所在操作系统的时间。
  * 尽量使用`CURRENT_TIMESTAMP`，它返回的是`TIMESTAMP WITH TIME ZONE`，能够用来安全的比较时间。

## 日期时间类型的时区

[Oracle Datetime Datatypes][oracle-datetime-types]有这么几种：

* [DATE][oracle-dt-types-date]，保存`YYYY-MM-DD HH24:MI:SS`。
* [TIMESTAMP][oracle-dt-types-timestamp]，比`DATE`多存了fractional seconds（`FF`）。
* [TIMESTAMP WITH TIME ZONE][oracle-dt-types-timestamp-tz]，比`TIMESTAMP`多了时区偏移量（比如+08:00，`TZH:TZM`）or 时区区域名称（比如Asia/Shanghai，`TZR`）和夏令时标记（`TZD`）。
* [TIMESTAMP WITH LOCAL TIME ZONE][oracle-dt-types-timestamp-ltz]。和`TIMESTAMP`类似，不过存储的数据会标准化为数据库的时区，用户获取它的时候会转换成用户时区（对于JDBC来说，就是JVM时区）。

```bash
docker run --name oracle-xe-timezone-test \
  -e ORACLE_ALLOW_REMOTE=true \
  -p 1521:1521 \
  -d wnameless/oracle-xe-11g:16.04
```

然后用system/oracle用户登录到oracle，执行下列sql建表：

```sql
create table test (
  date_field date,
  ts_field timestamp,
  ts_tz_field timestamp with time zone,
  ts_ltz_field timestamp with local time zone
);
```

为了验证这个结论，我写了一段程序来实验，这个程序做了三件事情：

1. 使用Asia/Shanghai时区构造一个日期java.util.Date：2018-09-14 10:00:00，然后插入到数据库里。
1. 使用Asia/Shanghai时区把这个值再查出来，看看结果。
1. 使用Asia/Shanghai时区，获得这个字段的格式化字符串（使用DATE_FORMAT()函数）。
1. 使用Europe/Paris时区重复第2-3步的动作。

运行程序获得以下结果：

```txt
JVM Time Zone      : 中国标准时间
Retrieve java.util.Date from DATE column                              : 2018-09-14 10:00:00.0
Retrieve java.util.Date from TIMESTAMP column                         : 2018-09-14 10:00:00.0
Retrieve java.util.Date from TIMESTAMP WITH TIME ZONE column          : 2018-09-14 10:00:00.0
Retrieve java.util.Date from TIMESTAMP WITH LOCAL TIME ZONE column    : 2018-09-14 10:00:00.0
Retrieve formatted string from DATE column                            : 2018-09-14 10:00:00
Retrieve formatted string from TIMESTAMP column                       : 2018-09-14 10:00:00
Retrieve formatted string from TIMESTAMP WITH TIME ZONE column        : 2018-09-14 10:00:00 +08:00 ASIA/SHANGHAI CST
Retrieve formatted string from TIMESTAMP WITH LOCAL TIME ZONE column  : 2018-09-14 10:00:00
--------------------
JVM Time Zone      : 中欧时间
Retrieve java.util.Date from DATE column                              : 2018-09-14 10:00:00.0
Retrieve java.util.Date from TIMESTAMP column                         : 2018-09-14 10:00:00.0
Retrieve java.util.Date from TIMESTAMP WITH TIME ZONE column          : 2018-09-14 04:00:00.0
Retrieve java.util.Date from TIMESTAMP WITH LOCAL TIME ZONE column    : 2018-09-14 04:00:00.0
Retrieve formatted string from DATE column                            : 2018-09-14 10:00:00
Retrieve formatted string from TIMESTAMP column                       : 2018-09-14 10:00:00
Retrieve formatted string from TIMESTAMP WITH TIME ZONE column        : 2018-09-14 10:00:00 +08:00 ASIA/SHANGHAI CST
Retrieve formatted string from TIMESTAMP WITH LOCAL TIME ZONE column  : 2018-09-14 04:00:00
```

可以看到，`DATE`和`TIMESTAMP`是不支持时区转换的，实际上`DATE`和`TIMESTAMP`会丢弃掉时区信息。

对于`TIMESTAMP WITH TIME ZONE`来说，使用`TO_CHAR`时要注意让它输出时区信息（`TZH:TZM TZR TZD`），否则结果会是截断的。

对于`TIMESTAMP WITH LOCAL TIME ZONE`来说，使用`TO_CHAR`返回的结果会转换时区。

## 当前日期时间相关函数

[Oracle和当前时间有关的函数][oracle-datetime-sql-functions]有这么几个：

* `CURRENT_DATE`，返回的是`DATE`类型
* `CURRENT_TIMESTAMP`，返回的是`TIMESTAMP WITH TIME ZONE`类型
* `LOCALTIMESTAMP`，返回的是`TIMESTAMP`类型
* `SYSDATE`，返回的是`DATE`类型
* `SYSTIMESTAMP`，返回的是`TIMESTAMP`类型

写了一段程序，输出结果是这样的：

```txt
=========TEST CURRENT DATE/TIME FUNCTIONS===========
JVM Time Zone               : 中国标准时间
Test CURRENT_DATE           : 2018-09-18 10:27:23.0
Test CURRENT_TIMESTAMP      : 2018-09-18 10:27:23.880378 Asia/Shanghai
Test LOCALTIMESTAMP         : 2018-09-18 10:27:23.926375
Test SYSDATE                : 2018-09-18 02:27:23.0
Test SYSTIMESTAMP           : 2018-09-18 02:27:23.929605 +0:00
--------------------
JVM Time Zone               : 中欧时间
Test CURRENT_DATE           : 2018-09-18 04:27:45.0
Test CURRENT_TIMESTAMP      : 2018-09-18 04:27:45.429024 Europe/Paris
Test LOCALTIMESTAMP         : 2018-09-18 04:27:45.482485
Test SYSDATE                : 2018-09-18 02:27:45.0
Test SYSTIMESTAMP           : 2018-09-18 02:27:45.48582 +0:00
```

可以发现，`CURRENT_DATE`、`CURRENT_TIMESTAMP`、`LOCALTIMESTAMP`的结果都根据客户端时区做了转换。而`SYSDATE`和`SYSTIMESTAMP`返回的则是数据库所在操作系统所在时区的时间。

## 在Oracle客户端操作时区

```sql
-- 查询系统时区和session时区
SELECT DBTIMEZONE, SESSIONTIMEZONE FROM DUAL;

-- 设置session时区
ALTER SESSION SET TIME_ZONE='Asia/Shanghai';
```

参见[Setting the Database Time Zone][oracle-setting-db-tz] 和 [Setting the Session Time Zone][oracle-setting-session-tz]

## 参考资料

* [Oracle Datetime Datatypes][oracle-datetime-types]
* [Oracle和当前时间有关的函数][oracle-datetime-sql-functions]
* [Oracle Datetime Comparisons][oracle-dt-comparision]
* [Setting the Database Time Zone][oracle-setting-db-tz]
* [Setting the Session Time Zone][oracle-setting-session-tz]
* [Oracle JDBC Connection Constant Field Values][Oracle JDBC Connection Constant Field Values]
* [W3C- Working with timezone][w3c-working-with-timezone]

## 相关代码

https://github.com/chanjarster/jdbc-timezone

[oracle-datetime-types]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1005983
[oracle-dt-types-date]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006006
[oracle-dt-types-timestamp]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006050
[oracle-dt-types-timestamp-tz]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006081
[oracle-dt-types-timestamp-ltz]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006169
[oracle-setting-db-tz]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006705
[oracle-setting-session-tz]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006728
[oracle-datetime-sql-functions]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1006333
[Oracle JDBC Connection Constant Field Values]: https://docs.oracle.com/database/121/JAJDB/constant-values.html#oracle_jdbc_OracleConnection_ACCESSMODE_SYSTEMPROP
[w3c-working-with-timezone]: https://www.w3.org/TR/timezone/
[oracle-dt-comparision]: https://docs.oracle.com/cd/B19306_01/server.102/b14225/ch4datetime.htm#i1009114