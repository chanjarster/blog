---
title: "使用Diskbenchmark测试硬盘"
author: "颇忒脱"
tags: ["运维"]
date: 2018-10-19T14:14:12+08:00
---

使用[diskbenchmark][diskbenchmark]测试硬盘性能。

<!--more-->

**本文使用的是Ubuntu服务器**

**无法在虚拟机上运行此工具**

**第1步：下载项目**

```bash
git clone https://github.com/ongardie/diskbenchmark.git
```

**第2步：安装必要的软件包**

```bash
sudo apt install -y gcc r-base-core r-cran-ggplot2 r-cran-plyr r-cran-scales
```

**第3步：编译项目**

```bash
make bench
```

**第4步：benchmark配置文件**

在`machines`目录下新建配置文件，比如`machine-a`：

```txt
disks="<硬盘名称>:<硬盘在/dev下的名称>:<测试文件写的目录>"
rootcmd () {
    sudo $*
}
cmd () {
    $*
}
sendfile () {
    cp $1 ~/
}
```

比如下面这样：

```txt
disks="mydisk:sda2:/tmp"
rootcmd () {
    sudo $*
}
cmd () {
    $*
}
sendfile () {
    cp $1 ~/
}
```

`<硬盘在/dev下的名称>`可以通过`sudo fdisk -l`得到。

**第5步：执行**

```bash
./runner.sh
```

**第6步：制作图表**

压测需要很长时间，我所测试的硬盘配置如下的情况下，跑了大约2小时：

* 6 * 1.2TB 10K RPM SAS 12Gbps 512n 2.5英寸热插拔硬盘
* PERC H730P+ RAID 控制器, 2Gb NV 缓存
* RAID 5 开启回写，预读

完成后会得到`results.csv`文件。

使用如下命令制作图表，获得`results.svg`文件：

```bash
R -e "source('post.R'); ggsave('results.svg', g, width=10, height=7)"
```

用浏览器打开：

![demo](result.png)

[diskbenchmark]: https://github.com/ongardie/diskbenchmark