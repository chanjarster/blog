---
title: "算法 - 查找第K大数字"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2019-02-25T10:21:10+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 12 | 排序（下）][1]


本题目借助快排思想，算法描述：

* a为待排序数组，n为数组长度

1. 问题转换：把第k大数字转换成第l小数字，比如：`n=5，k=1`，那么`l=n-k+1=5`，也就是第5小的数字，其下标`l_i=5-1=4`。
1. 取`a[n-1]` 作为 pivot
1. 用快排的思路，把 `< pivot` 的元素放到 pivot 左边，把 `>= pivot` 的元素放到 pivot 右边，得到pivot的下标：`pivot_i`
1. 如果 `pivot_i < l_i`，则说明被查找的数字可能在右边，对右边重复2-5步骤
1. 如果 `pivot_i > l_i`，则说明被查找的数字可能在左边，对左边重复2-5步骤

代码：

```java
public static int findKthBigNumber(int[] a, int kthBig) {
  int n = a.length;
  if (kthBig > n) {
    return -1;
  }
  int lthSmall = n - kthBig;

  return quickFind(a, 0, a.length - 1, lthSmall);
}

private static int quickFind(int[] a, int start, int end, int lthSmall) {
  if (start > end) {
    return -1;
  }
  int pivot_i = partition(a, start, end);

  if (pivot_i == lthSmall) {
    return a[pivot_i];
  }

  if (pivot_i < lthSmall) {
    return quickFind(a, pivot_i + 1, end, lthSmall);
  }

  return quickFind(a, start, pivot_i - 1, lthSmall);

}

/**
 * 快排的分区算法
 *
 * @param a
 * @param start
 * @param end
 * @return 分区点
 */
private static int partition(int[] a, int start, int end) {
  int pivot = a[end];

  int pivot_i = start;
  for (int j = start; j <= end - 1; j++) {
    if (a[j] < pivot) {
      if (pivot_i != j) {
        int tmp = a[j];
        a[j] = a[pivot_i];
        a[pivot_i] = tmp;
      }
      pivot_i++;
    }
  }

  a[end] = a[pivot_i];
  a[pivot_i] = pivot;
  return pivot_i;
}
```

算法复杂度分析：

最好情况：

* `k > n`，即要找的数字超出了数组所能给出的范围，复杂度O(1)。
* 第一次分区的pivot就是要找的数字，遍历n-1次，复杂度O(n)。

最坏情况：

* 每次pivot分区极不均匀——pivot的左分区元素数量为原始分区数量-1，或者pivot的右分区数量为原始分区数量-1——且分区大小要变成1之后，才能够找到要找的元素。
* 比如 k=n，且这个数组已经是有序了。那么每次遍历的次数是 `(n-1)+(n-2)+(n-3)+...+1=n(n-1)/2`，即O(n^2)。

平均情况：

* 不知怎么分析

[1]: https://time.geekbang.org/column/article/41913
[merge-sort]: ../11-merge-sort