---
title: "K8S中的TLS证书管理方案"
author: "颇忒脱"
tags: ["k8s", "tls"]
date: 2019-09-04T09:54:20+08:00
draft: false
---

本文介绍几种在K8S中管理TLS证书的方案。

<!--more-->

## 证书申请方案

先看如何申请证书。

### cert-manager

[cert-manager][cert-manager]是一个集成在k8s中的工具，它可以做到自动从Let's encrypt申请证书、自动更新证书、与Ingress无缝结合。

大多数情况下建议与Ingress集成的方式使用它，后面会讲。如果你仅需要签发功能，不需要和Ingress集成，则可参考[Setting up Issuers][cert-manager-setup-issuer]和[Issuing Certificates][cert-manager-issuing-certs]。

优点：

1. 自动签发
2. 自动续期
3. 与K8S集成良好
4. 免费

缺点：

1. 只能签发Server Auth证书，不能签发Client Auth证书
2. 证书仅用做认证，没有商业版证书更高级的功能

### 阿里云平台购买

比如你可以在阿里云上[购买SSL证书][aliyun-ssl]，一个账号的[最多申请100个证书][aliyun-ssl-quota]

优点：

1. 多种类型证书可以供选择，有免费的有收费的
2. 可在平台上管理
3. 申请的证书可用在其他产品上，比如SLB

缺点：

1. 与K8S集成不好，需要手动导入到Secret中才能使用
2. 只能签发Server Auth证书，不能签发Client Auth证书

### 用CFSSL自签发

你可以使用CFSSL自签发证书，有一篇[参考文档][cfssl]。

优点：

1. 可签发Client Auth证书

缺点：

1. 手动管理证书
2. 与K8S集成不好，需要手动导入到Secret中才能使用
3. 自签发的Server Auth证书在浏览器端会报警告

### 总结

对于Server Auth证书：

* 如果只是开发或者演示环境，cert-manager方案更适合你
* 如果是生产环境或者对证书有更高要求的，可以采用从平台购买的方案

对于Client Auth证书：

* 你只能选择用CFSSL自签发的方式

## 证书部署方案

下面介绍几种部署方案。

### 部署在阿里云SLB上

虽然本小节讲的是部署在阿里云的SLB的产品上，但是它的思路和优缺点在其他云平台上基本是一致的。

做法是在SLB上[配置HTTPS监听][aliyun-slb-https-port]，ACK（阿里云Kubernetes）在创建集群的时候会自动创建几个SLB实例，不要在这几个实例上配置HTTPS监听，因为在ACK中创建Type=LoadBalancer的Service的时候[会把你做的配置刷新掉][ack-svc-lb-doc]。

支持：

1. Server Auth
2. Client Auth

优点：

1. 可利用阿里云的SSL证书管理功能
2. 可用在阿里云的其他产品上，比如ECS

缺点：

1. 不支持SNI，如果你有多个域名，因为一个SLB只会有一个公网IP，此时你就有两种选择：

   * 在一个SLB上配置多个监听端口，这样URL中就会携带端口

   * 配置多个SLB，避免前面一个方案的问题

2. 要自己手动配置服务器组之类的信息

3. K8S Service类型得是Node Port，意味着在同一VPC子网内部流量不受保护

4. K8S集群内部流量不受保护

### LoadBalancer Service

[创建Type=LoadBalancer的Service][ack-svc-lb-doc]来暴露服务，然后在Deployment/StatefulSets里部署证书。

支持：

1. Server Auth
2. Client Auth

优点：

1. 集群内部流量受保护
2. VPC子网内部流量受保护

缺点：

1. 不支持SNI，而且因为你只可能有一个公网IP，因此URL中必定要携带端口
2. 在应用中配置证书，且方式方法与应用所使用[架构/类库][tls-learn]有关

### Ingress配合cert-manager

前面说过cert-manager支持与Ingress集成，你很少的工作能够配置Server Auth，和一个稍微复杂一点的步骤配置Client Auth，详情可参考[这篇文章][ingress-cert-manager]。

支持：

1. TLS Server Auth
2. TLS Client Auth
3. SNI，即一个443端口对应多个域名

优点：

1. Server Auth证书自动签发、自动续期
2. Client Auth手动配置
3. 对应用的侵入性为0

缺点：

1. 集群内部流量不受保护，这个问题可以通过Network Policy做namespace隔离来缓解

### 总结

优先考虑Ingress配合cert-manager的方案。

如果你对安全性有很高的要求，那么考虑LoadBalancer Service。



[cert-manager]: https://docs.cert-manager.io/en/latest
[cert-manager-setup-issuer]: http://docs.cert-manager.io/en/latest/tasks/issuers/index.html
[cert-manager-issuing-certs]: http://docs.cert-manager.io/en/latest/tasks/issuing-certificates/index.html
[aliyun-ssl]: https://www.aliyun.com/product/cas
[aliyun-ssl-quota]: https://help.aliyun.com/document_detail/90792.html
[cfssl]: https://github.com/chanjarster/tls-client-auth-samples/blob/master/certs/index.md
[aliyun-slb-https-port]: https://help.aliyun.com/document_detail/86438.html
[ack-svc-lb-doc]: https://help.aliyun.com/document_detail/86531.html
[tls-learn]: https://github.com/chanjarster/tls-client-auth-samples
[ingress-cert-manager]: https://github.com/chanjarster/tls-client-auth-samples/blob/master/server/ingress-nginx/index.md