---
title: "CentOS 7.9 给 Nginx 编译 Sticky 模块"
author: "颇忒脱"
tags: ["nginx"]
date: 2022-12-02T11:02:45+08:00
---

<!--more-->

Nginx Sticky 模块可用于配置基于 Cookie 的粘滞策略，但它并不是 Nginx 默认自带的模块，需要重新编译 Nginx 才能用到，下面讲配置方法。

## 编译 & 安装

下载 Nginx [1.22.2 源码][1] 和 Nginx Sticky [源码][2] 并解压缩：

```shell
cd /root
wget https://nginx.org/download/nginx-1.22.1.tar.gz
wget https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/08a395c66e42.zip
tar -xvf nginx-1.22.1.tar.gz
unzip 08a395c66e42.zip && mv nginx-goodies-nginx-sticky-module-ng-08a395c66e42 nginx-sticky-module-ng
```

安装编译需要的软件：

```shell
yum install -y \
 git gcc make zlib-devel openssl-devel pcre-devel \
 libxml2-devel libxslt-devel libgcrypt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel
```

创建用户和用户组和目录：

```shell
useradd --system --no-create-home --shell /usr/sbin/nologin --user-group nginx
mkdir -p /var/lib/nginx && chown nginx /var/lib/nginx && chgrp nginx /var/lib/nginx
```

然后开始编译 Nginx：

```shell
cd /root/nginx-1.22.1

./configure \
 --prefix=/usr/share/nginx \
 --conf-path=/etc/nginx/nginx.conf \
 --http-log-path=/var/log/nginx/access.log \
 --error-log-path=/var/log/nginx/error.log \
 --pid-path=/var/run/nginx.pid \
 --lock-path=/var/run/nginx.lock \
 --modules-path=/usr/lib64/nginx/modules \
 --sbin-path=/usr/sbin/nginx \
 --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
 --http-proxy-temp-path=/var/lib/nginx/proxy \
 --http-scgi-temp-path=/var/lib/nginx/scgi \
 --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
 --user=nginx \
 --group=nginx \
 --with-pcre \
 --with-pcre-jit \
 --with-threads \
 --with-select_module \
 --with-poll_module \
 --with-file-aio \
 --with-http_ssl_module \
 --with-http_v2_module \
 --with-http_realip_module \
 --with-http_addition_module \
 --with-http_xslt_module=dynamic \
 --with-http_image_filter_module \
 --with-http_geoip_module=dynamic \
 --with-http_sub_module \
 --with-http_dav_module \
 --with-http_flv_module \
 --with-http_mp4_module \
 --with-http_gunzip_module \
 --with-http_gzip_static_module \
 --with-http_auth_request_module \
 --with-http_random_index_module \
 --with-http_secure_link_module \
 --with-http_degradation_module \
 --with-http_slice_module \
 --with-http_stub_status_module \
 --without-http_charset_module \
 --with-http_perl_module \
 --with-stream=dynamic \
 --with-stream_ssl_module \
 --with-stream_realip_module \
 --with-stream_geoip_module=dynamic \
 --with-stream_ssl_preread_module \
 --with-openssl-opt=no-nextprotoneg \
 --with-mail=dynamic \
 --with-mail_ssl_module \
 --add-module=/root/nginx-sticky-module-ng

make && make install
```

更多编译参数[参考这里][3]。

## 创建 Systemd 服务

新建 `/etc/systemd/system/nginx.service` 文件：

```
cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=nginx - high performance web server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

[Install]
WantedBy=multi-user.target
EOF
```

然后启动 Nginx 服务并将其设定为开机自启动：

```shell
systemctl start nginx.service
systemctl enable nginx.service
```
## 测试

修改 `/etc/nginx/nginx.conf`：

```nginx
...
http {
  upstream test {
    sticky name=srv_id expires=12h domain=xxx.example.com path=/ secure httponly;
    server 1.1.1.1:8080;
  }
}
```

然后测试：

```shell
$ nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## 用法

完整用法见这里：https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/src/master/

为了方便，这里把用法在这里粘贴了一份：


    upstream {
      sticky;
      server 127.0.0.1:9000;
      server 127.0.0.1:9001;
      server 127.0.0.1:9002;
    }

	  sticky [name=route] [domain=.foo.bar] [path=/] [expires=1h] 
           [hash=index|md5|sha1] [no_fallback] [secure] [httponly];
  
  
- name:    the name of the cookies used to track the persistant upstream srv; 
  default: route

- domain:  the domain in which the cookie will be valid
  default: nothing. Let the browser handle this.

- path:    the path in which the cookie will be valid
  default: /

- expires: the validity duration of the cookie
  default: nothing. It's a session cookie.
  restriction: must be a duration greater than one second

- hash:    the hash mechanism to encode upstream server. It cant' be used with hmac.
  default: md5

    - md5|sha1: well known hash
    - index:    it's not hashed, an in-memory index is used instead, it's quicker and the overhead is shorter
    Warning: the matching against upstream servers list
    is inconsistent. So, at reload, if upstreams servers
    has changed, index values are not guaranted to
    correspond to the same server as before!
    USE IT WITH CAUTION and only if you need to!
 
- hmac:    the HMAC hash mechanism to encode upstream server
    It's like the hash mechanism but it uses hmac_key
    to secure the hashing. It can't be used with hash.
    md5|sha1: well known hash
    default: none. see hash.

- hmac_key: the key to use with hmac. It's mandatory when hmac is set
           default: nothing.

- no_fallback: when this flag is set, nginx will return a 502 (Bad Gateway or
              Proxy Error) if a request comes with a cookie and the
              corresponding backend is unavailable.

- secure    enable secure cookies; transferred only via https
- httponly  enable cookies not to be leaked via js

## 清理 Nginx

```shell
systemctl stop nginx
systemctl disable nginx
rm -rf \
 /etc/nginx \
 /var/log/nginx \
 /var/run/nginx* \
 /usr/lib64/nginx \
 /var/lib/nginx \
 /usr/sbin/nginx \
 /usr/share/nginx \
 /etc/systemd/system/nginx.service
```

## 参考资料

- [Installing Nginx From Source on CentOS 7][4]

[1]: https://nginx.org/en/download.html
[2]: https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/downloads/
[3]: https://nginx.org/en/docs/configure.html
[4]: https://tylersguides.com/guides/installing-nginx-from-source-on-centos-7/
