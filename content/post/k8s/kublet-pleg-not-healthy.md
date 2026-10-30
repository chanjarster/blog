---
title: "Kublet PLEG不健康问题排障"
author: "颇忒脱"
tags: ["k8s", "troubleshooting"]
date: 2019-02-18T09:30:06+08:00
---

<!--more-->

环境：Rancher管控的K8S集群。

现象：某个Node频繁出现“PLEG is not healthy: pleg was last seen active 3m46.752815514s ago; threshold is 3m0s”错误，频率在5-10分钟就会出现一次。

排查：

1. `kubectl get pods --all-namespaces` 发现有一个`istio-ingressgateway-6bbdd58f8c-nlgnd`一直处于Terminating状态，也就是说杀不死。
1. 到Node上`docker logs --tail 100 kubelet`也看到这个Pod的状态异常：

 ```txt
 I0218 01:21:17.383650   10311 kubelet.go:1775] skipping pod synchronization - [PLEG is not healthy: pleg was last seen active 3m46.752815514s ago; threshold is 3m0s]
 ...
 E0218 01:21:30.654433   10311 generic.go:271] PLEG: pod istio-ingressgateway-6bbdd58f8c-nlgnd/istio-system failed reinspection: rpc error: code = DeadlineExceeded desc = context deadline exceeded
 ```
1. 用`kubelet delete pod`尝试删除，命令挂住。
1. 用`kubectl delete pod --force --grace-period=0`，强制删除Pod。
1. 再到Node上检查这个容器是否真的被停止，`docker ps -a| grep ingressgateway-6bbdd58f8c-nlgnd`，看到容器处于Exited状态。
1. 观察Node状态，问题依旧。
1. 把Pod关联的Deployment删除，把一只处于Terminating的Pod用`kubectl delete pod --force --grace-period=0`的方式删除。
1. 重新部署Deployment。
1. 问题解决。

相关[issue][gh-issue]

[gh-issue]: https://github.com/kubernetes/kubernetes/issues/51835
