---
title: "收藏夹 - 监控（持续更新）"
author: "颇忒脱"
tags: ["收藏夹"]
date: 2018-12-03T13:14:38+08:00
---

<!--more-->

# Monitoring

* [Metrics, tracing, and logging][m-1]，Metrics、tracing、logging三个监控系统的区别和联系
* [Observability 3 ways: logging metrics and tracing][m-2]，上篇文章的Slides。


## Performance benchmark

* ["How NOT to Measure Latency" by Gil Tene][p-1]，如何正确解读监控/压力测试结果

## Metrics

### Prometheus

基本概念：

* [How does a Prometheus Counter work?][p8s-1]，对于理解rate()函数至关重要
* [Counting with Prometheus [I]][p8s-2] ，上篇博客的关联Presentation
* [rate()/increase() extrapolation considered harmful][p8s-3] 关于rate()函数extrapolation（外推）算法的讨论
* [How does a Prometheus Gauge work?][p8s-4]，gauge类型的分析
* [irate graphs are better graphs][p8s-5]，irate提供了更即时的结果
* [Avoid irate() in alerts][p8s-6]
* [Rate then sum, never sum then rate][p8s-7]，rate在前sum在后
* [Why are Prometheus histograms cumulative?][p8s-8]，histogram类型的分析

几个使用技巧：

* [Existential issues with metrics][p8s-9]，使用metrics-based monitoring system的的注意事项
* [Common query patterns in PromQL][p8s-10]，几个常见的PromQL语句
* [Composing range vector functions in PromQL][p8s-11]，如何实现诸如这样的查询：最近1小时内，rate(x[5m])的最高值

运维技巧：

* [Scaling and Federating Prometheus][p8s-12]
* [Dropping metrics at scrape time with Prometheus][p8s-13]

### Machine metrics

* [Understanding Machine CPU usage][mm-1]，虽然是P8S的一篇博客，但是对于理解常见的几个CPU指标还是有用的


## Tracing

TODO 

## Logging

TODO

[m-1]: https://peter.bourgon.org/blog/2017/02/21/metrics-tracing-and-logging.html
[m-2]: https://speakerdeck.com/adriancole/observability-3-ways-logging-metrics-and-tracing

[p-1]: https://www.youtube.com/watch?v=lJ8ydIuPFeU

[p8s-1]: https://www.robustperception.io/how-does-a-prometheus-counter-work
[p8s-2]: https://www.youtube.com/watch?v=67Ulrq6DxwA
[p8s-3]: https://github.com/prometheus/prometheus/issues/3746
[p8s-4]: https://www.robustperception.io/how-does-a-prometheus-gauge-work
[p8s-5]: https://www.robustperception.io/irate-graphs-are-better-graphs
[p8s-6]: https://www.robustperception.io/avoid-irate-in-alerts
[p8s-7]: https://www.robustperception.io/rate-then-sum-never-sum-then-rate
[p8s-8]: https://www.robustperception.io/why-are-prometheus-histograms-cumulative
[p8s-9]: https://www.robustperception.io/existential-issues-with-metrics
[p8s-10]: https://www.robustperception.io/common-query-patterns-in-promql
[p8s-11]: https://www.robustperception.io/composing-range-vector-functions-in-promql
[p8s-12]: https://www.robustperception.io/scaling-and-federating-prometheus
[p8s-13]: https://www.robustperception.io/dropping-metrics-at-scrape-time-with-prometheus

[mm-1]: https://www.robustperception.io/understanding-machine-cpu-usage