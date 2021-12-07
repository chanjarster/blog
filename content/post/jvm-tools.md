---
title: "jps jstat jstack...的工作原理"
author: "颇忒脱"
tags: ["jvm"]
date: 2021-12-07T13:12:18+08:00
---

本文介绍JDK 8的jps、jstat、jstack ... 的工作原理。

<!--more-->

## Jvmstat Performance Counters

jps和jstat命令使用的是[Jvmstat Performance Counters][a]。

### jps

先说结论：

* jps命令扫描的是 `$TMPDIR/hsperfdata_$usr` 下的PID文件。比如在 Linux 系统下，`/tmp/hsperfdata_foo/2121`，这体现两个信息，JVM进程的PID是2121，启动这个进程的是`foo`用户。

源码脉络：

- [Jps.java][2] 
- [MonitoredHost][3] ([javadoc][4]) 有三子类。
- 看local实现：[MonitoredHostProvider.java][5] 
- [LocalVmManager.java][6]
- [PerfDataFile.java][7] 规定了PID文件的匹配模式，[tmpDirName][8] 属性是平台相关的
- [VMSupport.c][9] -> [jvm.h][10] -> [jvm.cpp][11] 规定了 `JVM_GetTemporaryDirectory`的返回值

[2]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/jps/Jps.java#L58
[3]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/monitor/MonitoredHost.java
[4]: http://openjdk.java.net/groups/serviceability/jvmstat/sun/jvmstat/monitor/MonitoredHost.html
[5]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/MonitoredHostProvider.java#L47
[6]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/LocalVmManager.java#L81
[7]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/PerfDataFile.java#L57-L79
[8]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/PerfDataFile.java#L294-L305
[9]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/native/sun/misc/VMSupport.c#L59
[10]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/javavm/export/jvm.h#L1359
[11]: https://github.com/openjdk/jdk8u-dev/blob/master/hotspot/src/share/vm/prims/jvm.cpp#L424

## jstat

先说结论：

* jstat和jps一样，读取的是 `$TMPDIR/hsperfdata_$usr` 下的PID文件，这个文件准确来说应该是 perfdata。这里面有 jstat 所想要的一切。
* JVM在运行过程中会更新 perfdata，perfdata 采用的是mmap机制（内存映射文件），详见[JVM源码分析之jstat工具原理完全解读][29]
* 顺带一提，mmap文件内容的修改是无法通过 [inotify(7)][30] 探测到的（见Limitations and caveats）。

源码脉络：

- [Jstat.java][21]，你可以看到两个隐藏参数`-list`和`-snap`，这不是我们的主题，关键看[logSamples()][22]方法
- 可以看到同样依赖于 [MonitoredHost][3] ([javadoc][4])
- 然后得到 [MonitoredVm][23]，类层级结构是 [BufferedMonitoredVm][24] -> [AbstractMonitoredVm][25] -> [LocalMonitoredVm][26]
- [LocalMonitoredVm][27] 用到了 [PerfDataBuffer][28]

[21]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/jstat/Jstat.java#L70
[22]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/jstat/Jstat.java#L114
[23]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/monitor/MonitoredVm.java
[24]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/monitor/remote/BufferedMonitoredVm.java
[25]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/AbstractMonitoredVm.java
[26]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/LocalMonitoredVm.java
[27]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/LocalMonitoredVm.java#L68
[28]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/jvmstat/perfdata/monitor/protocol/local/PerfDataBuffer.java#L61
[29]: https://zhuanlan.zhihu.com/p/113673963
[30]: https://man7.org/linux/man-pages/man7/inotify.7.html

## Dynamic Attach Mechanism

jstack和jmap命令使用的是[Dynamic Attach Mechanism][b]。

### jstack

先说结论：

* 和socket文件 `/tmp/.java_pid$pid` 通信
* 如果这个文件不存在，则 `touch /proc/$pid/cwd/.attach_pid$pid`文件
* 然后 `kill -3 $pid`，JVM就会创建socket文件
* 然后把`attach_pid$pid`文件可以删掉

源码脉络：

- [Jstack.java][31] 使用 [VirtualMachine.attach()][32]
- [VirtualMachine][33]，有一个子类[HotSpotVirtualMachine][34]
- [VirtualMachine.attach()][32] 依赖 [AttachProvider][35] [javadoc][36]
- [AttachProvider][35]  子类 [HotSpotAttachProvider][37] 子类 [LinuxAttachProvider][38]
- 然后用到了 [LinuxVirtualMachine][39]，这里描述了上述逻辑。

[31]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/jstack/JStack.java#L160
[32]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/com/sun/tools/attach/VirtualMachine.java#L195
[33]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/com/sun/tools/attach/VirtualMachine.java
[34]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/attach/HotSpotVirtualMachine.java
[35]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/com/sun/tools/attach/spi/AttachProvider.java
[36]: https://docs.oracle.com/javase/8/docs/jdk/api/attach/spec/com/sun/tools/attach/spi/AttachProvider.html
[37]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/share/classes/sun/tools/attach/HotSpotAttachProvider.java
[38]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/solaris/classes/sun/tools/attach/LinuxAttachProvider.java
[39]: https://github.com/openjdk/jdk8u-dev/blob/master/jdk/src/solaris/classes/sun/tools/attach/LinuxVirtualMachine.java

### jmap

jmap的机制和jstack一摸一样，不做赘述


## 参考资料

* [Serviceability in the J2SE Repository][1]



[1]: http://openjdk.java.net/groups/serviceability/svcjdk.html
[a]: http://openjdk.java.net/groups/serviceability/svcjdk.html#bjvmstat
[b]: http://openjdk.java.net/groups/serviceability/svcjdk.html#battach
