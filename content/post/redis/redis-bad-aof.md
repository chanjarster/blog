---
title: "K8S中Redis损坏的AOF文件排查"
author: "颇忒脱"
tags: ["redis", "k8s", "troubleshooting"]
date: 2021-09-07T10:25:23+08:00
---

<!--more-->

## 现象

redis-server Pod启动不起来。

观察Pod日志，看到：

```bash
Bad file format reading the append only file: make a backup of your AOF file, then use ./redis-check-aof --fix <filename>
```

## 修复

错误很明确了，AOF文件破损，了解到之前因为Node出问题，把Pod强制删除过，应该是这个原因造成的。

修改Yaml，设置启动命令为`/bin/sh`，开启tty和stdin，注释掉所有Probe：

```yaml
   ...
   tty: true
   stdin: true
   command:
   - /bin/sh
   ...
   # livenessProbe: ...
   # readinessProbe: ...
```

容器启动后，因为用的是bitnami redis镜像，所以进入容器shell执行：

```bash
redis-check-aof /bitnami/redis/data/appendonly.aof
...
Continue [y/N]: y
```

然后再把上述修改撤回，重启Pod，问题修复。

