---
title: "缓存穿透后的并发数据库查询优化"
author: "颇忒脱"
tags: ["并发编程", "性能调优"]
date: 2024-06-20T14:10:20+08:00
---

<!--more-->

## 现象

当缓存中没有数据的时候，需要到数据库中查询，俗称缓存穿透。

在高并发情况下，多个线程同时穿透去查询同一条数据的时候，对数据库压力很大，事实上也造成了多余无效的数据库查询。

## 分析

那么希望一种方法，可以只让一个线程去数据库查询，其他线程等待这个线程的查询结果，这样就可以极大的减轻数据库压力。

## 解决

```java
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.FutureTask;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicLong;


public class ConcurrentDbQueryService {

  private static final int THREAD_POOL_SIZE = 20;

  private final String threadPrefix = "conc-db-query-";

  private final AtomicLong threadCount = new AtomicLong();

  private final ExecutorService threadPool = Executors.newFixedThreadPool(THREAD_POOL_SIZE, new ThreadFactory() {
    @Override
    public Thread newThread(Runnable r) {
      return new Thread(r, threadPrefix + threadCount.incrementAndGet());
    }
  });

  private final Map<String, FutureTask<String>> runningTaskMap = new ConcurrentHashMap<>();

  public String getByKey(String key) {

    FutureTask<String> runningTask = runningTaskMap.get(key);
    if (runningTask != null) {
      try {
        // 发现同一个 key 有其他线程在查询，直接等待它的结果
        return runningTask.get();
      } catch (InterruptedException e) {
        e.printStackTrace();
      } catch (ExecutionException e) {
        e.printStackTrace();
      }
    }

    FutureTask<String> task = new FutureTask<>(() -> {
      try {
        // TODO 从 db 中获取数据
        return null;
      } finally {
        // 任务完成后，把自己从 runningTaskMap 中拿掉
        runningTaskMap.remove(key);
      }
    });

    runningTask = runningTaskMap.putIfAbsent(key, task);
    if (runningTask == null) {
      // 说明没有其他线程做相同操作
      runningTask = task;
      threadPool.submit(runningTask);
    }

    try {
      return runningTask.get();
    } catch (InterruptedException e) {
      e.printStackTrace();
    } catch (ExecutionException e) {
      e.printStackTrace();
    }
  }
}
```