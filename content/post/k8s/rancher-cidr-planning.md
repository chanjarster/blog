---
title: "Rancher K8S 集群子网规划"
date: 2022-11-16T10:24:45+08:00
tags: ["k8s", "rancher", "network"]
author: "颇忒脱"
---

<!--more-->

规划好子网：

* Pod 和 Service 的总体子网空间
* 每个节点所能使用的子网空间

默认值：

* Pod CIDR：10.42.0.0/16
* Service CIDR：10.43.0.0/16
* node-cidr-mask-size：24

关键是 `node-cidr-mask-size` ，它决定了集群可以有多少个节点，以及每个节点的 IP 数量。

以默认情况为例，node 的数量是 24 - 16 = 8，2 ^ 8 = 256 个节点。而每个节点可以有 32 - 24 = 8，2 ^ 8 = 256 个 IP。

其实你看 Pod 的 IP 可以发现，第一个节点的上的 IP 是 10.42.0.xxx，第二个节点的 IP 是 10.42.1.xxx，以此类推。

当然情况会随着参数的变化而变化。

下面是修改的方法，修改 RKE 需要的 `cluster.yml`：

```yaml
...
services:
  kube-api:
    service_cluster_ip_range: 10.101.251.0/24
  kube-controller:
    cluster_cidr: 10.101.252.0/24
    service_cluster_ip_range: 10.101.251.0/24
    extra_args:
      node-cidr-mask-size: 26
  kubelet:
    cluster_dns_server: 10.101.251.10
```

上面这个例子可以容纳 4 个 node，而每个 node 最多有 64 个 IP，同时也把 DNS 服务器的 IP 地址也修改了一下。

参考资料：

* https://cloud.google.com/kubernetes-engine/docs/how-to/flexible-pod-cidr?hl=zh-cn
* https://github.com/rancher/rke/issues/830
* https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
* https://docs.rancher.cn/docs/rke/config-options/services/_index/
* https://docs.rancher.cn/docs/rancher2.5/cluster-provisioning/rke-clusters/options/_index
* https://github.com/flannel-io/flannel/blob/master/Documentation/configuration.md
