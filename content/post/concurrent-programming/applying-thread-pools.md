---
title: "Applying Thread Pools"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "并发编程"]
date: 2019-10-16T13:40:29+08:00
---

<!--more-->

## 执行策略和任务的隐式耦合

![](exec-policy-and-task.png)

## 认识基础组件

![](basic-components.png)

## 扩展线程池

![](extends-thread-pool.png)

## 配置线程池

![](configure-thread-pool.png)

## 递归算法平行化

![](parallelize-algo.png)

### 循环平行化

```java
void processCollection(List<Element> elements) {
  for (Element e : elements) {
    process(e);
  }
}

void processCollectionParallel(Executor exec, List<Element> elements) {
  for (final Element e : elements) {
    exec.execute(() -> process(e));
  }
}
```

### 递归平行化

```java
public void sequencialRecursive(List<Node> nodes, Collection results) {
  for (Node n : nodes) {
    results.add(node.compute());
    sequencialRecursive(n.getChildren(), results);
  }
}

public void parallelRecursive(final Executor exec, 
                              List<Node> nodes,
                              final Collection results) {
  for (Node n : nodes) {
    exec.submit(() -> results.add(n.compute()));
    parallelRecursive(exec, n.getChildren(), results);
  }
}

public Collection getParallelResults(List<Node> nodes) throws InterruptedException {
  ExecutorService exec = Executors.newCachedThreadPool();
  Queue resultQueue = new ConcurrentLinkedQueue();
  parallelRecursive(exec, nodes, resultQueue);
  exec.shutdown();
  // 等到所有任务执行完毕
  exec.awaitTermination(Long.MAX_VALUE, TimeUnits.SECONDS);
  return resultQueue;
}
```

