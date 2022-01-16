---
title: "算法 - 平滑窗口限流"
author: "颇忒脱"
tags: ["ARTS-A", "并发编程", "限流"]
date: 2020-02-20T14:17:36+08:00
---

<!--more-->

有这么一个要求，要求在任意5分钟内请求数不得超过1000。

在实现上可以使用队列，请求来的时候先看队列尺寸是否达到1000

* 如果没有达到，则将**当前时间戳**追加到队列尾部。
* 如果达到，则看队列的头部元素（也是时间戳）距离当前时间是否超过5分钟
  * 如果没有超过，则说明最近5分钟里已经有1000个请求了，那么**拒绝**这个请求
  * 如果超过，则删除队列头部元素，将**当前时间戳**追加到队列尾部。

这种方式的好处在于能够精确的控制请求速率，并且时间窗口可以比较大，具备一定的弹性，而且窗口是平滑的。缺点是需要维护一个队列，占用内存空间。

代码实现如下：

```java
public class SynchronizedSmoothRateLimiter implements SmoothRateLimiter {

  /**
   * 时间窗口长度（单位ms）
   */
  private final long windowLength;

  /**
   * 时间窗口内能够有多少个请求
   */
  private final int maxRequests;

  /**
   * 时间窗口，内记录的是时间戳
   */
  private final Queue<Long> window = new LinkedList<>();

  public SynchronizedSmoothRateLimiter(long windowLength, int maxRequests) {
    this.windowLength = windowLength;
    this.maxRequests = maxRequests;
  }

  @Override
  public synchronized boolean tryAcquire() {
    long now = System.currentTimeMillis();
    int windowSize = window.size();
    if (windowSize < maxRequests) {
      window.add(now);
      return true;
    }

    long head = window.peek().longValue();
    long distant = now - head;
    if (distant <= windowLength) {
      return false;
    }
    window.poll();
    window.add(now);
    return true;
  }

}
```

相关代码在[这里][1]。

[1]: https://github.com/chanjarster/code-snippets/tree/master/smooth-rate-limit

