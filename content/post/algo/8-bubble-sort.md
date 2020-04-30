---
title: "算法 - 冒泡排序（Bubble sort）"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T21:50:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 11 | 排序（上）][1]

算法描述：

1. a为待排序数组
2. j = 0，比较 a[j] 和 a[j+1]：
  * 如果 a[j] > a[j+1]，交换两个元素位置
  * 否则啥都不用做
  * j++
3. 循环n - 1次
  * 第一次循环，把最大的元素移动到了 最后
  * 第二次循环，把第2大元素移动到了 倒数第2位
  * 第三次循环，把第3大元素移动到了 倒数第3位
  * ...
  * 直到循环结束，元素都排序好了

算法本质：把大的元素像泡泡一样冒到最后。

```java
// 冒泡排序，a 表示数组
public void sort(int[] a) {
  int n = a.length;
  if (n <= 1) {
    return;
  }
  for (int i = 0; i < n; i++) {
    boolean flag = false;
    for (int j = 0; j < n - i - 1; j++) {
      // 每次交换把一个较大的元素移动到数组尾部
      if (a[j] > a[j + 1]) {
        int tmp = a[j];
        a[j] = a[j + 1];
        a[j + 1] = tmp;
        flag = true;
      }
    }
    if (!flag) {
      // 如果没有数据交换，则说明数组已经有序
      break;
    }
  }
}
```

<img src="../sort/bubble-sort.png" style="zoom:50%" />

[1]: https://time.geekbang.org/column/article/41802
