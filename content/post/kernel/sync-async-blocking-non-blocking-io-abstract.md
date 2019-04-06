---
title: "关于同步/异步、阻塞/非阻塞IO的摘要"
author: "颇忒脱"
tags: ["kernel", "io"]
date: 2019-04-04T14:04:26+08:00
---

<!--more-->

## 四种IO模型

[Boost application performance using asynchronous I/O][1]把同步阻塞、同步非阻塞、异步阻塞、异步非阻塞的模型讲得很清楚。

## 处理大量连接的问题

event-driven模型派（异步模型）：

* [Dan Kegal's C10K problem][2]
* 延伸阅读：如何解决C10M问题 [The Secret To 10 Million Concurrent Connections -The Kernel Is The Problem, Not The Solution][3] 这个presentation主要讲了如何消除内核network stack的瓶颈，没有特别提到采用哪种模型。

有人对于event-driven模型有一些批判，认为多线程模型（同步阻塞模型）不比事件模型差：

* [Thousands of Threads and Blocking I/O][4]，讲了C10K提到的多线程模型的性能瓶颈在如今的内核里已经不存在了，而多线程模型开发起来更简单。
* [Why Events are a Bad Idea(for high concurrency servers) Rob von Behren][5]，讲了多线程模型的性能瓶颈基本上是因为内核支持的不好、多线程类库有缺陷造成的。认为可以通过编译器的优化、修复内核、修复多线程类库来达到和事件驱动模型相当的结果。且认为事件驱动模型的开发比较复杂。

两种模型也不是说水火不容，[SEDA][7]提出了可以将两种模型结合起来，构建更具弹性的系统。10年之后该作者写了篇回顾文章[A Retrospective on SEDA][8]。

SEDA提出了几个很具有见地的意见：

1. 应用程序的各个stage的压力应该是可观测和可调节的。
2. 应用程序应该是well-conditioned。

什么是Well-conditioned service？

> Intuitively, a service is well-conditioned if it behaves like a simple pipeline, where the depth of the pipeline is determined by the path through the network and the processing stages within the service itself. As the offered load increases, the delivered throughput increases proportionally until the pipeline is full and the throughput saturates; additional load should not degrade throughput. Similarly, the response time exhibited by the service is roughly constant at light load, because it is dominated by the depth of the pipeline. As load approaches saturation, the queueing delay dominates. In the closed-loop scenario typical of many services, where each client waits for a response before delivering the next request, response time should increase linearly with the number of clients. 

> The key property of a well-conditioned service is graceful degradation: as offered load exceeds capacity, the service maintains high throughput with a linear response-time penalty that impacts all clients equally, or at least predictably according to some service-specific policy. Note that this is not the typical Web experience; rather, as load increases, throughput decreases and response time increases dramatically, creating the impression that the service has crashed.

简单来说当负载超过一个应用的容量时，其性能表现要满足以下两点：

* 吞吐量依然保持稳定，可以稍有下跌但绝不会断崖式下跌
* 随着负载的增加其延迟线性增长，绝不会出现尖刺

## Reactor pattern

事件驱动模型到最后就变成了Reactor Pattern，下面是几篇文章：

[Scalable IO in Java][9]介绍了如何使用NIO，其中很重要的一点是handler用来处理non-blocking的task，如果task是blocking的，那么要交给其他线程处理。这不就是简化版的SEDA吗？

Reactor Pattern的老祖宗论文：[Reactor Pattern][10]，TL;DR。[Understanding Reactor Pattern: Thread-Based and Event-Driven][11]帮助你快速理解什么是Reactor Pattern，文中提到如果要处理10K个长连接，Tomcat是开不了那么多线程的。对此有一个疑问，Tomcat可以采用NIO/NIO2的Connector，为啥不能算作是Reactor呢？这是因为Tomcat不是事件驱动的，所以算不上。

[The reactor pattern and non-blocking IO][12]对比了Tomcat和vert.x的性能差别，不过看下来发现文章的压测方式存在偏心：

1. 文中给Tomcat的线程少了（只给了500），只利用了40%左右的CPU，而vert.x的测试的CPU利用率为100%。我把的Tomcat的线程设到2000，测试结果就和vert.x差不多了（验证了多线程模型派的观点）。
2. vert.x的测试代码和Tomcat的测试代码不等价，没有使用`Thread.sleep()`。不过当我尝试在vert.x中使用sleep则发生了大量报错，应该是我的使用问题，后面就没有深究了。

我写的测试可以在[这里][14]看到。

## 总结

看了前面这么多文章其实总结下来就这么几点：

1. 选择事件驱动模型还是多线程模型要根据具体情况来（不过这是一句废话，; )
2. 推崇、反对某个模型的文章/论文都是在当时的历史情况下写出来的，说白了就是存在历史局限性，因此一定要自己验证，当时正确的论断对现在来讲未必正确，事情是会发生变化的。
3. 看测试报告的时候一定要自己试验，有些测试可能本身设计的就有问题，导致结果存在偏见。对于大多数性能测试来说，我觉得只要抓住一点就行了，就是CPU一定要用足。
4. 我们真正应该关注的是不变的东西。

