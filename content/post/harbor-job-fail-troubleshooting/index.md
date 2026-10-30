---
title: "排查Harbor定时任务无法执行的问题"
author: "颇忒脱"
tags: ["docker", "harbor", "troubleshooting"]
date: 2021-05-14T09:01:20+08:00
---

<!--more-->

## 现象

Harbor上的同步任务都是失败的：

![](1.png)

且点击任务看不到日志：

![](2.png)

## 查看harbor日志

到harbor服务器的 /var/log/harbor 上查看日志，找到 postgresql.log 里有一些错误日志：

![](3.png)

## 到harbor-db 查看Lock表

最终在 postgres database里找到lock表：

```bash
docker stop harbor-core
docker exec -it harbor-db /bin/bash
psql postgres
select * from lock;
```

![](4.png)

把这个表清空。

问题依旧。

## 查看其他日志

看到 jobservice.log 有以下日志：

![](5.png)

但是时间不匹配。

## 尝试重启harbor

```bash
cd /path/to/harbor-installer-dir
docker-compose down -v
```

发现 harbor-jobservice 删除不掉，于是强制删除：

```bash
docker rm –force harbor-jobservice
```

然后再启动harbor：

```bash
docker-compose up -d
```

得到提示：

![](6.png)

尝试删除 harbor_harbor network：

```bash
docker network rm harbor_harbor
```

得到提示：

![](7.png)

观察这个network：

```bash
docker network inspect harbor_harbor
```

![](8.png)

看到上面存在幽灵容器 harbor-jobservice的注册记录，而这个容器之前已经删除了。因为`docker network rm` 没有` --force` 选项，所以重启docker看看能不能修复数据。

```bash
systemctl restart docker
```

之后再观察harbor_harbor network 就正常了。

然后重启harbor成功，同步任务也能顺利执行。

## 总结

排查的过程中走了一些弯路，其实如果一开始就观察harbor容器的状况就有可能定位问题所在。

这个事情发生的原因是 harbor-jobservice 处于一种不健康的状态，具体原因因为破坏了现场，所以不无法知晓了，有可能和5月11号redis通信异常有关。

