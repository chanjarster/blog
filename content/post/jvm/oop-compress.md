---
title: "JVM - 指针压缩"
author: "颇忒脱"
tags: ["jvm"]
date: 2020-05-11T22:18:08+08:00
---

<!--more-->

## 原理解释

在32位系统中，指针占4个字节。在64位系统中，指针占8个字节。更大的指针尺寸带来了：

1. 更容易GC，因为占用空间更大了
2. 降低CPU缓存命中率，因为一条cache line中能存放的指针数变少了

在[JVM - 对象的内存布局](../object-layout)里提到，对象都是按照8字节对齐填充的，那么也就意味着指针的偏移量只会是8的倍数，而不会是下面中的1-7，只会是0或者8：

```txt
mem:  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
        ^                               ^
```

那么我们是否可以在堆中记录0x0、0x1偏移量来代表实际上的0x0、0x8呢？比如这样：

```txt
mem:  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
        ^                               ^
        |    ___________________________|
        |   |
heap: | 0 | 1 |
```

答案是可以的。你只需在从heap里拿出来的时候做一下翻译，像左位移3位，就得到了在内存中实际位置。放到heap中的时候只需右移3位，就得到了在heap中记录的位置。

JVM启用指针压缩后（默认开启），指针大小从8字节变成了4字节，也就是32位，而这个32位实际上能表达的地址范围是2<sup>35</sup>=32G。

## JVM参数

开启压缩（默认开启的）：`-XX:+UseCompressedOops`

关闭压缩：`-XX:-UseCompressedOops`

## 参考资料

* [JVM之压缩指针（CompressedOops）](https://juejin.im/post/5c4c8ad9f265da6179752b03)
* [CompressedOops](https://wiki.openjdk.java.net/display/HotSpot/CompressedOops)