---
title: "Another Reason Why Your Docker Containers May Be Slow"
author: "颇忒脱"
tags: ["docker", "linux"]
date: 2019-02-23T09:56:08+08:00
---

原文：[Another Reason Why Your Docker Containers May Be Slow][origin]

本文讲述了容器在运行过程中，不光会竞争CPU、内存、磁盘、网络，还会竞争内核资源。并提到了使用`perf`来debug问题。

<!--more-->

文章里提到一个应用，它需要 5 CPU / 30G Memory。

* 当单实例跑在一个虚拟机上的时候，某个调用的测试结果是 *a few milliseconds per query* 。
* 但是当多实例，也就3-4个，容器化跑在一个服务器上（72 CPU / 512G Memory）时，响应居然开始变慢了，可高达数秒。

按照理论上讲，跑4个实例才用了 20 CPU / 120G Memory，远远没有用足服务器上的资源。

然后他们用[Sysbench][sysbench]测试服务器的CPU、内存、磁盘均没有发现瓶颈。

直到他们用`perf`工具调试应用进程。结果发现有一个内核资源的调用非常频繁，次数高达70%以上。然后顺藤摸瓜找到使用的第三方库的参数优化方案，问题解决。

[origin]: https://hackernoon.com/another-reason-why-your-docker-containers-may-be-slow-d37207dec27f
[sysbench]: https://github.com/akopytov/sysbench