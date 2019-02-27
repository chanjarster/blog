---
title: "稳定与非稳定版本软件的Docker Image构建策略"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "docker", "CI_CD"]
date: 2019-02-27T09:11:04+08:00
---

<!--more-->

## Image tag是不稳定的

Docker image的tag是不稳定的，这句话的意思是**就算tag不变，其所代表的image并非一成不变**，例如`openjdk:8`在去年代表jdk 8u161今年则代表jdk 8u191。就算你使用`openjdk:8u181`也不能保证这个image是不变的，为什么这么说？

一个Docker image大致是由4部分组成的：

1. 其依赖的基础镜像，由Dockerfile的`FROM`指令所指定
1. 其所包含的软件，在这个例子里就是 openjdk 8u181
1. Dockerfile的其他脚本
1. 启动入口，比如`docker-entrypoint.sh`

就算软件不发生变化，另外3个也是有可能发生变化的，而构建的新image的tag依然是`openjdk:8u181`。而且要注意到一般采用的是软件的版本号作为tag，而不是commit、构建日期作为tag。如果你是Java程序员，可以类比docker image tag为maven的[SNAPSHOT][maven-version]。

那这意味着什么？

* 从docker image使用方角度，每次启动之前都需要pull一下，确保使用了新的image
* 从docker image提供方角度，就算你的软件版本已经冻结，你仍然需要定期构建image并发布仓库上

## 针对稳定与非稳定版本的构建策略

和Maven的版本定义一样，你的软件应该分为两种：

* stable版，即一旦发布其版本号对应的代码不会再做修改
* snapshot版，又称nightly-build版，即该版本号对应的代码是不稳定的

对于stable版，你应该定期对其构建image。比如你有版本1.0、1.1、1.2，那你应该定期从软件仓库中下载这三个版本的构建物，然后对为它们构建image。以Maven举例，定期从Maven仓库下载它们的Jar，然后为它们构建image。记得确保`docker build`添加了`--pull`选项。

对于snapshot版，你应该将构建image的过程融入到软件的构建过程中。以Maven为例，使用[spotify-dockerfile-plugin][spotify-dockerfile-plugin]，`mvn clean install dockerfile:build dockerfile:push`。

不论是stable版还是snapshot版，都应该利用CI/CD工具（如Jenkins）将image构建工作自动化。

[maven-version]: https://maven.apache.org/guides/getting-started/index.html#What_is_a_SNAPSHOT_version
[gitflow]: https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow
[spotify-dockerfile-plugin]: https://github.com/spotify/dockerfile-maven