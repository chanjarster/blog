---
title: "Prometheus 集群架构方案对比分析"
author: "颇忒脱"
tags: ["prometheus"]
date: 2023-01-06T09:42:05+08:00
---

<!--more-->

对比 [Thanos][1] Sidecar 和 Receive 模式、[Grafana Mimir][2] 三种 Prometheus 集群架构的优劣，[Cortex][3] 是 Grafana Mimir 的前任项目，因此这里不做对比。

|                  |  Thanos Sidecar               |   Thanos Receive              |   Grafana Mimir |
|:----------------:|:-----------------------------:|:-----------------------------:|:---------------:|
| 查询性能          | O(N) 复杂度，需遍历每个 Sidecar  | O(N) 复杂度，需遍历每个 Receive   |  O(1) 复杂度，使用了一致性 Hash 算法       |
| 采集性能          | 高                   | 高                  | 高                   |
| 近期数据隔离       | Y                   | Y                   | Y                   |
| 近期数据 Sharding | N                   | N                   | Y                   |
| 近期数据副本       | Y（依赖 Prom HA部署） | Y（依赖 Prom HA部署） | Y                   |
| 长期数据存储       | Y                   | Y                   | Y                   |
| 规则执行          | 官方提示风险          | 官方提示风险         | ？？                |
| HA 部署           | 不是所有组件都支持     | 不是所有组件都支持     | 支持                |
| 水平扩展          | N                    | N                   | Y                  |
| HTTP API         | N                    | N                   | Y            |

## 查询性能

根据 Thanos 的架构，其查询度是 O(N)，即 Query 组件挨个轮询下挂的 [Sidecar][t-sidecar] 或者 [Receive][t-receive]，然后把结果汇总起来。

> 对，你没看错，Thanos Query 可以连接任意多个实现了 [Store API][t-store-api] 的组件，这些组件包括 [Query][t-query]自己、[Store Gateway][t-store-gateway]、[Ruler][t-ruler]、[Sidecar][t-sidecar]、[Receive][t-receive]。

而 Grafana Mimir 得益于其一致性 Hash 的数据 Sharding 策略，能够在 O(1) 时间内找到数据所在的 Ingestor 位置，效率高了不少。

当然对于长期数据的查询 Thanos 和 Grafana Mimir 都得仰仗 Object Storage 本身的性能。

## 采集性能

Thanos Sidecar 是直接把本地 Prom 的 tsdb 推送到 Object Storage 里。

Thanos Receive 和 Grafana Mimir 则是要 Prom 通过 Remote Write 把数据写给它们。

具体性能没有测试过，应该吞吐量都挺高的。

## 近期数据隔离

近期数据隔离的意思是，把近期数据 和 长期数据分离开来，这样近期数据查询可以快一点。

根据官方文档：

* [Thanos Sidecar][t-sidecar] 模式下，近期数据是存在 Prom 本地的。
* [Thanos Receive][t-receive] 会在己侧保留近 2 小时的数据。
* Grafana Mimir 的 [Ingestor][g-ingestor] 组件己侧保留近 2 小时的数据。

## 近期数据 Sharding

Thanos 的架构不论近期数据还是长期数据，都不支持 Sharding。

Grafana Mimir 的 Distributor 组件则负责[将数据分片][g-distributor-shard]然后分发给 Ingestor。

## 近期数据副本

Thanos 架构下依赖于 Prom 本身的 HA 部署（[文档][t-prom-ha]）。

Grafana Mimir 的 Distributor 组件也负责分发给 Ingestor 的时候制造[数据副本][g-distributor-shard] 。

## 长期数据存储

都支持长期数据存储。

## 规则执行

[Thanos Rule][t-r] 组件官方文档提示了规则查询超时和失败等风险。

而 [Grafana Mimir Ruler][g-r] 组件官方则没有提示风险。

## HA 部署

Thanos 几乎所有组件都是无状态的，所以理论上可以部署 HA 架构。
但是怎么让一个组件的2个副本配合工作，一个不行了另一个顶上，两个副本不产生重复数据，或者对重复数据去重，则需要你自己来做。

而 Grafana Mimir 天生把水平扩展设计在架构内，所以组件都支持 HA 架构。

## 水平扩展

Thanos 的水平扩展依赖于你的部署水平，有些组件压根就不支持，需要你自己做一些工作。

Grafana Mimir 支持。

## HTTP API

Thanos Sidecar 可以感知 Prom 配置文件的变化，然后自动告知 Prom reload 配置文件。

Thanos 组件的配置基本都是命令行参数，也有一部分配置文件，本身几乎没有任何 HTTP API 供开发者调用。

Grafana Mimir 则提供了 [HTTP API][g-http-api]。

## 总结

Thanos 的架构很简洁，你可以像搭积木一样组合出你想要的架构，但是对于生产环境中关心的 HA 部署、水平扩展、数据 Sharding、HTTP API 等还比较欠缺。

而 Grafana Mimir 则对上述需求提供了支持，显得更为成熟。

[1]: https://thanos.io/tip/thanos/quick-tutorial.md/#components
[2]: https://grafana.com/docs/mimir/latest/operators-guide/architecture/about-grafana-mimir-architecture/
[3]: https://cortexmetrics.io/docs/architecture/
[t-r]: https://thanos.io/tip/components/rule.md/#risk
[g-r]: https://grafana.com/docs/mimir/latest/operators-guide/architecture/components/ruler/
[t-store-api]: https://thanos.io/tip/thanos/quick-tutorial.md/#store-api
[t-sidecar]: https://thanos.io/tip/thanos/quick-tutorial.md/#sidecar
[t-receive]: https://thanos.io/tip/components/receive.md/
[t-query]: https://thanos.io/tip/thanos/quick-tutorial.md/#querierquery
[t-ruler]: https://thanos.io/tip/thanos/quick-tutorial.md/#querierquery
[t-store-gateway]: https://thanos.io/tip/thanos/quick-tutorial.md/#store-gateway
[g-ingestor]: https://grafana.com/docs/mimir/latest/operators-guide/architecture/components/ingester/
[g-distributor-shard]: https://grafana.com/docs/mimir/latest/operators-guide/architecture/components/distributor/#sharding-and-replication
[t-prom-ha]: https://thanos.io/tip/thanos/quick-tutorial.md/#deduplicating-data-from-prometheus-ha-pairs
[g-http-api]: https://grafana.com/docs/mimir/latest/operators-guide/reference-http-api/