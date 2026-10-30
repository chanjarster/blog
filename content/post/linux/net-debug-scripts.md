---
title: "网络监控实用脚本"
author: "颇忒脱"
tags: ["linux", "cheatsheet", "network"]
date: 2021-09-07T11:33:22+08:00
---

<!--more-->

## man tcp

查看tcp协议的内核文档，相关内核参数。

## netstat

根据连接状态分类统计：

```bash
$ netstat -antpl | tail -n +3 | awk '{ print $6 }' | sort | uniq -c | sort -rn
      1 established)
      5 ESTABLISHED
      1 Foreign
      4 LISTEN
      2 TIME_WAIT
```

根据 连接状态 + Foreign Address 来统计：

```
$ netstat -antpl | tail -n +3 | awk '{print $6, $5}' | sed 's/:[[:print:]]*/\t/g' | sort | uniq -c | sort -rn
     20 ESTABLISHED 127.0.0.1
     10 ESTABLISHED 172.18.0.2
      3 LISTEN 0.0.0.0
      3 LISTEN
      2 TIME_WAIT xx.xx.xx.xx
      1 ESTABLISHED xx.xx.xx.xx
```

各协议统计：

```bash
$ netstat -s

Ip:
    36011721975 total packets received
    4 with invalid addresses
    25054109504 forwarded
    0 incoming packets discarded
...
Tcp:
    506169163 active connections openings
    28177249 passive connection openings
    143466 failed connection attempts
    48873 connection resets received
...
```

关注套接字统计信息：

```bash
$ netstat -s | grep socket
    73 resets received for embryonic SYN_RECV sockets
    308582 TCP sockets finished time wait in fast timer
    8 delayed acks further delayed because of locked socket
    290566 times the listen queue of a socket overflowed
    290566 SYNs to LISTEN sockets dropped
```

## conntrack

统计总的连接跟踪数：
```bash
$ conntrack -L -o extended | wc -l
100
```


统计TCP协议各个状态的连接跟踪数：

```bash
$ conntrack -L -o extended | awk '/^.*tcp.*$/ {sum[$6]++} END {for(i in sum) print i, sum[i]}'

conntrack v1.4.3 (conntrack-tools): 3349 flow entries have been shown.
CLOSE_WAIT 17
CLOSE 31
ESTABLISHED 758
TIME_WAIT 387
SYN_SENT 72
```

统计各个源IP的连接跟踪数：

```bash
$ conntrack -L -o extended | awk '{print $7}' | sort | uniq -c | sort -nr | head -n 10
conntrack v1.4.3 (conntrack-tools): 2693 flow entries have been shown.
   1048 src=192.168.100.21
    669 src=192.168.100.5
    504 dst=...
     61 dst=...
```

统计各个四元组的连接跟踪数：

```bash
$ conntrack -L -o extended | awk 'BEGIN {OFS="\t"}; {print $6, $7, $8}'  | sort | uniq -c | sort -nr | head -n 10

conntrack v1.4.3 (conntrack-tools): 3357 flow entries have been shown.
    500 ESTABLISHED src=... dst=...
     30 TIME_WAIT   src=... dst=...
     ...
```

## ss

查看连接状态统计：

```bash
$ ss -s
Total: 9190 (kernel 0)
TCP:   2450 (estab 30, closed 2309, orphaned 0, synrecv 0, timewait 1135/0), ports 0

Transport Total     IP        IPv6
*	        0         -         -
RAW	      0         0         0
UDP	      2         2         0
TCP	      141       75        66
INET	    143       77        66
FRAG	    0         0         0
```

## hping3

测试网络延迟Round-Trip Time：

```bash

# -c表示发送3次请求，-S表示设置TCP SYN，-p表示端口号为80
$ hping3 -c 3 -S -p 80 baidu.com
HPING baidu.com (eth0 123.125.115.110): S set, 40 headers + 0 data bytes
len=46 ip=123.125.115.110 ttl=51 id=47908 sport=80 flags=SA seq=0 win=8192 rtt=20.9 ms
len=46 ip=123.125.115.110 ttl=51 id=6788  sport=80 flags=SA seq=1 win=8192 rtt=20.9 ms
len=46 ip=123.125.115.110 ttl=51 id=37699 sport=80 flags=SA seq=2 win=8192 rtt=20.9 ms

--- baidu.com hping statistic ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 20.9/20.9/20.9 ms
```

## traceroute

```bash
# --tcp表示使用TCP协议，-p表示端口号，-n表示不对结果中的IP地址执行反向域名解析
$ traceroute --tcp -p 80 -n baidu.com
traceroute to baidu.com (123.125.115.110), 30 hops max, 60 byte packets
 1  * * *
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  * * *
13  * * *
14  123.125.115.110  20.684 ms *  20.798 ms
```

traceroute 会在路由的每一跳发送三个包，并在收到响应后，输出往返延时。如果无响应或者响应超时（默认 5s），就会输出一个星号。

## sar

安装：

```bash
yum install -y sysstat
```

观察 PPS（每秒收发的报文数）和BPS（每秒收发的字节数）：

```bash
$ sar -n DEV 1
08:55:49        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
08:55:50      docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
08:55:50         eth0  22274.00    629.00   1174.64     37.78      0.00      0.00      0.00      0.02
08:55:50           lo      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
```

