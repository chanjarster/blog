---
title: "如何在Docker Swarm部署应用"
author: "颇忒脱"
tags: ["docker", "tagB", "运维"]
date: 2019-02-01T09:02:45+08:00
---

<!--more-->

## 大纲

本文只是一种实际部署方案的例子，涉及到的技术有（除Docker/Docker Swarm外）：

1. Docker [overlay network][overlay-network]
1. [Fluentd][fluentd]
1. Prometheus stack
1. [vegasbrianc的Prometheus监控方案][v-p8s-mon-solution]

步骤大纲：

1. 部署Docker machine
   1. 基本配置
   1. 配置网络
   1. 启动Fluentd日志服务
1. 部署Docker swarm集群
   1. 配置网络
   1. 添加Node
1. 部署Prometheus stack
   1. 给Node打Label
   1. 创建监控网络
   1. 启动service
1. 部署应用
   1. 识别stateless与stateful
   1. 创建应用网络
   1. 给Node打Label
   1. 启动service

## 1 部署Docker machine


### 1.1 基本配置

准备若干Linux服务器（本例使用Ubuntu 16.04），参照[Docker CE 镜像源站][aliyun-docker-ce]提到的步骤安装Docker CE。

参照[Docker Daemon生产环境配置][docker-daemon-prod]。

### 1.2 配置bridge网络

参照[Docker Daemon生产环境配置][docker-daemon-prod]中的mtu和子网章节。

### 1.3 启动Fluentd日志服务

参考[使用Fluentd收集Docker容器日志][collect-docker-log-by-fluentd]。

## 2 部署Docker swarm集群

到一台机器上执行`docker swarm init`，这个机器将作为manager node。

执行`docker node ls`会看到类似下面的结果：

```bash
$ docker node ls

ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
dxn1zf6l61qsb1josjja83ngz *  manager1  Ready   Active        Leader
```

如果你计划不会把工作负载跑在manager node上，那么使用`docker drain`：

```bash
docker node update --availability drain <node-id>
```

可参考[Docker Swarm基本命令清单][swarm-command-list]。

### 2.1 配置网络MTU和子网

参考[Docker Overlay网络的MTU][docker-overlay-network-mtu]。

**特别注意**

观察`docker_gwbridge`和`ingress`的子网是否与已有网络冲突：

```bash
$ docker network inspect -f '{{json .IPAM}}' docker_gwbridge
{"Driver":"default","Options":null,"Config":[{"Subnet":"172.18.0.0/16","Gateway":"172.18.0.1"}]}

$ docker network inspect -f '{{json .IPAM}}' ingress
{"Driver":"default","Options":null,"Config":[{"Subnet":"10.255.0.0/16","Gateway":"10.255.0.1"}]}
```

如果有冲突则参考[Docker Overlay网络的MTU][docker-overlay-network-mtu]中的方法修改子网。

### 2.2 添加Node

参考[Docker Swarm基本命令清单][swarm-command-list]。

## 3 部署Prometheus stack

使用的是[vegasbrianc的Prometheus监控方案][v-p8s-mon-solution]。

整个监控方案包含一下几个组件：

1. Prometheus
1. Node-exporter，运行在每个node上
1. Alertmanager
1. cAdvisor，运行在每个node上
1. Grafana


### 3.1 给Node打Label

挑选一台Node作为运行监控服务的机器。给这个node打上label：

```bash
$ docker node update --label-add for-monitor-stack=1 <node-id>
```
### 3.2 创建监控网络

```bash
$ docker network create -d overlay --attachable monitor-net
```

参考参考[Docker Overlay网络的MTU][docker-overlay-network-mtu]检查子网与MTU是否配置正确。

### 3.3 启动service

clone [vegasbrianc的Prometheus监控方案][v-p8s-mon-solution] 项目代码。

使用我修改过的[docker-stack.yml][gist-docker-stack.yml]

启动service：

```bash
$ docker stack deploy \
  --with-registry-auth \
  --prune \
  -c docker-stack.yml \
  p8s-monitor-stack
```

访问地址：

