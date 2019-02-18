---
title: "容器打印日志到控制台阻塞的排障"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "docker", "troubleshooting"]
date: 2019-02-17T09:42:34+08:00
---

记一次容器打印到控制台阻塞，且容器停止响应的问题。

<!--more-->

今日生产环境发现有些容器停止响应了，但是容器没有死，`docker exec -it <container-name> /bin/bash`也能正常使用。

在容器内部使用`jstack <pid>`发现log4j2的Console Appender一直处于运行状态：

```txt
"AsyncAppender-asyncConsole" #21 daemon prio=5 os_prio=0 tid=0x00007fd968d07000 nid=0x1f runnable [0x00007fd91bffd000]
   java.lang.Thread.State: RUNNABLE
	at java.io.FileOutputStream.writeBytes(Native Method)
	at java.io.FileOutputStream.write(FileOutputStream.java:326)
	at java.io.BufferedOutputStream.write(BufferedOutputStream.java:122)
	- locked <0x00000000f002b408> (a java.io.BufferedOutputStream)
	at java.io.PrintStream.write(PrintStream.java:480)
	- locked <0x00000000f002b3e8> (a java.io.PrintStream)
	at org.apache.logging.log4j.core.util.CloseShieldOutputStream.write(CloseShieldOutputStream.java:53)
	at org.apache.logging.log4j.core.appender.OutputStreamManager.writeToDestination(OutputStreamManager.java:262)
	- locked <0x00000000f021d848> (a org.apache.logging.log4j.core.appender.OutputStreamManager)
	at org.apache.logging.log4j.core.appender.OutputStreamManager.flushBuffer(OutputStreamManager.java:294)
	- locked <0x00000000f021d848> (a org.apache.logging.log4j.core.appender.OutputStreamManager)
	at org.apache.logging.log4j.core.appender.OutputStreamManager.drain(OutputStreamManager.java:351)
	at org.apache.logging.log4j.core.layout.TextEncoderHelper.drainIfByteBufferFull(TextEncoderHelper.java:260)
	- locked <0x00000000f021d848> (a org.apache.logging.log4j.core.appender.OutputStreamManager)
	at org.apache.logging.log4j.core.layout.TextEncoderHelper.writeAndEncodeAsMuchAsPossible(TextEncoderHelper.java:199)
	at org.apache.logging.log4j.core.layout.TextEncoderHelper.encodeChunkedText(TextEncoderHelper.java:159)
	- locked <0x00000000f021d848> (a org.apache.logging.log4j.core.appender.OutputStreamManager)
	at org.apache.logging.log4j.core.layout.TextEncoderHelper.encodeText(TextEncoderHelper.java:58)
	at org.apache.logging.log4j.core.layout.StringBuilderEncoder.encode(StringBuilderEncoder.java:68)
	at org.apache.logging.log4j.core.layout.StringBuilderEncoder.encode(StringBuilderEncoder.java:32)
	at org.apache.logging.log4j.core.layout.PatternLayout.encode(PatternLayout.java:220)
	at org.apache.logging.log4j.core.layout.PatternLayout.encode(PatternLayout.java:58)
	at org.apache.logging.log4j.core.appender.AbstractOutputStreamAppender.directEncodeEvent(AbstractOutputStreamAppender.java:177)
	at org.apache.logging.log4j.core.appender.AbstractOutputStreamAppender.tryAppend(AbstractOutputStreamAppender.java:170)
	at org.apache.logging.log4j.core.appender.AbstractOutputStreamAppender.append(AbstractOutputStreamAppender.java:161)
	at org.apache.logging.log4j.core.config.AppenderControl.tryCallAppender(AppenderControl.java:156)
	at org.apache.logging.log4j.core.config.AppenderControl.callAppender0(AppenderControl.java:129)
	at org.apache.logging.log4j.core.config.AppenderControl.callAppenderPreventRecursion(AppenderControl.java:120)
	at org.apache.logging.log4j.core.config.AppenderControl.callAppender(AppenderControl.java:84)
	at org.apache.logging.log4j.core.appender.AsyncAppender$AsyncThread.callAppenders(AsyncAppender.java:459)
	at org.apache.logging.log4j.core.appender.AsyncAppender$AsyncThread.run(AsyncAppender.java:412)
```

但用`docker logs -f <container-name>`没有发现有新的日志输出，且访问该应用肯定会输出日志的接口也是没有任何日志输出，因此怀疑log4j2阻塞住了。

Google到有人在log4j提出了类似了问题[LOG4J2-2239][LOG4J2-2239]，官方给出的解释是问题出在log4j2之外。

于是查一下logback是否也有类似问题，找到[LOGBACK-1422][LOGBACK-1422]，同样给出的解释是问题出在logback之外。

两个问题的共通点都是用docker运行，于是把应用直接进程方式运行，没有出现问题。

于是Google搜索`docker logging to stdout hangs`，找到SO的这个[回答][so-1287790]，以及这个[issue][gh-35865]，解决方案将Docker升级到18.06。

查看生产环境的docker版本是18.03，升级到18.09后问题解决。

[LOG4J2-2239]: https://jira.apache.org/jira/browse/LOG4J2-2239
[LOGBACK-1422]: https://jira.qos.ch/browse/LOGBACK-1422
[so-1287790]: https://stackoverflow.com/a/52619471/1287790
[gh-35865]: https://github.com/moby/moby/issues/35865#issuecomment-407641385