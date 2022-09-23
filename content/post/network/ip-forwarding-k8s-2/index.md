---
title: "保护 K8S IP Forwarding 的安全"
author: "颇忒脱"
tags: ["network", "k8s"]
date: 2022-09-23T15:50:00+08:00
---

<!--more-->

> 本方法适用于 CentOS 7.9 或者 Iptables 不是以 nftable 作为后端的情况。
> 
> 如果操作系统使用 nftable 管理流量，请期待下一篇文章。

在[上文](../ip-forwarding-k8s)中提到了，在不做任何保护的情况下，K8S 节点同子网的服务器只需将路由配置为任一 K8S 节点，就可以访问到 Pod。

本文讲解如何使用 iptables 来保护 K8S 节点，只允许转发来自同集群的其他节点的 IP 包，来保护 Pod 不被同子网的其他服务器攻击。需要一些 [iptables 的基础知识](../iptables-intro)。

## 步骤

假设，我们的集群有 3 个节点，IP 是 172.18.10.1~3，我们先创建一个 [ipset][ipset-man]，名字叫做 `cluster_nodes`，把这 3 个 IP 放进去：

```shell
sudo ipset create cluster_nodes iphash
sudo ipset add cluster_nodes 172.18.10.1
sudo ipset add cluster_nodes 172.18.10.2
sudo ipset add cluster_nodes 172.18.10.3
```

根据 [iptables 的定义][iptables-packet-traverse]，IP 转发流量（非 NAT 和 Masquerading）对应的 Chain 是 `FORWARD`。

因此我们要在 `filter` Table 的 `FORWARD` Chain 上添加规则，阻止来自于非 `cluster_nodes` 的 IP 转发流量，

因为我们的节点上已经安装了 K8S，所以 Calico 已经给 `FORWARD` Chain 添加了一系列规则：

```shell
> sudo iptables -t filter -L FORWARD -n --line-numbers
Chain FORWARD (policy DROP)
num  target     prot opt source               destination
1    cali-FORWARD  all  --  0.0.0.0/0            0.0.0.0/0            /* cali:wUHhoiAYhphO9Mso */
2    KUBE-FORWARD  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */
3    KUBE-SERVICES  all  --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes service portals */
4    KUBE-EXTERNAL-SERVICES  all  --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
5    DOCKER-USER  all  --  0.0.0.0/0            0.0.0.0/0
6    DOCKER-ISOLATION-STAGE-1  all  --  0.0.0.0/0            0.0.0.0/0
7    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
8    DOCKER     all  --  0.0.0.0/0            0.0.0.0/0
9    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
10   ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
11   ACCEPT     all  --  10.42.0.0/16         0.0.0.0/0
12   ACCEPT     all  --  0.0.0.0/0            10.42.0.0/16
13   ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            /* cali:S93hcgKJrXEqnTfs */ /* Policy explicitly accepted packet. */ mark match 0x10000/0x10000
```

要记住 iptables 规则是按顺序执行的，因此新规则添加在哪里非常重要。

同时注意到 FORWARD Chain 的默认策略是 DROP，而最后一条规则又等于全部允许。

因此决定插入在 `11` 之后 `12` 这个之前是一个比较好的选择：

```shell
sudo iptables -t filter -I FORWARD 12 -i ens18 -m set ! --match-set cluster_nodes src -j REJECT
```

这条命令的意思是，把一条规则插入在 `12` 之前，而这个规则的意思是：凡是来自于网卡 `ens18` 的 IP 转发包，如果其来源 IP 不在 ipset `cluster_nodes` 范围内，那么就拒绝。

> 12 这个插入点，也需要根据实际情况斟酌判断。
> 
> `ens18` 需要根据你的实际情况修改，因为你的网卡不一定是这个可以通过 `ip link` 来得到

检查一下规则是否插入成功：

```shell
> sudo iptables -t filter -L FORWARD -n --line-numbers
Chain FORWARD (policy DROP)
num  target     prot opt source               destination
1    cali-FORWARD  all  --  0.0.0.0/0            0.0.0.0/0            /* cali:wUHhoiAYhphO9Mso */
2    KUBE-FORWARD  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */
3    KUBE-SERVICES  all  --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes service portals */
4    KUBE-EXTERNAL-SERVICES  all  --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
5    DOCKER-USER  all  --  0.0.0.0/0            0.0.0.0/0
6    DOCKER-ISOLATION-STAGE-1  all  --  0.0.0.0/0            0.0.0.0/0
7    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
8    DOCKER     all  --  0.0.0.0/0            0.0.0.0/0
9    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
10   ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
11   ACCEPT     all  --  10.42.0.0/16         0.0.0.0/0
12   REJECT     all  --  0.0.0.0/0            0.0.0.0/0            ! match-set cluster_nodes src reject-with icmp-port-unreachable
13   ACCEPT     all  --  0.0.0.0/0            10.42.0.0/16
14   ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            /* cali:S93hcgKJrXEqnTfs */ /* Policy explicitly accepted packet. */ mark match 0x10000/0x10000
```

以上操作在所有节点上都执行一遍。

然后观察你的集群是否正常工作。

## 观察效果

你可以按照[上文](../ip-forwarding-k8s)提到的方式，看看还能不能 ping 通 POD，并且可以通过以下命令看到规则拦截的包的数量：

```shell
> sudo iptables -t filter -L FORWARD -nv --line-numbers
Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination
...
12       1    60 REJECT     all  --  ens18  *       0.0.0.0/0            0.0.0.0/0            ! match-set cluster_nodes src reject-with icmp-port-unreachable
...
```

你可以我们的规则拦截了 1 个包，60 个字节。

## 节点增加/删除

给 ipset `cluster_nodes` 增加 IP：

```shell
sudo ipset add cluster_nodes <ip>
```

删除 IP：

```shell
sudo ipset del cluster_nodes <ip>
```

查看 IP：

```shell
sudo ipset list cluster_nodes
```

## 删除规则

如果集群工作异常，那么用下面命令删除这条规则：

```shell
sudo iptables -t filter -D FORWARD -i ens18 -m set ! --match-set cluster_nodes src -j REJECT
```

注意：删除的规则时，规则定义必须和你增加规则时的定义完全一样，否则会出现下面这种结果：

```shell
iptables: No chain/target/match by that name.
```

## 参考资料

* [How Packets Traverse The Filters][iptables-packet-traverse]
* [ipset man][ipset-man]
* [iptables man][iptables-man]

[iptables-man]: https://linux.die.net/man/8/iptables
[ipset-man]: https://linux.die.net/man/8/ipset
[iptables-packet-traverse]: https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO-6.html