* Prometheus：`http://<任意swarm node ip>:9000`
* Node-exporter：`http://<任意swarm node ip>:9010`
* Alertmanager：`http://<任意swarm node ip>:9020`
* cAdvisor：`http://<任意swarm node ip>:9030`
* Grafana：`http://<任意swarm node ip>:9040`，用户名admin，密码foobar

## 4 部署应用

### 4.1 识别stateless与stateful

如果你的应用由多个组件（service）组成，那么在部署它们之前你得识别出哪些是stateless service哪些是stateful service。

针对每个service你自问以下三个问题：

1. 这个service崩溃之后，是不是只需要重启它就可以了，而不需要关心数据恢复？
1. 这个service是否可以在node之间任意迁移，且不需要分布式存储？
1. 这个service是否无需固定IP？

如果上述回答都是Yes，那么这个service就是stateless的，只要有一个是No，则这个service是stateful的。

对于stateless service，你可以：

1. 用`docker stack deploy`部署
2. 用`docker service create`部署

对于stateful service，你可以：

1. 用`docker run`部署
2. 用`docker-compose up`部署
3. 如果没有固定IP的要求，那么你也可以用`docker stack deploy`/`docker service create`部署，前提是你得保证这个service只会固定在一台机器上运行。

有时候你的应用既有stateless service又有stateful service，这时需要把他们挂载到同一个overlay网络里，这样它们之间就能够互相通信了。

### 4.2 创建应用网络

创建`app-net`（你也可以改成自己的名字）

```bash
$ docker network create -d overlay --attachable app-net
```

参考[Docker Overlay网络的MTU][docker-overlay-network-mtu]检查子网与MTU是否配置正确。

### 4.3 给Node打Label

如果你对于Service部署在哪个Node上有要求，那么你得给Node打上Label：

```bash
$ docker node update --label-add <your-label>=1 <node-id>
```

然后在`docker-compose.yaml`里添加约束条件：

```yaml
version: "3.7"
services:
  busybox:
    image: busybox
    deploy:
      placement:
        constraints:
          - node.labels.<your-label> == 1
```

### 4.4 启动service

对于stateless service，编写`docker-compose.yaml`，里面写了同时挂载`app-net`和`monitor-net`，比如：

```yaml
version: "3.7"
services:
  busybox:
    image: busybox
    networks:
      app-net:
      monitor-net:
        aliases:
          - busybox
...
networks:
  app-net:
    external: true
  monitor-net:
    external: true
```

注意上面设置了busybox service在monitor-net中的别名，这是因为如果你用`docker stack deploy`部署，那么busybox的名字默认是`<stack-name>_busybox`，这样对于prometheus而言此名字不稳定，不便于配置详见[Prometehus监控Docker Swarm Overlay网络中的容器][p8s-scrape-container-in-docker-swarm-overlay-network]。

然后用`docker stack deploy`部署：

```bash
$ docker stack deploy \
  --with-registry-auth \
  --prune \
  -c docker-compose.yaml
  <stack-name>
```

如果用`docker service create`则：

```bash
$ docker service create \
 --network app-net \
 --network monitor-net \
 --name <name> \
 ... 其他参数
 <image>
```

下面举例`docker run`启动stateful service的方法：

```bash
$ docker run -d \
  --name <name> \
  --network app-net \
  ... 其他参数 \
  <image>
  
# 然后再挂载到monitor-net上
$ docker network connect monitor-net <name>
```

[fluentd]: https://docs.fluentd.org/v1.0/articles/quickstart
[overlay-network]: https://docs.docker.com/network/overlay/
[v-p8s-mon-solution]: https://github.com/vegasbrianc/prometheus/
[aliyun-docker-ce]: https://yq.aliyun.com/articles/110806
[docker-daemon-prod]: ../docker-daemon-prod/
[collect-docker-log-by-fluentd]: ../collect-docker-log-by-fluentd/
[docker-overlay-network-mtu]: ../docker-overlay-network-mtu
[swarm-command-list]: ../swarm-command-list/
[gist-docker-stack.yml]: https://gist.github.com/chanjarster/21fb7707246a7970eb89a116ea61f205
[p8s-scrape-container-in-docker-swarm-overlay-network]: ../p8s-scrape-container-in-docker-swarm-overlay-network/