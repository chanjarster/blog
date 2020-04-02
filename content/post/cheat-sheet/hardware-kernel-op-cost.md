---
title: "硬件/内核操作Cheat sheet"
author: "颇忒脱"
tags: ["kernel", "cheatsheet"]
date: 2020-04-02T15:09:20+08:00
---

<!--more-->

| operation        | cost                                               |
| ---------------- | -------------------------------------------------- |
| CPU执行1条指令   | ~1/12纳秒，也就是1纳秒可以执行12条指令             |
| 访问寄存器       | <=1 clock cycles                                   |
| 访问CPU L1d      | ~3 clock cycles                                    |
| 访问CPU L2       | ~14 clock cycle                                    |
| 访问CPU L3       | ~40 clock cycles                                   |
| 访问主内存       | ~100到~300 clock cycles                            |
|                  |                                                    |
| OS线程上下文切换 | ~1000到~1500 nanosecond，相当于~12k到~18k条指令。  |
| Go程上下文切换   | ~200 nanoseconds，相当于~2.4k instructions条指令。 |



这几个数字出现在：

* [Scheduling In Go : Part I - OS Scheduler 阅读笔记](/post/go/scheduling-in-go-part-1/)
* [What every programmer should know about memory, Part 2: CPU caches](/post/kernel/know-memory-cpu-cache/)

