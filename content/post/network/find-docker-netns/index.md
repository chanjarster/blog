---
title: "找到 Docker 的 netns"
author: "颇忒脱"
tags: ["network", "docker"]
date: 2022-09-27T15:50:05+08:00
---

<!--more-->

在前一篇[文章](../container-networking)提到容器的网络是通过 network namespace 隔离的，但是你却找不到 Docker 创建的 netns（K8S 同理）：

```shell
$ ip netns
# 什么都没有
```

这是因为 Docker 并不会在 `/var/run/netns/...` 下创建文件。下面讲进入 Docker 容器的 netns 的方法。

## 获得容器 ID

```shell
$ docker ps
```

## 得到容器 PID

```shell
$ docker inspect --format '{{ .State.Pid }}' <CONTAINER_ID>
```

## 进入 namespace

```shell
$ nsenter -t <CONTAINER_PID> -n ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    ...
16: eth0@if17: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1376 qdisc noqueue state UP group default
    ...
```

## 找到 veth 对子

回忆一下，`veth` 一个头在容器 namespace 里，一个头在 root namespace 里，在容器 namespace 里可以看到网卡： `eth0@if17`，这个 `if17` 就是在 root namespace 的另一头。

用下面命令找到：

```shell
# ip link | grep -A1 ^17
17: vethweplb3f36a0@if16: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1376 qdisc noqueue master weave state UP mode DEFAULT group default
    link/ether 72:1c:73:d9:d9:f6 brd ff:ff:ff:ff:ff:ff link-netnsid 1
```

## 参考资料

* [How to View the Network Namespaces in Kubernetes][how-view-docker-netns]

[how-view-docker-netns]: https://www.packetcoders.io/how-to-view-the-network-namespaces-in-kubernetes/