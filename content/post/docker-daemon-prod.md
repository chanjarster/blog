---
title: "Docker Daemon生产环境配置"
author: "颇忒脱"
tags: ["docker"]
date: 2019-01-11T09:16:30+08:00
---

一些docker daemon生产环境中要注意的参数配置。

<!--more-->

本文介绍一些生产环境中dockerd要特别注意的参数，这些参数可以通过在`dockerd`命令行参数形式给，也可以通过在`/etc/docker/daemon.json`里配置。本文介绍的就是`daemon.json`配置方式。

在开始之前，请先查看`/etc/docker/daemon.json`是否存在，如果不存在则新建一个，内容是`{}`。然后你要懂JSON文件格式。

## 如何应用配置

下面所讲的配置最好在Docker安装完之后马上做，如果已经有容器运行了，那么先stop掉所有容器，然后再做。

修改完之后重启Docker daemon，比如在Ubuntu 16.04下：`sudo systemctl restart docker.service`。

然后执行`docker info`来验证配置是否生效。

## `registry-mirrors`

```json
{
  "registry-mirrors": []
}
```

此参数配置的是Docker registry的镜像网站，国内访问docker hub有时候会抽风，所以配置一个国内的镜像网站能够加速Docker image的下载。

可以使用[Daocloud加速器][daocloud-acc]（需注册，使用免费）或者其他云厂商提供的免费的加速服务。它们的原理就是修改`registry-mirrors`参数。

## `dns`

```json
{
  "dns": []
}
```

Docker内置了一个DNS Server，它用来做两件事情：

1. 解析docker network里的容器或Service的IP地址
2. 把解析不了的交给外部DNS Server解析（`dns`参数设定的地址）

默认情况下，`dns`参数值为Google DNS nameserver：`8.8.8.8`和`8.8.4.4`。我们得改成国内的DNS地址，比如：

1. `1.2.4.8`
2. 阿里DNS：`223.5.5.5`和`223.6.6.6`
3. 114DNS：`114.114.114.114`和`114.114.115.115`

比如：

```json
{
  "dns": ["223.5.5.5", "223.6.6.6"]
}
```

## `log-driver`

[Log driver][config-log-driver]是Docker用来接收来自容器内部`stdout/stderr`的日志的模块，Docker默认的log driver是[JSON File logging driver][json-file-log-driver]。这里只讲`json-file`的配置，其他的请查阅相关文档。

`json-file`会将容器日志存储在docker host machine的`/var/lib/docker/containers/<container id>/<container id>-json.log`（需要root权限才能够读），既然日志是存在磁盘上的，那么就要磁盘消耗的问题。下面介绍两个关键参数：

1. `max-size`，单个日志文件最大尺寸，当日志文件超过此尺寸时会滚动，即不再往这个文件里写，而是写到一个新的文件里。默认值是-1，代表无限。
2. `max-files`，最多保留多少个日志文件。默认值是1。

根据服务器的硬盘尺寸设定合理大小，比如：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-files":"5"
  }
}
```

## `storage-driver`

Docker推荐使用[overlay2][overlay2-driver]作为Storage driver。你可以通过`docker info | grep Storage`来确认一下当前使用的是什么：

```bash
$ docker info | grep 'Storage'
Storage Driver: overlay2
```

如果结果不是overlay2，那你就需要配置一下了：

```json
{
  "storage-driver": "overlay2"
}
```

## `mtu`

**如果docker host machine的网卡MTU为1500，则不需要此步骤**

MTU是一个很容易被忽略的参数，Docker默认的MTU是1500，这也是大多数网卡的MTU值。但是！在虚拟化环境下，docker host machine网卡的MTU可能不是1500，比如在openstack创建的虚拟的网卡的MTU是1450：

```bash
$ ip link
1: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether fa:16:3e:71:09:f5 brd ff:ff:ff:ff:ff:ff
```

当Docker网络的MTU比docker host machine网卡MTU大的时候可能会发生：

1. 容器外出通信失败
2. 影响网络性能

所以将Docker网络MTU设置成和host machine网卡保持一致就行了，比如：

```json
{
  "mtu": 1450
}
```

验证：

```bash
$ ip link
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default
    link/ether 02:42:6b:de:95:71 brd ff:ff:ff:ff:ff:ff
```

注意到docker0的MTU还是1500，不用惊慌，创建一个容器再观察就变成1450了（下面的veth是容器的虚拟网卡设备）：

```bash
$ docker run -itd --name busybox --rm busybox
$ ip link
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP mode DEFAULT group default
    link/ether 02:42:6b:de:95:71 brd ff:ff:ff:ff:ff:ff
268: vethdf32b1b@if267: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker0 state UP mode DEFAULT group default
    link/ether 1a:d3:8a:3e:d3:dd brd ff:ff:ff:ff:ff:ff link-netnsid 2
```

在到容器里看看它的网卡，MTU也是1450：

```bash
$ docker exec busybox ip link
267: eth0@if268: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
```

关于Overlay network的MTU看[这篇文章][docker-overlay-network-mtu]

## 参考资料

* [Daemon CLI][dockerd-options]
* [Configure logging drivers][config-log-driver]
* [JSON File logging driver][json-file-log-driver]
* [Use the OverlayFS storage driver][overlay2-driver]

[dockerd-options]: https://docs.docker.com/engine/reference/commandline/dockerd/
[daocloud-acc]: https://www.daocloud.io/mirror#accelerator-doc
[config-log-driver]: https://docs.docker.com/config/containers/logging/configure/
[json-file-log-driver]: https://docs.docker.com/config/containers/logging/json-file/
[overlay2-driver]: https://docs.docker.com/storage/storagedriver/overlayfs-driver/#configure-docker-with-the-overlay-or-overlay2-storage-driver
[docker-overlay-network-mtu]: ../docker-overlay-network-mtu/