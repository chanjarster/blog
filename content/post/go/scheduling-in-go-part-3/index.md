---
title: "Scheduling In Go : Part III - Concurrency 阅读笔记"
author: "颇忒脱"
tags: ["go", "kernel", "thread", "scheduling", "arts", "arts-r"]
date: 2020-03-31T20:10:26+08:00
---

<!--more-->

原文：[Scheduling In Go : Part III - Go Scheduling][1]

## 几个数字

| operation      | cost                                               |
| -------------- | -------------------------------------------------- |
| 1纳秒          | 可以执行12条指令                                   |
| OS上下文切换   | ~1000到~1500 nanosecond，相当于~12k到~18k条指令。  |
| Go程上下文切换 | ~200 nanoseconds，相当于~2.4k instructions条指令。 |
| 访问主内存     | ~100到~300 clock cycles                            |
| 访问CPU cache  | ~3到~40 clock cycles（根据不同的cache类型）        |

## 不是所有问题都可以concurrency

不论你遇到什么种类的问题，你应该先求出一个正确的sequential解，然后再看这个问题是否有可能作出concurrency解。

## 什么是concurrency

Concurrency意味着乱序执行，拿一组原本顺序执行的指令，把它们乱序执行依然能够得到相同的结果。对于你来说就要去权衡concurrency之后得到的性能好处和其带来的复杂度。而且有些问题乱序执行压根就没道理，只能顺序执行。

并行和并发的区别在于，并行是指在不同的OS线程上，OS线程在不同的core上同时执行不相干的指令。

{{< figure src="96_figure1.png" width="100%">}}

上图中，P1和P2有自己的OS线程，OS线程在不同的core上，因此G1和G2是并行的。

但是在P1和P2自己看来，它有3个G要执行，而这三个G共享同一个OS线程/core，而且执行顺序是不定的，它们是并发执行的。

## 工作负载

前面讲过，有两种类型的工作负载：

1. CPU-Bound：永远不会使得Go程处于waiting状态，永远处于runnable/executing状态的纯计算型任务。
2. IO-Bound：天然的会使得Go程进入waiting状态。比如访问网络资源、syscall、访问文件。同时也把同步事件归到此类（atomic、mutex）

对于CPU-Bound任务来说，你需要利用并行。如果Go程数量多于OS线程/core数量，那么就会使得Go程被上下文切换，从而带来性能损失。

对于IO-Bound任务来说，你可以不需要利用并行，一个OS线程/core可以很轻松的处理这种天然就会进出waiting状态的任务。Go程数量大于OS线程/core数量可以大大提高OS线程/core的利用率，提高任务的处理速度。Go程的上下文切换不会造成性能损失，因为你的任务自己就会停止。

那么使用多个Go程能带来多大好处，以及多少个Go程能带来最大效果，那么就需要benchmark才能知道。

[1]: https://www.ardanlabs.com/blog/2018/12/scheduling-in-go-part3.html
