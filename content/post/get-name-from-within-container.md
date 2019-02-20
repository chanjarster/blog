---
title: "Docker容器如何获得自己的名字"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "docker"]
date: 2019-02-20T10:38:28+08:00
draft: true
---

<!--more-->

本文介绍的方法是通过环境变量把容器自己的名字传递进去，仅支持以下两种部署方式：

* `docker service create`
* `docker stack deploy`

## `docker service create`

`docker service create -e MY_NAME="{{.Task.Name}}" -d --name abc tomcat:8.5-alpine`

这样容器里的`MY_NAME`环境变量就是容器自己的名字，比如：`abc.1.rik8xgc0b9i2r7odnm6vnhnqg`

## `docker stack deploy`

docker-compose file:

```yaml
version: '3.7'
services:
  webapp:
    image: tomcat:8.5-alpine
    environment:
      MY_NAME: "{{.Task.Name}}"
```

同样地将容器名传到环境变量`MY_NAME`里。

## 参考资料


* [Docker logging best practice][docker-tomcat-logging]，在这个文章里提到了可以用`{{.Task.Name}}`做template expansion来设置变量。
* 上述两种方式都用到了go template，[Format command and log output][docker-format] 列举了几种template expansion的使用方式。
* [Inject chosen container name in container][gh-issue]，这个issue提出要能够在容器内获得自己的名字，但是此issue没有被解决，依然在讨论中。


[docker-tomcat-logging]: https://success.docker.com/article/logging-best-practices#modernizetraditionalapplications
[gh-issue]: https://github.com/docker/compose/issues/1503
[docker-format]: https://docs.docker.com/config/formatting/