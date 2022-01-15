---
title: "JVM - GC日志参数"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "jvm", "gc"]
date: 2022-01-15T18:18:08+08:00
---

介绍怎么开启GC日志采集。

<!--more-->

## Java <= 8

```bash
-XX:+PrintGC
-XX:+PrintGCTimeStamps
-XX:+PrintGCDetails
-Xloggc:/path/to/gc.log
-XX:+UseGCLogFileRotation
-XX:NumberOfGCLogFiles=5
```

前4个参数文档在[Java 8文档][1]，后两个参数的文档只能在[Java 7文档][2]看到，不过Java 8也能用。

如果你不想要日志滚动，可以这样：

```bash
-XX:+PrintGC
-XX:+PrintGCTimeStamps
-XX:+PrintGCDetails
-Xloggc:/path/to/gc-%t.log
```

形成的文件会是`YYYY-MM-DD_HH-MM-SS`（程序启动的时间）这个形式（[见这篇Blog][4]）。

## Java >= 9

Java 9开始，使用[Xlog（文档）][3]统一了所有日志的输出，所以参数要变化：

```bash
-Xlog:gc*:file=/path/to/gc.log:time,level,tags:filecount=5,filesize=5M
```

如果你不想要日志滚动，可以这样：

```bash
-Xlog:gc*:file=/path/to/gc-%t.log:time,level,tags:filecount=0
```

[1]: https://docs.oracle.com/javase/8/docs/technotes/tools/unix/java.html
[2]: https://www.oracle.com/java/technologies/javase/vmoptions-jsp.html
[3]: https://docs.oracle.com/javase/9/tools/java.htm#JSWOR-GUID-BE93ABDC-999C-4CB5-A88B-1994AAAC74D5
[4]: https://blog.gceasy.io/2019/01/29/try-to-avoid-xxusegclogfilerotation/