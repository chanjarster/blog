---
title: "docker/K8S故障排查Cheatsheet"
date: 2020-12-4T14:24:45+08:00
tags: ["k8s", "docker", "cheatsheet"]
author: "颇忒脱"
---

<!--more-->

## docker

### 拿到dockerd的thread dump

执行下列命令（不会kill掉进程）：

```bash
kill -SIGUSR1 $(pidof dockerd)
```

用`journalctl -u docker.service`可以看到输出到哪里：

```
Dec 04 07:08:11 docker-learn-5 dockerd[2090]: time="2020-12-04T07:08:11.362055588Z" level=info msg="goroutine stacks written to /var/run/docker/goroutine-stacks-2020-12-04T070811Z.log"
```

[参考文档](https://docs.docker.com/config/daemon/#force-a-stack-trace-to-be-logged)

## containerd

### 拿到thread dump

执行下列命令（不会kill掉进程）：

```bash
kill -SIGUSR1 $(pidof containerd)
```

用`journalctl -u containerd.service`直接查看thread dump。



如果是containerd-shim，则需要先启用`shim_debug`，然后

```bash
kill -SIGUSR1 $(pidof containerd-shim)
```

[参考文档](https://github.com/containerd/containerd/issues/2744#issuecomment-453614175)

## k8s

### 拿到kubelet的thread dump

**方法一（不会kill进程）：**

在一个终端执行：

```bash
kubectl proxy
```

如果是rancher，则使用直接连接到某台master的context配置。

在另一个终端执行：

```bash
curl 'http://localhost:8001/api/v1/nodes/<node name>/proxy/debug/pprof/goroutine?debug=2'
```

实际上这个方法就是go的pprof，你可以利用这个做很多事情。



**方法二（会kill进程）：**

```bash
kill -SIGABRT $(pidof kubelet)
```

[参考文档](https://stackoverflow.com/a/56648851/1287790)

