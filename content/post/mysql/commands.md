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
* 开启慢查询日志：`set global slow_query_log=1;`
* 执行shell命令：`system ...`
* 查询超过60秒的长事务：
  `select * from information_schema.innodb_trx where TIME_TO_SEC(timediff(now(),trx_started))>60;`

常见参数：

* `wait_timeout`：控制数据库连接多少时间没有动静就断开，默认8小时。
* 慢日志查询相关参数：`show variables like '%slow%;`和`long_query_time`（单位秒）
* `transaction-isolation`，查看数据库隔离级别