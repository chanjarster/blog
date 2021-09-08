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
$ netstat -antpl | gawk -F' ' '{ print $6 }' | sort | uniq -c
      1 established)
      5 ESTABLISHED
      1 Foreign
      4 LISTEN
      2 TIME_WAIT
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
$ conntrack -L -o extended | awk '{print $7}' | cut -d "=" -f 2 | sort | uniq -c | sort -nr | head -n 10
conntrack v1.4.3 (conntrack-tools): 2693 flow entries have been shown.
   1048 192.168.100.21
    669 192.168.100.5
    504 10.42.3.94
     61 10.42.3.171
     44 10.42.3.128
     41 10.42.3.3
     38 10.43.0.10
     26 10.42.3.70
     18 10.42.3.27
     16 10.42.3.41
```

统计各个四元组的连接跟踪数：

```bash
$ conntrack -L -o extended | awk '{print $6 " " $7 " " $8}'  | sort | uniq -c | sort -nr | head -n 10

conntrack v1.4.3 (conntrack-tools): 3357 flow entries have been shown.
    500 ESTABLISHED src=10.42.3.94 dst=10.42.4.129
     30 TIME_WAIT src=192.168.100.21 dst=10.42.3.167
     30 TIME_WAIT src=192.168.100.21 dst=10.42.3.156
     30 TIME_WAIT src=192.168.100.21 dst=10.42.3.133
     30 TIME_WAIT src=192.168.100.21 dst=10.42.3.132
     21 ESTABLISHED src=10.42.3.70 dst=10.43.239.23
     19 CLOSE src=10.42.3.128 dst=10.43.117.95
     15 SYN_SENT src=10.42.3.27 dst=10.43.161.131
     13 SYN_SENT src=10.42.3.41 dst=10.43.223.88
     12 TIME_WAIT src=192.168.100.21 dst=10.42.3.71
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

