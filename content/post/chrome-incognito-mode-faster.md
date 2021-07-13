---
title: "Chrome隐私模式网页加载速度更快"
date: 2021-07-13T09:24:00+08:00
tags: ["troubleshooting", "network", "chrome"]
author: "颇忒脱"
draft: false
---

<!--more-->

A客户现场反馈，访问我司某应用时，页面加载需要10~20秒，而同样应用在B客户只需要3秒。在排查这个问题的过程中无意中发现，使用Chrome的无痕模式（Incognito）和正常模式访问，页面加载速度天差地别，隐私模式只需2~3秒。

正常模式：

![正常模式](normal.jpg)

无痕模式：

![无痕模式](incognito.jpg)

仔细对比之后发现，对于同一个资源的下载，正常模式的**Stalled**时间高处无痕模式更长。

正常模式：

<img src="normal-timing.jpg" style="zoom:50%" />

无痕模式：

<img src="incognito-timing.jpg" style="zoom:50%" />

根据Chrome对于**Stalled**的[解释][1]，有三个原因：

- There are higher priority requests.
- There are already six TCP connections open for this origin, which is the limit. Applies to HTTP/1.0 and HTTP/1.1 only.
- The browser is briefly allocating space in the disk cache

因为访问的是同一个网站，发出的请求是一样的，因此前两条排除，那么只有可能是最后一条——磁盘缓存阻塞。

在Chromium的[wiki][2]中发现无痕模式的Cache采用的是内存实现，普通模式采用的是磁盘实现：

> Chromium has two different implementations of the cache interfaces: while the main one is used to store info on a given disk, there is also a very simple implementation that doesn’t use a hard drive at all, and stores everything in memory. The in-memory implementation is used for the *Incognito* mode

[1]: https://developer.chrome.com/docs/devtools/network/reference/#timing-explanation
[2]: https://www.chromium.org/developers/design-documents/network-stack/disk-cache#TOC-Implementation-Notes

