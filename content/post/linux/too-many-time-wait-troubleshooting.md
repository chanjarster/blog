---
title: "压测时大量TIME_WAIT问题排查"
author: "颇忒脱"
tags: ["nginx", "troubleshooting"]
date: 2021-09-07T11:42:45+08:00
---

<!--more-->

## 环境

一台Tomcat服务器，监听8080端口，注意这里采用host网络没有NAT：

```bash
docker run -d --name tomcat-8080 --network=host tomcat:8.5-alpine
```

用wrk做压测，连接数100，压5分钟，注意这里故意访问了一个不存在的地址，这是为了降低Tomcat CPU以及流量：

```bash
wrk -c 100 -t 2 -d 300 http://192.168.100.12:8080/abc
```

【服务端侧】Tomcat，netstat得到大量 TIME_WAIT 的连接：

```bash
$ sudo netstat -antpl | grep '192.168.100.12:8080' | gawk -F' ' '{ print $6 }' | sort | uniq -c
     93 ESTABLISHED
  19980 TIME_WAIT

$ sudo conntrack -L -o extended | awk '{print $6 " " $7 " " $8}'  | sort | uniq -c | sort -nr | head -n 10
conntrack v1.4.3 (conntrack-tools): 6566 flow entries have been shown.
   12361 TIME_WAIT src=192.168.100.21 dst=192.168.100.12
   ...
```

【客户端侧】wrk，netstat得到TIME_WAIT 连接在4000左右，conntrack的连接在 6400左右：

```bash
$ sudo netstat -antpl | grep '192.168.100.12:8080' | gawk -F' ' '{ print $6 }' | sort | uniq -c
    101 ESTABLISHED
      1 SYN_SENT
  11782 TIME_WAIT

$ sudo conntrack -L -o extended | awk '{print $6 " " $7 " " $8}'  | sort | uniq -c | sort -nr | head -n 10
conntrack v1.4.3 (conntrack-tools): 9972 flow entries have been shown.
   21081 TIME_WAIT src=192.168.100.21 dst=192.168.100.12
   ...
```

## 分析

【客户端侧】wrk连接数才100个就产生了近 12000 个TIME_WAIT连接，极大浪费了本地端口资源。

【服务端侧】在Tomcat侧也有近 20000 个TIME_WAIT，虽然不浪费端口资源但是浪费内核资源。

TIME_WAIT 状态代表socket已经关闭，走完了4次挥手流程，在等待网络里是否还有包传输过来：

```bash
$ man netstat
TIME_WAIT
    The socket is waiting after close to handle packets 
    still in the network.
```

联想到内核tcp相关参数：

```bash
$ man tcp

tcp_tw_reuse (Boolean; default: disabled; since Linux 2.4.19/2.6)
       Allow to reuse TIME_WAIT sockets for new connections 
       when it is safe from protocol viewpoint.  It should 
       not be changed without advice/request of technical experts.
```

## 调整参数

观察 `net.ipv4.tcp_tw_reuse`内核参数发现没有开启：

```bash
$ sysctl net.ipv4.tcp_tw_reuse
0
```

将其打开（如果要永久开启请看[Linux调整Limits](../limits)）：

```bash
$ sudo sysctl -w net.ipv4.tcp_tw_reuse=1
```

【客户端】wrk TIME_WAIT连接数 7000左右，比之前 12000 好很多：

```bash
$ sudo netstat -antpl | grep '192.168.100.12:8080' | gawk -F' ' '{ print $6 }' | sort | uniq -c
      1 CLOSING
     99 ESTABLISHED
   7018 TIME_WAIT
```

【服务端】Tomcat TIME_WAIT连接数 13000左右，比之前的 20000 好很多：

```bash
$ sudo netstat -antpl | grep '192.168.100.12:8080' | gawk -F' ' '{ print $6 }' | sort | uniq -c
    103 ESTABLISHED
  13628 TIME_WAIT
```

## 扩展

可以参考[常用网络内核参数优化](../net-params)给内核网络参数做一个完整的优化。