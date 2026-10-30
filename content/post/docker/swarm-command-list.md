---
title: "Docker Swarm基本命令清单"
author: "颇忒脱"
tags: ["docker"]
date: 2019-01-09T10:08:22+08:00
---

Docker swarm基本命令，更复杂的生产环境请仔细参阅文档。

<!--more-->

## 创建Swarm

准备两台服务器A、B

给服务器安装docker

确保所有服务器的防火墙开启了以下端口

* TCP/2377
* TCP/7946
* UDP/7946
* UDP/4789

ssh到A上，执行`docker swarm init`，A将作为manager，会输出类似下列的内容：

```txt
Swarm initialized: current node (dxn1zf6l61qsb1josjja83ngz) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join \
    --token SWMTKN-1-49nj1cmql0jkz5s954yi3oex3nedyz0fb0xx14ie39trti4wxv-8vxv8rssmk743ojnwacrr2e7c \
    <ip>:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

ssh到B上，执行上面提到的`docker swarm join ...`指令，B将作为worker

执行`docker node ls`，查看Swarm集群node

```txt
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
yd05eu5uvcqm0pbi8g6r25b2c *   docker-learn-1      Ready               Active              Leader              18.09.0
jkycxb3c7swrn5t37fp1d1xwb     docker-learn-2      Ready               Active                                  18.09.0
```

## node管理

### 添加manager

生产环境中应该有多个manager来保证高可用，manager的数量应该是单数，比如1、3、5。

到manager机器上，执行`docker swarm join-token manager`，得到以下输出：

```txt
To add a manager to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-0tfd7v1bu05od7fdsedqdu6tuny6ozjmfrq3hiwmc1xb5yaxix-e7kpq257cyblpdna9j89cjgyw <ip>:2377
```

到新机器上执行上述指令，添加manager

### 添加worker

到manager node上执行`docker swarm join-token worker`，得到以下输出：

```txt
To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-0tfd7v1bu05od7fdsedqdu6tuny6ozjmfrq3hiwmc1xb5yaxix-1fc3updzbx9tssop55yznh79w <ip>:2377
```

到新机器上执行上述指令，添加worker

### 更新节点AVAILABILITY

节点AVAILABILITY有三种状态：

* `ACTIVE`：可以安排新的工作负载到这个节点
* `PAUSE`：不会安排新的工作负载到这个节点，但是已经存在的负载继续运行
* `DRAIN`：不会安排新的工作负载到这个节点，已经存在的负载会被驱逐到其他node上

注意，上面提到的禁止安排、驱逐工作负载仅针对于`docker service create ...`、`docker stack deploy ...`创建的工作负载。对于`docker run ...`、`docker compose up ...`的工作负载不起作用。


运行以下命令更新节点的AVAILIBALITY：

```bash
docker node update --availability <active|pause|drain> <NODE-ID>
```

比如：

```bash
docker node update --availability drain <NODE-ID>
```

### 禁止manager承担工作负载

默认情况下manager也承担工作负载，在生产环境中这样不太好，因为manager可能会因为工作负载过多而变得卡顿，导致无法工作。

解决办法很简单，将manager的AVAILIBALITY变成`DRAIN`就行了

### 删除节点

到服务器上执行 `docker swarm leave`

如果是manager，则可能会报warning，你只需要这样`docker swarm leave --force`


### 清理swarm

删除所有manager和worker节点，swarm就被清理掉了。

## 参考文档

* [Getting started with swarm mode][doc-swarm-get-started]
* [Create a swarm][doc-swarm-create]
* [Add nodes to the swarm][dock-swarm-add-nodes]
* [Manage nodes in a swarm][doc-swarm-manager-nodes]
* [Administer and maintain a swarm of Docker Engines][doc-swarm-admin]

[doc-swarm-get-started]: https://docs.docker.com/engine/swarm/swarm-tutorial/
[doc-swarm-create]: https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/
[dock-swarm-add-nodes]: https://docs.docker.com/engine/swarm/swarm-tutorial/add-nodes/
[doc-swarm-manager-nodes]: https://docs.docker.com/engine/swarm/manage-nodes/
[doc-swarm-admin]: https://docs.docker.com/engine/swarm/admin_guide/
