---
title: "Scheduling In Go : Part II - Go Scheduler 阅读笔记"
author: "颇忒脱"
tags: ["go", "kernel", "thread", "scheduling", "arts", "arts-r"]
date: 2020-03-30T18:10:26+08:00
---

<!--more-->

原文：[Scheduling In Go : Part II - Go Scheduler][1]

可以同步阅读：[Go's work-stealing scheduler](https://rakyll.org/scheduler/)，不过没有本文写的明白。

## 几个数字

| operation      | cost                                               |
| -------------- | -------------------------------------------------- |
| 1纳秒          | 可以执行12条指令                                   |
| OS上下文切换   | ~1000到~1500 nanosecond，相当于~12k到~18k条指令。  |
| Go程上下文切换 | ~200 nanoseconds，相当于~2.4k instructions条指令。 |
| 访问主内存     | ~100到~300 clock cycles                            |
| 访问CPU cache  | ~3到~40 clock cycles（根据不同的cache类型）        |

## 逻辑组件

* P：Logical Processor，你有多少个虚拟core就有多少个P。之所以说虚拟core是因为如果处理器支持支持一个core有多个硬件线程（Hyper-Threading，超线程），那么每个硬件线程就算作一个虚拟core。`runtime.NumCPU()`能够得到虚拟core的数量。

* M：操作系统线程。这个线程依然由操作系统调度。每个P被分配一个M。
* G：Go程。Go程实际上是协程（[Coroutine][2]）。和操作系统线程有点像，只是操作系统线程上下文切换在core上，而Go程上下文切换在M上。Go程的上下文切换发生在用户空间，开销更低。
* 运行队列（队列中的G都是runnable的）：
  * LRQ（Local Run Queue）。每个P会给一个LRQ，P负责把LRQ中的G上下文切换到M上。
  * GRQ（Global Run Queue），GRQ放还未分配到P的G。

这是一张全景图：

{{< figure src="94_figure2.png" width="100%">}}

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

{{< figure src="94_figure3.png" width="100%">}}

G1移到了Net Poller，然后M可以跑G2

{{< figure src="94_figure4.png" width="100%">}}

G1就绪了，就回到LRQ中，等待被调度，整个过程不需要新的M：

{{< figure src="94_figure5.png" width="100%">}}

## 同步系统调用

文件IO不是异步的，所以G会把M给阻塞，那么Go调度器会这么做：

G1调用了阻塞系统调用：

{{< figure src="94_figure6.png" width="100%">}}

M1连带G1从P脱离（此时M1因为阻塞被操作系统上下文切换下去了），创建新的M2给P，把G2调度到M2上：

{{< figure src="94_figure7.png" width="100%">}}

而后G1从阻塞中恢复，追加到LRQ中等待下次调度，M1则保留下来等待以后使用：

{{< figure src="94_figure8.png" width="100%">}}

## Work Stealing

虽然名字叫做工作偷窃，但实际上是好事。简单来说就是当P1没有G时，把P2的LRQ中的G“偷”过来执行，借此来提高M的利用率。

看下图中P1和P2都有3个G等待调度，GRQ中有一个G

{{< figure src="94_figure9.png" width="100%">}}

这个时候P1先把自己的G都处理完了：

{{< figure src="94_figure10.png" width="100%">}}

P1会“偷”P2 LRQ中一半的G，偷窃算法如下，简单来说就是先偷P2的G，如果没有再从GRQ中取：

```go
runtime.schedule() {
    // only 1/61 of the time, check the global runnable queue for a G.
    // if not found, check the local queue.
    // if not found,
    //     try to steal from other Ps.
    //     if not, check the global runnable queue.
    //     if not found, poll network.
}
```

{{< figure src="94_figure11.png" width="100%">}}

当P2把G都做完了，然后P1没有G在LRQ中时：

{{< figure src="94_figure12.png" width="100%">}}

根据前面讲的算法，P2会拿GRQ中的G来运行：

{{< figure src="94_figure13.png" width="100%">}}

## 实际的例子

下面拿一个实际的例子来告诉你Go调度器是如何比你直接用OS线程做更多工作的。

### 协作式OS线程程序

有两个OS线程，T1和T2，它们之间的交互式这样的：

* T2等待消息，T1发送消息，T1等待消息
* T2接收消息，T2发送消息，T2等待消息
* T1接收消息。。。
* 。。。

T1一开始在C1上，T2处于等待状态：

{{< figure src="94_figure14.png" width="100%">}}

T1发送消息给T2，进入等待，从C1脱离；T2收到消息后调度到C2上：

{{< figure src="94_figure15.png" width="100%">}}

T2发送消息给T1，进入等待，从C2脱离；T1收到消息后调度到C3上：

{{< figure src="94_figure16.png" width="100%">}}

所以你可以看到T1和T2频繁发生OS上下文切换，而这个代价是很高的（见文头表格）。同时每次切换到不同core上，导致cache miss，所以还存在访问主内存的开销。

### 协作式Go程程序

下面来看看Go调度器怎么做的：

G1一开始在M1上，而M1和C1绑定，G2处于等待状态：

{{< figure src="94_figure17.png" width="100%">}}

G1发消息给G2，进入等待，从M1脱离；G2收到消息被调度到M1：

{{< figure src="94_figure18.png" width="100%">}}

G2发消息给G1，进入等待，从M1脱离；G1收到消息被调度到M1：

{{< figure src="94_figure19.png" width="100%">}}

所以Go程调度的优势：

* OS线程始终保持运行，没有进入waiting
* Go程上下文切换不是发生在OS层面，代价相对低， ~200 nanoseconds 或 ~2.4k instructions。
* 始终都是在同一个core上，优化了cache miss的问题，这个对于[NUMA架构][3]特别友好。

[1]: https://www.ardanlabs.com/blog/2018/08/scheduling-in-go-part2.html
[2]: https://en.wikipedia.org/wiki/Coroutine
[3]: http://frankdenneman.nl/2016/07/07/numa-deep-dive-part-1-uma-numa