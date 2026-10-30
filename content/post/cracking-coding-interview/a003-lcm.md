---
title: "算法题 - 最小公倍数"
author: "颇忒脱"
tags: ["ARTS-A"]
date: 2020-05-11T17:40:11+08:00
---

<!--more-->

求a和b的最小公倍数：

```txt
Input : 319, 377
Output: 29
```

## 解法

最小公倍数和最大公约数之间的关系：gcd(a, b) * lcm(a, b) = ab

```go
// 求最大公约数 Least Common Multiple
func lcm(a, b int) int {
  return a * b / gcd(a, b)
}
```

