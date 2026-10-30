---
title: "MySQL Master Slave Docker部署例子"
author: "颇忒脱"
tags: ["docker", "mysql"]
date: 2019-06-18T17:33:31+08:00
---

<!--more-->

本文对应代码：[github][github]

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
  GET_MASTER_PUBLIC_KEY=1,
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

## docker-compose版本

在[github][github]上也提供了docker-compose.yaml，操作过程和上述一致，只不过容器名字会有变化。

```bash
# 拉起Master和Slave
$ docker-compose -p mysql-repl up
# 连接Master
$ docker exec -it mysql-repl_mysql-master_1 mysql -u root -p
# 连接Slave
$ docker exec -it mysql-repl_mysql-slave_1 mysql -u root -p
```

并且`CHANGE MASTER TO`语句有所不同，使用的是Master的Service Name以及容器内端口`3306`：

```bash
CHANGE MASTER TO 
  MASTER_HOST='mysql-master',
  MASTER_PORT=3306,
  MASTER_USER='repl',
  MASTER_PASSWORD='password',
  GET_MASTER_PUBLIC_KEY=1,
  MASTER_AUTO_POSITION=1;
```

## Troubleshooting

### docker run版本在Mac上无法工作

这个是因为Slave容器无法访问到Master的host。解决办法我也不知道。

### 关于`GET_MASTER_PUBLIC_KEY`

在做本例子时出现过Slave无法连接到Master的情况：

```txt
2019-06-19T01:34:24.361566Z 8 [System] [MY-010597] [Repl] 'CHANGE MASTER TO FOR CHANNEL '' executed'. Previous state master_host='', master_port= 3306, master_log_file='', master_log_pos= 4, master_bind=''. New state master_host='mysql-master', master_port= 3306, master_log_file='', master_log_pos= 4, master_bind=''.
2019-06-19T01:34:28.274728Z 9 [Warning] [MY-010897] [Repl] Storing MySQL user name or password information in the master info repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START SLAVE; see the 'START SLAVE Syntax' in the MySQL Manual for more information.
2019-06-19T01:34:28.330825Z 9 [ERROR] [MY-010584] [Repl] Slave I/O for channel '': error connecting to master 'repl@mysql-master:3306' - retry-time: 60  retries: 1, Error_code: MY-002061
2019-06-19T01:35:28.333735Z 9 [ERROR] [MY-010584] [Repl] Slave I/O for channel '': error connecting to master 'repl@mysql-master:3306' - retry-time: 60  retries: 2, Error_code: MY-002061
2019-06-19T01:36:28.335525Z 9 [ERROR] [MY-010584] [Repl] Slave I/O for channel '': error connecting to master 'repl@mysql-master:3306' - retry-time: 60  retries: 3, Error_code: MY-002061
...
```

详细细节可见这个[issue][issue]，这是因为MySQL 8默认启用了caching_sha2_password authentication plugin，issue中提到了一个办法：在启动Slave的时候添加`--default-auth=mysql_native_password`参数。不过我感觉这个不太好，查阅相关文档后发现可以在`CHANGE MASTER TO`添加`GET_MASTER_PUBLIC_KEY=1`参数来解决这个问题。

更多详情参考[caching_sha2_password and Replication][caching_sha2]和[CHANGE MASTER TO Syntax][mysql-change-master]。

## 参考资料

* [Setting Up Replication Using GTIDs][mysql-gtid-repl]

* [Binary Logging Options and Variables][mysql-opt-bin-log]

* [Replication Slave Options and Variables][mysql-repl-options]

* [DNS Lookup Optimization and the Host Cache][mysql-dns]

* [CHANGE MASTER TO Syntax][mysql-change-master]

* [caching_sha2_password and Replication][caching_sha2]

* [Bitnami MySQL Docker][bitnami-mysql], Bitnami制作的MySQL镜像，支持通过环境变量来配置Master-Slave Replication，不过它不支持GTID，只支持基于Binary Log的Replication。

  

[mysql-gtid-repl]: https://dev.mysql.com/doc/refman/8.0/en/replication-gtids-howto.html
[mysql-opt-bin-log]: https://dev.mysql.com/doc/refman/8.0/en/replication-options-binary-log.html
[mysql-repl-options]: https://dev.mysql.com/doc/refman/8.0/en/replication-options-slave.html
[mysql-dns]: https://dev.mysql.com/doc/refman/8.0/en/host-cache.html
[mysql-change-master]: https://dev.mysql.com/doc/refman/8.0/en/change-master-to.html
[bitnami-mysql]: https://hub.docker.com/r/bitnami/mysql
[github]: https://github.com/chanjarster/mysql-master-slave-docker-example
[issue]: https://github.com/docker-library/mysql/issues/572
[caching_sha2]: https://dev.mysql.com/doc/refman/8.0/en/upgrading-from-previous-series.html#upgrade-caching-sha2-password-replication