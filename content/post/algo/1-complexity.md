---
title: "算法 - 时间复杂度"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T20:14:45+08:00
---

<!--more-->

[极客时间 - 数据结构与算法之美 - 03 | 复杂度分析（上）：如何分析、统计算法的执行效率和资源消耗？][1]

## unit_time

读、运算、写均算作一个unit_time

## 计算技巧

1. 只关注循环执行次数最多的一段代码。
2. 加法法则：总复杂度等于量级最大的那段代码的复杂度。
3. 乘法法则：嵌套代码的复杂度等于嵌套内外代码复杂度的乘积。

## 复杂度量级

* 常数阶 O(1)
* 线性阶 O(n)
* 对数阶 O(logn)
* 线性对数阶 O(nLogn)
* 平方阶 O(n^2)、立方阶 O(n^3)、k次方阶 O(n^k)
* 指数阶 O(2^n)
* 阶乘阶 O(n!)

举例：

O(1)

```java
int i = 8;
int j = 6;
int sum = i + j;
```

O(n)

```java
i=1;
while (i <= n)  {
  i = i * 2;
}
```

O(m + n)

```java
int cal(int m, int n) {
  int sum_1 = 0;
  int i = 1;
  for (; i < m; ++i) {
    sum_1 = sum_1 + i;
  }

  int sum_2 = 0;
  int j = 1;
  for (; j < n; ++j) {
    sum_2 = sum_2 + j;
  }

  return sum_1 + sum_2;
}
```


[1]: https://time.geekbang.org/column/article/40036