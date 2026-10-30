---
title: "docker0 eth设备MTU不正确导致容器无法访问外网"
date: 2021-02-25T09:29:54+08:00
tags: ["docker","troubleshooting"]
author: "颇忒脱"
---

<!--more-->

发现容器内无法访问公网资源，运行下列命令卡住不动了：

```bash
docker run --rm -it busybox
> wget http://mirrors.aliyun.com/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
```

## 排查主机网络通性

检查主机网络通性，在主机上执行相同命令，没有问题，说明问题出在docker上。

## 排查docker配置

在一台没有问题的机器上对比`docker info`，没有发现区别

在一台没有问题的机器上对比`docker network inspect bridge`，发现`com.docker.network.driver.mtu`值不一样，好的机器是`1450`，坏的机器是`1500`。

查看`docker0`设备的mtu也是`1500`：

```bash
ip a
...
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
...
```

## 排查mtu问题

[用ping确认mtu的合适大小][1]

在坏的主机上ping 1422+28=1450 字节（28字节是ICMP协议的头大小）：

```bash
docker run --rm -it nicolaka/netshoot:latest /bin/bash
> ping -c 3 -M do -s 1422 baidu.com
PING baidu.com (220.181.38.148) 1422(1450) bytes of data.
1430 bytes from 220.181.38.148 (220.181.38.148): icmp_seq=1 ttl=48 time=27.6 ms
```

可以看到结果正常，如果ping 1423+28=1451字节，就不行了：

```bash
> ping -c 3 -M do -s 1423 baidu.com
PING baidu.com (39.156.69.79) 1423(1451) bytes of data.
ping: local error: message too long, mtu=1450
```

这个就说明mtu最大只能是1450。

## 修改设备mtu

现在已经知道问题是`docker0`设备的mtu引起的，那么执行下列命令修改：

```bash
sudo ip link set docker0 mtu 1450
```

同时修改`/etc/docker/daemon.json`：

```json
{
  ... 其他配置不变
  "mtu": 1450
}
```

然后重启docker：

```bash
sudo systemctl restart docker
```

最后再试验就成功了：

```bash
docker run --rm -it busybox
> wget http://mirrors.aliyun.com/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
```



[1]: http://linux.vbird.org/linux_server/0140networkcommand.php#ping_mtu