---
title: "Redis Command 创建新集群"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

前提：

1. 根据[高可用部署](../../ha-arch) 规划 master 和 slave 的部署。
2. 使用 [bitnami-redis](../../bitnami-redis) 部署 master 和 slave StatefulSets。

## 组 Master 成为集群

进入任意 master，把另外两个加进来：

```bash
redis-cli -a <pass> CLUSTER MEET <master2-ip> <master2-port>
redis-cli -a <pass> CLUSTER MEET <master3-ip> <master3-port>
```

参考命令：

* [CLUSTER MEET][meet] 

## 分配 Slot

此时所有 master 都没有负责任何 slot，要为 3 个 master 分配 slot：

```bash
# 进入 master-1
redis-cli -a <pass> CLUSTER ADDSLOTS $(seq -s ' ' 0 5500)
# 进入 master-2
redis-cli -a <pass> CLUSTER ADDSLOTS $(seq -s ' ' 5501 11000)
# 进入 master-3
redis-cli -a <pass> CLUSTER ADDSLOTS $(seq -s ' ' 11001 16383)
```

如果是 Redis 7.0 则：

```bash
# 进入 master-1
redis-cli -a <pass> CLUSTER ADDSLOTSRANGE 0 5500
# 进入 master-2
redis-cli -a <pass> CLUSTER ADDSLOTS 5501 11000
# 进入 master-3
redis-cli -a <pass> CLUSTER ADDSLOTS 11001 16383
```

参考命令：

* [CLUSTER ADDSLOTS][add-slots]
* [CLUSTER ADDSLOTSRANGE][add-slots-range]

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
[OK] Not all 16384 slots covered.
```

## 添加 Slave

挨个进入 Slave 执行下列命令，把自己和集群建立联系，然后配置为某个 master 的 slave，注意根据 slave 运行位置安排对应关系，保持高可用架构：

```bash
# 把自己加入新建群中，连接集群中的任意节点
redis-cli -a <pass> CLUSTER MEET <any-master-ip> <any-master-port>
# 把自己设置为某个 Master Node 的 Slave
redis-cli -a <pass> CLUSTER REPLICATE <master-node-id>
```

参考命令：

* [CLUSTER MEET][meet] 
* [CLUSTER REPLICATE][replicate]


## 取消分配 Slot

如果想调整 slot 分布，则要先把 slot 解放出来。

使用的是 [CLUSTER DELSLOTS][del-slots]，和 [CLUSTER ADDSLOTS][add-slots] 不同，`CLUSTER DELSLOTS` 必须在**所有 master 和 slave** 上执行，这个命令的意思是，让执行此命令的节点忘记 slot 的归属（包括自己），简单来说就是，当所有人都忘记 slot 的归属时，这个 slot 就自由了：

```bash
# 进入所有 master 和 slave
redis-cli -a <pass> CLUSTER DELSLOTS $(seq -s ' ' <start> <end>)
```

如果是 Redis 7.0 则：

```bash
# 进入所有 master 和 slave
redis-cli -a <pass> CLUSTER DELSLOTSRANGE <start> <end>
```

参考命令：

* [CLUSTER DELSLOTS][del-slots]
* [CLUSTER ADDSLOTS][add-slots]
* [CLUSTER DELSLOTSRANGE][del-slotsrange]

## 删除 Master

前提：master 上没有任何 slot

方法：

* 要么通过上一小节《取消分配 Slot》把 master 清空
* 要么Resharding，[redis-cli方式](../../ops-cli/resharding) 或 [Redis Command方式](../resharding) ，把 slot 转移到其他节点上

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

**注意**：以上所有操作要在 60 秒内全部执行完，否则可能因为 gossip 协议导致被删除 master 再次加入。

参考命令：

* [CLUSTER FORGET][forget]
* [CLUSTER RESET][reset]

参考文档：

* [Removing a node][removing-node]


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


[forget]: https://redis.io/commands/cluster-forget
[meet]: https://redis.io/commands/cluster-meet
[add-slots]: https://redis.io/commands/cluster-addslots
[add-slots-range]: https://redis.io/commands/cluster-addslotsrange
[del-slots]: https://redis.io/commands/cluster-delslots
[del-slotsrange]: https://redis.io/commands/cluster-delslotsrange
[replicate]: https://redis.io/commands/cluster-replicate
[reset]: https://redis.io/commands/cluster-reset
[removing-node]: https://redis.io/topics/cluster-tutorial#removing-a-node
