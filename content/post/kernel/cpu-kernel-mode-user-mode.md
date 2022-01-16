---
title: "操作系统Kernel mode和User mode"
author: "颇忒脱"
tags: ["ARTS-T", "kernel"]
date: 2019-02-27T21:11:56+08:00
---

<!--more-->

## CPU modes

又称process modes, CPU states, CPU privilege levels，CPU modes是为了能够让某些计算机架构的CPU限制正在被CPU运行的进程所能执行的操作的类型和范围。得益于它操作系统才能够以比应用程序更高的privilege（特权）来运行。

CPU modes分为两类：

* kernel mode，不受任何限制的做任何事情
* user modes，受限模式，注意user modes可以有多个模式

## Protection ring

Protection ring又称hierarchical protection domains，是一种保护数据和功能免于遭受错误和恶意行为的机制。

一个Protection ring由一个或多个分级式levels or layers of privilege组成。
通常来说protection ring是硬件强制的，是由一些CPU架构在硬件或微代码层面提供不同的CPU modes来达成的。Protection ring本身也是层级的，由最具特权开始（编号0）到具有最少特权的（编号更大）。在大多数操作系统中，Ring 0是最具特权的，能够直接物理硬件（如CPU、内存）交互。

x86架构的protection ring：Ring 0（kernel）、Ring 1-2（Device drivers）、Ring 3（Applications）。下图：

![](https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Priv_rings.svg/320px-Priv_rings.svg.png)

各个CPU的架构提供的ring数不同，有的多达8个。操作系统为了适配更多的CPU架构，不会使用所有的ring，即使硬件支持更多的CPU modes。比如Windows Server 2008系统只用了Ring 0和Ring 3。

当处理器在某个ring发生错误时，会影响到所有低权限ring。所以当错误发生在ring 0时，整个系统都会崩溃。

## System call（系统调用）

Linux、macOS、Windows之类的单体内核（monolithic kernel）操作系统，操作系统运行在kernel mode（supervisor mode），应用程序运行在user mode。

运行在user mode的代码必须使用system call才能够使用到操作系统内核kernel所提供的服务。

因为针对不同CPU架构，system call的汇编码是不同的，因此操作系统会提供库（如glibc）将system call包一层，方便应用程序使用。System call发生时会将控制权交给kernel，调用结束时则将控制权交还给user mode的进程。

System call一般不要求context switch，因为system call发生在同一进程里。

## 参考资料

* [CPU modes][cpu-modes]
* [Protection rings][protection-rings]
* [System call][system-call]

[cpu-modes]: https://en.wikipedia.org/wiki/CPU_modes
[protection-rings]: https://en.wikipedia.org/wiki/Protection_ring
[system-call]: https://en.wikipedia.org/wiki/System_call
[call-gates]: https://en.wikipedia.org/wiki/Call_gate_(Intel)
