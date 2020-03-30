---
title: "Scheduling In Go : Part II - Go Scheduler 阅读笔记"
author: "颇忒脱"
tags: ["go", "kernel", "thread", "scheduling", "arts", "arts-r"]
date: 2020-03-30T18:10:26+08:00
---

<!--more-->

原文：[Scheduling In Go : Part II - Go Scheduler][1]

## 逻辑组件

* P：Logical Processor，你有多少个虚拟core就有多少个P。之所以说虚拟core是因为如果处理器支持支持一个core有多个硬件线程（Hyper-Threading，超线程），那么每个硬件线程就算作一个虚拟core。`runtime.NumCPU()`能够得到虚拟core的数量。

* M：操作系统线程。这个线程依然由操作系统调度。每个P被分配一个M。
* G：Go程。Go程实际上是协程（[Coroutine][2]）。和操作系统线程有点像，只是操作系统线程上下文切换在core上，而Go程上下文切换在M上。Go程的上下文切换发生在用户空间，开销更低。
* 运行队列（队列中的G都是runnable的）：
  * LRQ（Local Run Queue）。每个P会给一个LRQ，P负责把LRQ中的G上下文切换到M上。
  * GRQ（Global Run Queue），GRQ放还未分配到P的G。

这是一张全景图：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure2.png" width="100%">}}

## 协作式调度器

和操作系统的抢占式调度器不同，Go采用的是协作式调度器。Go调度器是Go运行时的一部分，而Go运行时在内置在你的程序里。所以Go调度器运行在用户空间。

Go调度器运行在用户空间，那么就需要定义明确的发生在safepoint的用户空间事件来做调度决策。不过程序员不需要太多关心这个，同时也无法控制调度行为，所以Go调度器虽然是协作式的但看起来像是抢占式的。

## Go程状态

* Waiting：Go程停止了，且在等待什么事情发生。比如等待操作系统（syscall）、同步调用（atomic和mutex操作）
* Runnable：Go程想要M的时间来执行指令。越多的Go程想要时间，就以为着等待越长的时间，每个Go程能分到的时间就越少。
* Executing：Go程正在M上执行指令。

## 上下文切换

Go调度程序需要定义明确的用户空间事件，这些事件发生在代码中的安全点，以便进行上下文切换。安全点体现在函数调用中。所以函数调用很重要。在Go 1.11之前，如果程序在跑一个很长的循环且循环里没有函数调用，那么就会导致调度器和GC被推迟。

4类事件允许调度器做调度决策，注意调度不一定会发生，而是给了调度器一个机会而已：

* 使用`go`
* 垃圾收集
* 系统调用
* 同步和编排（Synchronization and Orchestration）

**使用`go`**

`go`创建了一个新的Go程，自然调度器有机会做一个调度决策。

**垃圾收集**

垃圾收集跑在自己的Go程里，需要征用M来运行，因此调度器也需要做决策

**系统调用**

系统调用会导致Go程阻塞M。调度器有些时候会把这个G从M换下（上下文切换），然后把新的G换上M。也有可能创建一个新的M，用来执行P的LRQ中的G。

**同步和编排**

如果atomic、mutex、channel操作阻塞了一个G，调度器会把一个新的G去运行，等到它又能运行了（从阻塞中解除），那么再把它放到队列中，然后最终跑在到M上。

## 异步系统调用

比如MacOS中的kqueue、Linux中的epoll、Windows的iocp都是异步网络库。G做这些异步系统调用并不会阻塞M，那么就意味着M可以用来执行LRQ中的其他M。下面是图解：

G1准备做网络调用：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure3.png" width="100%">}}

G1移到了Net Poller，然后M可以跑G2

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure4.png" width="100%">}}

G1就绪了，就回到LRQ中，等待被调度，整个过程不需要新的M：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure5.png" width="100%">}}

## 同步系统调用

文件IO不是异步的，所以G会把M给阻塞，那么Go调度器会这么做：

G1调用了阻塞系统调用：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure6.png" width="100%">}}

M1连带G1从P脱离，创建新的M2给P，把G2调度到M2上：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure7.png" width="100%">}}

而后G1从阻塞中恢复，追加到LRQ中等待下次调度，M1则保留下来等待以后使用：

{{< figure src="https://www.ardanlabs.com/images/goinggo/94_figure8.png" width="100%">}}

## Work Stealing



[1]: https://www.ardanlabs.com/blog/2018/08/scheduling-in-go-part2.html
[2]: https://en.wikipedia.org/wiki/Coroutine