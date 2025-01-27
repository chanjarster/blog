---
title: "Redis 集群运维笔记 - 高可用架构规划"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T10:02:32+08:00
---

<!--more-->

Redis Cluster 中有两个角色，master 和 slave，本文探讨如何规划高可用架构。

## master 和 slave 共享服务器

原则：

* 同一组 master 和 slave 不能部署在同一个服务器上
* 同一组 slave 不能部署在同一个服务器上

1）1:1 部署 master slave

方案：master 和 slave 错开

```
|- Node1 -| |- Node2 -| |- Node3 -| 
|   M1    | |   M2    | |   M3    |
|   S2    | |   S3    | |   S1    |
|---------| |---------| |---------|
```

效果：

* 挂掉 1 个服务器，master 完整，slave 不完整
* 挂掉 2-3 个服务器，master 不完整，slave 不完整

2）1:2 部署 master slave

方案：master 和 slave 要错开，slave 也错开

```
|- Node1 -| |- Node2 -| |- Node3 -| 
|   M1    | |   M2    | |   M3    |
|   S2    | |   S3    | |   S1    |
|   S3    | |   S1    | |   S2    |
|---------| |---------| |---------|
```

效果：

* 挂掉 1 个服务器，master 完整，slave 完整
* 挂掉 2 个服务器，master 完整，slave 不完整
* 挂掉 3 个服务器，master 不完整，slave 不完整

## master 和 slave 服务器分离

原则：

* 同一组 master 和 slave 资源完全分开
* 同一组 slave 不能部署在同一个服务器上

1）1:1 部署 master slave

```
|- Node1 -| |- Node2 -| |- Node3 -|
|   M1    | |   M2    | |   M3    |
|---------| |---------| |---------|

|- Node4 -| |- Node5 -| |- Node6 -| 
|   S1    | |   S2    | |   S3    |
|---------| |---------| |---------|
```

效果：

* 挂掉 1-3 个 master 服务器，master 完整，slave 不完整
* 挂掉 1-3 个 slave 服务器，master 完整，slave 不完整

2）1:2 部署 master slave

方案：slave 错开

```
|- Node1 -| |- Node2 -| |- Node3 -|
|   M1    | |   M2    | |   M3    |
|---------| |---------| |---------|

|- Node4 -| |- Node5 -| |- Node6 -| 
|   S1    | |   S2    | |   S3    |
|   S2    | |   S3    | |   S1    |
|---------| |---------| |---------|
```

效果：

* 挂掉 1-3 个 master 服务器，master 完整，slave 完整
* 挂掉 1 个 slave 服务器，master 完整，slave 完整
* 挂掉 2-3 个 slave 服务器，master 完整，slave 不完整

## Failover 之后

Redis Cluster 在做过一次 Failover 之后可能会破坏原来的高可用架构，因此需要人工运维恢复架构的高可用。

最稳妥的办法就是，挂掉的 Redis 实例还是恢复在原地，然后通过手工 failover 的方式，把架构重新变得高可用。

## Slave 自动迁移

如果某个 master 有多余的 slave，而又有 master 缺少 slave，则会自动匀一个给它。

参考资料：

* [Replicas migration][replica-migration]
* 配置参数 `cluster-migration-barrier` ，默认 1

## 升级节点

步骤：

* 先把手动 failover，把一个 master 变成 slave
* 等待 master 变成 slave
* 升级这个 master
* 如果有需要，再次手动 failover，把 master 变回来

参考资料：

* [Upgrading nodes in a Redis Cluster][upgrading-node]


[replica-migration]: https://redis.io/topics/cluster-tutorial#replicas-migration
[upgrading-node]: https://redis.io/topics/cluster-tutorial#upgrading-nodes-in-a-redis-cluster
