---
title: "JVM - 目录"
author: "颇忒脱"
tags: ["jvm"]
date: 2019-09-05T08:50:08+08:00
---

<!--more-->

## 内存区域

* [JVM - 运行时数据区](../run-time-data-areas/)
* [JVM - String interning](../string-interning/)
* [JVM - OutOfMemoryError异常分析](../out-of-memory-errors/)

## GC

* [Visualizing Garbage Collection Algorithms](https://spin.atomicobject.com/2014/09/03/visualizing-garbage-collection-algorithms/)，现代垃圾收集算法（语言无关）
* [JVM - 对象已经死了吗？](../is-object-dead/)
* [JVM - GC算法](../gc-algos/)
* [JVM - 垃圾收集器](../gc-collectors/)
* [JVM - 内存分配与回收策略](../memory-alloc-and-reclaim/)
* [JVM - G1垃圾收集器](../g1)
* [JVM - Card Table和Write Barriers](../card-table)

## ClassLoader

* [JVM - 类加载时机](../class-loading-chance)
* [JVM - 类加载过程](../class-loading-steps)
* [JVM - 类加载器](../class-loading-classloader)
* [JVM - Tomcat类加载器](../classloader-tomcat)
* [JVM - OSGi类加载器](../classloader-osgi)
* [JVM - 字节码生成及动态代理](../classloader-byte-gen-dynamic-proxy)

以下是阅读JVM Spec时所整理的笔记，比较细：

* [ClassLoader（一）- 介绍](../classloader/1-intro/)
* [ClassLoader（二）- 加载过程](../classloader/2-steps/)
* [ClassLoader - 总结及参考](../classloader/references/)

## 字节码指令

* [JVM执行方法调用（一）- 重载与重写](../method-call/1-overload-override/)
* [JVM执行方法调用（二）- 指令](../method-call/2-instrucions/)

## 内存模型与线程

* [JVM - 内存模型](../memory-model)
* [JVM - 线程](../thread)
* [JVM - 线程安全](../thread-safe)
* [JVM - 锁优化](../lock-optimization)

## 其他

* [JVM - 对象的内存布局](../object-layout)
* [JVM - 指针压缩原理](../oop-compress)

## 实战

* [Java应用性能调优套路](../jvm-perf-tuning-common-ways)

