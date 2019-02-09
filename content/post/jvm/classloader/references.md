---
title: "ClassLoader - 总结及参考"
author: "颇忒脱"
tags: ["JVM", "ClassLoader", "ARTS", "ARTS-T"]
date: 2019-01-26T13:59:55+08:00
---

<!--more-->

## 思维导图

![](../classloader.png)

## 参考资料

* [极客时间 - 深入拆解Java虚拟机 - 03 - Java虚拟机是如何加载Java类的?][geektime]
* [Java Language Specification - Chapter 12. Execution][jls-execution]
* [Java Virtual Machine Specification - Chapter 4. The `class` File Format][jvms-class-format]
* [Java Virtual Machine Specification - Chapter 5. Loading, Linking, and Initializing][jvms-loading-linking-initializing]

[geektime]: https://time.geekbang.org/column/article/11523
[jls-execution]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-12.html
[jvms-loading-linking-initializing]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html
[jvms-class-format]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html