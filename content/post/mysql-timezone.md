---
title: "数据库时区那些事儿 - MySQL的时区处理"
author: "颇忒脱"
tags: ["JDBC", "MySQL", "数据库时区那些事儿"]
date: 2018-09-17T15:09:20+08:00
---

当JVM时区和数据库时区不一致的时候，会发生什么？这个问题也许你从来没有注意过，但是当把Java程序容器化的时候，问题就浮现出来了，因为目前几乎所有的Docker Image的时区都是UTC。本文探究了MySQL及其JDBC驱动对于时区的处理方式，并尝试给出最佳实践。

<!--more-->

## 先给总结

* `DATE`和`TIME`类型不支持时区转换。
* 对于`TIMESTAMP`类型，MySQL会正确的根据connection时区（对于JDBC来说就是JVM时区）/服务端时区做转换。
  * JDBC程序不需要特别注意什么事情。只要保证JVM时区和用户所在时区保持一致即可。
* 不要在服务器端做日期时间的字符串格式化（`DATE_FORMAT()`），因为返回的结果是服务端的时区，而不是connection的时区（对于JDBC来说就是JVM时区）。
* `CURRENT_TIMESTAMP()`, `CURRENT_TIME()`, `CURRENT_DATE()`可以安全的使用，返回的结果会转换成connection时区（对于JDBC来说就是JVM时区）。
* `CURRENT_TIME()`有一个不知道是不是BUG的[Bug #92453][mysql-bug-92453]。

## 日期时间类型的时区

[MySQL - The DATE, DATETIME, and TIMESTAMP Types][mysql-datetime-types]：

> MySQL converts `TIMESTAMP` values from the current time zone to UTC for storage, and back from UTC to the 
> current time zone for retrieval. (This does not occur for other types such as `DATETIME`.) 
> By default, the current time zone for each connection is the server's time. The time zone can be set on 
> a per-connection basis. 
> As long as the time zone setting remains constant, you get back the same value you store. 
> If you store a `TIMESTAMP` value, and then change the time zone and retrieve the value, the retrieved value 
> is different from the value you stored. This occurs because the same time zone was not used for conversion 
> in both directions. 

简而言之就是两句话：

1. 查询`TIMESTAMP`类型所返回的值，会根据connection的时区（对于JDBC来说就是JVM时区）做转换
2. 在MySQL中只有`TIMESTAMP`类型会做时区转换

为了验证这个结论，我写了一段程序来实验，这个程序做了三件事情：

1. 使用`Asia/Shanghai`时区构造一个日期`java.util.Date`：`2018-09-14 10:00:00`，然后插入到数据库里（表：test，列：timestamp类型）
1. 使用`Asia/Shanghai`时区把这个值再查出来，看看结果。
1. 使用`Asia/Shanghai`时区，获得这个字段的格式化字符串（使用`DATE_FORMAT()`函数）。
1. 使用`Europe/Paris`时区重复第2-3步的动作

在运行程序之前，我们先用Docker启动一个MySQL，它所在的MySQL的时区是UTC（除非特别设定，所有Docker Image时区都默认为UTC）：

```bash
docker run --name mysql-timezone-test \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=tz \
  -e MYSQL_PASSWORD=tz \
  -p 3306:3306 \
  -d mysql:8
```

下面是结果：

```txt
Insert data, Time Zone        : 中国标准时间
java.util.Date                : 2018-09-14 10:00:00
Insert into timestamp column  : 2018-09-14 10:00:00
--------------------
Retrieve data, Time Zone      : 中国标准时间
Retrieve java.util.Date       : 2018-09-14 10:00:00
Retrieve formatted string     : 2018-09-14 02:00:00
--------------------
Retrieve data, Time Zone      : 中欧时间
Retrieve java.util.Date       : 2018-09-14 04:00:00
Retrieve formatted string     : 2018-09-14 02:00:00
```

可以看到`Retrieve java.util.Date`返回的结果根据JVM时区做了转换的。而`Retrieve formatted string`返回的结果则是UTC时间。

## 当前日期时间相关函数

MySQL与"当前日期时间"相关的函数有这么些，[MySQL - Date and Time Functions][mysql-date-time-functions]：

> The `CURRENT_TIMESTAMP()`, `CURRENT_TIME()`, `CURRENT_DATE()`, and `FROM_UNIXTIME()` functions return values 
> in the connection's current time zone, which is available as the value of the time_zone system variable.

而且根据文档所讲，它们返回的结果匹配当前连接所设定的时区。

为了验证这个结论，同样写了一段程序，分别使用`Asia/Shanghai`和`Europe/Paris`来调用`CURRENT_TIMESTAMP()`、`CURRENT_TIME()`、`CURRENT_DATE()`。

下面是运行结果：

```txt
JVM Time Zone              : 中国标准时间
Test CURRENT_DATE()        : 2018-09-18
Test CURRENT_TIME()        : 10:55:41
Test CURRENT_TIMESTAMP()   : 2018-09-18 10:55:41.0
--------------------
JVM Time Zone              : 中欧时间
Test CURRENT_DATE()        : 2018-09-18
Test CURRENT_TIME()        : 03:56:02
Test CURRENT_TIMESTAMP()   : 2018-09-18 04:56:02.0
```

可以看到结果是基本符合文档里的说明的，但是要注意，在`Europe/Paris`时区，`CURRENT_TIME()`和`CURRENT_TIMESTAMP()`的时间部分相差一小时。
看上去`CURRENT_TIMESTAMP()`返回的是UTC DST offset结果，而`CURRENT_TIME()`返回的是UTC offset结果，关于这个我登记了[Bug #92453][mysql-bug-92453]。
关于`Europe/Paris`的DST信息可以在这里找到[Wiki - List of tz database time zones][wiki-tz-database]。

## 在MySQL客户端操作时区

```sql
-- 查询系统时区和session时区
SELECT @@global.time_zone, @@session.time_zone;

-- 设置session时区
SET time_zone = 'Asia/Shanghai';
```

详见：[MySQL Server Time Zone Support][mysql-timezone-support]

## 参考资料

* [MySQL - The DATE, DATETIME, and TIMESTAMP Types][mysql-datetime-types]
* [MySQL - Date and Time Functions][mysql-date-time-functions]
* [MySQL Server Time Zone Support][mysql-timezone-support]
* [Wiki - List of tz database time zones][wiki-tz-database]
* [W3C- Working with timezone][w3c-working-with-timezone]

## 相关代码

https://github.com/chanjarster/jdbc-timezone

[mysql-timezone-support]: https://dev.mysql.com/doc/refman/8.0/en/time-zone-support.html
[mysql-datetime-types]: https://dev.mysql.com/doc/refman/8.0/en/datetime.html
[mysql-date-time-functions]: https://dev.mysql.com/doc/refman/8.0/en/date-and-time-functions.html
[wiki-tz-database]: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
[mysql-bug-92453]: https://bugs.mysql.com/bug.php?id=92453
[w3c-working-with-timezone]: https://www.w3.org/TR/timezone/