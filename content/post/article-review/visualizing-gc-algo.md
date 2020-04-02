---
title: "Visualizing Garbage Collection Algorithms阅读笔记"
author: "颇忒脱"
tags: ["ARTS", "ARTS-R", "gc"]
date: 2020-03-27T11:39:29+08:00
---

<!--more-->

原文：[Visualizing Garbage Collection Algorithms][1]

用动画解释了4种GC算法

## Cleanup at the end: No GC

就是没有GC，程序在执行完一个任务后自己去释放内存。

![](NO_GC.gif)

动画黑色代表没有被使用的内存，闪烁的绿色和黄色代表内存被读或写，颜色变暗代表内存没有被使用（垃圾）。这个算法适合不需要考虑垃圾的程序。

## Reference Counting Collector

对对象的被使用次数进行计数，如果计数变成0，那么就是垃圾，然后释放内存。

引用计数的问题：

* 无法解决循环引用问题，计数永远到不了0，无法被回收
* 无法并发访问问题，因为要计数，所以得串行访问
* 就算内存使用没有增加，也要做计数
* 计数值要频繁从内存加载到CPU Cache，无法有效缓存，效率低

![](REF_COUNT_GC.gif)



动画中的红色闪烁代表更新计数。有时候你会发现红色闪烁之后马上就变成黑色，引用计数算法可以立马发现垃圾然后清理掉。

引用计数是一种分摊成本的算法，所以并不能保证pause time。虽然在程序运行过程中分摊下来pause time比较少，但是不排除某个task会出现pause time很长的情况。

## Mark-Sweep Collector

标记清理算法就是标记Live对象，然后把死掉的对象清理掉。

![](MARK_SWEEP_GC.gif)

它放弃了立即清理垃圾，而是等到后面处理，所以动画中有一段时间没有红色闪烁（标记），然后突然一堆红色闪烁，然后一次性清理了垃圾。

优点：

1. 它不会有引用计数的循环引用问题，因为它是根据可达性来找出Live对象的，因此少了引用计数的开销。

问题：

1. 必须遍历整个内存才能做好标记
2. 清理之后产生内存碎片

## Mark-Compact Collector

标记整理算法，和标记清理算法差不多，只是清理之后把内存压紧了一下，去掉了内存碎片。Oracle JVM的Old区采用的是这个算法。

![](MARK_COMPACT_GC.gif)

优点：

1. 清理之后没有内存碎片
2. 新对象总是在尾部创建，就和stack一样，因为是在heap里的，所以没有stack的大小限制
3. 对象挨个存放之后，有助于CPU cache（见这篇[文章][2]）

问题：

1. 额外的开销，因为对象的内存位置移动了，因此需要更新对象指针指向新地址

## Copying Collector

Copy算法同样也能消除内存碎片，但不是通过移动，而是copy。

通过对两个内存区域的来回Copy实现无碎片垃圾清理。实践中会有多个“代区”，比如JVM的Young区里的S0和S1，已经对象从Young区promote到Old区用的就是这个算法。

![](COPY_GC.gif)

优点：

1. 非常高效，无需标记，直接收集。在对Live对象的遍历过程中连带的对象就顺带被Copy了。

问题：

1. 如果每次Copy没有垃圾可清理，那么这个回收就得不偿失了。所以你就需要tuning gc，使得每次GC的时候能够清理掉大部分对象。
2. 一定要有空闲空间可供腾挪，否则就没法GC了。这也就意味着有一定的内存浪费，因此有算法尽量减少浪费。

[1]: https://spin.atomicobject.com/2014/09/03/visualizing-garbage-collection-algorithms/
[2]: /post/kernel/know-memory-cpu-cache/