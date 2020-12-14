---
title: "K8S服务器性能测试"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "k8s"]
date: 2020-12-14T09:03:06+08:00
---

<!--more-->

## 磁盘读写

使用[fio](https://github.com/axboe/fio)对磁盘做性能测试：

顺序读测试：

```bash
fio -filename=/var/test.file -direct=1 \
 -iodepth 1 -thread -rw=read \
 -ioengine=psync -bs=16k -size=2G -numjobs=10 \
 -runtime=60 -group_reporting -name=test_r
```

随机写测试：

```bash
fio -filename=/var/test.file -direct=1 \
 -iodepth 1 -thread -rw=randwrite \
 -ioengine=psync -bs=16k -size=2G -numjobs=10 \
 -runtime=60 -group_reporting -name=test_randw
```

顺序写测试：

```bash
fio -filename=/var/test.file -direct=1 \
 -iodepth 1 -thread -rw=write \
 -ioengine=psync -bs=16k -size=2G -numjobs=10 \
 -runtime=60 -group_reporting -name=test_w
```

混合随机读写测试：

```bash
fio -filename=/var/test.file -direct=1 \
 -iodepth 1 -thread -rw=randrw \
 -rwmixread=70 -ioengine=psync -bs=16k -size=2G -numjobs=10 \
 -runtime=60 -group_reporting -name=test_r_w -ioscheduler=noop
```

## 网络带宽

使用[iperf](https://iperf.fr/)测试服务器间的网络带宽。

现在要测试A到B的网络带宽，先在B启动iperf服务端

```bash
iperf -s
```

再到A上启动iperf客户端：

```bash
iperf -c <ip-to-b>
```

## 参考资料

* [3 个方便的命令行网速度测试工具](https://zhuanlan.zhihu.com/p/106409769)
* [Linux如何查看与测试磁盘IO性能](https://www.cnblogs.com/mauricewei/p/10502539.html)