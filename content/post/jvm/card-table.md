---
title: "JVM - Card Table和Write Barriers"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "jvm"]
date: 2020-05-15T09:18:08+08:00
---

<!--more-->

在前一篇[G1垃圾收集器](../g1)里提到了Card Table是Remeber Set的一种特殊形式，它记录了外部Region的某个区域里有对象引用了我这个Region里对象的信息。

## 为何会存在Card Table

**下面的描述不是对G1的精确描述，而是逻辑上的描述：**

YGC的时候，理想情况下YGC只需要扫描GC Root（栈中的本地变量表，静态变量）就行了，看下图：

![](https://msdnshared.blob.core.windows.net/media/TNBlogsFS/BlogFileStorage/blogs_msdn/abhinaba/WindowsLiveWriter/BackToBasicsGenerationalGarbageCollectio_115F4/image_6.png)

但是老年代里也会存在对年轻代对象的引用，如果不扫描老年代就会误把一个对象当成是垃圾，看下图：

![](https://msdnshared.blob.core.windows.net/media/TNBlogsFS/BlogFileStorage/blogs_msdn/abhinaba/WindowsLiveWriter/BackToBasicsGenerationalGarbageCollectio_115F4/image_14.png)

我们又知道老年代的GC远没有年轻代频繁，也就造成了老年代的尺寸是很大的。同时，老年代存在对年轻代的引用的概率又很小，如果在YGC的时候对整个老年代进行扫描那么性价比太低。

因此就有了Card Table，年轻代的Card Table里记录了老年代的X区域里的对象引用了年轻代的对象，然后只需要扫描那片区域就行了。

也就是说Card Table是分代垃圾收集算法的特定产物。

## G1中的Card Table

G1中的每个Region都有一个Remember Set，Remeber Set存在3种粒度形式，其中某一种就是Card Table。当然其他两种粒度形式存在的目的和Card Table一样，为了能够降低扫描耗时。

## Card Table结构

实际上Card Table是一个bitmap，每个bit代表着一块区域，那么这块区域到底多大呢？这个似乎也不重要，网上有说是512 byte的，有说是4K的。下面是一张图，图中的Gen1可以看作是老年代（因为是从.Net中抄的图）：

![](https://msdnshared.blob.core.windows.net/media/TNBlogsFS/BlogFileStorage/blogs_msdn/abhinaba/WindowsLiveWriter/BackToBasicsGenerationalGarbageCollectio_115F4/image_18.png)

## 什么是Write Barrier

Writer Barrier就是编译器在你更新引用的地方插入的一小段代码：

* Pre Write Barrier，个人理解和并发标记算法有关，用来解决在并发标记的同时new出来的非垃圾对象不被误认为垃圾的问题。
* Post Write Barrier，用来更新Card Table的，更新old -> old 和 old -> young的信息

## 参考资料

* [Back To Basics: Generational Garbage Collection](https://docs.microsoft.com/en-us/archive/blogs/abhinaba/back-to-basics-generational-garbage-collection)，虽然是.Net的但是思路一样
* [Write-Barriers-in-Garbage-First-Garbage-Collector](https://www.jfokus.se/jfokus17/preso/Write-Barriers-in-Garbage-First-Garbage-Collector.pdf)