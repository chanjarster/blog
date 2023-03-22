---
title: "cgroup 内存泄漏导致容器无法创建的问题"
date: 2023-03-22T12:24:45+08:00
tags: ["k8s", "troubleshooting"]
author: "颇忒脱"
---

<!--more-->

有时候你会发现 K8S 创建 Pod 失败，会给你提示下面这个错误：

```
OCI runtime create failed: container_linux.go:380: starting container process caused: process_linux.go:385: 
applying cgroup configuration for process caused: mkdir /sys/fs/cgroup/memory/kubepods/burstable/podxxx/xxx: 
cannot allocate memory: unknown"
```

同样的错误你可以在 docker 的日志里看到：

```
$ journalctl -u docker
Mar 20 00:04:33 k8sworker06-new dockerd[3176]: time="2023-03-20T00:04:33.461528517+08:00" level=error 
msg="Handler for POST /v1.40/containers/bc91b4fd862386647df69cb636f779c05eb034d9e5db2ab527b51b90f128a5df/start 
returned error: OCI runtime create failed: container_linux.go:380: starting container process caused: 
process_linux.go:385: applying cgroup configuration for process caused: 
mkdir /sys/fs/cgroup/memory/kubepods/burstable/podxxx/xxx: cannot allocate memory: unknown"
```

参考[这篇文章][1]提到：

* linux kernel 3.10.xxx 中对于 cgroup 的 kmem allocation 存在 bug 会有内存泄漏问题。
* 如果频繁创建销毁容器，内存泄漏到一定程度，就会出现上述情况。

其实这个问题你也可以这样重现：

```
$ mkdir /sys/fs/cgroup/memory/test
cannot allocate memory
```

> 删除这个目录到方法是 `rmdir /sys/fs/cgroup/memory/test`

所以解决方案是：

* CentOS 7.x 的内核都是 3.10.xxx 的，升级 CentOS 到 8.x 内核会变成 4.x 解决了这个问题
* 或者重启服务器（重启 docker 服务是没用的，因为问题出在 cgroup 上）


[1]: https://www.modb.pro/db/212312