---
title: "Ingress Controller根据User-Agent和IP控制访问"
author: "颇忒脱"
tags: ["k8s", "cheatsheet", "ingress", "nginx"]
date: 2022-04-27T09:32:21+08:00
---

<!--more-->

本例子讲的是怎么根据 User-Agent 和 IP 来控制访问（白名单模式），需求如下：

* 如果请求来自 DingTalk 浏览器，不论内外网，都可以访问
* 如果请求来自非 DingTalk 浏览器，只有内网可以访问

本文修改 System项目 > ingress-nginx 命名空间 > nginx-configration ConfigMap

添加 `http-snippet` key，值为：

```
# User-Agent 白名单
map $http_user_agent $allow_agent {
  # 默认不允许
  default    0;
  # DingTalk 允许
  ~DingTalk  1;
}

# IP 白名单
map $remote_addr $allow_remote_addr {
  # 默认不允许
  default         0;
  # 允许的 IP
  ~10\.100\..+    1;
  ~127\.0\.0\.1   1;
}
```

注意 `~DingTalk` 前面的 `~` ，这是正则表达式匹配，其余的也是一样。

添加 `server-snippet` key，值为：

```
set $agent_inner "";
if ($allow_agent = 0) {
  # 不是允许的User-Agent
  set $agent_inner F;
}
if ($allow_remote_addr = 0) {
  # 不是允许的 IP
  set $agent_inner "${agent_inner}F";
}
if ($agent_inner = FF) {
  # User-Agent 和 IP 都不允许，拒绝访问
  return 403;
}
```

参考资料：

* [Ingress Nginx ConfigMap - http-snippet][1]
* [Ingress Nginx ConfigMap - server-snippet][2]
* [Multiple if Conditions in Nginx][3]
* [nginx if 指令][4]
* [nginx map 指令][5]
* [nginx remote_addr 变量][6]
* [nginx http_user_agent 变量][7]

[1]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#http-snippet
[2]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#server-snippet
[3]: https://ezecodes.wordpress.com/2016/06/30/multiple-if-conditions-in-nginx/
[4]: https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#if
[5]: https://nginx.org/en/docs/http/ngx_http_map_module.html#map
[6]: https://nginx.org/en/docs/http/ngx_http_core_module.html#var_remote_addr
[7]: https://nginx.org/en/docs/http/ngx_http_core_module.html#variables