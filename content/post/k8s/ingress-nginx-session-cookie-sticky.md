---
title: "Nginx Ingress的Cookie粘滞策略"
author: "颇忒脱"
tags: ["k8s"]
date: 2019-12-03T15:16:23+08:00
---

<!--more-->

如果你的应用部署在K8S上，replicas &gt; 1，且你的应用是基于Session的，**同时又没有做Session共享or复制**，那么你是不能通过NodePort Service来暴露应用的，因为Service只支持一种策略，就是轮询，这样会导致用户的Session丢失。

默认的Ingress的配置也是轮询的，但是你可以启用基于Cookie的粘滞策略，当用户第一次访问的时候会得到一个Cookie，该Cookie记录了所访问的Pod，再下一次访问的时候Nginx Ingress Controller会将请求转发到同一个Pod上，从而实现Session粘滞。

关键的两个Annotation：

* `nginx.ingress.kubernetes.io/affinity: cookie`
* `nginx.ingress.kubernetes.io/affinity-mode: persistent`

更多参考[Session Affinity](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#session-affinity)。