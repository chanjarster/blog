---
title: "Kubectl 端口转发"
date: 2022-05-31T10:24:45+08:00
tags: ["k8s", "cheatsheet"]
author: "颇忒脱"
---

<!--more-->

使用 kubectl port-forward ，将集群上的 Pod / Deployment / Service 端口映射到本地，解决本地无法连接集群内资源的问题。

学好本文介绍的方法对于开发、调试、连接数据库非常有用。

**转发 Service 端口**

```shell
kubectl port-forward --namespace <命名空间> svc/<service名字> <本地端口>:<service端口>
```

**转发 Deployment 端口**

```shell
kubectl port-forward --namespace <命名空间> deployment/<deployment名字> <本地端口>:<deployment端口>
```

**转发 Pod 端口**

```shell
kubectl port-forward --namespace <命名空间> pod/<pod名字> <本地端口>:<pod端口>
```

**转发其他内部服务器端口**

如果有一个服务器（比如数据库），只有 k8s 集群可以访问，你就算连了 VPN 也不能访问，那么你可以临时开启一个用来转发的 deployment，然后通过它转发端口（[参考这个][1]）。

先在k8s上部署一个转发端口的程序：

```shell
kubectl run -n <命名空间> \
  --env REMOTE_HOST=<服务器IP> \
  --env REMOTE_PORT=<服务器端口> \
  --env LOCAL_PORT=<服务器端口> \
  --port <服务器端口> \
  --image marcnuri/port-forward \
  test-port-forward
```

然后转发端口：

```shell
kubectl port-forward -n <命名空间> deployment/test-port-forward <本地端口>:<服务器端口>
```

使用完删除：

```shell
kubectl -n <命名空间> delete deployment kubectl port-forward -n <命名空间>
```

[1]: https://stackoverflow.com/a/65598273/1287790