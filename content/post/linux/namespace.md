---
title: "Linux命名空间一些笔记"
author: "颇忒脱"
tags: ["linux", "kernel", "docker"]
date: 2021-12-07T16:35:45+08:00
---

<!--more-->

容器使用了 [Linux Namespace][2] 技术，通过Namespace技术可以做到网络、PID、用户等等信息的隔离，因此就产生了容器。

但是这种隔离并非物理隔离，只是一种逻辑上的隔离，如果你是root用户，Host上可以看到一切信息。

以PID Namespace来说，容器内进程的PID从1开始，但其在Host上的PID不仅可以看见，而且是另外一个值。

以用户 Namespace来说，容器内的用户UID和用户组GID，是可以和Host上的现有用户、用户组冲突的，比如容器内有个用户foo UID=1000，Host上有个用户 bar UID=1000，完全没有任何问题。

同时容器fs在Host的 `/proc/<host pid>/root` 目录下（参考[这个][9]），如果以 bar 用户 操作这个目录下需要foo 用户的文件/目录也是完全没有任何问题的，因为 bar的foo的UID相同。

**下面是一些脚本**

得到容器在Host上的PID：

```bash
docker inspect $container_id -f '{{.State.Pid}}'
```

探测容器用户、UID、用户组、GID：

```bash
# 先touch个一文件
$ docker exec $container_id touch /tmp/.pod_jvm_tools
# stat这个文件
$ docker exec $container_id stat -c '%u %U %g %G' /tmp/.pod_jvm_tools)
1000  java-app 65535 nogroup
[uid] [usr]    [gid] [group]
```

检查当前系统有没有用户、用户组：

```bash
getent passwd [uid]
getent group [gid]
```

[nsenter][3]，进入某个PID的Namesapce，然后执行某些命令:

```bash
nsenter -t <pid> -a -r
```

[runuser][6]，以某用户某group身份执行某些命令：

```bash
runuser -u <usr> -g <group> -m -- cat /proc/<pid>/root/path/to/file
```

[pgrep][8]，列出同属某进程Namespace的所有其他进程：

```bash
pgrep --ns <pid> -a
```

[lsns][4]，显示每个容器的根namesapce，但实际用下来没有搞明白（可以参考[这个][5]和[这个][7]），没有nsenter好用：

```bash
lsns -t pid
```



[2]: https://man7.org/linux/man-pages/man7/namespaces.7.html
[3]: https://man7.org/linux/man-pages/man1/nsenter.1.html
[4]: https://man7.org/linux/man-pages/man8/lsns.8.html
[5]: https://www.redhat.com/sysadmin/linux-pid-namespaces
[6]: https://man7.org/linux/man-pages/man1/runuser.1.html
[7]: https://unix.stackexchange.com/questions/105403/how-to-list-namespaces-in-linux
[8]: https://man7.org/linux/man-pages/man1/pgrep.1.html
[9]: https://kubernetes.io/zh/docs/tasks/configure-pod-container/share-process-namespace/