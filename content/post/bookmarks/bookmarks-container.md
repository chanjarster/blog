---
title: "收藏夹 - 容器技术（持续更新）"
author: "颇忒脱"
tags: ["收藏夹"]
date: 2018-11-15T15:21:38+08:00
---

<!--more-->
# Docker

* [Docker architecture][docker-1]，Container不是运行在Docker之上的
* [Linux Container Internals 2.0 - Lab 1: Introduction to Containers][docker-2]，Container is just a fancy process
* [Limit a container's resources][docker-3]，如何控制container的内存、CPU使用上限

Java in container

* [Java SE support for Docker CPU and memory limits][docker-4]，Java SE 8u131之后能感知容器内存使用上限
* [Java inside docker: What you must know to not FAIL][docker-5]，为何我的Java程序container OOMKilled
* [OpenJDK and Containers][docker-6]，补充OpenJDK运行在container的注意事项

# K8S

* [华为K8S视频培训（免费）][k8s-1]
  * [CKA考纲与K8S基础概念解读][k8s-2]
  * [K8S调度管理实训][k8s-3]
  * [K8S日志、监控与应用管理实训][k8s-4]
  * [K8S网络管理实训][k8s-5]
  * [K8S存储管理实训][k8s-6]
  * [K8S安全管理实训][k8s-7]
  * [K8S集群运维与安装配置实训][k8s-8]
  * [K8S问题排查实训][k8s-9]

# Rancher

* [Rancher 2.1培训][rancher-1]
  * [Kubernetes集群管理的轻松之道（上）][rancher-2-1], [Q&A][rancher-2-2]
  * [Kubernetes集群管理的轻松之道（下）][rancher-3-1], [Q&A][rancher-3-2]
  * [基于Kubernetes的CI/CD流水线构建][rancher-4-1], [Q&A][rancher-4-2]
  * [Kubernetes应用管理][rancher-5-1], [Q&A][rancher-5-2]
  * [Rancher 2.1新功能演示分享][rancher-6-1], [Q&A][rancher-6-2]
  * [PPT资料链接][rancher-7] 提取码：aqrf

[docker-1]: https://docs.docker.com/engine/docker-overview/#docker-architecture
[docker-2]: https://learn.openshift.com/subsystems/container-internals-lab-2-0-part-1
[docker-3]: https://docs.docker.com/config/containers/resource_constraints/#memory

[docker-4]: https://blogs.oracle.com/java-platform-group/java-se-support-for-docker-cpu-and-memory-limits
[docker-5]: https://developers.redhat.com/blog/2017/03/14/java-inside-docker/
[docker-6]: https://developers.redhat.com/blog/2017/04/04/openjdk-and-containers/


[k8s-1]: https://bbs.huaweicloud.com/forum/thread-11064-1-1.html
[k8s-2]: http://zhibo.huaweicloud.com/watch/2378525
[k8s-3]: https://zhibo.huaweicloud.com/watch/2416214
[k8s-4]: https://zhibo.huaweicloud.com/watch/2425190
[k8s-5]: https://zhibo.huaweicloud.com/watch/2461774
[k8s-6]: http://zhibo.huaweicloud.com/watch/2485659
[k8s-7]: http://zhibo.huaweicloud.com/watch/2502438
[k8s-8]: http://zhibo.huaweicloud.com/watch/2527955
[k8s-9]: http://zhibo.huaweicloud.com/watch/2545023

[rancher-1]: https://mp.weixin.qq.com/s/CBQoVN4WVA-UBqHU_RsHNw
[rancher-2-1]: http://live.vhall.com/375439580
[rancher-2-2]: https://shimo.im/docs/LXVaR64WVDwRfcAA/
[rancher-3-1]: http://live.vhall.com/951094496
[rancher-3-2]: https://shimo.im/docs/zcmFxo93JtUoGuSd/
[rancher-4-1]: http://live.vhall.com/312352038
[rancher-4-2]: https://shimo.im/docs/x7nxSHVi5Hc3c3lV/
[rancher-5-1]: http://live.vhall.com/940973786
[rancher-5-2]: https://shimo.im/docs/7pxWUZfcm3EDL3N7/
[rancher-6-1]: http://live.vhall.com/881351242
[rancher-6-2]: https://shimo.im/docs/oBHLuyh16CUznar6/ 
[rancher-7]: https://pan.baidu.com/s/15otnAU1LEXP8D2Au-Bfpvw