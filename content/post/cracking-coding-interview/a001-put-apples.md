---
title: "算法题 - 放苹果"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A"]
date: 2020-05-11T16:01:11+08:00
---

<!--more-->

把 M 个同样的苹果放在 N 个同样的盘子里，允许有的盘子空着不放，问共有多少种不同的分法？注意：5、1、1 和 1、5、1 是同一种分法，即顺序无关。

例子：

```txt
Input : 7,3
Output: 8
```

## 分析

我们先穷举看看7个苹果3个盘子有多少种摆法，我们可以在尝试在第一个盘子放0-7个苹果，在第二个盘子放0-剩下的苹果，第三个盘子放剩下的苹果的思路来摆放：

```txt
0 + 0 + 7              3 + 0 + 4 (dup)
0 + 1 + 6              3 + 1 + 3 (dup)
0 + 2 + 5              3 + 2 + 2 (dup)
0 + 3 + 4              3 + 3 + 1 (dup)
0 + 4 + 3 (dup)        3 + 4 + 0 (dup) 
0 + 5 + 2 (dup)        
0 + 6 + 1 (dup)        4 + 0 + 3 (dup)
0 + 7 + 0 (dup)        4 + 1 + 2 (dup)
                       4 + 2 + 1 (dup)
1 + 0 + 6 (dup)        4 + 3 + 0 (dup)
1 + 1 + 5              
1 + 2 + 4              5 + 0 + 2 (dup)
1 + 3 + 3              5 + 1 + 1 (dup)
1 + 4 + 2 (dup)        5 + 2 + 0 (dup)
1 + 1 + 5 (dup)        
1 + 6 + 0 (dup)        6 + 0 + 1 (dup)
                       6 + 1 + 0 (dup)
2 + 0 + 5 (dup)        
2 + 1 + 4 (dup)        7 + 0 + 0 (dup)
2 + 2 + 3              3 + 0 + 4 (dup)
2 + 3 + 1 (dup)        3 + 1 + 3 (dup)
2 + 4 + 1 (dup)        3 + 2 + 2 (dup)
2 + 5 + 0 (dup)        3 + 3 + 1 (dup)
```

把重复的排除掉就得到，正好8个：

```txt
0 + 0 + 7
0 + 1 + 6
0 + 2 + 5
0 + 3 + 4
1 + 1 + 5              
1 + 2 + 4
1 + 3 + 3
2 + 2 + 3
```

你可以看到，我们的结果里，摆放的苹果数量是递增的。所以在摆放的时候要保证：

1. 当前盘子的苹果 >= 前一个盘子的苹果
2. 当前剩余的苹果 >= 前一个盘子的苹果

这样你就能得到去重的结果了。

## 解法

代码：

```go
// params:
//  apples: 苹果数量
//  dishes: 盘子数量
func putApples(apples int, dishes int) int {
	if dishes == 0 {
		return 0
	}
	result := 0
	fill(&result, make([]int, dishes), 0, apples)
	return result
}

// 把苹果放到盘子里，盘子里的苹果数量只能是递增的
// 举例：盘子1的苹果数<=盘子2的苹果数<=盘子3的苹果数
// params:
//  result, 成功摆法的数量
//  dishes, 盘子数组
//  dishIndex, 当前盘子的下标
//  remainingApples, 剩余的苹果数
func fill(result *int, dishes []int, dishIndex int, remainingApples int) {

	prevApples := 0
	if dishIndex > 0 {
		prevApples = dishes[dishIndex-1]
	}
	// 剩余的值不能小于前一个数字
	if remainingApples < prevApples {
		return
	}
	// 已经是最后一个盘子
	if dishIndex == len(dishes)-1 {
		// 把剩余苹果都放到最后一个盘子里
		dishes[dishIndex] = remainingApples
		// fmt.Println(dishes)
		*result++
		return
	}

	// prevApples <= 当前盘子放的苹果数量的尝试 <= remainingApples
	for currApples := prevApples; currApples <= remainingApples; currApples++ {
		dishes[dishIndex] = currApples
		fill(result, dishes, dishIndex+1, remainingApples-currApples)
		dishes[dishIndex] = 0
	}

}
```
