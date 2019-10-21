---
title: "K8S中Service的FQDN"
author: "颇忒脱"
tags: ["k8s"]
date: 2019-10-21T09:32:21+08:00
---

<!--more-->

Service在集群内部的DNS全名：<service名字>.<namespace名字>.svc.<zone名字>

Zone名字一般是`cluster.local`，可以通过`kubectl -n kube-system get configmaps coredns -o yaml`查看coredns配置来得到：

```txt
  Corefile: |
    .:53 {
        errors
        health

        kubernetes cluster.local in-addr.arpa ip6.arpa {

           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

## 相关资料

* [Pod 与 Service 的 DNS][doc-1]
* [Customizing DNS Service][doc-2]
* [Kubernetes DNS-Based Service Discovery][dns-3]



[dns-1]: https://kubernetes.io/zh/docs/concepts/services-networking/dns-pod-service/
[dns-2]: https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
[dns-3]: https://github.com/kubernetes/dns/blob/master/docs/specification.md

