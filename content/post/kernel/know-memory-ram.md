---
title: "What every programmer should know about memory, Part 1
, RAM"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "kernel"]
date: 2019-03-03T15:30:40+08:00
---

<!--more-->

原文：[What every programmer should know about memory, Part 1
, RAM][origin]

# 2 Commodity Hardware Today


* 所有CPU通过[FSB][wiki-fsb]连接到北桥，北桥包含内存控制器（memory controller），连接到RAM

TODO，重新看文章，重新总结。

![](https://static.lwn.net/images/cpumemory/cpumemory.4.png)

![](https://static.lwn.net/images/cpumemory/cpumemory.5.png)

![](https://static.lwn.net/images/cpumemory/cpumemory.6.png)


## 2.1 RAM Types

### 2.1.1 Static RAM

* 访问SRAM没有延迟，但SRAM贵，容量小。

### 2.1.3 DRAM Access

* DRAM物理结构：若干RAM chip，RAM chip下有若干RAM cell，每个RAM cell的状态代表1 bit。
* 访问DRAM有延迟（等待电容充放电），但DRAM便宜，容量大。商业机器普遍使用DRAM，DDR之类的就是DRAM。

## 2.2 DRAM Access Technical Details

* 访问DRAM的步骤：1）RAS（Row address selection）2）CAS（Column address selection）2）传输数据。RAS和CAS都需要消耗时钟频率，如果每次都需要重新RAS-CAS则性能会低。如果一次性把一行的数据都传输，则速度很快。

![](https://static.lwn.net/images/cpumemory/cpumemory.9.png)

### 2.2.4 Memory Types

* 现代DRAM会内置I/O buffer增加每次传输的数据量。

![](https://static.lwn.net/images/cpumemory/cpumemory.47.png)

**Figure 2.14: DDR3 SDRAM Operation**

* 假如DRAM的时钟频率为200MHz，I/O buffer每次传送4份数据（商业宣传其FSB为800MHz），你的CPU是2GHz，那么两者时钟频率则是1:10，意味着内存延迟1个时钟频率，那么CPU就要等待10个时钟频率。

## 2.3 Other Main Memory Users

* 用到内存的不仅仅是CPU，使用DMA（Direct memory access）的设备、没有独立显存的系统（会使用内存作为显寸）都会对FSB产生争用，意味着会导致内存访问延迟。

[origin]: https://lwn.net/Articles/250967/
[wiki-fsb]: https://en.wikipedia.org/wiki/Front-side_bus