---
title: "把日志打印到控制台会很慢吗？"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "linux"]
date: 2019-02-17T10:03:48+08:00
draft: true
---

<!--more-->

在[容器打印日志到控制台阻塞的排障][docker-console-logging-hangs]的时候看到一个观点：

> 把日志打印到控制台要比打印到文件慢，而且是非常慢。

log4j2和logback的两个issue官方也提到了这一点，TODO。

Google了很多文章也提到了这一点，TODO。

SO的[Why is printing to stdout so slow? Can it be sped up?][so-3857052]也探讨了这个问题，这里有两个回答比较引人注意：

* 一个回答是[打印到stdout就是慢，而且没法进一步提升][so-answer-1]。
* 一个回答是[打印到stdout慢是因为终端的关系，换一个快速的终端就能提升][so-answer-2]。

我倾向于第二个回答。

linux的stdout的实现到底是如何的？TODO

[docker-console-logging-hangs]: ../docker-console-logging-hangs
[so-3857052]: https://stackoverflow.com/questions/3857052/why-is-printing-to-stdout-so-slow-can-it-be-sped-up
[so-answer-1]: https://stackoverflow.com/a/3857543/1287790
[so-answer-2]: https://stackoverflow.com/a/3860319/1287790