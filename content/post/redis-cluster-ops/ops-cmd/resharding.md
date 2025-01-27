---
title: "Redis Command Resharding"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

Resharding 指的是把某个 slot 的所有权从一个 master 转移到另一个 master。

Resharding 的参与方有二：

* src master，slot 的迁出方
* dst master，slot 的迁入方

和 [redis-cli 方式](../../ops-cli/resharding) 不同，Command 方式只能一个 slot 一个 slot 地迁。

1）进入 dst master，设置导入某个 src master 的某个 slot：

```bash
CLUSTER SETSLOT <slot> IMPORTING <src-master-node-id>
```

2）进入 src master，设置某个 slot 处于迁移状态：

```bash
CLUSTER SETSLOT <slot> MIGRATING <dst-master-node-id>
```

1) 进入 src master，得到 slot 中所有的 key：

```bash
CLUSTER GETKEYSINSLOT <slot> <count>
```

4) 进入 src master，把 key 转移到 dst master：

```bash
MIGRATE <dst-master-ip> <dst-master-port> "" 0 5000 AUTH2 <user> <pass> KEYS <key1> <key2> ...
```

5) 进入 src master，更新 slot 归属：

```bash
CLUSTER SETSLOT <slot> NODE <dst-master-node-id>
```

6) 进入 dst master，更新 slot 归属：

```bash
CLUSTER SETSLOT <slot> NODE <dst-master-node-id>
```

参考命令：

* [CLUSTER SETSLOT][setslot] 
* [CLUSTER GETKEYSINSLOT][getkeysinslot]
* [MIGRATE][migrate]


参考资料：

* [Redis Cluster live resharding explained][resharding-explained]

[setslot]: https://redis.io/commands/cluster-setslot
[resharding-explained]: https://redis.io/commands/cluster-setslot#redis-cluster-live-resharding-explained
[migrate]: https://redis.io/commands/migrate
[getkeysinslot]: https://redis.io/commands/cluster-getkeysinslot
