---
title: "Linux 文件系统 inode 耗尽问题解决"
author: "颇忒脱"
tags: ["linux", "troubleshooting", "bash"]
date: 2023-06-12T15:33:22+08:00
---

<!--more-->

线上发现服务器执行任何命令都出现这个错误：

```shell
bash: cannot create temp file for here-document: No space left on device
```

发现磁盘空间是够的：

```shell
df -h
Filesystem      Size  Used Avail Use% Mounted on 
tmpfs           618M  8.8M  609M   2% /run
/dev/sda1       100G  50G    50G   1% /
...
```

查看 inode 用量：

```shell
Filesystem       Inodes   IUsed    IFree IUse% Mounted on
tmpfs            459110     842   458268    1% /run
/dev/sda1       2621440  2621440       0    0% /
...
```

根据这个[帖子][1]的方法，检查哪个目录下的文件多：

```shell
sudo find . -xdev -type f | cut -d "/" -f 2 | sort | uniq -c | sort -n
```

或者按照这个方法 `count_em.sh`：

```shell
#!/bin/bash

# count_em - count files in all subdirectories under current directory.
echo 'echo $(ls -a "$1" | wc -l) $1' >/tmp/count_em_$$
chmod 700 /tmp/count_em_$$
find . -mount -type d -print0 | xargs -0 -n1 /tmp/count_em_$$ | sort -n
rm -f /tmp/count_em_$$
```

[1]: https://stackoverflow.com/questions/653096/how-to-free-inode-usage