---
title: "连接Rancher中的Prometheus的方法"
author: "颇忒脱"
tags: ["k8s", "prometheus", "rancher"]
date: 2021-01-06T10:59:27+08:00
---

<!--more-->

如果Rancher里[启用了监控][1]，那么Rancher会为你安装一套Prometheus+Grafana，本文介绍如何连接这个Prometheus的方法。

### 找到Prometheus的连接密码

1. 进入`System`项目
2. 找到`cattle-prometheus`下的 `prometheus-cluster-monitoring` StatefulSets
3. 选择`prometheus-proxy`容器，进入命令行终端
4. `cat /var/cache/nginx/nginx.conf`查看Nginx配置，可以发现下面内容：

```txt
proxy_set_header    Authorization "Bearer ...";
```

记住这个`Authorization`请求头，还有它的值（包含`Bearer部分`）。

之后每次请求Prothemeus的时候都需要带上这个请求头。

这个Prometheus的集群内访问地址是：`http://prometheus-operated.cattle-prometheus.svc:9090`

### 在Grafana中配置数据源

如果你有自己的Grafana，那么需要配置Custom HTTP Headers，把上面的`Authorization`请求头配置上去，这样就能够连接到了。

[1]: https://docs.rancher.cn/docs/rancher2/cluster-admin/tools/monitoring/_index