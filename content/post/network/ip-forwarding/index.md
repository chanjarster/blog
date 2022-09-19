---
title: "IP Forwarding 的安全问题"
author: "颇忒脱"
tags: ["network"]
date: 2022-09-16T08:50:00+08:00
---

<!--more-->

在[网络模型和网络设备](../network-model-and-devices/)提到了路由器。我们可以把任何一台 Linux 服务器都变成一个路由器，只需要设置内核参数 `net.ipv4.ip_forward = 1` 即可，这意味着服务器打开了 IP 包转发的能力，而转发规则是根据本地路由表。

有些同学可能会担心，把此开关打开会造成安全问题，我们具体分析。

为了下文的说明简便，讲路由分为两种：

* 软路由：开启了 IP Forwarding 的 Linux 服务器。
* 硬路由：真正的路由器

## 软路由只有一张网卡时

子网 192.168.0.0/24 中有 3 个设备：192.168.0.1 硬路由、192.168.0.2 软路由、192.168.0.3 服务器。拓扑如下：

```
┌---- srv ----┐     ┌--- router --┐     ┌--s/router --┐
| 192.168.0.3 |---->| 192.168.0.1 |<----| 192.168.0.2 |
└-------------┘     └-------------┘     └-------------┘
```

软路由 192.168.0.2 的路由规则是这样的：

```shell
> ip route show
default via 192.168.0.1 dev ens18 metric 103
192.168.0.0/24 dev ens18 proto kernel scope link src 192.168.0.2
```

意思是：

* 凡是要去 192.168.0.0/24 子网的，都直接走网卡 ens18。
* 去其他子网的默认都发给硬路由 192.168.0.1。

服务器 192.168.0.3 的路由规则是这样的（意思和软路由差不多）：

```shell
> ip route show
default via 192.168.0.1 dev ens18 metric 103
192.168.0.0/24 dev ens18 proto kernel scope link src 192.168.0.3
```

### 跨子网添加软路由

现在假设我是黑客，控制了一台 172.18.0.2 的服务器，我想通过软路由 192.168.0.2 访问子网 192.168.0.0/24 下的其他服务器可行吗？

这是不可行的，你打下面的命令会出现这种结果：

```shell
> ip route add 192.168.0.0/24 via 192.168.0.2
Error: Nexthop has invalid gateway.
```

上面的命令的意思是如果我要去 192.168.0.0/24 子网，则转发给 192.168.0.2 软路由。而因为网段不同，这个操作是不可能成功的。

同理，我直接使用硬路由也不可行。

### 同子网添加软路由

前面讲了，必须是同子网的才能添加软路由或硬路由。

那么既然我——黑客——已经控制了一台 192.168.0.0/24 子网的服务器，那我废那劲添加软路由干嘛呢？同子网的通信压根就不走路由，在交换机层面就解决了。

只有当跨子网访问时才会用到路由，假设给一台服务器设置软路由：

```shell
> ip route add 192.168.0.0/24 via 192.168.0.2
```

当跨子网访问时，你会看见软路由（192.168.0.2）会重定向到硬路由（192.168.0.1）：

```shell
>  ping 172.18.1.1
PING 172.18.1.1 (172.18.1.1) 56(84) bytes of data.
From 192.168.0.2 icmp_seq=1 Redirect Host(New nexthop: 192.168.0.1)
64 bytes from 172.18.1.1: icmp_seq=1 ttl=63 time=2.10 ms
From 192.168.0.2 icmp_seq=2 Redirect Host(New nexthop: 192.168.0.1)
64 bytes from 172.18.1.1: icmp_seq=2 ttl=63 time=2.11 ms
````

## 软路由有两张网卡时

假设有子网一：

* CIDR: 192.168.0.0/24
* 硬路由: 192.168.0.1
* 服务器: 192.168.0.2，用的硬路由。

子网二：

* CIDR: 172.18.0.0/24
* 硬路由: 172.18.0.1
* 服务器: 172.18.0.2，用的硬路由。
  
注意，两个硬路由不互通，即两个子网隔离。

还有一个软路由，上面有两张网卡：

* 网卡1: 192.168.0.3
* 网卡2: 172.18.0.3

它路由规则是这样的：

```shell
 ip route
