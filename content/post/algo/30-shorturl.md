---
title: "算法 - 如何实现短网址服务"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2020-05-12T20:25:10+08:00
---

<!--more-->

[如何实现短网址服务][1]

## 哈希法

大致思路：对原始网址求哈希值，把这个哈希值作为key，原始网址作为value存在redis或数据库中。用户访问短网址的时候，到库中找，然后302重定向到原始网址。

**用什么哈希算法？**

你可以用SHA256、MD5、java的String#hashCode都可以。比较著名的是[MurmurHash3算法][2]。MurmurHash比SHA和MD5性能高，因为它是非密码学算法，它可以产生32bit和128bit两种哈希值。

如何把哈希值转换成短网址？

虽然你可以采用32bit的版本得到一个int，直接把这个作为短网址，比如`shorturl.cn/181338494`，但是这样还不够短，可以把把十进制转换成十六进制，也可以转换成62进制，用52个大小写英文字母 + 10个数字来表示。算法代码看[进制转换](../31-radix-convert)。

**哈希值冲突了怎么办？**

分析冲突的原因：

1）一种原因，用户用同样的原始网址求了两次短网址，那么哈希值肯定会冲突。解决思路有两个：

* 不管它，冲突消解，生成个新的短网址。优点是简单，容易缺点被攻击，浪费哈希槽位。
* 每次都到redis或数据库中取一下，如果存在那么对比原始网址是否一样，如果一样就直接返回之前的短网址，如果不一样就冲突消解。

2）另一个原因，就是两个不同的原始字符串的哈希值冲突了，没二话直接冲突消解。

**冲突消解的思路？**

有两个思路：

1. （不推荐）采用开放寻址法，哈希值是32bit也就是一个int，那么把int++，看看有没有冲突。这个方法比较简单，缺点是要避免位溢出变成负数，占用了别人的位置了，哈希的分布不均匀，容易导致需要消解几次冲突。
1. 追加特殊字符，在原始网址后面加上程序自己识别的字符，比如`[DUP]`，对其取哈希，看看有没有冲突。如果再有冲突则换一个特殊字符`[DUP_AGAIN]`。这个方法也简单，基本上第一次冲突就消解了，极个别的需要两次。

**如何提升服务的性能？**

按照追加特殊字符的冲突消解的代码大致如下：

```go
func shortify(url string) string {
  for  {
    shorturl := hash(url)
    if store.exists(shorturl) {
      existedUrl := store.get(shorturl)
      if existedUrl == url {
        return shorturl
      }
      url = resolveConflict(url) // 修改url追加特殊字符
      continue
    }
    store.save(shorurl, url)
    return shorturl
  }
}
```

可以看到整个过程必须查询一次`store.exists(shorturl)`再保存一次`store.save(shorturl, url)`

**如何减少每次判断？**

1）可以利用redis的`SETNX`和数据库中添加唯一索引让这个过程变得只有一次：

```go
func shortify(url string) string {
  for  {
    shorturl := hash(url)
    if store.save(shorurl, url) {
      return shorturl
    }
    existedUrl := store.get(shorturl)
    if existedUrl == url {
      return shorturl
    }
    url = resolveConflict(url) // 修改url追加特殊字符    
  }
}
```

2）可以利用布隆过滤器，布隆过滤器是比较节省内存的一种存储结构，长度是 10 亿的[布隆过滤器](../32-bloom-filter)，也只需要 125MB 左右的内存空间。

## 自增ID法

数据库中自增ID生成作为短网址。

**相同的原始网址可能会对应不同的短网址**

解决思路：

1. 不解决。反正用户关心的是能够跳转到原始网址。
2. 和哈希法一样，到数据库中查询一下原始网址是否已经有短网址了。在数据库中需要给原始网址和短网址都加上索引，多一个索引会增加性能开销。对于redis来说则是建两套key，一个是 shorturl -> longurl 的，一个是 longurl -> shorturl 的。

**如何实现高性能的 ID 生成器？**

因为ID不能重复，必须自增，那么它就会加锁，这样会影响性能。

解决思路：

1. 多个ID生成器，每个都有一个号段，号段问一个号段管理器要。号段用完了再要新的号段。这样可以增加并发效率。
2. 多个ID生辰器，他们天然就不会生成相同的ID，比如一个只生成尾号为0的，一个只生成尾号为1的。再比如[Twitter的雪花算法][3]。



[1]: https://time.geekbang.org/column/article/80850
[2]: https://zh.wikipedia.org/wiki/Murmur%E5%93%88%E5%B8%8C
[3]: https://juejin.im/post/5a7f9176f265da4e721c73a8

