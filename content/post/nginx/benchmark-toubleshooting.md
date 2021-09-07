---
title: "某次压力测试中对Nginx的排障"
author: "颇忒脱"
tags: ["nginx", "troubleshooting"]
date: 2021-09-07T08:02:45+08:00
---

<!--more-->

某次压力测试时，Jmeter得到大量connection reset、connect timeout的错误。

## 拓扑

```
Jmeter -> nginx[:9001] -> k8s worker[:80](ingress-nginx) -> k8s pod[:10080]
```

## 观察nginx

nginx采用的是四层代理，用的是[stream模块][1]

查看 `/var/log/nginx/error.log`，看到大量`too many open files`的错误。

观察`ulimit -a`得到`open files (-n) 1024`，这个值太小了，采用[这个方式调大][2]。

## 优化nginx

再优化nginx，调整 `/etc/nginx/nginx.conf` 。

调整[worker_processes][5]，默认值是 1，改为auto。

```
worker_processes  auto;
```

调整[worker_connections][6]，默认值是512太小了，压测并发有15000，因为服务器有10核，woker_processes的实际值是10，所以调整到1600，那么总共就是16000。

```
worker_connections 1600;
```

调整[worker_rlimit_nofile][3]到16000，该值小于不能总的worker_connections：

```
worker_rlimit_nofile 16000;
```



再次压测后，Jmeter得到502 bad gateway等错误。

观察nginx的 `/var/log/nginx/error.log` ，没有新的错误日志产生。

## 观察ingress nginx

先设置ingress nginx配置 [disable-access-log=true][8] ，关闭access log打印，可以让我们专注在错误日志上。

观察ingress nginx日志，发现先有大量Connection timed out错误：

```
[error] 46#46: *7495 upstream timed out (110: Connection timed out) while connecting to upstream
....
```

然后出现大量Cannot assign requested address的错误：

```
[crit] 46#46: *10527 connect() to 10.42.5.220:10080 failed (99: Cannot assign requested address) while connecting to upstream
```

看来是ingress nginx和Pod的连接超时了，根据[ingress nginx文档][7]，`proxy-connection-timeout`默认值5秒，太短了，调整到60秒。

再次压测后Connection timed out问题没有了，而且Cannot assign requested address也没有了。



[1]: http://nginx.org/en/docs/stream/ngx_stream_core_module.html
[2]: ../linux/limits
[3]: http://nginx.org/en/docs/ngx_core_module.html#worker_rlimit_nofile
[4]: http://nginx.org/en/docs/ngx_core_module.html#worker_connections
[5]: http://nginx.org/en/docs/ngx_core_module.html#worker_processes
[6]: http://nginx.org/en/docs/ngx_core_module.html#worker_connections
[7]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
[8]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#disable-access-log