default via 192.168.0.1 dev ens18 metric 103
192.168.0.0/24 dev ens18 proto kernel scope link src 192.168.0.2
172.18.0.0/24 dev ens19 proto kernel scope link src 172.18.0.2 metric 101
```

意思是：

* 要去 192.168.0.0/24 子网的，都直接走网卡 ens18。
* 要去 172.18.0.0/24 子网的，都直接走网卡 ens19。
* 去其他子网的默认都发给硬路由 192.168.0.1。

拓扑图如下：

```
┌---- srv ----┐     ┌--- router --┐
| 192.168.0.2 |---->| 192.168.0.1 |<-┐
└-------------┘     └-------------┘  |  ┌-- s/router -┐
                                     └--| 192.168.0.3 |
                                        |-------------|
┌---- srv ----┐     ┌--- router --┐  ┌--| 172.18.0.3  |
| 172.18.0.2  |---->| 172.18.0.1  |<-┘  └-------------┘
└-------------┘     └-------------┘
```

### 利用软路由访问另一个子网

假设我是黑客，现在控制了 192.168.0.2 ，想通过软路由访问 172.18.0.2 行不行呢？

那尝试添加路由规则：

```shell
> ip route add 172.18.0.0/24 via 192.168.0.3
> ip route show
...
172.18.0.0/16 via 192.168.0.3 dev ens18
```

意思是，要去 172.18.0.0/24 子网，走 192.168.0.3 软路由。

然后你去 ping，实际上是 ping 不通的。

因为 172.18.0.2 可以收到来自 192.168.0.2 的 ICMP echo request 包，但是当它返回 ICMP echo reply 时会交给硬路由 172.168.0.1 ，而硬路由是无法和 192.168.0.0/24 子网通信的。

> 也就是说，此时的通信是单向的，192.168.0.2 -> 172.18.0.2 是通的，但是 172.18.0.2 -> 192.168.0.2 是不通的。

上面的结论，你可以在软路由和 172.18.0.2 上 `tcpdump -nn 'host 192.168.0.2'` 抓包来验证。

除非在 172.18.0.2 添加路由规则：

```shell
> ip route add 192.168.0.0/24 via 172.18.0.3
```

拓扑图就变成这样了：

```
┌---- srv ----┐---┐ ┌--- router --┐
| 192.168.0.2 |--┐└>| 192.168.0.1 |<-┐
└-------------┘  |  └-------------┘  └--┌-- s/router -┐
                 └--------------------->| 192.168.0.3 |
                 ┌------------------┐   |-------------|
┌---- srv ----┐  |  ┌--- router --┐ └-->| 172.18.0.3  |
| 172.18.0.2  |--┘┌>| 172.18.0.1  |<----└-------------┘
└-------------┘---┘ └-------------┘
```

## 总结

* 必须是和软路由同子网的服务器，才可以将软路由配置到其本地 ip route 表里。
* 当你的软路由只有一张网卡时：
  * 同子网的服务器间通信不走路由，软路由的存在无所谓。
  * 跨子网的服务器通信，软路由会重定向到硬路由，至于是否能通取决于两个子网的硬路由配置。
* 如果你有两个子网，本来就互通的，软路由的存在无所谓。
* 如果两个子网不通，但你的软路由有两张网卡连接两个子网时：
  * 黑客必须控制两个子网各一台服务器，让它们都指向软路由，才能建立这两台服务器之间的双向通信。
  * 如果只配置一个子网的服务器，让其指向软路由，那么只能建立单向通信。
  * TCP 协议无法利用单向通信建立连接，因为它需要双方握手。
  * 对于连接 free 的协议——比如 UDP —— 单向通信是否是一个安全漏洞取决于应用的实现逻辑。

## 参考资料

* [Wiki IP 转发][wiki]
* [How To Add Route on Linux][add-route]
* [Setup Linux As Router][setup]
* [极客时间 - 路由][gktime]

[wiki]: https://zh.wikipedia.org/zh-cn/IP%E8%BD%AC%E5%8F%91
[setup]: https://www.tecmint.com/setup-linux-as-router/
[gktime]: https://time.geekbang.org/column/article/8590
[add-route]: https://devconnected.com/how-to-add-route-on-linux/