---
title: "MySQL - 开启日志记录"
author: "颇忒脱"
tags: ["mysql", "troubleshooting"]
date: 2023-06-21T16:03:02+08:00
---

<!--more-->

MySQL 支持将 Query 和 Slow Query 日志输出到文件或者表里。

输出 Query 日志到文件（注意 Query 日志会很大，排查结束后就要关掉）（注意目录要提前建好）：

```sql
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/log/mysql/mysql.log';
```

输出 Slow Query 日志到文件（注意目录要提前建好）：

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';
```

如果要把 Query 和 Slow Query 输出到表里：

```sql
SET GLOBAL log_output='TABLE,FILE';
SET GLOBAL log_error_verbosity = 1;
```

查询日志表：

```sql
SELECT * FROM mysql.general_log;
SELECT * FROM mysql.slow_log;
```

清理日志表：

```sql
TRUNCATE TABLE mysql.general_log;
TRUNCATE TABLE mysql.slow_log;
```

## 参考资料

* [MySQL Server Logs][my-logs]
* [Selecting General Query Log and Slow Query Log Output Destinations][log-dst]
* [general_log][general_log]
* [general_log_file][general_log_file]
* [slow_query_log][slow_query_log]
* [slow_query_log_file][slow_query_log_file]
* [log_output][log_output]

[my-logs]: https://dev.mysql.com/doc/refman/8.0/en/server-logs.html
[log-dst]: https://dev.mysql.com/doc/refman/8.0/en/log-destinations.html
[general_log]: https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_general_log
[general_log_file]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_slow_query_log
[slow_query_log]: https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_general_log_file
[slow_query_log_file]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_slow_query_log_file
[log_output]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_log_output
[log_error_verbosity]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_log_error_verbosity