---
title: "Cancellation and Shutdown"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "并发编程"]
date: 2019-10-13T13:40:29+08:00
---

<!--more-->

![](cancellation-and-shutdown.png)

## 任务取消

![](task-cancellation.png)

一种做法是设置cancel flag，但是存在永远无法响应的风险：

```java
public Task {
  private volatile boolean cancelled = false;
  public void cancel() {
    this.cancelled = true;
  }
  public void run() {
    if (!cancelled) {
      // 如果这个方法阻塞了，那么Task就永远不会cancel
      someBlockingMethod();      
    }
  }
}
```

### 线程中断

```java
public class Thread {
  public void interrupt(); // 通知target thread中断
  public boolean isInterrupted(); // 查询target thread的中断状态
  public static boolean interrupted(); // 清空当前thread的中断状态，返回前一个中断状态
}
```

### 利用线程中断来取消任务的例子

```java
public Task implements Runnable {
  public void run() {
    try {
      // 检测中断状态
      while (!Thread.currentThread().isInterrupted()) {
        someBlockingMethod();
      }
    } catch (InterruptedException e) {
      // 在阻塞方法时线程被中断了
      // 除非你知道自己在做什么，否则你应该rethrow 或者恢复线程的中断状态
      Thread.currentThread().interrupt();
    }
  }
}
```

### 就算某个任务不可中断也要在它结束后恢复中断状态

```java
public Task {
  public void run() {
    try {
      while (true) {
        try {
          someBlockingMethod()
        } catch (InterruptedException e) {
          interrupted = true;
        }
      }      
    } finally {
      if (interrupted) {
        Thread.currentThread().interrupt();
      }
    }
  }
}
```

阻塞库的方法一旦探知线程中断状态，就会抛出异常，下面代码会造成死循环，他会不停抛出InterruptedException：

```java
public Task {
  public void run() {
    while (!blockingQueue.isEmpty()) {
      try {
        blockingQueue.take();
      } catch (InterrupttedException e) {
        Thread.currentThread().interrupt();
      }
    }
  }
}
```

### 反面例子，擅自中断

1. 不知道线程拥有者的中断策略就擅自中断
2. `r.run()`里面如果抛出了RuntimeException，返回到了caller那里，然后时间到了触发了caller线程的interruption
3. `r.run()`先结束了，然后和第2点说的一样
4. 如果`r.run()`不响应中断，那么timedRun方法就不会返回直到r.run()结束

```java
// 本意是控制timeRun方法的执行时长
public void timedRun(Runnable r) {
  final Thread taskThread = Thread.currentThread();
  scheduledExecutor.schedule(() -> taskThread.interrupt(), timeout, unit);
  r.run();
}
```

### 用Future中断

```java
public void timedRun(Runnable r) {
  Future f = executorService.submit(r);
  try {
    f.get(timeout, unit);
  } catch (TimeoutException e) {
    // 下面会取消这个task的
  } catch (ExecutionException e) {
    // 在task里出现异常，rethrow
    throw e.getCause();
  } finally {
    // 对一个正常结束的future执行cancel是没有伤害的
    f.cancel(true); // true代表interrupt
  }
}
```

### 对付不响应中断

有些方法不响应中断，但是我们要中断咋整？下面给了一个思路：

```java
public class ReaderThread extends Thread {
  private final Socket socket;
  private final InputStream in;
  @Override
  public void interrupt() {
    try {
      socket.close();
    } catch (IOException ignored) {}
    finally {
      super.interrupt(); // 注意还是得让上级中断的
    }
  }
  @Override
  public void run() {
    in.read(buf); // 这个方法阻塞但是不响应中断
  }
}
```

### 对付不响应中断2

如果你是用Executor执行，则可以这样做提供自己的`ThreadPoolExecutor.newTaskFor`实现，并提供自己的`Future.cancel(boolean)`：

```java
public interface CancellableTask<T> extends Callable<T> {
  void cancel();
  RunnableFuture<T> newTask();
}
public class CancellingExecutor extends ThreadPoolExecutor {
  // 看这个方法
  @Override
  protected<T> RunnableFuture<T> newTaskFor(Callable<T> callable) {
    if (callable instanceof CancellableTask) {
      return ((CancellableTask<T>) callable).newTask();
    }
    return super.newTaskFor(callable);
  }
}
public abstract class SocketUsingTask<T> implements CancellableTask<T> {
  private Socket socket;
  public synchronized void cancel() {
    try {
      if (socket != null) {
        socket.close();
      }
    } catch (IOException ignored) {}
  }
  public RunnableFuture<T> newTask() {
    return new FutureTask<T>(this) {
      // 看这个方法
      @Override
      public boolean cancel(boolean mayInterruptIfRunning) {
        try {
          try {
            SocketUsingTask.this.cancel()            
          } finally {
            return super.cancel(mayInterruptIfRunning);
          }
        }
      }
    }
  }
}
```

## 停止基于线程的Service

![](stopping-service.png)

### 利用ExecutorService

```java
public class LogService {
  private final ExecutorService exec = ...;
  public void stop() throws InterruptionException {
    try {
      exec.shutdown();
      exec.awaitTermination(timeout, unit);
    } finally {
      writer.close();
    }
  }
  public void log(String msg) {
    try {
      exec.execute(new WriteTask(msg));
    } catch (RejectedExecutionException ignored) {}
  }
}
```

### 利用Poison Pills

```java
producer.(POISON_PILL);

if (POISON_PILL == consumer.take()) {
  doShutdownWork();
}
```

### 跟踪shutdownNow时开始但未结束的任务

`ExecutorService.shutdownNow`会返回还未开始的任务，但是不会返回开始了但是没有结束的任务，用类似下面的代码可以得到这些任务：

```java
public class TrackingExecutor extends AbstractExecutorService {
  private final ExecutorService exec;
  private final Set<Runnable> tasksCancelledAtShutdown = 
    Collections.synchronizedSet(new HashSet<Runnable>());
  public List<Runnable> getCancelledTasks() {
    if (!exec.isTerminated()) {
      throw new IllegalStateException(...);
    }
    return new ArrayList<>(tasksCancelledAtShutdown);
  }
  public void execute(final Runnable runnable) {
    exec.execute(() -> {
      try {
        runnable.run();
      } finally {
        if (isShutdown() && Thread.currentThread.isInterrupted()) {
          tasksCancelledAtShutdown.add(runnable);
        }
      }
    })
  }
}
```

## 线程异常退出

![](abnormal-termination.png)

下面的代码在线程异常退出前告知框架它死了：

```java
public void run() {
  Throwable thrown = null;
  try {
    while (!isInterrupted()) {
      runTask(getTaskFromWorkQueue());
    }
  } catch (Throwable e) {
    thrown = e;
  } finally {
    threadExited(this, thrown);
  }
}
```

## JVM shutdown

![](jvm-shutdown.png)