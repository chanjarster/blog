---
title: "Perf分析CPU性能问题笔记"
author: "颇忒脱"
tags: ["kernel", "java", "运维", "troubleshooting"]
date: 2019-04-12T15:35:55+08:00
---

<!--more-->

## 场景

### 观察进程的CPU使用情况

观察进程内各个函数的CPU使用情况：

```bash
sudo perf top -p <pid>
```

同时显示函数调用链：

```bash
sudo perf top -g -p <pid>
```

记录采样结果，以供后续分析，加上`-g`会记录调用链：

```bash
sudo perf record -g -p <pid>
```

读取采样结果：

```bash
sudo perf report
```

### 观察容器内进程CPU使用情况

容器内的进程实际上可以在host machine上看到，`ps -ef | grep <text>`可以找得到。

因此同样可以用`perf top -p <pid>`观察，但是会出现无法显示函数符号的问题，注意观察`perf top`最下面一行：

```txt
Failed to open /opt/bitnami/php/lib/php/extensions/opcache.so, continuing without symbols
```

解决办法是先用`perf record`记录采样数据，然后将容器内文件系统绑定到host上，然后用`perf report --symfs <path>`指定符号目录。你得先安装bindfs（下面有安装方法）。

```bash
mkdir /tmp/foo
PID=$(docker inspect --format {{.State.Pid}} <container-name>)
bindfs /proc/$PID/root /tmp/foo
perf report --symfs /tmp/foo

# 使用完成后不要忘记解除绑定
umount /tmp/foo/
```

把上面的`<container-name>`改成你要观察的容器名。

### 观察Java进程的CPU使用情况

你得要先安装[perf-map-agent][perf-map-agent]（下面有安装方法），在启动Java进程的时候添加`-XX:+PreserveFramePointer`参数，下面是几个用法：

* `perf-java-top <pid> <perf-top-options>`
* `PERF_RECORD_SECONDS=30 perf-java-record-stack <pid> <perf-record-options>`
* `PERF_RECORD_SECONDS=30 perf-java-report-stack <pid> <perf-report-options>`

更多用法见官网说明。

还可以使用`PERF_RECORD_SECONDS=30 perf-java-flames <pid> <perf-record-options>`生成火焰图，你得先安装[FlameGraph][flame-graph]（下面有安装方法）。关于火焰图的解读看[netflix的这篇博客][netflix-blog]。

### 观察容器内Java进程CPU使用情况

目前没有办法。

## 附录：安装方法

下面讲的都是在Ubuntu 16.04系统上的安装方法。

### perf

安装perf

```bash
$ sudo apt install -y linux-tools-common
```

运行perf会出现：

```bash
$ perf
WARNING: perf not found for kernel 4.4.0-145

  You may need to install the following packages for this specific kernel:
    linux-tools-4.4.0-145-generic
    linux-cloud-tools-4.4.0-145-generic

  You may also want to install one of the following packages to keep up to date:
    linux-tools-generic
    linux-cloud-tools-generic
```

于是安装：

```bash
sudo apt install linux-tools-4.4.0-145-generic linux-cloud-tools-4.4.0-145-generic linux-cloud-tools-generic
```

### bindfs

到[bindfs官网][bindfs]下载源码包（本文写是版本为1.13.11）。

先安装编译需要的工具：

```bash
sudo apt install -y cmake pkg-config libfuse-dev libfuse2 autoconf 
```

解压缩源码包，进入bindfs目录，编译：

```bash
./configure && make && sudo make install
```

### perf-map-agent

到[github][perf-map-agent] clone perf-map-agent的源码仓库。

安装JDK，你之后要监测的程序都得用这个JDK启动，这个JDK也用来编译perf-map-agent。用apt安装openjdk的方法见下面。

编译：

```bash
cmake .
make

# will create links to run scripts in /usr/local/bin
sudo bin/create-links-in /usr/local/bin
```

### 安装openjdk

```bash
sudo apt-get install -y openjdk-8-jdk
```

通过这种方式安装是没有JAVA_HOME环境变量的，因此我们要自己设置一个，查找openjdk的安装路径：

```bash
dpkg-query -L openjdk-8-jdk
```

将发现结果写到`~/.bashrc`里：

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
```

#### FlameGraph

到[github][flame-graph] clone FlameGraph的源码仓库。

到`~/.bashrc`设置环境变量：

```bash
export FLAMEGRAPH_DIR=<path-to-flame-graph>
```

#### BCC

官方[安装文档][bcc]。

如果你是Ubuntu 18.04：

```bash
sudo apt-get install bpfcc-tools linux-headers-$(uname -r)
```

如果你是Ubuntu 16.40：

```bash
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get update
sudo apt-get install bcc-tools libbcc-examples linux-headers-$(uname -r)
```



[bindfs]: https://bindfs.org/
[perf-map-agent]: https://github.com/jvm-profiling-tools/perf-map-agent
[flame-graph]: https://github.com/brendangregg/FlameGraph
[netflix-blog]: https://medium.com/netflix-techblog/java-in-flames-e763b3d32166

[bcc]: https://github.com/iovisor/bcc/blob/master/INSTALL.md#ubuntu---binary