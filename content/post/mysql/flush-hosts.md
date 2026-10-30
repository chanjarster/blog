---
title: "MySQL - block host 连接"
author: "颇忒脱"
tags: ["mysql", "troubleshooting"]
date: 2023-06-21T11:39:00+08:00
---

<!--more-->

有时候遇到这个错误：

```shell
Host 'xxx' is blocked because of many connection errors; unblock with 'mysqladmin flush-hosts'
```

可以用 root 登陆 MySQL 查询 IP 对应的连接错误数量：

```sql
select * from performance_schema.host_cache;
```

执行以下命令清空 `host_cache` 表，然后就可以了：

```sql
flush hosts;
```

也可以调整 `max_connect_errors` 来放大 block 的阈值：

```shell
SET PERSIST max_connect_errors = 1000;
```

## 参考资料

* [FLUSH HOSTS][flush-hosts]
* [max_connect_errors][max_connect_errors]

[flush-hosts]: https://dev.mysql.com/doc/refman/8.0/en/flush.html#flush-hosts
[max_connect_errors]: https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_max_connect_errors