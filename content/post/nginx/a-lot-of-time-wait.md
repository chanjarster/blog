---
title: "Nginx 造成 Upstream 服务器大量 TIME_WAIT 连接"
author: "颇忒脱"
tags: ["nginx", "troubleshooting", "network"]
date: 2023-02-01T11:02:45+08:00
---

<!--more-->

## 网络拓扑

``` 
[JMeter] -> [ Nginx ] ----> [ Web Server ]
```

## 现象

在压力测试期间，在 Web Server 服务器存在大量来自 Nginx 的 `TIME_WAIT` 连接：

```shell
$ netstat -antpl | awk '{print $5, $6}' | sed 's/:[[:print:]]* /\t/g' | sort | uniq -c | sort -rn
  30020 TIME_WAIT <nginx-ip>
     ...
```

`TIME_WAIT` 是在 TCP 协议 4 次挥手过程中的中间状态，过一段时间都会消失。

## 分析

这里存在两个疑点：

1. `TIME_WAIT` 状态的连接数量超出了 JMeter 的并发数（500）
2. 而 JMeter 脚本里都是开启了 Keep-Alive 的

这个现象看上去就像是 Nginx -> Web Server 的连接没有 Keep Alive，导致每次请求都重新建立了连接然后又断开。

查看 Nginx 配置文件：

```
upstream web_server {
    server <ip1>:8080 max_fails=20;
    keepalive 500;
}

map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      close;
}

server {
    listen 80;
    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://web_server;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 900s;
        proxy_buffering off;
    }
}
```

可以看到，已经配置了 [keepalive][2] 指令，但是看上去没有生效。

不过查看 [keepalive][2] 指令的文档发现，它需要配合把 `Connection` 请求头设置为 `""` 才可以使用：

```
upstream http_backend {
    ...
    keepalive 16;
}

server {
    ...
    location /http/ {
        ...
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        ...
    }
}
```

而实际上的 `Connection` 是这样的：

```
map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      close;
}

server {
    listen 80;
    location / {
        ...
        proxy_set_header Connection $connection_upgrade;
        ...
    }
}
```

为什么这样配置呢？这是抄了 Nginx 关于代理 Websocket 的一篇[官方博客][1]。

根据上面的配置这个 `Connection` 实际上的值是 `close`，所以才会每次请求都会断开连接，然后新的请求又创建连接，然后导致大连 `TIME_WAIT` 的 TCP 连接。

## 结论

修改 `map` 指令，改成下面这样问题解决：

```
map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      '';
}
```

[1]: http://nginx.org/en/docs/http/websocket.html
[2]: https://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive