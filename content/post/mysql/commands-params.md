---
title: "MySQL - 常见命令及参数"
author: "颇忒脱"
tags: ["mysql"]
date: 2019-12-18T22:55:52+08:00
---

<!--more-->

docker测试：

```bash
docker run -d --name mysql8 \
-e MYSQL_ROOT_PASSWORD=12345 \
-e MYSQL_USER=test \
-e MYSQL_PASSWORD=test \
-e MYSQL_DATABASE=test \
mysql:8

docker exec -it mysql8 mysql -u test -p test
```

常见命令：

* 查看数据库连接：`show processlist`
* 查看数据库参数：`show variables`也可以模糊查询`show variables like '%wait%'`
* 执行shell命令：`system ...`
* 查询超过60秒的长事务：
  `select * from information_schema.innodb_trx where TIME_TO_SEC(timediff(now(),trx_started))>60;`
* 重建索引：`alter table T engine=InnoDB`
* [`FLUSH TABLES WITH READ LOCK`][5]：全局读锁

系统参数：

* 设置全局参数：`set global xxx=yyy`
* 持久全局参数：`set persist xxx=yyy`
* [`wait_timeout`][1]：控制数据库连接多少时间没有动静就断开，默认8小时。
* 慢日志查询相关参数：`show variables like '%slow%;`和`long_query_time`（单位秒）
* [`slow_query_log`][2]：是否开启慢日志查询
* [`transaction_isolation`][3]，查看数据库隔离级别
* [`max_execution_time`][4]，SELECT语句的最大执行时长
* [`innodb_lock_wait_timeout`][6]，事务获得行锁的最大等待时间（秒）。默认50秒。
* [`innodb_deadlock_detect`][7]，开启死锁检测。默认on。
* [`binlog_expire_logs_seconds`][9]，binlog的保留时间（秒），默认30天。

InnoDB 参数：

* [`innodb_page_size`][10]，数据页大小，默认16K
* [`innodb_change_buffering`][11]，change buffer模式，默认all
* [`innodb_change_buffer_max_size`][12]，change buffer占用buffer pool的比例

session参数：

* 设置Session参数：`set xxx=yyy`
* [`sql_log_bin`][8]：控制当前session是否产生binlog。

[1]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_wait_timeout
[2]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_slow_query_log
[3]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_transaction_isolation
[4]: https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_max_execution_time
[5]: https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-tables-with-read-lock
[6]: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_lock_wait_timeout
[7]: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_deadlock_detect
[8]: https://dev.mysql.com/doc/refman/8.0/en/set-sql-log-bin.html
[9]: https://dev.mysql.com/doc/refman/8.0/en/replication-options-binary-log.html#sysvar_binlog_expire_logs_seconds
[10]: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_page_size
[11]: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_change_buffering
[12]: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_change_buffer_max_size