---
title: "redis-cli Resharding"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

Resharding 指的是把某个 slot 的所有权从一个 master 转移到另一个 master。

## 交互方式

进入任何一个 master：

```bash
redis-cli --user <user> --pass <pass> \
  --cluster reshard <any-master-ip>:<any-master-port>
How many slots do you want to move (from 1 to 16384)? 
What is the receiving node ID?
Please enter all the source node IDs.
  Type 'all' to use all the nodes as source nodes for the hash slots.
  Type 'done' once you entered all the source nodes IDs.
Source node #1: 
Ready to move <number of slots> slots.
  Source nodes:
    M: <node-id> <host:ip>
       slots: <slots> (<number of slots> slots) master
  Destination node:
    M: node-id host:ip
       slots: <slots> (<number of slots> slots) master
Resharding plan:
  Moving slot <slot> from <node-id>
  Moving slot <slot> from <node-id>
Do you want to proceed with the proposed reshard plan (yes/no)? yes
Moving slot <slot> from <host>:<ip> to <host>:<ip>: .
Moving slot <slot> from <host>:<ip> to <host>:<ip>: ...
Moving slot <slot> from <host>:<ip> to <host>:<ip>: 
Moving slot <slot> from <host>:<ip> to <host>:<ip>: ..
```

参考文档：

* [Resharding the cluster][resharding]

## 脚本方式

进入任何一个 master：

```bash
redis-cli --user <user> --pass <pass> \
  --cluster reshard <any-master-ip>:<any-master-port> \
  --cluster-from <src-master-id>/all \
  --cluster-to <dst-master-id> \
  --cluster-slots <number of slots> \
  --cluster-yes

Moving slot <slot> from <host>:<ip> to <host>:<ip>: .
Moving slot <slot> from <host>:<ip> to <host>:<ip>: ...
Moving slot <slot> from <host>:<ip> to <host>:<ip>: 
Moving slot <slot> from <host>:<ip> to <host>:<ip>: ..
```

参考文档：

* [Scripting a resharding operation][script-resharding]

[resharding]: https://redis.io/topics/cluster-tutorial#resharding-the-cluster
[script-resharding]: https://redis.io/topics/cluster-tutorial#scripting-a-resharding-operation
