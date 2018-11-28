---
title: "收藏夹 - 系统架构（持续更新）"
author: "颇忒脱"
tags: ["收藏夹"]
date: 2018-11-15T15:21:38+08:00
draft: false
---

<!--more-->

# Monitoring

* [Metrics, tracing, and logging](https://peter.bourgon.org/blog/2017/02/21/metrics-tracing-and-logging.html)
Metrics、tracing、logging三个监控系统的区别和联系
* [Observability 3 ways: logging metrics and tracing](https://speakerdeck.com/adriancole/observability-3-ways-logging-metrics-and-tracing)
同上，Slides。
* ["How NOT to Measure Latency" by Gil Tene](https://www.youtube.com/watch?v=lJ8ydIuPFeU) 如何正确解读监控/压力测试结果


## Prometheus

* [Counting with Prometheus [I] - Brian Brazil, Robust Perception](https://www.youtube.com/watch?v=67Ulrq6DxwA) 
* [rate()/increase() extrapolation considered harmful](https://github.com/prometheus/prometheus/issues/3746) 关于rate()/increase()函数extrapolation算法的讨论

## Log

* [The Log: What every software engineer should know about real-time data's unifying abstraction](https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying)
讲了Log/Event/Stream与Table是同一件事情的两个面，为流处理应用，分布式存储系统的建设提供了高屋建瓴的指导。

# 分布式架构

* 分布式系统
* [左耳听风 | 分布式系统架构的冰与火](https://time.geekbang.org/column/article/1411)
* [左耳听风 | 从亚马逊的实践，谈分布式系统的难点](https://time.geekbang.org/column/article/1505)
* [左耳听风 | 分布式系统的技术栈](https://time.geekbang.org/column/article/1512)
* [左耳听风 | 分布式系统关键技术：全栈监控](https://time.geekbang.org/column/article/1513)
* [左耳听风 | 分布式系统关键技术：服务调度](https://time.geekbang.org/column/article/1604)
* [左耳听风 | 分布式系统关键技术：流量与数据调度](https://time.geekbang.org/column/article/1609)
* [左耳听风 | 分布式系统：洞悉PaaS平台的本质](https://time.geekbang.org/column/article/1610)
* 弹力设计
* [左耳听风 | 弹力设计篇之“认识故障和弹力设计”](https://time.geekbang.org/column/article/3912)
* [左耳听风 | 弹力设计篇之“隔离设计”](https://time.geekbang.org/column/article/3917)
* [左耳听风 | 弹力设计篇之“异步通讯设计”](https://time.geekbang.org/column/article/3926)
* [左耳听风 | 弹力设计篇之“幂等性设计”](https://time.geekbang.org/column/article/4050)
* [左耳听风 | 弹力设计篇之“服务的状态”](https://time.geekbang.org/column/article/4086)
* [左耳听风 | 弹力设计篇之“补偿事务”](https://time.geekbang.org/column/article/4087)
* [左耳听风 | 弹力设计篇之“重试设计”](https://time.geekbang.org/column/article/4121)
* [左耳听风 | 弹力设计篇之“熔断设计”](https://time.geekbang.org/column/article/4241)
* [左耳听风 | 弹力设计篇之“限流设计”](https://time.geekbang.org/column/article/4245)
* [左耳听风 | 弹力设计篇之“降级设计”](https://time.geekbang.org/column/article/4252)
* [左耳听风 | 弹力设计篇之“弹力设计总结”](https://time.geekbang.org/column/article/4253)
* 管理设计
* [左耳听风 | 管理设计篇之"分布式锁"](https://time.geekbang.org/column/article/5175)
* [左耳听风 | 管理设计篇之"配置中心"](https://time.geekbang.org/column/article/5819)
* [左耳听风 | 管理设计篇之"边车模式"](https://time.geekbang.org/column/article/5909)
* [左耳听风 | 管理设计篇之"服务网格"](https://time.geekbang.org/column/article/5920)
* [左耳听风 | 管理设计篇之"网关模式"](https://time.geekbang.org/column/article/6086)
* [左耳听风 | 管理设计篇之"部署升级策略"](https://time.geekbang.org/column/article/6283)
* 性能设计
* [左耳听风 | 性能设计篇之"缓存"](https://time.geekbang.org/column/article/6282)
* [左耳听风 | 性能设计篇之"异步处理"](https://time.geekbang.org/column/article/7036)
* [左耳听风 | 性能设计篇之"数据库扩展"](https://time.geekbang.org/column/article/7045)
* [左耳听风 | 性能设计篇之"秒杀"](https://time.geekbang.org/column/article/7047)
* [左耳听风 | 性能设计篇之"边缘计算"](https://time.geekbang.org/column/article/7086)
