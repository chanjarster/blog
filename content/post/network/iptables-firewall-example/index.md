---
title: "iptables 防火墙例子"
author: "颇忒脱"
tags: ["network", "iptables"]
date: 2024-10-25T11:50:00+08:00
---

<!--more-->

本文仅针普通的服务器的防火墙配置，不适用于 docker 和 k8s 的防火墙配置。

## 关闭内置防火墙

先关闭 ufw 和 firewalld 服务。

## 配置 ipset

创建若干 ipset，你允许这些 ipset 来访问你的服务器。

如果就是 ip 地址，命令是这样：

```shell
ipset create <名字> hash:ip
ipset add <名字> <ip>
```

如果是子网，命令是这样：

```shell
ipset create <名字> hash:net
ipset add <名字> <ip/cidr>
```

后面假设 ipset 的名字叫做 `allow-ips`。

## 得到网卡名字

```shell
ip a
...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether fe:fc:fe:ed:20:e7 brd ff:ff:ff:ff:ff:ff
    inet 172.17.9.102/24 brd 172.17.9.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
...
```

上例中 `eth0` 就是网卡的名字。

## 添加 iptables 规则

先查看 iptables 的 `filter` 表里的 `INPUT` chain 里的规则情况，有没有自己设置的规则在里面：

```shell
iptables -t filter -L INPUT -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:53
2    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:53
3    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:67
4    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:67
```

然后添加规则：

```shell
# 允许 allow-ips 访问 80,443 端口
iptables -t filter -A INPUT -i eth0 -p tcp --dport 80  -m set --match-set allow-ips src -j ACCEPT
iptables -t filter -A INPUT -i eth0 -p tcp --dport 443 -m set --match-set allow-ips src -j ACCEPT

# 22 端口是完全放开的
iptables -t filter -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT

# 兜底规则，拒绝其他情况的访问
iptables -t filter -A INPUT -i eth0 -j REJECT
```

再查看一下 iptables 的规则，应该是这样的：

```shell
iptables -t filter -L INPUT -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:53
2    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:53
3    ACCEPT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:67
4    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:67
...
7    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:80  match-set allow-ips src
8    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:443 match-set allow-ips src
9    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:22
10   REJECT     all  --  0.0.0.0/0            0.0.0.0/0            reject-with icmp-port-unreachable
```