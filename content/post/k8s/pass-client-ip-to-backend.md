---
title: "传递Client Ip到Ingress后端"
author: "颇忒脱"
tags: ["k8s","ingress"]
date: 2019-10-25T14:26:23+08:00
---

<!--more-->

## 部署拓扑

1. 前端一个Nginx服务器做反向代理（4层或7层）到各worker节点。这个服务器的IP记为IP-A。
2. K8S集群里部署了Ingress Controller
3. K8S集群是由Rancher创建的

## 问题

在K8S集群中部署了inanimate/echo-server 看到`X-Forwarded-For`请求头得到的是IP-A，而不是客户端IP。

## 七层代理解决办法

如果前端Nginx服务器使用的是http模式（即7层代理），并且在转发的时候添加了`X-Real-IP`和`X-Forwarded-For`两个请求头：

```
location / {
  ...
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_http_version 1.1;
  proxy_pass ....;
  ...
}
```

修改ingress-nginx 命名空间下的nginx-configuration ConfigMap，添加`use-forwarded-headers: true`

## 四层代理解决办法

如果前端Nginx服务器使用的是stream模式（即4层代理）

1. 修改ingress-nginx 命名空间下的nginx-configuration ConfigMap，添加`use-proxy-protocol: true`

2. 修改Nginx服务器添加`proxy_protocol on;`指令：

   ```txt
   server {
       listen     80;
       proxy_pass worker_nodes_http;
       proxy_protocol on;
   }
   server {
       listen     443;
       proxy_pass worker_nodes_https;
       proxy_protocol on;
   }    
   ```

3. 重启Nginx服务器

### 坑

* 前端Nginx和后端Nginx要么同时开启PROXY protocol那么同时关闭，否则会无法访问。
* 不要修改Rancher自己的Nginx Ingress的配置，一旦修改你就完了，kubectl会无法使用。

### 参考资料

* [Passing the Client’s IP Address to the Backend][1]
* [Configuring NGINX to Accept the PROXY Protocol][2]
* [Ingress Nginx ConfigMaps - use-proxy-protocol][3]
* [Ingress Nginx ConfigMaps - use-forwarded-headers][4]

[1]: https://www.nginx.com/blog/tcp-load-balancing-udp-load-balancing-nginx-tips-tricks/#IpBackend
[2]: https://docs.nginx.com/nginx/admin-guide/load-balancer/using-proxy-protocol/#configuring-nginx-to-accept-the-proxy-protocol
[3]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#use-proxy-protocol
[4]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#use-forwarded-headers