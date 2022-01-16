---
title: "Stateful Service Design Consideration for the Kubernetes Stack"
author: "颇忒脱"
tags: ["Akka", "微服务", "k8s"]
date: 2019-01-30T20:43:08+08:00
---

<!--more-->

[原文地址][origin]

关键词：微服务、Cloud-native stateful service、Akka

## 大纲

Stateful service不可避免：

1. stateless service在k8s上部署已经被证明是成功的。
1. 将state从stateful service中剥离出来，使其成为stateless service是一种成功的做法。
1. 但是这些stateless service依然大多依赖于，老的架构、设计、习惯、模式、实践和工具，而这些东西都是为运行“全能”的RDBMS之上的单体单节点系统所发展出来的。
1. 当前的service越来越data-centric和data-driven，将service和data紧密贴合显得更为重要，因为这样做能够高效率、高性能，可靠的管理、处理、转换、丰富data。
1. service无法承受在data访问时与数据库 or 存储的round-trip，并需要持续处理接近实时的data，从永无止境的数据流中挖掘知识。而这份data在被存储之前，也时常需要被分布式地处理——以实现可扩展性、低延迟、高吞吐。

实施stateful service的难点：

1. stateful 实例不是能够简单替换的，因为它有自己的状态，在替换的时候要考虑进去。
2. 部署stateful 副本必须要求副本之间协作，比如启动依赖顺序、版本升级、schema变动等。
3. replication需要时间，一个正在处理replication的机器会获得比平时更高的负载。如果开启一个新副本，有可能会down掉整个数据库or服务。

k8s对于stateful service的方案：

1. k8s对于不是cloud-native stateful service的方案是StatefulSet
1. 每个pod有一个稳定的标识符（namespace + name）以及一个专用的即使Pod重启也不会丢失的磁盘，甚至Pod重新调度到另一台机器上也不会丢失。
1. 开发人员需要新一代的能够构建**cloud-native的stateful service**工具，而这些service只需要k8s为stateless service提供的基础设施。

设计cloud-native stateful service的难点：

1. 难点不在于设计和实现这些service，而是管理它们之间的空间。难点有：数据一致性保证、可靠通信、数据复制与故障转移、组件失败侦测、恢复、分片、路由、共识算法等等。
2. 对于不同的service来说End-to-end的正确性、一致性、安全性是不同的，是完全依赖于用例的，是不能外包给基础设施的。我们需要一种编程模型，配合一个把重活都包了的运行时，让我们专注于实现业务价值，而不是陷入错综复杂的网络编程与failure mode里。**Akka与K8S就是上述问题的解决方案**

[Akka][akka]简介：

1. 基于[Reactive Manifesto][reactivemanifesto]构建，是面向today和tomorrow的架构。
2. Akka的unit of work和state被称为actor，是stateful、fault-tolerant、isolated、autonomous的component or entity。
3. actor/entity是非常轻量级的，在一台机器上可以轻易运行百万个，并且它们之间使用异步通信。它们内置自动自我恢复机制，同时distributable and location transparent by default。也就意味着它们**可以根据需要在集群里扩展、复制、移动，而这对于actor/entity的用户来说是透明的**。
4. Akka和K8S的配合方式：K8S负责容器，粗粒度，负责资源。Akka负责应用层，细粒度，负责如何在给定资源下分发工作。

Akka的“let it crash”哲学：

1. 传统基于线程的编程模型只给了你对于单个线程的控制，如果线程异常崩溃你就麻烦了，所以你需要显式地在这个线程内部做异常处理。异常不会在线程间传播，不会跨网络，没有办法在外部知道这个线程已经失败了。但是丢失这个线程又是代价极高的，最坏情况下，如果用了同步协议，会将这个错误波及到整个应用。
2. Akk把你的应用设计为“supervisor hierarchies”，actor们彼此注意健康、彼此管理失败。如果一个actor失败了，它的错误会被隔离并被包起来，以异步消息的方式发送到它的supervising actor（可能通过网络）。supervising actor能够在安全健康的上下文中处理异常，并且根据声明式定义规则自动重启失败的actor。
3. 和K8S有点像，不过是在application stack层面。


## 延伸阅读

* [microliths][microliths]
* [Designing Events-First Microservices][boner-events-first-microservices]

[origin]: https://www.infoq.com/articles/stateful-service-design-kubernetes
[akka]: https://akka.io/
[reactivemanifesto]: https://www.reactivemanifesto.org/
[boner-events-first-microservices]: https://www.infoq.com/news/2018/07/boner-events-first-microservices
[microliths]: https://www.infoq.com/news/2017/03/microliths-microsystems