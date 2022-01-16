---
title: "算法 - 队列"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2019-02-13T21:10:33+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 09 | 队列][1]

## 队列

* 先进者先出
* 顺序队列，由数组实现，有边界
* 循环队列，由数组实现，进一步优化顺序队列的操作时间复杂度
* 链式队列，由链表实现，无边界
* 操作：入队、出队。

顺序队列

* 缺点：数据搬移
* 优化1：tail到底时再搬，均摊复杂度

循环队列，由数组实现，进一步优化顺序队列的操作时间复杂度

* head指向头，tail指向尾，tail不存数据
* 队满条件，(tail+1) % n = head
* 队空条件，tail = head

```java
public class CircularQueue {
  // 数组：items，数组大小：n
  private String[] items;
  private int n = 0;
  // head 表示队头下标，tail 表示队尾下标
  private int head = 0;
  private int tail = 0;

  // 申请一个大小为 capacity 的数组
  public CircularQueue(int capacity) {
    items = new String[capacity + 1];
    n = capacity;
  }

  // 入队
  public boolean enqueue(String item) {
    // 队列满了
    if ((tail + 1) % n == head) return false;
    items[tail] = item;
    tail = (tail + 1) % n;
    return true;
  }

  // 出队
  public String dequeue() {
    // 如果 head == tail 表示队列为空
    if (head == tail) return null;
    String ret = items[head];
    head = (head + 1) % n;
    return ret;
  }
}
```

[1]: https://time.geekbang.org/column/article/41330
