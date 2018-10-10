---
title: "利用VisualVm远程监控Java进程"
author: "颇忒脱"
tags: ["java", "visualvm"]
date: 2018-10-10T10:59:27+08:00
---

本文介绍利用[VisualVm][VisualVm]和[jstatd][doc-jstatd]来远程监控Java进程的方法。

<!--more-->

要实现远程监控Java进程，必须在远程主机（运行Java程序的主机）上跑一个[jstatd][doc-jstatd]进程，这个进程相当于一个agent，用来收集远程主机上的JVM运行情况，然后用[VisualVm][VisualVm]连接到这个[jstatd][doc-jstatd]，从而实现远程监控的目的。

## 第一步：在远程主机上启动jstatd

要注意的是，[jstatd][doc-jstatd]是一个RMI server application，因此在启动时支持[java.rmi properties][doc-java.rmi-properties]。

根据[jstatd][doc-jstatd]文档，我们需要在启动[jstatd][doc-jstatd]时提供一个security policy文件：

```txt
grant codebase "file:${java.home}/../lib/tools.jar" {   
    permission java.security.AllPermission;
};
```

然后运行下面命令启动：

```bash
jstatd -J-Djava.security.policy=jstatd.all.policy
```

**不过这里有一个陷阱**，见SO上的这个提问：[VisualVm connect to remote jstatd not showing applications][so-answer]。在启动时还得指定rmi server hostname，否则VisualVm无法看到远程主机上的Java进程。所以正确的命令应该是这样：

```bash
jstatd -J-Djava.security.policy=jstatd.all.policy -J-Djava.rmi.server.hostname=<host or ip>
```

远程主机的hostname可以随便填，只要VisualVm能够ping通这个hostname就行了。所以说下面这几种情况都是可行的：

* 远程主机没有DNS name，但VisualVm所在主机的`/etc/hosts`里配置了`some-name <ip-to-remote-host>`。jstatd启动时指定`-J-Djava.rmi.server.hostname=some-name`，VisualVm连接`some-name`。
* 远程主机经过层层NAT，它的内部ip比如是`192.168.xxx.xxx`，它的对外的NAT地址是`172.100.xxx.xxx`。jstatd启动时指定`-J-Djava.rmi.server.hostname=172.100.xxx.xxx`，VisualVm连接`172.100.xxx.xxx`。
* 上面两种方式混合，即在VisualVm所在主机的`/etc/hosts`里配置`some-name <ip-to-remote-host-nat-address>`。jstatd启动时指定`-J-Djava.rmi.server.hostname=some-name`，VisualVm连接`some-name`。

## 第二步：启动VisualVm

在你的机器上运行`jvisualvm`启动VisualVm。按照下面步骤添加远程主机：

**第一步**

![step 1](jvisualvm-01.png)

**第二步**

![step 2](jvisualvm-02.png)

**第三步**

![step 3](jvisualvm-03.png)

你就能看到远程主机上的Java进程了。

需要注意的是如果你点开一个远程进程，那么你会发现有些信息是没有的，比如：CPU、线程、和MBeans。这是正常的，如果需要这些信息（就像监控本地Java进程一样），那么就需要用JMX，相关内容会在另一篇文章中讲解。

## 参考资料

* [VisualVm - Working with Remote Applications][doc-VisualVm-remote]
* [jstatd][doc-jstatd]
* [java.rmi Properties][doc-java.rmi-properties]
* [VisualVm connect to remote jstatd not showing applications][so-answer]

[VisualVm]: https://visualvm.github.io/
[doc-VisualVm-remote]: https://htmlpreview.github.io/?https://raw.githubusercontent.com/visualvm/visualvm.java.net.backup/master/www/applications_remote.html
[so-answer]: https://stackoverflow.com/a/33219226/1287790
[doc-jstatd]: https://docs.oracle.com/javase/8/docs/technotes/tools/unix/jstatd.html
[doc-java.rmi-properties]: https://docs.oracle.com/javase/8/docs/technotes/guides/rmi/javarmiproperties.html