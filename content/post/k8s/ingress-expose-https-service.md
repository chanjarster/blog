---
title: "Ingress 代理 HTTPS Backend 的方法"
date: 2022-07-13T08:57:26+08:00
tags: ["k8s", "ingress"]
author: "颇忒脱"
---

<!--more-->

如果你有一个服务，它是 HTTPS 协议的，那么需要在 Ingress 上添加 Annotation：

```yaml
nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

[1]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#backend-protocol