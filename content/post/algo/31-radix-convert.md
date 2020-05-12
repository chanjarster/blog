---
title: "算法 - 进制转换"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2020-05-12T20:46:10+08:00
---

<!--more-->

问题：把10进制转换成N进制，可以使用52个大小写英文字母+10个数字来表达新数字

解法：把数字不停的除以N，得到的余数则是N进制的位，然后对商再除以N，如此反复，直到商为0位置，把这些余数串起来就是N进制的表现形式了。

```txt
16 | 255
   -----
16  | 15  余数: 15 (f)
    ----
       0  余数: 15 (f)

所以hex(255) = ff

16 | 254
   -----
16  | 15  余数: 14 (e)
    ----
       0  余数: 15 (f)

所以hex(254) = fe
```

代码：

```go
var ntab = []byte("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func convert(num int, radix int) string {
	r := make([]byte, 0)
	for num != 0 {
		d := num / radix
		m := num % radix
		r = append(r, ntab[m])
		num = d
	}
	// 把结果反转过来
	for i := 0; i < len(r)/2; i++ {
		oi := len(r) - 1 - i
		r[i], r[oi] = r[oi], r[i]
	}
	return string(r)
}
```







​    