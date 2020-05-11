---
title: "算法题 - 最大公约数"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2020-05-11T17:01:11+08:00
---

<!--more-->

求a和b的最大公约数：

```txt
Input : 319, 377
Output: 29
```

## 解法

采用[欧几里德算法](https://baike.baidu.com/item/%E6%9C%80%E5%A4%A7%E5%85%AC%E7%BA%A6%E6%95%B0)（又称辗转相除法），定理：gcd(a,b) = gcd(b,a mod b)

```go
// 求最大公约数 Greatest Common Divisor
// 辗转相除法(欧几里德算法)
func gcd(a, b int) int {
	if a < b {
		return gcd(b, a)
	}
	for {
		remain := a % b
		if remain == 0 {
			return b
		}
		a = b
		b = remain
	}
}
```

