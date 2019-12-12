---
title: "K8S的一些诊断工具镜像"
author: "颇忒脱"
tags: ["k8s"]
date: 2019-12-12T10:59:27+08:00
---

<!--more-->

## 诊断方法

方法一：启动一个诊断工具镜像的Deployment，在Pod上执行诊断脚本（一般都是进入shell）。

方法二：启动一个诊断工具镜像的DaemonSet，这个方法在你怀疑某个工作节点存在问题时有用，因为DaemonSet会在所有工作节点上启动一个Pod实例，然后你只需要在每个Pod上执行诊断脚本即可。

## 诊断工具镜像

* [busybox](https://hub.docker.com/_/busybox)，老牌工具箱，有nslookup、wget、ping、telnet。没有tcpdump、curl，略显不便。
* [nicolaka/netshoot](https://hub.docker.com/r/nicolaka/netshoot)，更全面的网络工具箱。

