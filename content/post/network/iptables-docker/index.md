---
title: "用 iptables 保护 Docker host"
author: "颇忒脱"
tags: ["network", "k8s", "docker"]
date: 2024-10-25T12:50:00+08:00
---

<!--more-->

本文仅针对纯粹的 docker 安装环境下的防火墙，不适用于配置 k8s 防火墙。

## 关闭内置防火墙

先关闭 ufw 和 firewalld 服务。

## 配置 ipset

创建若干 ipset，你允许这些 ipset 来访问你的 docker host。

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

根据 [docker Packet filtering and firewalls][1]，`DOCKER-USER` chain 是提供给用户的一个添加自定义防火墙规则的入口，所以你的 iptables 规则应该加在这里。

> BTW，ufw 防火墙规则之所以无效，是因为它的规则优先级 Docker 的规则之后。


先查看 iptables 的 `filter` 表里的 `DOCKER-USER` chain 里的规则情况，如果之前没有添加过任何防火墙规则，应该是这样的：

```shell
iptables -t filter -L DOCKER-USER -n --line-numbers
Chain DOCKER-USER (1 references)
num  target     prot opt source               destination
1    RETURN     all  --  0.0.0.0/0            0.0.0.0/0
```

如果你得到的结果是下面这样，提示你没有这个 chain：

```shell
iptables: No chain/target/match by that name.
```

那么你重启一下 docker：

```shell
systemctl restart docker
```

然后添加规则：

```shell
iptables -t filter -I DOCKER-USER 1 -i eth0 -j REJECT
iptables -t filter -I DOCKER-USER 1 -i eth0 -m set --match-set allow-ips src -j ACCEPT
iptables -t filter -I DOCKER-USER 1 -m state --state ESTABLISHED,RELATED -j ACCEPT
```

再查看一下 iptables 的规则，应该是这样的：

```shell
iptables -t filter -L DOCKER-USER -n --line-numbers -v
Chain DOCKER-USER (1 references)
num   pkts bytes target     prot opt in     out     source               destination
1      186  108K ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
2       11  3519 ACCEPT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0            match-set k8s-node-ips src
3       58  3704 REJECT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0            reject-with icmp-port-unreachable
4     1073  494K RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0
```

注意 iptables 的规则执行是有顺序的，按照顺序来看，意思就是：

1. 第 1 条规则，用来保证出站流量不被拦截
2. 第 2 条规则，如果网卡 `eth0` 收到的包的 src IP 在 `allow-ips` IP Set 范围内，接受
3. 第 3 条规则，其他情况，直接拒绝
4. 第 4 条规则，这个是 Docker 提供的默认规则，其实是走不到这条规则，你可以忽略。

[1]: https://docs.docker.com/engine/network/packet-filtering-firewalls/