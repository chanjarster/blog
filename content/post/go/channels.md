---
title: "Go Channels cheatsheet"
date: 2020-04-28T08:59:19+08:00
tags: ["go", "cheatsheet"]
author: "颇忒脱"
---

<!--more-->

## channel类型

是否buffered：

* unbuffered：
  ```go
  ch := make(chan int)
  ```
* buffered
  ```go
  ch := make(chan int, 100)
  ```

方向：

* 双向：
  ```go
  chan int
  ```
* 只接收：
  ```go
  <-chan int
  ```
* 只发送：
  ```go
  chan<- int
  ```

## 发送到channel

* unbuffered channel：阻塞，直到receiver准备好
* buffered channel：阻塞，直到buffer有空间
* 已关闭的channel：panic
* nil channel：永远阻塞

## 从channel接收

* unbuffered channel：阻塞，直到channel有值
* buffered channel：同上
* 已关闭的channel：不阻塞，把channel中的值都消费光之后返回类型零值
* nil channel：永远阻塞

关于从已关闭的channle接收的另一种形式：

```go
x, ok := <-ch
```

如果ok为true：取出的值是channel被关闭之前发送的

如果ok为false：channel已经被关闭了而且空了

所以，**从接收方来说你无法知道channel何时被关闭**，因为关闭之后你还可以从buffer（如果有的话）中取值。

## 关闭channel

```go
close(ch)
```

* 关闭只接收channel（`<-chan int`）：编译不通过
* 关闭nil channel：panic
* 关闭已关闭channel：panic

## select channel

在一组发送和接收case中，选择一个不会阻塞case：

```go
select {
  case v, ok := <- ch:
    // 从channel接收
  case ch <- 1:
    // 发送到channel
  default:
    // 上面两个case都会阻塞时
}
```

规则：

* 根据源码顺序挨个尝试所有case。
* case中的发送和接收操作遵循前面提到的规则。
* 有多个case可以执行时，随机选择其中一个（uniform pseudo-random selection）。

* 当所有case都会阻塞时，执行default。如果没有default则整个select操作阻塞，直到某个case不阻塞。

## for range channel

从一个channel中接收：

```go
for v := range ch {
}
```

规则：

* 如果channel空了，则阻塞
* 如果channel已关闭，则退出循环
* 如果nil channel，永远阻塞

## 参考资料

* [Channel types][1]
* [Sending to channel][2]
* [Receiving from channel][3]
* [Making channel][4]
* [Select statements][5]
* [Close channel][6]
* [For statement][7]

[1]: https://golang.org/ref/spec#Channel_types
[2]: https://golang.org/ref/spec#Send_statements
[3]: https://golang.org/ref/spec#Receive_operator
[4]: https://golang.org/ref/spec#Making_slices_maps_and_channels
[5]: https://golang.org/ref/spec#Select_statements
[6]: https://golang.org/ref/spec#Close
[7]: https://golang.org/ref/spec#For_statements