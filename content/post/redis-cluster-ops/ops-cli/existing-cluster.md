---
title: "redis-cli 集群管理"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

这里讲的是已有集群（已经有数据且在运行）的运维操作。

## 检查集群状态

进入任意 master：

```bash
redis-cli -a <pass> --cluster check <node-ip>:<node-port>

<master1-ip>:<master1-port> (<master1-id>) -> 3355 keys | 5501 slots | 0 slaves.
<master2-ip>:<master2-port> (<master2-id>) -> 3287 keys | 5383 slots | 0 slaves.
<master3-ip>:<master3-port> (<master3-id>) -> 3359 keys | 5500 slots | 0 slaves.
[OK] 10001 keys in 3 masters.
0.61 keys per slot on average.
>>> Performing Cluster Check (using node 127.0.0.1:6379)
M: <master1-id> <master1-ip>:<master1-port>
   slots:[<start>-<end>] (<num> slots) master
M: <master2-id> <master2-ip>:<master2-port>
   slots:[<start>-<end>] (<num> slots) master
M: <master3-id> <master3-ip>:<master3-port>
   slots:[<start>-<end>] (<num> slots) master
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

## 添加 Master

进入任意 master，把新 master 加进来：

```bash
redis-cli -a <pass> --cluster add-node \
   <new-master-ip>:<new-master-port> \
   <any-master-ip>:<any-master-port> \
```

成功后要 Resharding，[redis-cli方式](../resharding) 或 [Redis Command方式](../../ops-cmd/resharding) ，把一些 slot 转移到新 master 上。

参考资料：

* [Adding a new node][adding-new-node]

## 添加 Slave 节点

进入任意 master，把新 slave 加进来，同时将其配置为某个 master 的 slave，注意符合[高可用部署架构](../../ha-arch)：

```bash
redis-cli -a <pass> --cluster add-node \
   <new-slave-ip>:<new-slave-port> \
   <any-master-ip>:<any-master-port> \
   --cluster-slave \
   --cluster-master-id <master-id>
```

参考资料：

* [Adding a new node as replica][add-new-replica]

## 删除 Master

前提：master 是空的，不负责任何 slot。

方法：Resharding，[redis-cli方式](../resharding) 或 [Redis Command方式](../../ops-cmd/resharding) ，把 master 上的所有 slot 转移到其他 master 上。

进入任意 master：

```bash
redis-cli -a <pass> --cluster del-node \
  <other-master-ip>:<other-master-port> <del-master-id>
```

被删掉的 master 的 slave 会自动转移到其他 master 下。

参考资料：

* [Removing a node][removing-node]

## 删除 Slave

进入任意 master 节点：

```bash
redis-cli -a <pass> --cluster del-node \
  <any-master-ip>:<any-master-port> <del-slave-id>
```

## 手动 Failover

见 [Redis Command方式](../../ops-cmd/existing-cluster/#手动-failover)

## K8S部署环境崩溃

见 [Redis Command方式](../../ops-cmd/existing-cluster/#k8s部署环境崩溃)

## 升级节点

见 [高可用架构](../../ha-arch)。


[adding-new-node]: https://redis.io/topics/cluster-tutorial#adding-a-new-node
[forget]: https://redis.io/commands/cluster-forget
[failover]: https://redis.io/commands/cluster-failover
[manual-failover]: https://redis.io/topics/cluster-tutorial#manual-failover
[add-new-replica]: https://redis.io/topics/cluster-tutorial#adding-a-new-node-as-a-replica

[removing-node]: https://redis.io/topics/cluster-tutorial#removing-a-node
[replica-migration]: https://redis.io/topics/cluster-tutorial#replicas-migration

[meet]: https://redis.io/commands/cluster-meet
[add-slots]: https://redis.io/commands/cluster-addslots
[add-slots-range]: https://redis.io/commands/cluster-addslotsrange
[del-slots]: https://redis.io/commands/cluster-delslots
[del-slotsrange]: https://redis.io/commands/cluster-delslotsrange
[replicate]: https://redis.io/commands/cluster-replicate
[nodes]: https://redis.io/commands/cluster-nodes
[creat-new-cluster]: https://redis.io/topics/cluster-tutorial#creating-and-using-a-redis-cluster