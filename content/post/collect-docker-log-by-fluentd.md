---
title: "使用Fluentd收集Docker容器日志"
author: "颇忒脱"
tags: ["docker", "运维", "fluentd"]
date: 2019-01-24T11:32:32+08:00
---

本文介绍使用Fluentd收集standalone容器日志的方法。

<!--more-->

Docker提供了很多[logging driver][config-logging-driver]，默认情况下使用的[json-file][json-file]，它会把容器打到stdout/stderr的日志收集起来存到json文件中，`docker logs`所看到的日志就是来自于这些json文件。

当有多个docker host的时候你会希望能够把日志汇集起来，集中存放到一处，本文讲的是如何通过[fluentd logging driver][logging-fluentd]配合[fluentd][fluentd]来达成这一目标。

目标：

1. 将standalone容器打到stdout/stderror的日志收集起来
2. 收集的日志根据容器名分开存储
3. 日志文件根据每天滚动

## 第一步：配置Fluentd实例

首先是配置文件`fluent.conf`：

```txt
<source>
  @type   forward
</source>

# 处理docker service容器的日志
# input 
#   tag: busybox.2.sphii6yg9rw045kqi4kh6owxv
# output
#   file: busybox/inst-2.yyyy-MM-dd.log
<match *.*.*>
  @type              file
  path               /fluentd/log/${tag[0]}/inst-${tag[1]}
  append             true
  <format>
    @type            single_value
    message_key      log
  </format>
  <buffer tag,time>
    @type             file
    timekey           1d
    timekey_wait      10m
    flush_mode        interval
    flush_interval    30s
  </buffer>
</match>

# 处理standalone容器的日志
# input 
#   tag: busybox
# output
#   file: busybox/busybox.yyyy-MM-dd.log
<match *>
  @type              file
  path               /fluentd/log/${tag}/${tag}
  append             true
  <format>
    @type            single_value
    message_key      log
  </format>
  <buffer tag,time>
    @type             file
    timekey           1d
    timekey_wait      10m
    flush_mode        interval
    flush_interval    30s
  </buffer>
</match>
```

新建一个目录比如`/home/ubuntu/container-logs`，并赋予权限`chmod 777 /home/ubuntu/container-logs`。

然后启动Fluentd实例，这里使用的Docker方式：

```bash
docker run -it \
  -d \
  -p 24224:24224 \
  -v /path/to/conf/fluent.conf:/fluentd/etc/fluent.conf \
  -v /home/ubuntu/container-logs:/fluentd/log
  fluent/fluentd:v1.3
```

## 第二步：指定容器的logging driver

在启动容器的时候执行使用fluentd作为logging driver，下面以standalone容器举例：

```bash
docker run -d \
  ...
  --log-driver=fluentd \
  --log-opt fluentd-address=<fluentdhost>:24224 \
  --log-opt mode=non-blocking \
  --log-opt tag={{.Name}} \
  <image>
```

注意上面的`--log-opt tag={{.Name}}`参数。

如果是docker compose / docker stack deploy部署，则在`docker-compose.yaml`中这样做 ：

```yaml
version: "3.7"
x-logging:
  &default-logging
  driver: fluentd
  options:
    fluentd-address: <fluentdhost>:24224
    fluentd-async-connect: 'true'
    mode: non-blocking
    max-buffer-size: 4m
    tag: "{{.Name}}"
services:
  busybox:
    image: busybox
    logging: *default-logging
```

## 第三步：观察日志

到`/home/ubuntu/container-logs`目录下能够看到类似这样的目录结构：

```txt
.
└── <container-name>
    └── <container-name>.20190123.log
```
 
## 参考文档

* [Configure logging drivers][config-logging-driver]
* [Customize log driver output][customize-logger]
* [Use Fluentd logging driver][logging-fluentd]
* [Docker CLI - run][docker-cli-run]
* [Fluentd][fluentd]
  * [Fluentd - out_file][fluentd-out_file]
  * [Fluentd - formatter_single_value][fluentd-formatter_single_value]
  * [Fluentd - buf_file][fluentd-buf_file]
  * [Fluentd - buffer][fluentd-buffer]

[fluentd]: https://docs.fluentd.org/v1.0/articles/quickstart
[logging-fluentd]: https://docs.docker.com/config/containers/logging/fluentd/
[customize-logger]: https://docs.docker.com/config/containers/logging/log_tags/
[config-logging-driver]: https://docs.docker.com/config/containers/logging/configure/
[json-file]: https://docs.docker.com/config/containers/logging/json-file/
[fluentd-out_file]: https://docs.fluentd.org/v1.0/articles/out_file
[fluentd-formatter_single_value]: https://docs.fluentd.org/v1.0/articles/formatter_single_value
[fluentd-buf_file]: https://docs.fluentd.org/v1.0/articles/buf_file
[fluentd-buffer]: https://docs.fluentd.org/v1.0/articles/buffer-section
[docker-cli-run]: https://docs.docker.com/engine/reference/commandline/run/