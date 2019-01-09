---
title: "一种生产环境Docker Overlay Network的配置方案"
author: "颇忒脱"
tags: ["docker"]
date: 2019-01-09T10:59:56+08:00
---

介绍一种生产环境Docker overlay network的配置方案。

<!--more-->

## 概要

先讲一下生产环境中的问题：

* 有多个Docker host，希望能够通过Docker swarm连接起来。
* Docker swarm只适合于无状态应用，不适合有状态应用。
* 因此生产环境中会同时存在
  1. 无状态应用：利用`docker service create`/`docker stack deploy`创建的。
  2. 有状态应用：利用`docker run`/`docker compose up`创建的。
* 希望两种应用能够连接到同一个overlay网络，在网络内部能够通过
  1. `tasks.<service-name>` DNS name 连接到无状态应用（见[Container discovery][doc-cd]）
  2. `<container-name>` DNS name 连接到有状态应用

解决办法：

1. 创建attachable的overlay network
2. 有状态应用挂到这个overlay network上
3. 无状态应用也挂到这个overlay network上

## 步骤

到manager节点上创建attachable的overlay network，名字叫做prod-overlay：

```bash
docker network create -d overlay --attachable prod-overlay
```

在manager节点上查看这个网络是否创建成功：

```bash
$ docker network ls

NETWORK ID          NAME                DRIVER              SCOPE
fbfde97ed12a        bridge              bridge              local
73ab6bbac970        docker_gwbridge     bridge              local
a2adb3de5f7a        host                host                local
nm7pgzuh6ww4        ingress             overlay             swarm
638e550dab67        none                null                local
qqf78g8iio10        prod-overlay        overlay             swarm
```

在worker节点上查看这个网络，这时你看不到这个网络，不过不要担心，当后面在worker节点上创建工作负载后就能看到了：

```bash
$ docker network ls

NETWORK ID          NAME                DRIVER              SCOPE
fbfde97ed12a        bridge              bridge              local
73ab6bbac970        docker_gwbridge     bridge              local
a2adb3de5f7a        host                host                local
nm7pgzuh6ww4        ingress             overlay             swarm
638e550dab67        none                null                local
```

在manager上创建容器`c1`，挂到`prod-overlay` network上：
```bash
docker run --name c1 --network prod-overlay -itd busybox
```

在worker上创建容器`c2`，挂到`prod-overlay` network上：

```bash
docker run --name c2 --network prod-overlay -itd busybox
```

在manager上创建service `c`，挂到`prod-overlay` network上：

```bash
docker service create -td --name c --replicas 2 --network prod-overlay busybox
```

## 验证

### 查看worker节点的network

之前在worker节点上没有看到`prod-overlay` network，现在你应该可以看见了：

```bash
$ docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
01180b9d4833        bridge              bridge              local
cd94df435afc        docker_gwbridge     bridge              local
74721e7670eb        host                host                local
nm7pgzuh6ww4        ingress             overlay             swarm
32e6853ea78d        none                null                local
dw8kd2nb2yl3        prod-overlay        overlay             swarm
```

### 确认容器可以互ping


到manager节点上，让`c1` ping `c2`

```bash
$ docker exec c1 ping -c 2 c2
PING c2 (10.0.2.2): 56 data bytes
64 bytes from 10.0.2.2: seq=0 ttl=64 time=0.682 ms
64 bytes from 10.0.2.2: seq=1 ttl=64 time=0.652 ms
```

到manager节点上，让`c1` ping `tasks.c`，`tasks.c`是之前创建的service `c`的DNS name：

```bash
$ docker exec c1 ping -c 2 tasks.c
PING tasks.c (10.0.2.8): 56 data bytes
64 bytes from 10.0.2.8: seq=0 ttl=64 time=2.772 ms
64 bytes from 10.0.2.8: seq=1 ttl=64 time=0.694 ms
```

到manager节点上，让`c1` 查询 `tasks.c`的DNS name，可以看到`tasks.c`有两条记录：

```bash
$ docker exec c1 nslookup -type=a tasks.c
Server:		127.0.0.11
Address:	127.0.0.11:53

Non-authoritative answer:
Name:	tasks.c
Address: 10.0.2.7
Name:	tasks.c
Address: 10.0.2.8
```

到manager节点上，查看service `c`的task，看到有`c.1`、`c.2`两个task，分别部署在两个节点上：

```bash
$ docker service ps c
ID            NAME  IMAGE           NODE            DESIRED STATE  CURRENT STATE           ERROR  PORTS
p5n70vhtnz2f  c.1   busybox:latest  docker-learn-1  Running        Running 17 minutes ago
byuoox1t7cve  c.2   busybox:latest  docker-learn-2  Running        Running 17 minutes ago
```

到`c.1` task所在的节点上，查看task `c.1`的容器名：

```bash
$ docker ps -f name=c.1
CONTAINER ID  IMAGE           COMMAND  CREATED         STATUS         PORTS  NAMES
795a3bd3c20a  busybox:latest  "sh"     21 minutes ago  Up 21 minutes         c.1.p5n70vhtnz2f5q8p2pcvbyfmw
```

然后在`c1`里ping task `c.1`的容器名：

```bash
$ docker exec c1 ping -c 2 c.1.p5n70vhtnz2f5q8p2pcvbyfmw
PING c.1.p5n70vhtnz2f5q8p2pcvbyfmw (10.0.2.7): 56 data bytes
64 bytes from 10.0.2.7: seq=0 ttl=64 time=0.198 ms
64 bytes from 10.0.2.7: seq=1 ttl=64 time=0.128 ms
```

你同样可以：

* 在`c2`里：
  1. ping `c1`
  1. ping `tasks.c`
  1. ping task `c.1`、`c.2`的容器
* 在task `c.1`、`c.2`的容器里：
  1. ping `c1`、`c2`；
  1. ping `tasks.c`
  1. ping task `c.1`、`c.2`的容器

## 注意

通过`docker run` / `docker compose up`创建的容器的名字，要保证在整个集群里是唯一的。docker 不会帮你检查名称冲突的情况，如果名称冲突了那么会得到错误的DNS结果。

## 参考资料

* [Use overlay networks][doc-overlay]
* [Use an overlay network for standalone containers][doc-standalone]


[doc-cd]: https://docs.docker.com/network/overlay/#container-discovery
[doc-overlay]: https://docs.docker.com/network/overlay/
[doc-standalone]: https://docs.docker.com/network/network-tutorial-overlay/#use-an-overlay-network-for-standalone-containers