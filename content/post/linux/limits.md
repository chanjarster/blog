---
title: "Linux内核参数/Limits调整方法"
author: "颇忒脱"
tags: ["linux", "cheatsheet"]
date: 2021-09-07T08:00:22+08:00
---

<!--more-->

## 配置方法

### 查看内核限制

```bash
ulimit -a
```

### 系统级调整

添加配置

```bash
vi /etc/sysctl.conf
```

生效配置

```bash
sysctl -p
```

### 用户级调整

修改配置

```bash
vi /etc/security/limits.conf
```

## 常用配置

### max open files

系统级：

```bash
fs.file-max=500000
```

验证：

```bash
cat /proc/sys/fs/file-max
```

用户级：

```bash
## Example hard limit for max opened files
<domain>        hard nofile 4096
## Example soft limit for max opened files
<domain>        soft nofile 1024
```

