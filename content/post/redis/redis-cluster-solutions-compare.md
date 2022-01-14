---
title: "Redis集群方案对比"
author: "颇忒脱"
tags: ["redis", "分布式算法"]
date: 2022-01-13T10:03:00+08:00
draft: false
---

本文专注于从程序角度看如何使用Redis集群，以及相关的方案。

<!--more-->

## 概要

为何要做集群？主要原因就是为了做Sharding/Partitioning，所以Redis集群方案等价为Redis Sharding/Partitioning方案。

[Partitioning: how to split data among multiple Redis instances][1] 对Redis做集群的利弊和考量做了详细说明。因此，在确定方案之前，要先确定你的Redis是用来做什么的？做Cache还是数据持久化，不同方案对此的支持程度是不同的。不言自明的是，如果Redis用途是Cache，整个集群方案会更简单。

需要注意的是，无论采取何种方案，因为Sharding的存在，天然会导致有些命令在集群环境下是无法（正常）工作的，因此对于程序的改造是不可避免的。

Redis集群的方案基本上由以下组件构成：

* Client
* Proxy
* Redis实例

集群管理组件和Redis Sentinel不在本文的探讨范围之内。

而这些组件又可以做出以下细分：

| 组件       | 类型            | 说明      |
|:---------:|:---------------:|:---------|
| Redis     | simple          | 最简单的standalone Redis实例 |
|           | cluster         | [Redis Cluster][3] |
| Proxy     | sharding        | 连接多个Redis Simple实例，内置Sharding逻辑 |
|           | cluster         | 支持[Redis Cluster][3] |
| Client    | simple          | 傻瓜式客户端，只能连接单个Redis Simple实例 |
|           | sharding        | 连接多个Redis Simple实例，内置Sharding逻辑 |
|           | cluster         | 支持[Redis Cluster][3] |


## 组件

具体讲讲集群的各个组件，以及可用的开源项目。

### Proxy

不管何种Proxy，其目的都是伪装成一个Simple Redis实例，使得程序无需改造就能够利用Redis集群。

#### sharding类型

这种类型的Proxy连接多个simple redis实例，根据自己的Sharding/LB算法，把请求分配到各个redis实例上。

这类Proxy 需要配合 Dashboard（管理组件）才能够更新节点列表。更复杂的运维任务也需要Dashboard配合。

#### cluster类型

这种类型的Proxy直接连接在[Redis Cluster][3]上，集群的管理工作全部交给[Redis Cluster][3]，Proxy能够感知到集群节点变化，并且路由命令到正确的Slot上，避免MOVED/ASK重定向，提升执行效率。

#### 开源项目

| 项目        | sharding | cluster | 维护       | 说明                     |
|:----------:|:---------:|:--------:|:-----:|:-------------------------|
| [twemproxy][4]  | Y | | 不活跃 | |
| [corvus][6]     | Y | | 停止 | 改进[twemproxy][4]，饿了么  |
| [Codis][12] | Y | | 停止 | 改进[twemproxy][4]，自带Dashboard，豌豆荚 |
| [samaritan][8]  | ? | Y | 停止 | [corvus][6]的继任项目，sidecar形式的proxy，只支持Redis <= 5.0，配套Dashboard [sash][9] |
| [Redis Cluster Proxy][5] | | Y | 停止 | 官方搞的，处于alpha状态，不推荐生产使用 |
| [envoy][10]     | ? | Y | 活跃 | sidecar形式的proxy, redis只是其中一项功能 |
| [camellia-redis-proxy][11] | Y | Y | 活跃 | 网易 |


### Client

Client方案和Proxy方案类似，可以类比为把Proxy的基本功能以类库的形式集成到Client里。

simple （傻瓜式）client没什么好谈的，就是最简单的客户端，只能连接一个Redis实例。

随着技术的发展，有些simple client也渐渐支持sharding和cluster特性。

不过需要注意的是，某些Client的实现不是太好，不同模式的API形式不一致，这意味着一定的改造成本。

#### sharding类型

这种类型的Client连接多个simple redis实例，根据自己的Sharding/LB算法，把请求分配到各个redis实例上。

这类Client 需要配合 Dashboard（管理组件）才能够更新节点列表。更复杂的运维任务也需要Dashboard配合。

#### cluster类型

这种类型的 Client 直接支持 [Redis Cluster][3] 协议，能够感知到集群中节点的变化。

#### 开源项目

| 项目        | sharding | cluster | API一致 | 维护   | 说明                     |
|:----------:|:---------:|:--------:|:-----:|:-----:|:-------|
| [jedis][13]          | [ShardedJedis][2]  |  | N |    |    |
| [lettuce][14]        |   | Y | Y | 活跃 |      |
| [camellia-redis][11] | Y | Y | Y | 活跃 | 网易 |

## 结论

根据上面的信息，可以组合出以下几种方案（方案顺序最便利->最麻烦）：

|   Client     |   Proxy     |   Redis     | 便利性 |
|:------------:|:-----------:|:-----------:|:------|
| simple       | cluster     | cluster     | 无改动 |
| simple       | sharding    | simple      | 无改动，另外需要Dashboard来管理集群  |
| cluster      | --          | cluster     | 可能有改动|
| sharding     | --          | simple      | 可能有改动，无改动，另外需要Dashboard来管理集群 |

注意：这里的程序改动指的是建立连接或者API的改动，不包括Redis命令的改动，这部分改动是不可避免的。

[1]: https://redis.io/topics/partitioning
[2]: https://github.com/redis/jedis/wiki/AdvancedUsage#shardedjedis
[3]: https://redis.io/topics/cluster-tutorial
[4]: https://github.com/twitter/twemproxy
[5]: https://github.com/RedisLabs/redis-cluster-proxy
[6]: https://github.com/eleme/corvus
[7]: https://github.com/samaritan-proxy/samaritan
[8]: https://samaritan-proxy.github.io/docs/arch/protocol/redis/redis/
[9]: https://github.com/samaritan-proxy/sash
[10]: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_protocols/redis
[11]: https://github.com/netease-im/camellia
[12]: https://github.com/CodisLabs/codis
[13]: https://github.com/redis/jedis
[14]: https://lettuce.io/docs/