---
title: "让Ingress Nginx支持TLSv1的方法"
author: "颇忒脱"
tags: ["k8s", "ingress"]
date: 2019-12-16T08:59:27+08:00
---

<!--more-->

Ingress Nginx默认只支持TLSv1.2，如果想要使其支持更旧版本，则需要修改它的ConfigMap，添加以下KV：

```txt
ssl-protocols: "TLSv1 TLSv1.1 TLSv1.2"
ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA"
```

注意`ssl-ciphers`不是随便写的，你可通过[Mozilla SSL Configuration Generator][3]生成。

验证方法：

你可用过curl来验证：`curl --tlsv1 --tls-max 1.0 <url>`，如果成功得到结果则说明服务端启用了TLSv1的支持。

也可以使用`mvance/testssl`来验证，它能检查得更多：`docker run --rm -it mvance/testssl -p <url>`

参考文档：

* [Default TLS Version and Ciphers][1]
* [SSL Ciphers][2]

[1]: https://kubernetes.github.io/ingress-nginx/user-guide/tls/#default-tls-version-and-ciphers
[2]: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#ssl-ciphers
[3]: https://mozilla.github.io/server-side-tls/ssl-config-generator/