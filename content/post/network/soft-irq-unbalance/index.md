---
title: "NET_RX 软中断不平衡问题"
author: "颇忒脱"
tags: ["network", "linux", "troubleshooting"]
date: 2023-02-08T09:30:00+08:00
---

<!--more-->

偶然间发现服务器上的 NET_RX 软中断（关于接受网络数据包）很不平衡，只有两个 CPU 在工作，另外两个在摸鱼。

```shell
[root@localhost ~]# cat /proc/softirqs
                    CPU0       CPU1       CPU2       CPU3
          HI:          7          0          0          0
       TIMER:   10977073   10904906    7607531    7526045
      NET_TX:        482        532         57         77
      NET_RX:    1915719    1313858          0          0
       BLOCK:      22144      12545      45951      12450
BLOCK_IOPOLL:          0          0          0          0
     TASKLET:        427        246        262        296
       SCHED:    2882528    2946414    2240633    2224537
     HRTIMER:          0          0          0          0
         RCU:    7573691    7529060    5955773    5877884
```

怎么测出来的呢？通过 `iperf3` 测试服务器带宽时测出来的。

环境情况：

* 服务器是运行在深信服 acloud 上的虚拟机
* 操作系统 CentOS 7.9，内核版本 3.10.0-1160.83.1.el7.x86_64
* 因为是虚拟机，网卡使用的是 Virtio 设备（或者说驱动，这个不太懂）
* ethtool eth0 看不到任何信息

## 失败的实验

做过以下实验，都没有能够解决问题。

因为正好具有 acloud 管理权限，尝试设置物理机的网络转发 CPU 个数，以及 CPU 是否独占对这个问题没有帮助。

开启系统的 `systemctl start irqbalance.service`，对这个问题没有帮助。

也许是内核问题，因为在[这篇博客][3]里提到：

> 老版本的centos的内核对virtio方式的网卡支持不好，升级centos plus提供的内核后，中断问题得以解决。

不过经过实验，并没有效果。安装 CentOS Plus 内核的方法间[这里][4]。

## 成功的实验

又搞了一台 [Anolis 8.6][2]（和 CentOS 差不多吧）虚拟机，结果没有这个问题，内核版本 4.19.91-26.an8.x86_64。

## 参考资料

* [Linux内核网络数据包处理流程][1]，看不懂，纯收藏。

[1]: https://zhuanlan.zhihu.com/p/344526925
[2]: https://openanolis.cn/anolisos
[3]: https://blog.huoding.com/2013/10/30/296
[4]: https://plone.lucidsolutions.co.nz/linux/centos/7/install-centos-plus-kernel-kernel-plus/view