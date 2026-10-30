---
title: "nftables 简介"
author: "颇忒脱"
tags: ["network", "linux"]
date: 2022-09-20T10:50:00+08:00
---

<!--more-->

## 基本概念

### Address Family

nftable 把数据包的类型分类 6 大类：

| Family  |  Description         |
|:-------:|:---------------------|
| ip      | IPv4 address family. |
| ip6     | IPv6 address family. |
| inet    | Internet (IPv4/IPv6) address family. |
| arp     | ARP address family, handling IPv4 ARP packets. |
| bridge  | Bridge address family, handling packets which traverse a bridge device. |
| netdev  | Netdev address family, handling packets from ingress. |

### Table

每个 Address Family 可以有 N 个 Table，而每个 Table 下则有 N 个 Chain。

比如：

> **nft add table** `family` `table_name` 

### Hooks

每一种 Address Family 都有对应的 Hooks 来对应网络包处理的不同阶段：

| Hook          | Description          |
|:-------------:|:---------------------|
| prerouting    | All packets entering the system are processed by the prerouting hook. It is invoked before the routing process and is used for early filtering or changing packet attributes that affect routing. |
| input         | Packets delivered to the local system are processed by the input hook. |
| forward       | Packets forwarded to a different host are processed by the forward hook. |
| output        | Packets sent by local processes are processed by the output hook. |
| postrouting   | All packets leaving the system are processed by the postrouting hook. |

### Chain

Chain 分类两种，base chain 和 regular chain。

* base chain 是处理包的入口。
* regular chain 是用户自定义的，用作规则的 jump target，也可用来组织规则便于维护。

创建 base chain 时：

* 必须指定：table（隐含 family）、chain type、hook（介入阶段）、priority（优先级）
* 可选指定：devide（设备）、policy（默认结果）。

比如：

> **nft add chain** `[family]` `table_name` `chain_name` **type** `chain_type` **hook** `hook_name` [**device** `device_name`] **priority** `priority_value` ; [**policy** `policy_name` ;]`

创建 regular chain 时，以上都不能指定，比如：

> **nft add chain** `[family]` `table_name` `chain_name`

base chain type 有 3 种，不同的 Family + Hook 组合下：


| Type          |  Description                             |
|:-------------:|:-----------------------------------------|
| filter        | Standard chain type to use in doubt.     |
| nat           | Chains of this type perform Native Address Translation based on conntrack entries. Only the first packet of a connection actually traverses this chain - its rules usually define details of the created conntrack entry (NAT statements for instance). |
| route         | If a packet has traversed a chain of this type and is about to be accepted, a new route lookup is performed if relevant parts of the IP header have changed. This allows to e.g. implement policy routing selectors in nftables. |

### Family、Hook、Chain Type

不同的 Family 能使用的 Hook 不同，而不同的 Family + Hook 的组合所能使用的 Base Chain type 也不同，总结在下面这张表里：

|    Family    |     Hook      | Base Chain Type      |
|:------------:|:-------------:|:-------------------|
| netdev       |  ingress      | filter             |
| ip,ip6,inet  |  prerouting   | filter, nat        |
|              |  forward      | filter             |
|              |  input        | filter, nat        |
|              |  output       | filter, nat, route |
|              |  postrouting  | filter, nat        |
| bridge       |  prerouting   | filter             |
|              |  forward      | filter             |
|              |  input        | filter             |
|              |  output       | filter             |
|              |  postrouting  | filter             |
| arp          |  input        | filter             |
|              |  output       | filter             |

### Chain 的顺序

当一个 Table 有 N 个 Base Chain ，当这些 Chain 挂在同一个 Hook 下时，根据 Chain 的 Priority 来排序（升序）执行。

Priority 可以是数字，可以是内置 Priority 名称，还可以内置 Priority 名称上做加减法，比如 `dstnat - 5`。

nftable 内置 Pirority 名称（注意 Value 的顺序）：

|  Name    | Value   | Families    |  Hooks    |
|:--------:|:-------:|:------------|:----------|
| raw      | -300    | ip,ip6,inet | all       |
| mangle   | -150    | ip,ip6,inet | all       |
| dstnat   | -100    | ip,ip6,inet | prerouting     |
| filter   | 0       | ip,ip6,inet,arp,netdev | all |
| security | 50      | ip,ip6,inet | all            |
| srcnat   | 100     | ip,ip6,inet | postrouting    |

bridge family 下的 Priority 名称：

|  Name    | Value   | Hooks          |
|:--------:|:-------:|:---------------|
| dstnat   | -300    | prerouting     |
| filter   | -200    | all            |
| out      | 100     | output         |
| srcnat   | 300     | postrouting    |

> 虽然上面两个表格看上去 Priority 名称有期其适用的 Family + Hook 组合，实际使用时没有这个限制，因为 nftables 只是取其值排序而已，只不过阅读上去会有点奇怪

### Rule

Rule 指的是处理网络包的规则，一个 Chain 下可以有 N 个 Rule，按照顺序执行 Rule。

## 规则例子

```nginx
# family=ip 的一个 table，名字叫 foo
table ip foo {
  chain bar {
    # base chain，名字叫 bar, priority=filter=0
    type filter hook input priority filter; policy accept;
    # 一个规则
    ip protocol tcp jump nonbased-chain-name
  }
  # 自定义 regular chain
  chain nonbased-chain-name {
    ...
  }
}
```

## 各 Family 下 Hook 的流转顺序

下图总结了 Family 下 Hook 的流转顺序：

![](https://people.netfilter.org/pablo/nf-hooks.png)

## 参考资料

* [Netfilter hooks][nf-hooks]
* [nftables man][nft-man]
* [A comprehensive guide to Nftables][comp-guide]


[nf-hooks]: https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks
[nft-man]: https://www.netfilter.org/projects/nftables/manpage.html
[comp-guide]: https://www.linkedin.com/pulse/comprehensive-guide-nftables-leading-packet-filtering-arash-shirvar