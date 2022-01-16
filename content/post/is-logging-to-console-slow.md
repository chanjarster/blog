---
title: "为何把日志打印到控制台很慢？"
author: "颇忒脱"
tags: ["ARTS-T", "linux", "java", "日志", "docker"]
date: 2019-02-22T15:42:48+08:00
---

<!--more-->

在[容器打印日志到控制台阻塞的排障][docker-console-logging-hangs]的时候看到一个观点：

> 把日志打印到控制台要比打印到文件慢，而且是非常慢。

log4j2和logback的两个issue官方也提到了这一点（见[LOG4J2-2239][LOG4J2-2239]、[LOGBACK-1422][LOGBACK-1422]）。

那么为何输出到控制台慢？有何办法加速呢？问题要从三个角度来分别回答：

1. linux的`stdout`角度
1. Java程序角度
1. docker容器角度

## `stdout`角度

写到控制台其实就是写到`stdout`，更严格的说应该是`fd/1`。Linux操作系统将`fd/0`、`fd/1`和`fd/2`分别对应`stdin`、`stdout`和`stdout`。

那么问题就变成为何写到`stdout`慢，有何优化办法？

造成`stdout`慢的原因有两个：

* 你使用的终端会拖累`stdout`的输出效率
* `stdout`的缓冲机制

在SO的这个问题中：[Why is printing to stdout so slow? Can it be sped up?][so-3857052]，这回答提到[打印到stdout慢是因为终端的关系，换一个快速的终端就能提升][so-answer-2]。这解释了第一个原因。

`stdout`本身的缓冲机制是怎样的？[Stdout Buffering][stdout-buffering]介绍了glibc对于stdout缓冲的做法：

* 当`stdout`指向的是终端的时候，那么它的缓冲行为是`line-buffered`，意思是如果缓冲满了或者遇到了newline字符，那么就flush。
* 当`stdout`没有指向终端的时候，那么它的缓冲行为是`fully-buffered`，意思是只有当缓冲满了的时候，才会flush。

其中缓冲区大小是4k。下面是一个总结的表格“
GNU libc (glibc) uses the following rules for buffering”:

| Stream             | Type   | Behavior       |
|--------------------|--------|----------------|
| stdin              | input  | line-buffered  |
| stdout (TTY)       | output | line-buffered  |
| stdout (not a TTY) | output | fully-buffered |
| stderr             | output | unbuffered     |

那也就是说当`stdout`指向一个终端的时候，它采用的是`line-buffered`策略，而终端的处理速度直接影响到了性能。

同时也给了我们另一个思路，不将`stdout`指向终端，那么就能够用到`fully-buffered`，比起`line-buffered`能够带来更大提速效果（想想极端情况下每行只有一个字符）。

我写了一段小代码来做测试（[gist][gist]）。先试一下`stdout`指向终端的情况：

```bash
$ javac ConsolePrint.java
$ java ConsolePrint 100000
...
lines: 100,000
System.out.println: 1,270 ms
file: 72 ms
/dev/stdout: 1,153 ms
```

代码测试了三种用法：

* `System.out.println` 指的是使用`System.out.println`所花费的时间
* `file` 指的是用4k BufferedOutputStream 写到一个文件所花费的时间
* `/dev/stdout` 则是同样适用4k BufferedOutputStream 直接写到`/dev/stdout`所花费的时间

发现写到文件花费速度最快，用`System.out.println`和写到`/dev/stdout`所花时间在一个数量级上。

如果我们将输出重定向到文件：

```bash
$ java ConsolePrint 100000 > a
$ tail -n 5 a
...
System.out.println: 920 ms
file: 76 ms
/dev/stdout: 31 ms
```

则会发现`/dev/stdout`速度提升到`file`一个档次，而`System.out.println`并没有提升多少。之前不是说`stdout`不指向终端能够带来性能提升吗，为何`System.out.println`没有变化呢？这就要Java对于`System.out`的实现说起了。

## Java程序角度

下面是`System`的源码：

```java
public final static PrintStream out = null;
...
private static void initializeSystemClass() {
  FileOutputStream fdOut = new FileOutputStream(FileDescriptor.out);
  setOut0(newPrintStream(fdOut, props.getProperty("sun.stdout.encoding")));
}
...
private static native void setOut0(PrintStream out);
...
private static PrintStream newPrintStream(FileOutputStream fos, String enc) {
  ...
  return new PrintStream(new BufferedOutputStream(fos, 128), true);
}
```

可以看到`System.out`是`PrintStream`类型，下面是`PrintStream`的源码：

```java
private void write(String s) {
  try {
    synchronized (this) {
      ensureOpen();
      textOut.write(s);
      textOut.flushBuffer();
      charOut.flushBuffer();
      if (autoFlush && (s.indexOf('\n') >= 0))
        out.flush();
    }
  } catch (InterruptedIOException x) {
    Thread.currentThread().interrupt();
  } catch (IOException x) {
    trouble = true;
  }
}
```

可以看到：

1. `System.out`使用的缓冲大小仅为128字节。大部分情况下够用。
1. `System.out`开启了autoFlush，即每次write都会立即flush。这保证了输出的及时性。
1. `PrintStream`的所有方法加了同步块。这避免了多线程打印内容重叠的问题。
1. `PrintStream`如果遇到了newline符，也会立即flush（相当于`line-buffered`）。同样保证了输出的及时性。

这解释了为何`System.out`慢的原因，同时也告诉了我们就算把`System.out`包到BufferedOutputStream里也不会有性能提升。

## Docker容器角度

那么把测试代码放到Docker容器内运行会怎样呢？把gist里的Dockerfile和ConsolePrint.java放到同一个目录里然后这样运行：

```bash
$ docker build -t console-print .
$ docker run -d --name console-print console-print 100000
$ docker logs --tail 5 console-print
...
lines: 100,000
System.out.println: 2,563 ms
file: 27 ms
/dev/stdout: 2,685 ms
```

可以发现`System.out.println`和`/dev/stdout`的速度又变回一样慢了。因此可以怀疑`stdout`使用的是`line-buffered`模式。

为何容器内的`stdout`不使用`fully-buffered`模式呢？下面是我的两个猜测:

* 不论你是`docker run -t`分配`tty`启动，还是`docker run -d`不非配tty启动，docker都会给容器内的`stdout`分配一个`tty`。
* 因为docker的logging driver都是以“行”为单位收集日志的，那么这个`tty`必须是`line-buffered`。

虽然`System.out.println`很慢，但是其吞吐量也能够达到~40,000 lines/sec，对于大多数程序来说这不会造成瓶颈。


## 参考文档

* [Standard output (stdout)][wiki-stdout]
* [Stdout Buffering][stdout-buffering]

[docker-console-logging-hangs]: ../docker-console-logging-hangs
[so-3857052]: https://stackoverflow.com/questions/3857052/why-is-printing-to-stdout-so-slow-can-it-be-sped-up
[so-answer-1]: https://stackoverflow.com/a/3857543/1287790
[so-answer-2]: https://stackoverflow.com/a/3860319/1287790
[LOG4J2-2239]: https://jira.apache.org/jira/browse/LOG4J2-2239
[LOGBACK-1422]: https://jira.qos.ch/browse/LOGBACK-1422
[gist]: https://gist.github.com/chanjarster/4598cb15bac03662c1dd66c8097c8282
[wiki-stdout]: https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)
[stdout-buffering]: https://eklitzke.org/stdout-buffering