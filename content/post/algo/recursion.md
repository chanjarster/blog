---
title: "算法（六） - 递归"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2019-02-13T21:19:01+08:00
---

<!--more-->

* [极客时间 - 数据结构与算法之美 - 10 | 递归][1]

## 递归

递归需要满足的三个条件

1. 一个问题的解可以分解为几个子问题的解
2. 这个问题与分解之后的子问题，除了数据规模不同，求解思路完全一样
3. 存在递归终止条件


### 警惕

1. 递归代码要警惕堆栈溢出
2. 递归代码要警惕重复计算，看下面代码

```java
public int f(int n) {
  if (n == 1) return 1;
  if (n == 2) return 2;
  
  // hasSolvedList 可以理解成一个 Map，key 是 n，value 是 f(n)
  if (hasSolvedList.containsKey(n)) {
    return hasSovledList.get(n);
  }
  
  int ret = f(n-1) + f(n-2);
  hasSovledList.put(n, ret);
  return ret;
}
```

### 将递归代码改写为非递归代码

`f(x)=f(x-1)+1`改写：

```java
int f(int n) {
  int ret = 1;
  for (int i = 2; i <= n; ++i) {
    ret = ret + 1;
  }
  return ret;
}
```

`f(n)=f(n-2)+f(n-1)`改写：

```java
int f(int n) {
  if (n == 1) return 1;
  if (n == 2) return 2;
  
  int ret = 0;
  int pre = 2;
  int prepre = 1;
  for (int i = 3; i <= n; ++i) {
    ret = pre + prepre;
    prepre = pre;
    pre = ret;
  }
  return ret;
}
```

[1]: https://time.geekbang.org/column/article/41440
