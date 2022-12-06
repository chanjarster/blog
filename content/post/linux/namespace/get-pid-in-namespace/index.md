---
title: "得到进程在下层 namespace 里的 PID"
author: "颇忒脱"
tags: ["linux", "kernel", "namespace", "docker", "container"]
date: 2022-12-06T16:13:45+08:00
---

<!--more-->

容器通过 [Linux Namespace][2] 技术，对网络、PID、用户等等信息的隔离。

从进程的角度来说，你可以在 Host 上看到所有容器内的进程。

或者更准确的说，当你在 Host 所在的 root PID namespace 时，可以看到其所有下层 PID namespace 里的进程。

当你在 Host 上得到了一个进程的 PID，比如是 6052，那么怎么知道它在其所属的 PID namespace 里的 PID 呢？

## Linux Kernel >= 4.1

> `host_pid` 指代你在 root PID namespace 里看到的进程 ID

从 Linux Kernel 4.1 开始，在 `/proc/[host_pid]/status` 里有一个 NSpid 字段，它就是其在自己的 PID namespace 里的 PID：

```
$ grep 'NSpid' /proc/[host_pid]/status | awk '{print $2}'
```



## Linux Kernel < 4.1

在 Linux Kernel 4.1 之前的版本则没有 `NSpid` 字段可以利用，那么就需要迂回一点，利用 procfs 的 `/proc/[pid]/maps` 伪文件来匹配查找。

具体原理是，只要两个 PID 实际指向的是同一个进程，那么 `/proc/[pid]/maps` 文件就应该是一样的，因为这个文件记录了进程的内存映射信息。

具体步骤：

* 进入 `host_pid` 的 namespace
* 用 ps 列出这个 namespace 下所有的 PID，下面称为 `cont_pid`，然后遍历：
  * 在 root namespace 里对 `/proc/[host_pid]/maps` 计算 md5sum
  * 在下层 namespace 里对 `/proc/[cont_pid]/maps` 计算 md5sum
  * 比较两者的结果，如果一样，则 `cont_pid` 就是答案

下面是脚本：

```shell
function get_container_pid_by_host_pid
{
  local host_pid=$1
  for cont_pid in $(nsenter --target "$host_pid" --mount --uts --ipc --net --pid ps -o'pid=')
  do
    # 通过 md5 来找 host_pid 对应的 cont_pid （容器 pid）
    # 注意 /proc/[pid]/maps 文件会变，如果两次命令的间隔期间文件变了，则得到的 md5 会不同
    host_maps_md5=$(md5sum /proc/"$host_pid"/maps | awk '{print $1}')
    cont_maps_md5=$(nsenter --target "$host_pid" --mount --uts --ipc --net --pid md5sum /proc/  "$cont_pid"/maps | awk '{print $1}')
    if [[ "$host_maps_md5" == "$cont_maps_md5" ]]; then
      echo "$cont_pid"
      return 0
    fi
    echo ""
  done
}

```

这个方法有两个点要注意：

1. 是否会出现两个不同的进程 `/proc/[pid]/maps` 一样的情况，这个以我目前的知识来说，不能完全排除这种可能性。
2. `/proc/[pid]/maps` 是随时变化的，在上面的脚本里实际上对同一个进程的 `/proc/[pid]/maps` 做了两次 md5sum，因此可能会出现匹配不到的情况。


## 参考资料

- [procfs][3]
- [proc(5) — Linux manual page][4]
- [Namespaces in operation, part 3: PID namespaces][5]
- 上文的翻译版：[命名空间介绍之三：PID 命名空间][6]

[2]: https://man7.org/linux/man-pages/man7/namespaces.7.html
[3]: https://docs.kernel.org/filesystems/proc.html
[4]: https://man7.org/linux/man-pages/man5/proc.5.html
[5]: https://lwn.net/Articles/531419/
[6]: https://cloud.tencent.com/developer/article/1529664

