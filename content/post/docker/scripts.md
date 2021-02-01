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

给docker命令添加 `--format '{{ json .}}'`参数，能够使得返回结果变成JSON。，比如：

```bash
$ docker image ls --format '{{json .}}'
```

## 删除所有镜像

利用`--format`参数得到镜像ID，然后删除：

```bash
docker image ls --format '{{ .ID}}' | xargs -n1 -I{} docker image rm  {}
```

## 得到容器的PID

```bash
docker inspect --format '{{.State.Pid}}' <container-name/id>
```

## 列出所有容器的PID

```bash
docker ps -q | xargs docker inspect --format '{{.State.Pid}}, {{.Name}}'
```

## 列出容器暴露的端口

```bash
docker inspect --format '
{{- range $port, $hostPorts := .NetworkSettings.Ports }}
container port: {{ $port }}, host ports: {{json $hostPorts}}
{{- end -}}' <container-name/id>
```

## 列出所有容器暴露的端口

```bash
docker ps -q | xargs docker inspect --format '
Pid:{{.State.Pid}}, Name:{{ .Name }}
{{- range $port, $hostPorts := .NetworkSettings.Ports }}
container port: {{ $port }}, host ports: {{json $hostPorts}}
{{- end -}}'
```

