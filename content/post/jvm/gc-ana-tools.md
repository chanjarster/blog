---
title: "JVM - GC分析工具"
author: "颇忒脱"
tags: ["jvm", "高并发", "cheatsheet", "debug"]
date: 2022-10-05T18:02:16+08:00
---

<!--more-->

## gceasy.io

https://gceasy.io 是一个在线分析GC日志的工具。把得到的gc.log日志。

## GCViewer

[GCViewer](https://sourceforge.net/projects/gcviewer/) 是另一个本地分析 GC 日志的工具。

## 查看 heap 情况

```shell
jmap -heap <pid>
```

## heap dump分析

利用下面命令得到heap dump，然后放到 MAT 中分析

```shell
jmap -dump:live,format=b,file=heap.bin <pid>
```

有些时候你需要把垃圾一起dump下来，比如GC很频繁，那么去掉live参数：

```shell
jmap -dump:format=b,file=heap.bin <pid>
```

