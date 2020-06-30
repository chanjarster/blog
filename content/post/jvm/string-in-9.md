---
title: "JVM - String对象在Java 9中的变化"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "jvm"]
date: 2020-05-21T08:55:08+08:00
---

<!--more-->

## 概要

在Java 9中，String对象底层从原来的`char[]`变成了`byte[]`，这一变化带来的直接好处就是更节省内存了，因此也被称为Compact Strings Improvement。为什么呢？因为在Java中`char`占有2个字节，`byte`占用1个字节，而一个Unicode字符的表示并不一定需要2个字节，至少ASCII字符只需要1个字节就搞定了。也就是说，如果你的字符串里都是ASCII字符，如果用char的话就会浪费一半的空间。

## 简要Unicode说明

说到这里不得不提一下Unicode编码，以及它的Code Point（码点）和Code Unit。可以把Unicode想象成一张巨大的表格，每个字符都有一个唯一对应的数字。

一个Code Point代表了一个Unicode字符的在表中的序号：

```
> 'A'.codePointAt(0).toString(16)
'41'
> 'π'.codePointAt(0).toString(16)
'3c0'
> '🙂'.codePointAt(0).toString(16)
'1f642'
```

一个或者多个Code Unit代表了一个Code Point，Code Unit是用来存储和传输Unicode字符的，以下是UTF-8编码：

| Character | Code point | Code units                             |
| --------- | ---------- | -------------------------------------- |
| A         | 0x0041     | 01000001                               |
| π         | 0x03C0     | 11001111, 10000000                     |
| 🙂       | 0x1F642    | 11110000, 10011111, 10011001, 10000010 |

UTF-8的Code Unit占用8位（1字节），UTF-16的Code Unit占用16位（2字节），UTF-32的Code Unit占用32位（4字节），除了UTF-32之外，UTF-8/16都是变长编码，也就是说在对一个Code Point转换成Code Unit的时候，根据情况使用1个或多个Code Unit（上面表格已经说明了）。

所以，当Java 9 String底层从`char[]`改成`byte[]`，除非使用UTF-32编码（定长编码），那么它肯定是变长编码，使得内存占用更紧凑。也因此Java 9 String API中添加了关于Code Point的方法。

## 参考文档

* [Unicode – a brief introduction](https://exploringjs.com/impatient-js/ch_unicode.html)
* [Java 9 – Compact Strings Improvement [JEP 254]](https://howtodoinjava.com/java9/compact-strings/)
* [Java 9 String API](https://docs.oracle.com/javase/9/docs/api/java/lang/String.html)

