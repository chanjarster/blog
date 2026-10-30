---
title: "JVM - 线程分析工具"
author: "颇忒脱"
tags: ["jvm", "高并发", "cheatsheet", "debug"]
date: 2022-11-05T18:02:16+08:00
---

<!--more-->


## jstack 

利用 jstack 得到 thread dump：

```shell
jstack <pid>
```

## Spring Boot Actuator

Spring Boot Actuator 有 [Threaddump endpoint][1]，你可以通过它得到 JSON 格式的 Threaddump。

## fastthread.io

jstack 和 Spring Boot Actuator 得到的 thread dump 都可以给到 https://fastthread.io/ 分析。

[1]: https://docs.spring.io/spring-boot/docs/2.3.5.RELEASE/actuator-api/html/#threaddump