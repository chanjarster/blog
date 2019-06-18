---
title: "MySQL Master Slave Docker部署例子"
author: "颇忒脱"
tags: ["docker", "mysql"]
date: 2019-06-18T17:33:31+08:00
---

<!--more-->

本文对应代码：[github](https://github.com/chanjarster/mysql-master-slave-docker-example)

用Docker部署基于GTID的MySQL Master-Slave Replication例子。

## 启动Master

写一个文件`mysql-master.cnf`：

```txt
[mysqld]
server_id=1
binlog_format=ROW
gtid_mode=ON
enforce-gtid-consistency=true
```

这个配置文件把Master的`server_id`设置为1，要注意在同一个Master-Slave集群里，`server_id`不能重复。

启动Master：

```bash
docker run -d --name mysql-master \
  -e MYSQL_USER=my_user \
  -e MYSQL_DATABASE=my_database \
  -e MYSQL_PASSWORD=my_database_password \
  -e MYSQL_ROOT_PASSWORD=my_root_password \
  -p 3307:3306 \
  -v $(pwd)/mysql-master.cnf:/etc/mysql/conf.d/mysql-master.cnf \
  mysql:8.0 \
  --log-bin=my
```

## 启动Slave

写一个文件`mysql-slave-1.cnf`：

```txt
[mysqld]
server_id=2
binlog_format=ROW
gtid_mode=ON
enforce-gtid-consistency=true
read_only=ON
```

这个文件把Slave的`server_id`设置为2，如果你有多个Slave，那么得分别设置不同的`server_id`。此外，将Slave设置为`read_only`模式（这样就不能在slave上执行写操作了）。

启动Slave：

```bash
docker run -d --name mysql-slave-1 \
  -e MYSQL_ROOT_PASSWORD=my_root_password \
  -p 3308:3306 \
  -v $(pwd)/mysql-slave-1.cnf:/etc/mysql/conf.d/mysql-slave-1.cnf \
  mysql:8.0 \
  --skip-log-bin \
  --skip-log-slave-updates \
  --skip-slave-start
```

## 创建Replication用户

到Master上创建Replication用户：

```bash
$ docker exec -it mysql-master mysql -u root -p
Enter password: my_root_password

mysql> CREATE USER 'repl'@'%' IDENTIFIED BY 'password';
mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
```

## 将Slave和Master关联

到Slave上把自己和Master关联起来：

```bash
$ docker exec -it mysql-slave-1 mysql -u root -p
Enter password: my_root_password

mysql> CHANGE MASTER TO 
  MASTER_HOST='192.168.101.21',
  MASTER_PORT=3307,
  MASTER_USER='repl',
  MASTER_PASSWORD='password',
  MASTER_AUTO_POSITION=1;
```

注意`MASTER_HOST`写的是Master所在的Host的IP，`MASTER_PORT`写的是Master暴露在Host上的端口，`MASTER_USER`和`MASTER_PASSWORD`则是Replication用户的信息。

最后正式启动Slave：

```bash
mysql> START SLAVE;
```

## 验证

到Slave上看看my_database是否存在：

```bash
$ docker exec -it mysql-slave-1 mysql -u root -p
Enter password: my_root_password

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| my_database        |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
5 rows in set (0.01 sec)
```

如果有就说明my_database从Master复制到了Slave上。

## 已知问题

### Slave无法使用hostname来链接Master

本例子中使用的MySQL Docker镜像自带了一个配置文件位置在`/etc/mysql/conf.d/docker.cnf`，它里面配置了：

```txt
[mysqld]
skip-host-cache
skip-name-resolve
```

注意`skip-name-resolve`，因为这个配置，在`MASTER_HOST`里只能写IP，不能写hostname，否则就解析不到。这个可以观察Slave的日志看到：`docker logs -f mysql-slave-1`。

### 本例在Mac上无法工作

这个是因为Slave容器无法访问到Master的host。解决办法我也不知道。

## 备选方案

[Bitnami MySQL Docker][bitnami-mysql]能够通过环境变量来配置Master-Slave Replication，不过它还不支持GTID。

## 参考资料

* [Setting Up Replication Using GTIDs][mysql-gtid-repl]
* [Binary Logging Options and Variables][mysql-opt-bin-log]
* [Replication Slave Options and Variables][mysql-repl-options]
* [DNS Lookup Optimization and the Host Cache][mysql-dns]
* [CHANGE MASTER TO Syntax][mysql-change-master]



[mysql-gtid-repl]: https://dev.mysql.com/doc/refman/8.0/en/replication-gtids-howto.html
[mysql-opt-bin-log]: https://dev.mysql.com/doc/refman/8.0/en/replication-options-binary-log.html
[mysql-repl-options]: https://dev.mysql.com/doc/refman/8.0/en/replication-options-slave.html
[mysql-dns]: https://dev.mysql.com/doc/refman/8.0/en/host-cache.html
[mysql-change-master]: https://dev.mysql.com/doc/refman/8.0/en/change-master-to.html
[bitnami-mysql]: https://hub.docker.com/r/bitnami/mysql