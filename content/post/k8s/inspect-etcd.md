---
title: "查询 k8s etcd 数据的方法"
author: "颇忒脱"
tags: ["k8s", "etcd", "troubleshooting"]
date: 2023-05-23T13:30:06+08:00
---

<!--more-->

## 安装 etcd-client

```shell
$ sudo apt install -y etcd-client
```

## 得到元信息

利用 `docker ps` 找到 k8s 的 etcd 容器：

```shell
$ docker ps
...
72921b78c9c4   rancher/mirrored-coreos-etcd:v3.4.15-rancher1   "/usr/local/bin/etcd…"   19 months ago    Up 5 months               etcd
...
```

利用 `docker inspect` 观察这个容器的配置元信息：

```shell
$ docker inspect etcd
...
            "Env": [
                "ETCDCTL_API=3",
                "ETCDCTL_CACERT=/etc/kubernetes/ssl/kube-ca.pem",
                "ETCDCTL_CERT=/etc/kubernetes/ssl/kube-etcd-172-18-10-1.pem",
                "ETCDCTL_KEY=/etc/kubernetes/ssl/kube-etcd-172-18-10-1-key.pem",
                "ETCDCTL_ENDPOINTS=https://127.0.0.1:2379",
                "ETCD_UNSUPPORTED_ARCH=x86_64",
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
...
```

可以发现它使用的 V3 版本的 API，且告诉了你 CA 证书，证书，私钥的文件位置，以及端口。

## 命令模板

```shell
$ sudo ETCDCTL_API=3 etcdctl \
--endpoints 127.0.0.1:2379 \
--cacert <上面的 ETCDCTL_CACERT> \
--cert <上面的 ETCDCTL_CERT> \
--key <上面的 ETCDCTL_KEY> \
<etcd 命令>
```

## 常见命令

help：

```shell
$ ETCDCTL_API=3 etcdctl help
$ ETCDCTL_API=3 etcdctl <命令> -h
```

列出集群节点：

```shell
$ <模板> member list
1a51951451665d46, started, etcd-xxx, https://xxx:2380, https://xxx:2379
5611b18ab33e296b, started, etcd-yyy, https://yyy:2380, https://yyy:2379
c190e474054c0acf, started, etcd-zzz, https://zzz:2380, https://yyy:2379
```

列出所有 key：

```shell
$ <模板> get --keys-only --prefix ""

/registry/apiextensions.k8s.io/customresourcedefinitions/nodedrivers.management.cattle.io

/registry/services/specs/cattle-system/rancher

/registry/services/specs/cattle-system/rancher-webhook

/registry/services/specs/default/kubernetes

/registry/services/specs/fleet-system/gitjob

...
```

得到某个 key 的值：

```shell
$ <模板> get <key>

...
```

## V2 版本

如果是 V2 版本的 API，则是这样：

```shell
sudo etcdctl \
--endpoints http://127.0.0.1:2379 \
--ca-file <上面的 ETCDCTL_CACERT> \
--cert-file <上面的 ETCDCTL_CERT> \
--key-file <上面的 ETCDCTL_KEY> \
<etcd 命令>
```
