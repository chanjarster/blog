---
title: "为 CoreDNS 配置 hosts 静态解析"
author: "颇忒脱"
tags: ["k8s","coredns","rancher"]
date: 2022-12-06T09:30:27+08:00
---

<!--more-->

CoreDNS 是 Rancher 默认的 DNS 组件，现在想在它返回 hosts 静态文件结果，而不是到上游 DNS 服务器去查询。

这样可以解决上游 DNS 服务器压根就没有办法解析所查询域名的问题。

## 1）配置 hosts ConfigMap

在 kube-system 命名空间下，新建一个 ConfigMap `coredns-hosts`：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-hosts
  namespace: kube-system
data:
  coredns-hosts: |-
    127.0.0.1 baidu.com
    127.0.0.2 www.baidu.com
```

根据情况修改 `coredns-hosts` 的内容。

## 2）修改 coredns deployment

修改 kube-system 命名空间下 Deployment `coredns`，将 ConfigMap `coredns-hosts` 挂载到 Pod 的 `/etc/hosts-custom/coredns-hosts`，注意下面的 `volumeMounts` 和 `volumes` 部分：

```
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    ...
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: CoreDNS
  name: coredns
  namespace: kube-system
  ...
spec:
  ...
  template:
    metadata:
      ...
    spec:
      ...
      containers:
      - ...
        image: rancher/mirrored-coredns-coredns:1.8.0
        ...
        volumeMounts:
        ...
        - mountPath: /etc/hosts-custom
          name: coredns-hosts
      
      volumes:
      ...
      - configMap:
          defaultMode: 420
          name: coredns-hosts
          optional: false
        name: coredns-hosts

```
## 3）修改 CoreDNS 配置

修改 kube-system 命名空间下 ConfigMap `coredns`，Key `Corefile` 就是它的配置文件，添加这么 3 行：

```
{
    ...
    hosts /etc/hosts-custom/coredns-hosts <zone1> <zone2> ... {
      fallthrough <zone1> <zone2> ...
    }
    ...
}
```

上述 `<zone>` 的意思则是域名后缀，比如 `edu.cn` 那么所有后缀是 `.edu.cn` 的域名查询都会到 `/etc/hosts-custom/coredns-hosts` 里去找答案。

`fallthrough` 则是用来设置哪些 `<zone>` 找不到答案时可以递交给上游 DNS 服务器查询。

## 4）加载配置

CoreDNS 会自动加载配置（无需重启），如果你修改了 hosts 文件它也会自动加载。

然后进入任意 Pod 用 nslookup 来实验即可。

## 参考资料

* [CoreDNS hosts Plugin](https://coredns.io/plugins/hosts/)