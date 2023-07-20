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

## 参考文档

* [Rancher - 安全加固指南 - v2.5.0 - CIS1.5][1]
* [Rancher - 使用 RKE 安装 Kubernetes][2]
* [RKE - 升级指南][3]

[1]: https://docs.rancher.cn/docs/rancher2.5/security/rancher-2.5/1.5-hardening-2.5/_index
[2]: https://docs.rancher.cn/docs/rancher2.5/installation/resources/k8s-tutorials/ha-rke/_index#%E5%AE%89%E8%A3%85-kubernetes
[3]: https://docs.rancher.cn/docs/rke/upgrades/_index/