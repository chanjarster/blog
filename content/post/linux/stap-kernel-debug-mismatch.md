---
title: "内核版本不匹配导致 systemtap 不可用问题的解决办法"
author: "颇忒脱"
tags: ["linux", "systemtap", "kernel"]
date: 2023-02-19T14:33:22+08:00
---

<!--more-->

环境：Anolis Linux 8.6。

最近在使用 systemtap 的时候发现下面这么一个问题：

```shell
$ stap -v -e 'probe vfs.read {printf("read performed\n"); exit()}'
Pass 1: parsed user script and 490 library scripts using 507916virt/99428res/16760shr/82536data kb, in 220usr/60sys/281real ms.
WARNING: cannot find module kernel debuginfo: No DWARF information found [man warning::debuginfo]
semantic error: resolution failed in DWARF builder

semantic error: while resolving probe point: identifier 'kernel' at /usr/share/systemtap/tapset/linux/vfs.stp:980:18
        source: probe vfs.read = kernel.function("vfs_read")
                                 ^

semantic error: no match

semantic error: resolution failed in alias expansion builder

Pass 2: analyzed script: 0 probes, 0 functions, 0 embeds, 0 globals using 533960virt/110748res/22092shr/88516data kb, in 810usr/120sys/933real ms.
Pass 2: analysis failed.  [man error::pass2]
```

经过研究发现，`stap -h` 告诉我们它想要使用的 kernel-debuginfo 的版本是`4.19.91-27.an8.x86_64`：

```shell
$ stap -h
   ...
   -r RELEASE cross-compile to kernel /lib/modules/RELEASE/build, instead of
              /lib/modules/4.19.91-27.an8.x86_64/build
   ...
```

而`uname -r` 告诉我们当前的内核版本是 `4.19.91-26.an8.x86_64` 两者不一致：

```shell
$ uname -r
4.19.91-26.an8.x86_64
```

但是 yum 仓库里没有 `4.19.91-27.an8.x86_64` 的内核。

`yum repolist --all` 查看所有仓库：

```shell
$ yum repolist --all
...
Plus               [Disabled]
BaseOS-debuginfo   [Enabled]
Plus-debuginfo     [Enabled]
```

把 Plus 仓库启用起来：

```shell
$ yum-config-manager --enable Plus
```

然后再安装 kernel 和 kernel-devel：

```shell
$ yum install -y kernel
AnolisOS-8 - Plus                                         126 kB/s | 3.8 kB     00:00
软件包 kernel-4.19.91-26.an8.x86_64 已安装。
依赖关系解决。
=====================================================================================
 软件包                架构         版本                        仓库         大小
=====================================================================================
安装:
 kernel               x86_64      4.19.91-27.an8              Plus        307 k
安装依赖关系:
 kernel-core          x86_64      4.19.91-27.an8              Plus        23 M
 kernel-modules       x86_64      4.19.91-27.an8              Plus        21 M
...

$ dnf install kernel-devel-4.19.91-27.an8.x86_64
```

重启机器，问题解决。
