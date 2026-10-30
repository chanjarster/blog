---
title: "Rancher 给 kube-apiserver 开启 pprof"
author: "颇忒脱"
tags: ["rancher", "k8s", "pprof", "go"]
date: 2023-07-20T13:55:10+08:00
---

<!--more-->

注意：本文档没有亲自试验过，仅供参考。

## 步骤

先看 kuber-apiserver 的启动参数：

```shell
docker inspect kube-apiserver
...
"Args": [
    ...
    "--profiling=false",
    ...
]
```

可以看到 profiling 没有开，因此 `/debug/pprof` 接口是没有办法调用的。

编辑 RKE cluster.yaml，把 profiling 打开：

```yaml
services:
  kube-api:
    ...
    extra_args:
      profiling: "true"
```

然后使用 RKE 升级集群：

```shell
rke up --config ./rancher-cluster.yml
```

然后启动（注意 `kube_config_cluster.yml` 是 RKE 安装 K8S 之后生成的）：

```shell
kubectl --kubeconfig kube_config_cluster.yml proxy
Starting to serve on 127.0.0.1:8001
```

访问浏览器 `http://localhost:8001/debug/pprof`

## 参考文档

* [Rancher - 安全加固指南 - v2.5.0 - CIS1.5][1]
* [Rancher - 使用 RKE 安装 Kubernetes][2]
* [RKE - 升级指南][3]
* [kube-apiserver内存溢出问题调查及go tool pprof工具的使用][4]

[1]: https://docs.rancher.cn/docs/rancher2.5/security/rancher-2.5/1.5-hardening-2.5/_index
[2]: https://docs.rancher.cn/docs/rancher2.5/installation/resources/k8s-tutorials/ha-rke/_index#%E5%AE%89%E8%A3%85-kubernetes
[3]: https://docs.rancher.cn/docs/rke/upgrades/_index/
[4]: https://segmentfault.com/a/1190000039649589