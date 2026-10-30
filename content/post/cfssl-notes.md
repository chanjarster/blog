---
title: "CFSSL笔记"
author: "颇忒脱"
tags: ["openssl"]
date: 2019-05-02T16:00:47+08:00
---

<!--more-->

## Doc

* [Introducing CFSSL - CloudFlare's PKI toolkit](https://blog.cloudflare.com/introducing-cfssl/)
* [cfssl bootstrap](https://github.com/cloudflare/cfssl/blob/master/doc/bootstrap.txt)，这个文档里面有错误
* [cfssl config](https://github.com/cloudflare/cfssl/blob/master/doc/cmd/cfssl.txt)，列出了config.json所有的字段
* [db-config.json](https://github.com/cloudflare/cfssl/blob/master/certdb/README.md)，db-config.json的样子，亲测mysql不行，有bug
* [remote_auth](https://github.com/cloudflare/cfssl/issues/566#issuecomment-269070807)，bootstrap文档中的一个错误，用`remote_auth`

## CRL

* [CRL Support](https://github.com/cloudflare/cfssl/wiki/CRL-Support)，稍微解释了一下CFSSL怎么支持CRL的，但是并没有什么用

* [cfssl使用十进制而不是十六进制来读取serial number](https://github.com/cloudflare/cfssl/issues/979)

## How Tos

* [How to build your own public key infrastructure](https://blog.cloudflare.com/how-to-build-your-own-public-key-infrastructure/)，可以大致看一看，有些地方有错误
* [Certificate Authority with CFSSL](https://jite.eu/2019/2/6/ca-with-cfssl/)，讲了怎么利用Intermediate CA签发
* [Integration of CFSSL with the Lemur Certificate Manager](https://www.howtoforge.com/tutorial/integration-of-cfssl-with-the-lemur-certificate-manager/)，CFSSL和Lemur CM集成的例子，也讲了怎么做Intermediate CA
