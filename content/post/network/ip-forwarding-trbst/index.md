---
title: "排查 IP Forwarding 故障"
author: "颇忒脱"
tags: ["network"]
date: 2022-09-20T15:50:00+08:00
---

<!--more-->

## 检查内核参数

```shell
sysctl -q net.ipv4.ip_forward
```

## 检查通性

用 ping 来检查软路由到相关服务器之间是否通。

## 检查网络包流程

在软路由上用 tcpdump 排查以下几个问题：

1. Does the outbound connection request reach the router?
2. Does the router forward the request onto the other network?
3. Does the reply reach the router?
4. Does the router forward the reply back onto the original network?

如果 1 和 3 有问题，则说明问题和 IP Forwarding 无关。

如果 2 和 4 有问题，则有以下几个可能：

1. forwarding has not been switched on;
2. the output interface has not been correctly configured;
3. there is an error in the routing table; or
4. the traffic is being dropped by a firewall, iptables.

前两种可能应该在之前的步骤排除掉了，

## 检查路由规则

利用 ip 工具在软路由上测试路由规则：

```shell
ip route get to 198.51.100.1 from 192.168.0.2 iif eth0
```

上面的命令用来测试一个从 eth0 网卡进来的，来自 192.168.0.2 的包，要去 198.51.100.1 会走哪个网卡出去，转发给哪个网关。

比如结果：

```shell
198.51.100.1 from 192.168.0.2 via 203.0.113.2 dev eth1  src 192.168.0.1
    cache <src-direct>  mtu 1500 advmss 1460 hoplimit 64 iif eth0
```

## 检查防火墙

需要结合 [iptables](../iptables-intro) 的知识一起看。

检查 `filter` table 的规则：

```shell
iptables -t filter -L FORWARD -n
```

`nat` 和 `mangle` 表也有可能把包丢弃，所以也检查一下：

```shell
iptables -t nat -L -n
iptables -t mangle -L -n
```

也可以通过观察 Rule 的网络包计数来观察哪个规则丢器了包：

先将网络包计数清零：

```shell
iptables -t filter -Z FORWARD
```

然后 `ping` 测试，同时观察网络包计数器：

```shell
iptables -t filter -L FORWARD -nv
```

如果某个规则丢弃的Forward网络包，你可能会看到类似这样的结果：

```shell
Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    6   504 DROP       all  --  any    any     198.51.100.1         anywhere
```

说明有 6 个包被这条规则给丢弃了。

## 参考资料

* [Troubleshooting IP Forwarding][ts]

[ts]: http://www.microhowto.info/howto/enable_forwarding_of_ipv4_packets.html#idp17360