---
title: "算法 - 选择排序（Selection sort）"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2019-02-13T22:10:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 11 | 排序（上）][1]

算法描述：

* a为待排序数组，n为数组长度
* i为元素下标，a[ < i]的元素都是已排序好的，a[ >= i]的元素都是还未排序的。即把a分为两个区间：**已排序区间**和**未排序区间**。
* 循环 n - 1 次，初始i = 0：
  * 在a[i .. n - 1]的范围里找到最小的元素，记为a[min]
  * 将a[min]与a[i]交换，i++

速记法：想象成一个手扑克牌，从第一张～最后一张里找最小的牌，和第一张交换；从第二张～最后一张找最小的牌，和第二张交换，……

算法本质：不停从未排序区间中找到**最小的元素**，将其放到已排序区间的末尾。第一次找最小的，第二次找第二小的，第三次找第三小的。

```java
public void selectionSort(int[] a, int n) {
  if (n <= 1) return;

  for (int i = 0; i < n; i++) {
    int min_i = i;
    // 找到最小值的下标
    for (int j = i + 1; j < n; j++) {
      if (a[j] < a[min_i]) {
        // 更新最小值的下标
        min_i = j;
      }
    }
    if (min_i == i) {
      continue;
    }
    // 交换数据
    int tmp = a[i];
    a[i] = a[min_i];
    a[min_i] = tmp;
  }
}
```

<img src="../sort/selection-sort.png" style="zoom:50%" />

[1]: https://time.geekbang.org/column/article/41802