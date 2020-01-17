---
title: "利用Rancher中的Prometheus采集JVM数据"
author: "颇忒脱"
tags: ["k8s", "prometheus"]
date: 2020-01-17T10:59:27+08:00
---

<!--more-->

Rancher中可以很方便的开启监控功能，其使用的是Prometheus Operator + Grafana，那么我们也可以利用它来采集JVM数据。

## 开启监控

首先，开启集群的监控：

<img src="step-1.png" style="zoom:50%" />

然后，开启项目的监控：

<img src="step-2.png" style="zoom:50%" />

## 应用配置JMX Exporter

你的Java应用的镜像得配置JMX Exporter，配置方法见[使用Prometheus+Grafana监控JVM](../../prom-grafana-jvm)，我在这里选择将JMX Exporter端口设置为6060。

然后在你的Deployment/StatefulSets 中配置这个端口：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ...
  namespace: ...
spec:
  selector:
    matchLabels:
      app: ...
  replicas: 1
  template:
    metadata:
      labels:
        app: ...
    spec:
      containers:
      - name: ...
        image: ...
        ports:
        - containerPort: 6060
          name: http-metrics
        - ...
```

和 Service 也一样：

```yaml
apiVersion: v1
kind: Service
metadata:
  namespace: ...
  name: ...
  labels:
    app: ...
    needMonitor: 'true'
spec:
  ports:
  - port: 6060
    targetPort: http-metrics
    protocol: TCP
    name: http-metrics
  - ...
  selector:
    app: ...
```

可以看到，我把端口取了个名字叫做http-metrics，同时Service添加了Label `needMonitor: 'true'`

## 添加ServiceMonitor

ServiceMonitor是Prometheus Operator定义的CRD：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ...
  namespace: ...
spec:
  selector:
    matchLabels:
      needMonitor: 'true'
  endpoints:
  - port: http-metrics
    path: /metrics
```

这样Prometheus就能把同namespace下的所有`needMonitor: 'true'`的Service的JMX Exporter都采集到。

## 给Grafana添加JVM Dashboard

你需要给Grafana添加JVM Dashboard，在这之前你需要设置Grafana的admin密码，进入项目找到Grafana，进入其Shell：

<img src="step-4.png" style="zoom:50%" />

执行：

```bash
grafana-cli admin reset-admin-password <新密码>
```

然后随便进入一个Deployment/StatefulSets，进入Grafana：

<img src="step-5.png" style="zoom:50%" />

用admin账号和你刚才设置的密码登录进去，进入管理页面导入Dashboard：

<img src="step-6.png" style="zoom:50%" />

到 https://grafana.com/orgs/chanjarster/dashboards 找到 [JVM dashboard (for Prometheus Operator)](https://grafana.com/grafana/dashboards/8878)，看到它的编号是8878。把这个编号填到导入页面：

<img src="step-7.png" style="zoom:50%" />

然后大功告成：

<img src="step-8.png" style="zoom:50%" />