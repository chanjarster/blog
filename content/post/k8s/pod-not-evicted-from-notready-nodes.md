---
title: "Pod没有从NotReady节点迁出的排查"
date: 2021-09-07T10:22:44+08:00
tags: ["k8s", "troubleshooting"]
author: "颇忒脱"
---

<!--more-->

## 现象

某节点出现故障，在Rancher上看到的是Inactive状态。但是这个机器上的Pod一个都没有被迁移，导致业务无法运行。

分析：首先这个Node不光kubelet坏了，上面的Pod也受损了，其次K8S没有把它们迁移到健康Node上。

## 排查

查了Google后得到，如果Node变成NotReady、Unkonwn等非正常情况，但是Pod没有正确的从这些Node移除迁移到其他Node，这是一个K8S的Bug。
这个Bug在 v1.19.9及以后, v1.20.5及以后，v1.21.0 及以后才被修复。
现在的K8S版本是 v1.17.3 。

相关issue：https://github.com/kubernetes/kubernetes/issues/55713