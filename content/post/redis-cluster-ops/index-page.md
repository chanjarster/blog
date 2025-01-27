---
title: "Redis 集群运维笔记"
author: "颇忒脱"
tags: ["redis"]
date: 2025-01-27T12:02:32+08:00
featured: true
---

<!--more-->

基本资料：

* [redis.conf for Redis 6.2][rc-conf]
* [Redis Cluster and Docker][rc-docker]

部署手册：

* [高可用架构规划](../ha-arch)
* [利用 bitnami/redis 部署 Redis Cluster](../bitnami-redis)
* [迁移到 Redis Cluster](../deploy-migration)

运维手册（redis-cli方式）：

* [创建新集群](../ops-cli/new-cluster)
* [集群管理](../ops-cli/existing-cluster)
* [Resharding](../ops-cli/resharding)
* 灾备 TODO

运维手册（Redis Command方式）：

* [创建新集群](../ops-cmd/new-cluster)
* [集群管理](../ops-cmd/existing-cluster)
* [Resharding](../ops-cmd/resharding)
* 灾备 TODO

[rc-docker]: https://redis.io/topics/cluster-tutorial#redis-cluster-and-docker
[rc-conf]: https://raw.githubusercontent.com/redis/redis/6.2/redis.conf
[1]: https://supwisdom.coding.net/p/redis-tools/d/multi-tenant-proxy/git

