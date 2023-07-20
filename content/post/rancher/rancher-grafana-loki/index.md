---
title: "Rancher安装Grafana Loki"
author: "颇忒脱"
tags: ["grafana", "rancher", "监控", "日志"]
date: 2021-05-31T12:55:10+08:00
---

<!--more-->

## 步骤

在Rancher中添加Grafana应用商店：https://grafana.github.io/helm-charts

<img src="1.jpg" style="zoom:50%;" />

部署loki-stack

<img src="2.jpg" style="zoom:50%;" />

在应答中配置参数

<img src="3.jpg" style="zoom:50%;" />

下面是一个参数参考列表

| 参数                                 | 说明                        | 参考值            |
| ------------------------------------ | --------------------------- | ----------------- |
| grafana.enabled                      | 是否安装Grafana             | true              |
| grafana.ingress.enabled              | Grafana是否部署Ingress      | true              |
| grafana.ingress.hosts                | Grafana Ingress域名         | {grafana.xxx.com} |
| grafana.persistence.enabled          | Grafana是否启用持久卷       | true              |
| grafana.persistence.storageClassName | Grafana持久卷的StorageClass |                   |
| loki.persistence.enabled             | Loki是否启用持久卷          | true              |
| loki.persistence.size                | Loki持久卷的大小            | 5Gi               |
| loki.persistence.storageClassName    | Loki持久卷的StorageClass    |                   |
| prometheus.enabled                   | 是否安装Prometheus          | false             |
| prometheus.alertmanager.enabled      | 是否安装Alertmanager        | false             |



访问Grafana：访问 `grafana.ingress.hosts` 配置的值。使用`admin/admin`账号登录。

在Rancher的服务发现中找到loki的Service

Grafana中配置Loki数据源：

<img src="5.jpg" style="zoom:50%;" />

选择Loki数据源，配置Loki的地址为：`http://<loki-svc>:3100`

<img src="6.jpg" style="zoom:50%;" />

搜索日志（要学习[LogQL][2]）：

<img src="7.jpg" style="zoom:50%;" />

## 参考文档

* [Helm安装Grafana Loki](https://grafana.com/docs/loki/latest/installation/helm/)
* [LogQL][2]



[2]: https://grafana.com/docs/loki/latest/logql/

