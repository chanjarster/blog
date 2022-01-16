---
title: "虚函数表（vtable/virtual table/virtual method table）"
author: "颇忒脱"
tags: ["ARTS-T", "vtable"]
date: 2019-02-25T21:55:10+08:00
---

<!--more-->

**本文只是拿Java代码做说明的例子，不代表Java的vtable是这样实现的**

虚函数表，又称 virtual method table (VMT), virtual function table, virtual call table, dispatch table, vtable, or vftable。是一种用于支持[dynamic dispatch][dd]（或称为run-time method binding）的机制。而**动态转发**则是实现多态中重要一环——方法重写——的重要机制。

考虑下面代码：

```java
class Super {
  void test() {}
}
class Derived extends Super {
  void test() {
  }
}

Super s = ...;
s.test();
```

`s.test()`所调用的是`Super#test()`还是`Derived#test()`在编译期是无法知道，因为`s`指向的真正类型可能是Super也可能是Derived，那么`s.test()`到底调用那个类的test方法只能在运行时知道，那么是如何知道的呢？答案是依靠vtable。

每个类都有一张vtable，vtable里记录了每个虚方法（PS. 在Java中除static、`<init>`、`<clinit>`、final method之外的都是虚方法）的偏移量及内存地址。父类的vtable的内容会在子类vtable中复制一份，并且保持相同的偏移量，方法的内存地址则要看子类是否覆盖了父类方法而定。下面是vtable布局大致概念：

Object vtable

| offset | method     | addr    |
|:------:|:----------:|:-------:|
| 0      | toString() | addr-1  |
| 1      | hashcode() | addr-2  |

Super vtable

| offset | method     | addr    |
|:------:|:----------:|:-------:|
| 0      | toString() | addr-1  |
| 1      | hashcode() | addr-2  |
| 2      | test()     | addr-3  |

Derived vtable

| offset | method     | addr    |
|:------:|:----------:|:-------:|
| 0      | toString() | addr-1  |
| 1      | hashcode() | addr-2  |
| 2      | test()     | addr-4  |

可以看到Super虽然没有覆盖Object类的`toString()`、`hashcode()`，但是其vtable中依然有这两个函数，且偏移量和地址与Object vtable一样。Derived的`test()`方法偏移量与Super的`test()`方法偏移量一样，但是地址不同，因为Derived覆盖了`test()`方法。

当`s.test()`时做了这么几件事情：

1. 获得`s`所指向的类的vtable
2. 在vtable中找到`test()`方法条目里所记载的地址
3. 调用该地址的函数

所以虚方法的调用要比直接调用多了几个步骤，对于性能是有损失的。

那么能够想到的优化方法是记录`Derived#test()`方法的偏移量，那么当下一次调用的时候就变成了：

1. 获得`s`所指向的类的vtable
2. 发现本次是找`Derived#test()`，上次记录了该方法在vtable中的偏移量是2
3. 调用偏移量2的条目的内存地址上的函数

## 参考资料

* [Virtual method table][wiki-vtable]
* [12.5 — The virtual table][cpp-vtable]

[dd]: https://en.wikipedia.org/wiki/Dynamic_dispatch
[wiki-vtable]: https://en.wikipedia.org/wiki/Virtual_method_table
[cpp-vtable]: https://www.learncpp.com/cpp-tutorial/125-the-virtual-table/
