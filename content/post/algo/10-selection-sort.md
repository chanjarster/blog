---
title: "算法 - 选择排序（Selection sort）"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T22:10:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 11 | 排序（上）][1]

算法描述：

* 同样分为已排序区间和未排序区间。
* 从未排序区间中找到**最小的元素**，将其放到已排序区间的末尾。第一次找最小的，第二次找第二小的，第三次找第三小的。

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

![](../sort/selection-sort.png)

[1]: https://time.geekbang.org/column/article/41802