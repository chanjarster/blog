---
title: "Redis Command 集群管理"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

这里将的是已有集群（已经有数据且在运行）的运维操作。

## 检查集群状态

进入任意节点：

```bash
redis-cli -a <paas> CLUSTER NODES
<node1-id> <node1-ip>:<node1-port>@<node1-bus-port> myself,master - 0 1646104749000 2 connected 5501-11000
<node2-id> <node2-ip>:<node2-port>@<node1-bus-port> master - 0 1646104751293 1 connected 11001-16383
<node3-id> <node3-ip>:<node3-port>@<node1-bus-port> master - 0 1646104752300 1 connected 0-5500
```

**注意：** 这里看到的是当前节点的集群视图，如果发现 A 节点和 B 节点的结果不一致，那就说明出现故障了。

参考命令：

* [CLUSTER NODES][nodes]

## 添加 Master

进入任意 master，把新 master 加进来：

```bash
redis-cli CLUSTER MEET <new-master-ip> <new-master-port>
```

成功后要 Resharding，[redis-cli方式](../../ops-cli/resharding) 或 [Redis Command方式](../resharding) ，把一些 slot 转移到新 master 上。

参考命令：

* [CLUSTER MEET][meet]

## 添加 Slave

进入新 slave，把自己加入到集群里，将其配置为某个 master 的 slave，注意符合[高可用部署架构](../../ha-arch)：

```bash
redis-cli CLUSTER MEET <any-master-ip> <any-master-port>
redis-cli CLUSTER REPLICATE <master-node-id>
```

参考命令：

* [CLUSTER REPLICATE][replicate] 

## 删除 Master

前提：master 是空的，不负责任何 slot。

方法：Resharding，[redis-cli方式](../../ops-cli/resharding) 或 [Redis Command方式](../resharding) ，把 master 上的所有 slot 转移到其他 master 上。

进入到以下节点执行命令：

* 每个 master（除了要被删掉的 master）
* 每个 slave （除了要被删掉的 master 的 slave）

```bash
redis-cli -a <pass> CLUSTER FORGET <master-id>
```

进入到被删除 master，重置：

```bash
redis-cli -a <pass> CLUSTER RESET
```

被删掉的 master 的 slave 会自动转移到其他 master 下。

**注意**：以上所有操作要在 60 秒内全部执行完，否则可能因为 gossip 协议导致被删除 master 再次加入。

参考命令：

* [CLUSTER FORGET][forget]
* [CLUSTER RESET][reset]

## 删除 Slave

进入到以下节点执行命令：

* 每个 master
* 每个 slave （除了要被删掉的的 slave）

```bash
redis-cli -a <pass> CLUSTER FORGET <slave-id>
```

进入到被删除 slave，重置：

```bash
redis-cli -a <pass> CLUSTER RESET
```

**注意**：以上所有操作要在 60 秒内全部执行完，否则可能因为 gossip 协议导致被删除 slave 再次加入。


## 手动 Failover

手动 failover 让你把一个 master 和其 slave 对调角色，常见于升级节点的时候。

进入 slave，让其升格为 master，这样它会把自己的 master 踢掉，自己做 master，而原来的 master 则会变成它的 slave：

```bash
redis-cli -a <pass> CLUSTER FAILOVER
```

参考命令：

* [CLUSTER FAILOVER][failover]

参考资料：

* [Manual Failover][manual-failover]

## K8S部署环境崩溃

如果你的 Redis 集群部署在 K8S 环境中，而恰巧，整个 K8S 环境出现过崩溃，导致你的集群处于不可用状态，那么你可以通过下面方法恢复集群（假设 Redis 都挂载了 PVC 数据没丢失）。

假设你的 Redis 实例 Pod 都已经重建了，而且是超过一半以上的 Redis Pod 发生过重建。

虽然每个实例的 node id 没有发生变化，但是他们的 IP 变了，导致每个实例根据 `nodes.conf` 中保存的 IP 信息已经无法联系到对方。

这时你需要做的是，到每个实例中执行以下命令：

```bash
$ redis-cli -a <pass> CLUSTER NODES | grep myself
<node1-id> <node1-ip>:<node1-port>@<node1-bus-port> myself,master - 0 1646104749000 2 connected 5501-11000
```

然后整理出以下表格：

| ip      | role   | node id  |
|---------|--------|----------|
| x.x.x.x | master | zzzz     |
| x.x.x.x | master | zzzz     |
| x.x.x.x | master | zzzz     |
| x.x.x.x | slave  | zzzz     |
| x.x.x.x | slave  | zzzz     |
| x.x.x.x | slave  | zzzz     |

然后，随意进入到**一个** master 实例，和其他 master 碰个面：

```bash
redis-cli -a <pass> CLUSTER MEET <other-master-ip> <other-master-port>
```

最后，进入到**所有** slave 实例，和**任意一个** master 碰个面：

```bash
redis-cli -a <pass> CLUSTER MEET <any-master-ip> <any-master-port>
```

这样 Redis 集群就恢复了。

## 升级节点

见 [高可用架构](../../ha-arch)。

[adding-new-node]: https://redis.io/topics/cluster-tutorial#adding-a-new-node
[forget]: https://redis.io/commands/cluster-forget
[failover]: https://redis.io/commands/cluster-failover
[manual-failover]: https://redis.io/topics/cluster-tutorial#manual-failover
[add-new-replica]: https://redis.io/topics/cluster-tutorial#adding-a-new-node-as-a-replica

[removing-node]: https://redis.io/topics/cluster-tutorial#removing-a-node

[meet]: https://redis.io/commands/cluster-meet
[add-slots]: https://redis.io/commands/cluster-addslots
[add-slots-range]: https://redis.io/commands/cluster-addslotsrange
[del-slots]: https://redis.io/commands/cluster-delslots
[del-slotsrange]: https://redis.io/commands/cluster-delslotsrange
[replicate]: https://redis.io/commands/cluster-replicate
[upgrading-node]: https://redis.io/topics/cluster-tutorial#upgrading-nodes-in-a-redis-cluster
[nodes]: https://redis.io/commands/cluster-nodes
[reset]: https://redis.io/commands/cluster-reset