---
title: "Go和Java的区别"
author: "颇忒脱"
tags: ["Go"]
date: 2020-02-10T13:29:07+08:00
---

Go和Java的区别（纯笔记，不系统）

<!--more-->

- Go更像C，Java更像C++
- Go不允许存在声明但是没有使用的东西，比如声明了多余的变量，import了多余的包
- Go对不同平台有不同的编译结果
- Go的function可以返回多个值
- Go的function没有overload
- Go用defer实现try-finally和try-catch，可以运行时决定使用哪个
- Go有function闭包，可以读写外部变量。Java的lambda有类似的，但是是基于匿名内部类的，且只能读外部变量：外部变量必须是final或者事实上是final的（即不会被修改）
- Go没有线程，而是Goroutine，Goroutine是由Go运行时管理的task，所以Go没有线程池。Goroutine可以类似于Green threads？
- Go的类型方法通过function上加receiver来实现
- Go中struct首字母大写字段是public的，首字母小写字段是private的
- Go没有this
- Go没有显式的继承，而是嵌入，而且采用duck typing来判断A类型实例是否可以复制给B类型变量。
- Go有指针，和值。Java里除了基本类型则都是引用
- Go的变量赋值、参数传递是复制，指针类型复制的是地址（和Java的引用一样），其他类型复制的是内存中的数据。
- Go中有些类型实例的复制就是两个实例，不共享数据，比如array。有些则不是，虽然是两个实例，但是共享数据，比如slice。没有明显规律。
- Go没有NullPointerException，有些类型的nil值具有开箱即用的特性，有些则没有，没有明显规律
- Go的Mutex是不可重入锁，比较接近操作系统底层mutex
- Go自带了单元测试、性能测试、CPU+Memory+Net的Profile库