[Jeff Darcy's notes on high-performance server design][6]提到了高性能服务器的几个性能因素：

* data copy，问题依然存在，需要程序员去优化。
* context switch，这个问题已经没有了（见多线程派的几篇文章），现代操作系统不论有多少thread，开销不会有显著增加。
* memory allocation，这个要看看，不过在Java里似乎和JVM GC有关。
* lock contention，这个问题依然存在，应该尽量使用lock-free/non-blocking的数据结构。
* 另外补充：在[C10M][3]里提到kernel和内核的network stack也是瓶颈。

仔细看看有些因素不就是事件驱动模型和多线程模型都面临的问题吗？而又有一些因素则是两种模型提出的当时所各自存在的短板吗？而某些短板现在不是就已经解决了吗？

上面说的有点虚，下面讲点实在的。

如果你有10K个长连接，每个连接大部分时间不使用CPU（处于Idle状态或者blocking状态），那么为每个连接创建一个单独的线程就显得不划算。因为这样做会占用大量内存，而CPU的利用率却很低，因为大多数时间线程都闲着。

事件驱动模型解决的是C10K问题，注意C是Connection，解决的是用更少的硬件资源处理更多的连接的问题，它不解决让请求更快速的问题（这是程序员/算法的问题）。

要不要采用事件驱动模型取决于Task的CPU运算时间与Blocking时间的比例，如果比例很低，那么用事件驱动模型。对于长连接来说，比如websocket，这个比例就很小，甚至可近似认为是0，这个时候用事件驱动模型比较好。如果比例比较高，用多线程模型也可以，它的编程复杂度很低。

不论是采用哪种模型，都要用足硬件资源，这个资源可以是CPU也可以是网络带宽，如果发生资源闲置那你的吞吐量就上不去。

对于多线程模型来说开多少线程合适呢？[Thousands of Threads and Blocking I/O][4]里讲得很对，当能够使系统饱和的时候就够了。比如CPU到100%了、网络带宽满了。如果内存用满了但是这两个都没用满，那么一般来说是出现BUG了。

对于事件驱动模型来说也有CPU用满的问题，现实中总会存在一些阻塞操作会造成CPU闲置，这也就是为什么[SEDA][7]和[Scalable IO in Java][9]都提到了要额外开线程来处理这些阻塞操作。关于如何用满CPU我之前写了一篇文章[如何估算吞吐量以及线程池大小][13]可以看看。

如何用满网络带宽没有什么经验，这里就不说了。

[1]: https://developer.ibm.com/articles/l-async/
[2]: http://www.kegel.com/c10k.html
[3]: http://highscalability.com/blog/2013/5/13/the-secret-to-10-million-concurrent-connections-the-kernel-i.html
[4]: https://www.slideshare.net/e456/tyma-paulmultithreaded1
[5]: https://people.eecs.berkeley.edu/~brewer/papers/threads-hotos-2003.pdf
[6]: http://pl.atyp.us/content/tech/servers.html
[7]: http://www.sosp.org/2001/papers/welsh.pdf
[8]: http://matt-welsh.blogspot.com/2010/07/retrospective-on-seda.html
[9]: http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf
[10]: https://www.dre.vanderbilt.edu/~schmidt/PDF/Reactor2-93.pdf
[11]: https://dzone.com/articles/understanding-reactor-pattern-thread-based-and-eve
[12]: https://www.celum.com/en/blog/technology/the-reactor-pattern-and-non-blocking-io
[13]: ../../concurrent-programming/throughput-and-thread-pool-size/
[14]: https://github.com/chanjarster/io-modes-benchmark