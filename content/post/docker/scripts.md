---
title: "Docker实用小脚本"
author: "颇忒脱"
tags: ["docker", "cheatsheet"]
date: 2021-01-07T10:08:22+08:00
---

<!--more-->

## grep docker log

```bash
docker logs nginx 2>&1 | grep "127." 

# ref: http://stackoverflow.com/questions/34724980/finding-a-string-in-docker-logs-of-container
```

## 返回json

给docker命令添加 `--format '{{ json .}}'`参数，能够使得返回结果变成JSON，知道JSON结构后你可以很方便的利用`--format`做其他事情，比如：

```bash
$ docker image ls --format '{{json .}}'
```

## 镜像

### 删除所有镜像

利用`--format`参数得到镜像ID，然后删除：

```bash
docker image ls --format '{{ .ID}}' | xargs -n1 -I{} docker image rm  {}
```

### 得到镜像的pull命令

```bash
docker image ls --format 'docker pull {{.Repository}}:{{.Tag}}'
```

### save/load镜像

```bash
docker save <image> <image>... | gzip > <name>.tar.gz
docker load --input <name>.tar.gz
```

## 容器

### 得到容器的PID

```bash
$ docker inspect --format '{{.State.Pid}}' <container-name/id>
```

### 列出所有容器的PID

```bash
$ docker ps -q | xargs docker inspect --format '{{.State.Pid}}, {{.Name}}'
```

### 列出容器暴露的端口

```bash
$ docker inspect --format '
{{- range $port, $hostPorts := .NetworkSettings.Ports }}
container port: {{ $port }}, host ports: {{json $hostPorts}}
{{- end -}}' <container-name/id>
```

### 列出所有容器暴露的端口

```bash
$ docker ps -q | xargs docker inspect --format '
Pid:{{.State.Pid}}, Name:{{ .Name }}
{{- range $port, $hostPorts := .NetworkSettings.Ports }}
container port: {{ $port }}, host ports: {{json $hostPorts}}
{{- end -}}'
```

### 观察网络命名空间

docker使用linux network namespace来隔离网络设备，下面将你怎么在host上debug容器网络命名空间。

```bash
# 得到容器进程id
$ container_id=<container_id>
$ pid=$(docker inspect -f '{{.State.Pid}}' ${container_id})

# 创建 netns 目录
$ mkdir -p /var/run/netns/

# 创建命名空间软连接
$ ln -sfT /proc/$pid/ns/net /var/run/netns/${container_id}

# 运行ip netns命令访问这个命名空间
$ ip netns exec ${container_id} ip a

# 运行 nsenter 进入命名空间，用 netstat 命令查看容器进程的tcp/udp连接情况
$ nsenter -t $pid -n netstat -antpl
```

参考文档：[How to Access Docker Container’s Network Namespace from Host][1]

[1]: https://www.thegeekdiary.com/how-to-access-docker-containers-network-namespace-from-host/
