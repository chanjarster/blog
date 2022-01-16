---
title: "算法 - 归并排序（Merge sort）"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2019-02-14T21:00:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 12 | 排序（下）][1]

算法描述：

* a为待排序数组，n为数组长度
* 把 a 一分为二
* 对 a 左半部分排序
* 对 a 右半部分排序
* 把两部分合并，合并结果得是有序的
* 其中对 a 左、右部分排序也是使用相同的算法

伪代码：

```java
mergeSort(a) {
  mergeSort(a_left_part)
  mergeSort(a_right_part)
  merge(a_left_part, a_right_part)
}
```

算法复杂度分析：

```txt
T(1) = C   因为无法再分左右两半了，所以n=1时只需要常数时间
T(n) = 2 * T(n/2) + n    代表左右两半到时间 + 合并结果需要的时间
     = 2 * (2 * T(n/4) + n/2) + n = 4 * T(n/4) + 2 * n
     = 4 * (2 * T(n/8) + n/4) + 2 * n = 8 * T(n/8) + 3 * n
     = 8 * (2 * T(n/16) + n/8) + 3 * n = 16 * T(n/16) + 4 * n
     = ...
     = 2 ^ k * T(n/2^k) + k * n
```

当T(n/2^k)=T(1)时，k为log<sub>2</sub>n，公式变成 

* 2<sup>log<sub>2</sub>n</sup> * C + n * log<sub>2</sub>n 
* => n * C + n * log<sub>2</sub>n
* => O(nlogn)

上面提到的k = log<sub>2</sub>n = 递归深度

```java
// a为待排序数组，start为排序区间开始，end为排序区间结束
public void merge_sort(int[] a, int start, int end) {
  if (start >= end) {
    return;
  }
  int mid = (start + end) / 2;
  merge_sort(a, start, mid);
  merge_sort(a, mid + 1, end);
  merge(a, start, mid, end);
}

public void merge(int[] a, int start, int mid, int end) {
  // 合并两个有序数组
  int i = start;
  int j = mid + 1;
  int k = 0;
  int[] tmp = new int[end - start + 1];
  while (i <= mid && j <= end) {
    if (a[i] <= a[j]) {
      tmp[k] = a[i];
      i++;
    } else {
      tmp[k] = a[j];
      j++;
    }
    k++;
  }
  while (i <= mid) {
    tmp[k] = a[i];
    i++;
    k++;
  }
  while (j <= end) {
    tmp[k] = a[j];
    j++;
    k++;
  }
  for (int x = 0; x < k; x++) {
    a[start + x] = tmp[x];
  }
}
```

<img src="../sort/merge-sort.png" style="zoom:50%" />

[1]: https://time.geekbang.org/column/article/41913