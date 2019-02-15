---
title: "算法 - 插入排序（Insertion sort）"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T22:00:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 11 | 排序（上）][1]

算法描述：

* 将数组中的数据分为两个区间，**已排序区间**和**未排序区间**。初始已排序区间只有一个元素，就是数组的第一个元素。
* 取未排序区间中的元素，在已排序区间中找到合适的插入位置将其插入，并保证已排序区间数据一直有序。
* 重复这个过程，直到未排序区间中元素为空，算法结束。

```java
// 插入排序，a 表示数组，n 表示数组大小
public void insertionSort(int[] a, int n) {
  if (n <= 1) return;

  for (int i = 1; i < n; ++i) {
    int value = a[i];
    int j = i - 1;
    // 查找插入的位置
    for (; j >= 0; --j) {
      if (a[j] > value) {
        a[j+1] = a[j];  // 数据移动
      } else {
        break;
      }
    }
    a[j+1] = value; // 插入数据
  }
}
```

![](../sort/insertion-sort.png)

[1]: https://time.geekbang.org/column/article/41802