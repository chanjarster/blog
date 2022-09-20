---
title: "iptables 简介"
author: "颇忒脱"
tags: ["network"]
date: 2022-09-20T10:50:00+08:00
---

<!--more-->

[iptables][ipt] 是 [netfilter][nf-site] 的一个子项目，在 Linux 内核 3.13 之后 [nftables][nft] 作为 iptables 的继任者出现。

在较新的 RHEL 发行版中，iptables 依然存在，只不过其 backend 已经切换成了 nftable：

```shell
iptables -V
iptables v1.8.4 (nf_tables)
```

## 规则结构

iptables 的可以用于对 IP 包（IP 协议的包）进行过滤、转发、修改，最常见的用途是作为防火墙，但是它的功能不仅仅局限于此。

iptables 的执行依赖于一系列规则，结构是：Table > Chain > Rule > Target

* Table：
  * 内置 Table 有 filter、nat、mangle、raw。
  * 不允许用户自定义 table。
* Chain：
  * 内置 Chain：INPUT、FORWARD、PREROUTING、POSTROUTING、OUTPUT。
  * 用户也可以自定义 Chain。
  * 每个 Table 能使用的内置 Chain 不同。
  * Chain 下面有一系列 Rule 列表。
  * IP 包进入 Chain 后按照顺序匹配 Rule。
  * 把所有 Rule 都过了一遍之后没有找到 Target，那么 Chain 的 Policy 就是 Target。
* Rule：
  * IP 包匹配规则，并决定 Target。
  * 如果匹配，把 IP 包交给设定的 Target。
  * 如果匹配但是没有设定 Target，则 Chain 会继续执行后面的 Rule。
* Target：
  * 决定 IP 包的去向。
  * 可以是内置 Target，比如 ACCEPT、DROP、SNAT、DNAT、MASQUERADE。
  * 也可以用户自定义 Chain。
  * 内置 Target 的使用受限于当前在哪个 Table 和哪个 Chain。

## 内置 Table

下表描述了内置 Table 和其对应的内置 Chain

| Chain       | raw | filter | nat | mangle |
|------------:|:---:|:------:|:---:|:------:|
| PREROUTING  |  Y  |        |  Y  |   Y    |
| INPUT       |     |   Y    |     |   Y    |
| OUTPUT      |  Y  |   Y    |  Y  |   Y    |
| POSTROUTING |     |        |  Y  |   Y    |
| FORWARD     |     |   Y    |     |   Y    |

## Chain 的顺序

下图从内置 Chain 的角度出发，描述了 IP 包如何进入、流出 Chain 的过程，以及 Table 和 Chain 的关系。

比如 Chain `PREROUTING` 在 Table `raw`、`mangle`、`nat` 中存在：

![](iptables.jpeg)


## Chain 对应 Target

下图从另一个角度描述了 IP 包如何经过内置 Chain 和 Table，以及允许的内置 Target。

比如 Table `nat` 的 Chain `PREROUTING`，的可用 Target 有 `DNAT`、`REDIRECT`、`BALANCE`、`NETMAP`。

![](iptables-chains.jpeg)


## 参考资料

* [iptables man][ipt-man]
* [Understanding Iptables][und-ipt]
* [Linux 2.4 Packet Filtering HOWTO][nf-pf-howto]

[nf-site]: https://www.netfilter.org/
[ipt]: https://www.netfilter.org/projects/iptables/index.html
[nft]: https://www.netfilter.org/projects/nftables/index.html
[ipt-man]: https://linux.die.net/man/8/iptables
[und-ipt]: https://jimmysong.io/en/blog/understanding-iptables/
[nf-pf-howto]: https://www.netfilter.org/documentation/HOWTO/packet-filtering-HOWTO.html#toc9