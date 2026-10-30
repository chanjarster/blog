---
title: "查找K8S中高磁盘占用Pod"
author: "颇忒脱"
tags: ["k8s", "troubleshooting"]
date: 2019-11-11T09:32:21+08:00
---

<!--more-->

这是一次排障过程，发现Worker节点磁盘占用高，K8S报告`kublet has disk pressure`。

K8S是Rancher管理的，开启了监控（Grafana+Prometheus），在Grafana监控大盘观察，的确发现节点的磁盘可用空间在10%左右，节点磁盘大小为1T，如此占用不正常。

尝试在Grafana查找哪个Pod占用的磁盘，但是并未提供这样的视图。

在节点上执行：

```bash
sudo du -h --max-depth 1 /var/lib/docker/
```

得到的确是Docker占用的磁盘。

在节点上执行：

```bash
docker system df
```

得到Container占用磁盘特别高

在节点上执行：

```bash
docker ps -a --format "table {{.Size}}\t{{.Names}}"
```

得到容器的磁盘占用，发现`kubelet`占用磁盘特别高，且符合`docker system df`的结果。

进入`kubelet`查看占用情况：

```bash
docker exec -it kubelet /bin/bash
du -h --max-depth 1
```

发现在`/v8`磁盘占用了大部分空间，进入后查看发现大量应用日志。

找到相关应用开发人员，原来是他们使用了hostPath来挂载卷，把日志都写到了节点上，且没有开启日志滚动和压缩，导致占用大量节点磁盘。

后经研究发现，hostPath挂载的卷在Deployment/StatefulSets删除后也依然存在，手动删除后问题解决，并让开发人员不要使用hostPath后解决。