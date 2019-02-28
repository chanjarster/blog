---
title: "Container Isolation Gone Wrong"
author: "颇忒脱"
tags: ["ARTS", "ARTS-R", "linux", "docker", "troubleshooting"]
date: 2019-02-23T16:31:04+08:00
---

<!--more-->

原文：[Container isolation gone wrong][origin]。

这篇文章讲了如何分析定位容器运行性能问题的案例。

现象很简单：有两个容器worker和trasher，当worker独自运行的时候一切OK，当worker和trasher在同一个host上运行的时候，worker性能衰减的很厉害。

了解这两个容器干什么的：

1. worker定期扫描某个目录下文件是否有变化
1. trasher则是异步处理文件

重现问题：

1. 在host上只启动worker，cgroup设定为10% CPU/512M 内存，通过StatsD指标发现任务延迟耗时稳定在~250ms
1. 启动trasher之后，cgroup设定为10% CPU/512M 内存，观察一个小时内的变化，延迟逐步攀升到~550ms
1. 把trasher关掉之后，worker立即回到~250ms

先期排查：

1. 怀疑容器的内存/cpu cgroups没有设置正确，结果发现设置正确
1. 怀疑容器的内存/cpu cgroups没有生效，发现的确生效了。且两个容器的CPU/内存使用都远远没有达到cgroup设置的上限。

继续观察：发现host的内存使用量在持续上升，高达~25G，如果trasher关掉，则内存使用量立马下降到正常值，数百M。**这提供了一个重要信息，就是内存是被内核所使用的** 。

尝试从系统调用（system call）来观察两个容器干了什么，用`sudo sysdig container.name=<container-name>`观察两个容器的系统调用：

1. worker递归扫描某个目录下的文件
1. trasher尝试打开大量/tmp/UUID（比如，/tmp/356eb968-88e8-43bf-ba29-d4523577d48e）文件，而这些文件并不存在。

看不出什么，然后找到那个系统调用导致了任务延迟从~250ms到500-600ms

1. 用`sysdig -r worker1.scap -r worker2.scap -c topscalls_time`分别查看单启worker和同时启worker和trasher的时候，worker的系统调用的累积时间。发现`lstat`的调用增长符合观察到的预期。
1. 用`sysdig -r worker1.scap -c spectrogram evt.type=lstat`和`sysdig -r worker2.scap -c spectrogram evt.type=lstat`做的频谱图证实，大部分的`lstat`的调用从1.x us增长到10.x us

用`perf`工具进一步观察：

1. `sudo perf top -p <worker-pid> -d 60 --stdio`，观察到`__d_lookup`的调用占了50%以上的时间。`__d_lookup`是内核函数，也就意味着大部分时间被内核占用了。
1. `__d_lookup`是一个从缓存中查找文件metadata的函数。linux内核会将之前查找过的文件的metadata（dentry）存到一个缓存中，这个缓存就是一个hash table，这样可以加快执行速度。这个hash table是一个固定长度的数组，数组元素是链表。当hash冲突时将同hash值元素追加到链表里。

观察`dentry cache`：

1. `$ dmesg | grep Dentry`，可以观察到系统启动时这个数组的大小以及尺寸：`Dentry cache hash table entries: 4194304 (order: 13, 33554432 bytes)`
1. 于是怀疑是否这个cache在trasher运行期间增长过大，导致内核内存使用飙升呢？`sudo slabtop -o`观察到果然占用了~26G内存，存了5百万个dentry。
1. 但是host上根本没有那么多文件，是怎么产生5百万个dentry呢？

了解`dentry`的创建机制：不论你查找的目录是否存在，linux内核都会为查询文件创建一个dentry。而trasher则会大量的查询不存在的文件，导致dentry数量持续上升。这解释了为何trasher启动期间内存使用率持续攀升。

> linux内核的这个机制和互联网架构中的缓存穿透一模一样，所谓缓存穿透就是查询数据库中不存在的key，导致每次查询都hit到数据库，避免方式就是对每次查询的key的结果都做缓存。看来很多事情老前辈们早就解决了。

那么如何解释`__d_lookup`慢呢？这是因为大量的dentry产生了大量的hash冲突，导致单个hash槽里的链表变长，增加了查询时间。文章里用了一堆神奇的方法观察到了这一点：

观察 `__d_lookup` 函数：

```bash
$ sudo perf probe -L __d_lookup
      0  struct dentry * __d_lookup(struct dentry * parent, struct qstr * name)
      1  {
      2         unsigned int len = name->len;
      3         unsigned int hash = name->hash;
      4         const unsigned char *str = name->name;
      5         struct hlist_head *head = d_hash(parent,hash);
                struct dentry *found = NULL;
                struct hlist_node *node;
                struct dentry *dentry;

                rcu_read_lock();

     12         hlist_for_each_entry_rcu(dentry, node, head, d_hash) {
                        struct qstr *qstr;

     15                 if (dentry->d_name.hash != hash)
                                continue;
     17                 if (dentry->d_parent != parent)
                                Continue;
...
```

分别在函数调用处和函数第15行打入probe：

```bash
$ sudo perf probe --add __d_lookup
Added new event:
  probe:__d_lookup     (on __d_lookup)

$ sudo perf probe --add __d_lookup_loop=__d_lookup:15
Added new events:
  probe:__d_lookup_loop (on __d_lookup:15)
```

分别观察trasher启动时和trasher没有启动时调用次数：

```bash
$ sudo perf stat -p 18189 -e "probe:__d_lookup" -e "probe:__d_lookup_loop" -- sleep 60
 Performance counter stats for process id '18189':

         2,763,816      probe:__d_lookup
        75,503,432      probe:__d_lookup_loop

      60.001285559 seconds time elapsed

$ sudo perf stat -p 18189 -e "probe:__d_lookup" -e "probe:__d_lookup_loop" -- sleep 60
 Performance counter stats for process id '18189':

         3,800,247      probe:__d_lookup
         3,811,830      probe:__d_lookup_loop

      60.002976808 seconds time elapsed
```

发现trasher启动时第二个probe有~30倍于第一个probe的调用次数。

## 总结

* kill trasher container会释放dentry，在trasher container内部kill 进程则不会。
* 看似不相关的两个容器会在内核层面产生相互影响。
* 一切以观测结果为依据，而不是胡乱猜测。
* 对container的关键指标做好测算打好baseline，在线上观测到结果于预期不符的时候就可以报警，提前知道问题。

PS. linux新内核将kernel object pools和cgroup内存限制绑定在一起了，所以到时候trasher会被内核干掉。


[origin]: https://sysdig.com/blog/container-isolation-gone-wrong/
