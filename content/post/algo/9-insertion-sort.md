---
title: "算法 - 插入排序（Insertion sort）"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T22:00:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 11 | 排序（上）][1]

算法描述：

* a为待排序数组，n为数组长度
* i为元素下标，a[ < i]的元素都是已排序好的，a[ >= i]的元素都是还未排序的。即把a分为两个区间：**已排序区间**和**未排序区间**。
* 循环 n - 1 次，初始i = 1：
  * 取a[i]，与a[i - 1 ... 0]的元素比较（注意是从后往前的顺序），记这个元素为a[j]
  * 若a[i] < a[j]，则将a[j]往后移动
  * 若a[i] >= a[j]，则将a[i]插入到a[j+1]的位置，i++
  * 直到 i = n 为止

算法本质：**已排序区间**初始为数组的第一个元素，然后不停将**未排序区间**的元素插入到**已排序区间**的合适的位置。

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