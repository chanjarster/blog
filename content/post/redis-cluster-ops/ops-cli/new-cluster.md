---
title: "redis-cli 创建新集群"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

前提：

1. 根据[高可用部署](../../ha-arch) 规划 master 和 slave 的部署。
2. 使用 [bitnami-redis](../../bitnami-redis) 部署 master 和 slave StatefulSets。

## 组 Master 成为集群

进入任意 master：

```bash
redis-cli -a <pass> --cluster create \
  <master1-ip>:<master1-port> \
  <master2-ip>:<master2-port> \
  <master3-ip>:<master3-port>
```

## 检查集群状态

进入任意 master：

```bash
redis-cli -a <pass> --cluster check <any-master-ip>:<any-master-port>

[OK] 0 keys in 3 masters.
0.00 keys per slot on average.
>>> Performing Cluster Check (using node <any-master-ip>:<any-master-port>)
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

## 添加 Slave

进入任意 master，一个个把 slave 加上，注意根据 slave 运行位置安排对应关系，保持高可用架构：

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

先做 Resharding，[redis-cli方式](../resharding) 或 [Redis Command方式](../../ops-cmd/resharding)，把要删除的 master 上所有 slot 转移到其他 master 上：

```bash
redis-cli --user <user> --pass <pass> \
  --cluster reshard <other-master-ip>:<other-master-port> \
  --cluster-from <del-master-id> \
  --cluster-to <other-master-id> \
  --cluster-slots <number of slots on del master> \
  --cluster-yes
```

进入任意 master：

```bash
redis-cli -a <pass> --cluster del-node \
  <other-master-ip>:<other-master-port> <del-master-id>
```

被删掉的 master 的 slave 会自动转移到其他 master 下。

参考资料：

* [Removing a node][removing-node]

## 删除 slave

进入任意 master 节点：

```bash
redis-cli -a <pass> --cluster del-node \
  <any-master-ip>:<any-master-port> <del-slave-id>
```

[forget]: https://redis.io/commands/cluster-forget
[meet]: https://redis.io/commands/cluster-meet
[add-slots]: https://redis.io/commands/cluster-addslots
[add-slots-range]: https://redis.io/commands/cluster-addslotsrange
[del-slots]: https://redis.io/commands/cluster-delslots
[del-slotsrange]: https://redis.io/commands/cluster-delslotsrange
[replicate]: https://redis.io/commands/cluster-replicate
[reset]: https://redis.io/commands/cluster-reset
[removing-node]: https://redis.io/topics/cluster-tutorial#removing-a-node
[add-new-replica]: https://redis.io/topics/cluster-tutorial#adding-a-new-node-as-a-replica
