---
title: "常用网络内核参数优化"
author: "颇忒脱"
tags: ["linux", "cheatsheet", "network", "性能调优"]
date: 2021-09-08T14:33:22+08:00
---

<!--more-->

参考自 [极客时间 - Linux性能优化实战](https://time.geekbang.org/column/article/84003)，根据[Linux调整内核参数](../limits)的方法调整以下参数值。

## tcp参数

```bash
# 增大处于 TIME_WAIT 状态的连接数量
net.ipv4.tcp_max_tw_buckets=1048576
# 增大跟踪连接表大小
net.netfilter.nf_conntrack_max=1048576

# 缩短处于 TIME_WAIT 状态的超时时间
net.ipv4.tcp_fin_timeout=15
# 缩短跟踪连接表中处于 TIME_WAIT 状态连接的超时时间
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

# 允许 TIME_WAIT 状态占用的端口还可以用到新建的连接中
net.ipv4.tcp_tw_reuse=1
# 开上一个必须要开这个
net.ipv4.tcp_timestamps=1

# 增大本地端口号的范围
net.ipv4.ip_local_port_range=10000 65000

# 增大进程的最大文件描述符数
fs.nr_open=1048576
# 系统的最大文件描述符数
fs.file-max=1048576

# 增加半连接的最大数量
net.ipv4.tcp_max_syn_backlog=16384
# 开启 SYN Cookies
net.ipv4.tcp_syncookies=1
# 减少 SYN_RECV 状态的连接重传 SYN+ACK 包的次数
net.ipv4.tcp_synack_retries=1

# 缩短Keepalive探测包的间隔时间
net.ipv4.tcp_keepalive_intvl=30
# 缩短最后一次数据包到Keepalive探测包的间隔时间
net.ipv4.tcp_keepalive_time=600
# 减少Keepalive探测失败后通知应用程序前的重试次数
net.ipv4.tcp_keepalive_probes=3
```

