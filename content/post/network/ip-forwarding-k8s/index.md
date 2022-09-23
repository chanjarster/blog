---
title: "IP Forwarding 在K8S中的安全问题"
author: "颇忒脱"
tags: ["network", "k8s"]
date: 2022-09-19T14:50:00+08:00
---

<!--more-->

在任意一台 K8S 节点上，你可以看到类似下面的路由表：

```shell
> ip route show
default via 192.168.0.1 dev ens18 proto static
...
10.42.1.0/24 via 10.42.1.0 dev flannel.1 onlink
10.42.2.0/24 via 10.42.2.0 dev flannel.1 onlink
...
```

这个表里的 10.42.1.0/24 和 10.42.2.0/24 子网正好是 K8S Overlay 网络的一部分。而这个路由表给了你一个线索，就是你可以从**任意节点**通过 Cluster IP 访问到 Pod：

```shell
> ping 10.42.2.56
PING 10.42.2.56 (10.42.2.56) 56(84) bytes of data.
64 bytes from 10.42.2.56: icmp_seq=1 ttl=62 time=0.852 ms
...
```

注意，是从**任意节点**，而不是从 K8S 集群 Overlay 网络内部访问 Pod。

那现在我们总结一下目前的情况：

1. K8S 要求安装时把 `net.ipv4.ip_forward = 1` 打开（[文档][k8s-install-net]）。
2. 可以从任意节点通过 Cluster IP 访问到集群内的 Pod，因为节点上设置了路由表。
3. 隐含情况：Pod 可以访问到节点所在的子网。

结合目前这 3 个情况，可以得出一个结论：

> 可以利用任意 K8S 节点，通过 Cluster IP 访问到 K8S 集群内的 Pod。

事实上也的确如此，找一台同子网但不是 K8S 节点的服务器，设置路由规则，你会发现可以 ping 通 Pod 的 Cluster IP：

```shell
> ip route add 10.42.0.0/16 via 192.168.10.1
> ping 10.42.2.56
PING 10.42.2.56 (10.42.2.56) 56(84) bytes of data.
64 bytes from 10.42.2.56: icmp_seq=1 ttl=62 time=0.788 ms
...
```

所以结论是：

* 可以利用任意 K8S 节点，通过 Cluster IP 访问到 K8S 集群内的 Pod。
* 因此 K8S 的节点需要配置防火墙规则，见这[此文](../ip-forwarding-k8s)。


[k8s-install-net]: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic