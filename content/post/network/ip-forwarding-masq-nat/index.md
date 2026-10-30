---
title: "IP Forwarding, Masquerading 和 NAT"
author: "颇忒脱"
tags: ["network"]
date: 2022-09-20T13:50:00+08:00
---

<!--more-->

## 关系概述

在提到 NAT 的时候，不得不提到另外两个相关的概念，IP Forwarding 和 Masquerading。

IP Forwarding 在之前的[文章](../ip-forwarding)提到过，如果一个 Linux 服务器开启了 IP Forwarding，那么它就具有了 IP 包转发能力，更底层的是，服务器能够接收目标不是本机的 IP 包，而不是丢弃。IP Forwarding 是 NAT 的基础。

Masquerading （IP 伪装）是修改 IP 包的头信息使得 IP 包看上去来自于另一个 IP 的一种技术。Masquerading 是 SNAT 的一种特殊形式。

NAT（Network Address Translation），分为两种 SNAT 和 DNAT。SNAT 用于吧真实的源 IP 隐藏起来，而 DNAT 则是把真实的目标 IP 隐藏起来。

## 结合 iptables 的运用

配合 [iptables 简介](../iptables-intro) 一起阅读。

### SNAT

SNAT 发生在 iptables 的 `nat` Table 的 `POSTROUTING` Chain 上，正好在发送到网卡前的最后一步，对应的是 outbound 流量。

> 所以 `filter` 规则、路由规则会看到没有被修改的包。

```shell
# Change source addresses to 1.2.3.4.
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to 1.2.3.4

# Change source addresses to 1.2.3.4, 1.2.3.5 or 1.2.3.6
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to 1.2.3.4-1.2.3.6

# Change source addresses to 1.2.3.4, ports 1-1023
iptables -t nat -A POSTROUTING -p tcp -o eth0 -j SNAT --to 1.2.3.4:1-1023
```

### Masquerading

Masquerading 是 SNAT 的特殊形式，在 iptables 中，只允许被用在动态分配 IP 地址的情况下，比如拨号上网：

```shell
# In the NAT table (-t nat), Append a rule (-A) after routing
# (POSTROUTING) for all packets going out ppp0 (-o ppp0) which says to
# MASQUERADE the connection (-j MASQUERADE).
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
```

早期没有路由器直接电脑拨号上网的场景中，如果你想宿舍里的另一台电脑也能上网，你就需要在拨号机上开启 Masquerading，在另一台电脑上把路由规则改成拨号机。

## DNAT

DNAT 发生在 iptables 的 `nat` Table 的 `PREROUTING` Chain 上，正好在刚接收到包的之后一步，对应的是 inbound 流量。

> 所以 `filter` 规则、路由规则会看到“真实”的目标 IP。

```shell
# Change destination addresses to 5.6.7.8
iptables -t nat -A PREROUTING -i eth0 -j DNAT --to 5.6.7.8

# Change destination addresses to 5.6.7.8, 5.6.7.9 or 5.6.7.10.
iptables -t nat -A PREROUTING -i eth0 -j DNAT --to 5.6.7.8-5.6.7.10

# Change destination addresses of web traffic to 5.6.7.8, port 8080.
iptables -t nat -A PREROUTING -p tcp --dport 80 -i eth0 \
        -j DNAT --to 5.6.7.8:8080
```

### Redirection

Redirection 是 DNAT 的一种特殊形式，是对 来流数据的网卡地址做 DNAT 的一种便捷方式。

```shell
# Send incoming port-80 web traffic to our squid (transparent) proxy
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 \
        -j REDIRECT --to-port 3128
```

## 参考资料

* [极客时间 - 路由][gktime]
* [Deploying IP Forwarding and Masquerading][dep-ip-for-masq]
* [Netfilter - Linux 2.4 NAT HOWTO][nf-nat-how-to]
* [Mixing NAT and Packet Filtering][nf-iptables-mix-nat]

[gktime]: https://time.geekbang.org/column/article/8590
[dep-ip-for-masq]: https://flylib.com/books/en/3.100.1.37/1/
[nf-nat-how-to]: https://www.netfilter.org/documentation/HOWTO/NAT-HOWTO.html
[nf-iptables-mix-nat]: https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO-9.html