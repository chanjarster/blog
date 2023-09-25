---
title: "Ubuntu 20.04/22.04 cgroup 没有启用导致的问题"
author: "颇忒脱"
tags: ["k8s", "ubuntu", "linux", "kernel", "troubleshooting", "docker"]
date: 2023-09-24T19:04:02+08:00
draft: false
---

记一次诡异的容器被 OOM Killed 的问题。

<!--more-->

到一个新客户部署容器，发现容器总是被 OOM Killed。现场服务器是 Ubuntu 22.04（内核 5.15），内存 64G。

因为容器是一个 Java 程序，因此添加 JVM 启动参数 `-XX:+PrintFlagsFinal -XshowSettings:vm`，观察启动后的日志输出。

发现 `-XX:InitialHeapSize=32178700288` 和 `-XX:MaxHeapSize=32178700288`，Java 认为自己的堆可以使用接近 30G，但是容器给的上限是 1G。

再通过 `docker stats` 看，容器刚启动的一瞬间就占满了 1G 内存，随后就是 OOM Killed。
问题很明显了，容器内的 JRE 觉得自己有很多内存可用，但实际上给的上限只有 1G 左右，两者错配，导致触发 OOM Killed。

把内存上限调到3G，确保容器可以启动后，用 `jmap` dump 出内存，发现 live objects 其实只有 90M，更印证了上述的推断。

查看容器内的 Java 版本，发现是 `8u_212`，怀疑版本太老，JRE 感知不了 Ubuntu 22.04 （内核 5.15）上的 cgroup 设置，于是打一个 `8u_342` 的试试。

结果问题依旧。

于是怀疑是否 Ubuntu 22.04 （内核 5.15）太新，导致 cgroup 不太兼容。在网上搜索一番之后，找到以下方法：

1. 修改 `/etc/default/grub`，给 `GRUB_CMDLINE_LINUX_DEFAULT=""` 这个选项添加，`cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1 systemd.unified_cgroup_hierarchy=0`。
2. 然后 `sudo update-grub`
3. 接着重启服务器。
4. 重启完成后， `cat /proc/cmdline` 看这些参数是否出现了，出现了，说明 grub 更新成功。

PS. 注意 grub 的修改要谨慎，如果改错了服务器是启动不起来的，做之前做好备份。

然后再观察 Pod 的启动日志，发现 `-XX:InitialHeapSize` 和 `-XX:MaxHeapSize` 的值是正确的，容器能够正常启动。

这个方法也适用于 Ubuntu 20.04。

参考文档： https://askubuntu.com/a/1444247

