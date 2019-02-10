---
title: "From Microliths to Microsystems"
author: "颇忒脱"
tags: ["ARTS", "ARTS-R", "微服务"]
date: 2019-02-10T18:24:55+08:00
---

<!--more-->

[原文地址][origin] | [Presentation][origin-prensentation] | [Slides][origin-slides]

关键词：微服务、event-first DDD、Reactive

## 大纲

* 避免构建mini-moniliths，即microliths。
* 构建resilient和elastic的系统。
* 最小化系统内部的耦合度，最小化系统内部的通信。
* 使用reactive programming，reactive system design，eventual consistency。
* 把无状态行为从有状态实体分离出来，更容易扩展性。
* 实践event-first DDD。

> **Each** microservice needs to be designed as a distributed system: a microsystem. We need to move from microliths to microsystems.

microliths既非resilient也不elastic。根据[The Reactive Manifesto][reactive-manifesto]，要达成resilient和elastic需要：

* Decentralised architecture
* Bulkheading
* Replication
* Failure detection
* Supervision
* Gossip protocols
* Self-organisation
* Location transparency

一切信息都有延迟，我们总是通过分布式系统通信来窥视过去发生的事情。开发者应尽量减少耦合与通信，并拥抱最终一致性。

作者推荐了两个设计微服务系统的工具：

**工具一：Reactive desgin**

* Reactive programming，比如RxJava，可以帮助让单个服务实例高性能以及高效。
* 基于异步消息的Reactive系统可以帮助构建elastic and resilient的分布式系统。
* 实现异步和非阻塞微服务可以更有效的利用资源，降低共享资源的争用。
* 总是使用[back-pressure][back-pressure]，一个快速系统不应该是慢速系统过载。

**工具二：Event-first [DDD][ddd-quickly]**

* 每一个微服务应该被设计成为一个微系统，无状态行为要从有状态实体中剥离出来，使得独立服务能够具有扩展性。
* 实体可以称为确定性和一致性的安全岛，但是扩展无状态行为易，扩展有状态实体难。
* 开发者应该实践event-first DDD，从一致性边界的角度思考[data on the inside][data-on-the-outside-versus-data-on-the-inside]代表现在，data from the outside代表过去，而command则代表未来的动作。

> Don't focus on the things - the nouns. Focus on what happens - the events! Let the events define the bounded context.

一个微服务应该包含一切可变状态并发布事实，所谓事实就是event。event log应该是一个“代表过去的数据库”，[single immutable source of truth][single-truth]。event logging可以避免臭名昭著的[object-relational impedance mismatch][orm-mismatch]，读写问题可以通过[CQRS][cqrs]与[Event sourcing][event-sourcing]解开。开发者不应该基于[assuming distributed transactions][assuming]来构建大型可扩展应用，而应该使用“guess, apoligize, compensate”（和TCC、Saga类似）协议。

## 延伸阅读

* [Youtube - From Microliths to Microsystems][origin-prensentation]
* [The Reactive Manifesto][reactive-manifesto]
* [Data on the Outside versus Data on the Inside][data-on-the-outside-versus-data-on-the-inside]
* [Immutability Changes Everything][single-truth]
* [Life Beyond Distributed Transactions][assuming]
* [CQRS][cqrs]
* [Event sourcing][event-sourcing]

[origin]: https://www.infoq.com/news/2017/03/microliths-microsystems
[origin-prensentation]: https://www.youtube.com/watch?v=NotiE8Mm8F4
[origin-slides]: https://www.slideshare.net/jboner/from-microliths-to-microsystems
[reactive-manifesto]: http://www.reactivemanifesto.org/
[ddd-quickly]: https://www.infoq.com/minibooks/domain-driven-design-quickly
[back-pressure]: http://www.reactivemanifesto.org/glossary#Back-Pressure
[data-on-the-outside-versus-data-on-the-inside]: https://blog.acolyer.org/2016/09/13/data-on-the-outside-versus-data-on-the-inside/
[single-truth]: https://queue.acm.org/detail.cfm?id=2884038
[orm-mismatch]: https://en.wikipedia.org/wiki/Object-relational_impedance_mismatch
[cqrs]: https://martinfowler.com/bliki/CQRS.html
[event-sourcing]: https://martinfowler.com/eaaDev/EventSourcing.html
[assuming]: http://queue.acm.org/detail.cfm?id=3025012
