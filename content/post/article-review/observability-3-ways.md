---
title: "Logging, Metrics & Tracing"
author: "颇忒脱"
tags: ["ARTS-R", "日志", "监控", "调用链追踪"]
date: 2019-02-21T20:10:27+08:00
---

<!--more-->

原文：

* [Observability 3 ways: Logging, Metrics & Tracing][a-1]
* [Logging vs Tracing vs Monitoring][a-2]
* [Metrics, tracing, and logging][a-3]
* [Logging,Metrics 和 Tracing][a-4]

所谓“日志”分为三种：

* logging，通常意义上的日志，比如程序打印到文件或stdout的字符串行。记录了程序运行过程中发生的事件。
* metrics，应用程序运行指标，用于测量程序的运行情况。
* tracing，在微服务架构中应用程序/组件之间的调用链。

以error为例：

* logging 可以告诉你error合适发生，以及细节信息
* metrics 可以告诉你error发生了多少次
* tracing 可以告诉你这个error的影响面有多大

三者提供的数据不同：

* logging可以 1）提供事件细节；2）部分日志可以被聚合
* metrics可以 1）提供数字，可被聚合；2）告诉数据趋势
* tracing可以 1）提供调用span；2）提供部分事件的部分细节

三者存储的也不同：

* logging，时间戳 + 格式良好的非结构化文本/结构化日志（json）
* metrics，时间戳 + 数字
* tracing，时间戳 + span 

三者都是对事件的不同角度的描述，三者互补形成完整的监控系统。

[a-1]: https://www.dotconferences.com/2017/04/adrian-cole-observability-3-ways-logging-metrics-tracing
[a-2]: https://winderresearch.com/logging-vs-tracing-vs-monitoring/
[a-3]: https://peter.bourgon.org/blog/2017/02/21/metrics-tracing-and-logging.html
[a-4]: https://zhuanlan.zhihu.com/p/28075841