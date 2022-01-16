---
title: "The Java Memory Model"
author: "颇忒脱"
tags: ["ARTS-T", "并发编程"]
date: 2019-11-26T20:56:29+08:00
---

<!--more-->

## 什么是内存模型

以下因素会阻止一个线程看到变量的最新值，导致在其他线程的内存操作看起来不按顺序发生：

* 编译器生成的指令的顺序可以和源代码的顺序不同
* 编译器可以把变量存到寄存器而不是内存
* 处理器可以并行执行指令，或者不按顺序执行指令
* cache可能使得对变量的写以不同的顺序提交到main memory
* 保存在处理器本地cache中的值可能对其他处理器不可见

Java语言规范要求JVM维持“线程内看起来顺序执行的语义”。

为何会有以上因素：

* CPU的并行度的增加：pipelined superscalar执行单元，动态指令调度，speculative execution（投机执行），成熟的多级缓存。
* 编译器变得更复杂：充安排指令以优化执行，使用成熟的全局寄存器分配算法。

### 平台内存模型

多处理器架构，每个处理器有它自己的cache定时和主内存保持一致。

处理器架构提供了不同程度的cache coherence，缓存一致性。

确保每个处理器在任何时刻知道其他处理器在干什么代价是很高的。

一个架构的“内存模型”告诉程序它能够从内存系统得到怎样的保证，并规定了在共享数据时哪些特殊指令（称为内存屏障或者fence）可以得到额外的内存协调保证。

Java内存模型屏蔽了不同架构的内存模型，提供了一种抽象，它会在何时的地方插入内存屏障。

Java内存模型也不提供顺序一致性，现代多处理器架构也不支持顺序一致性。

### 重排序

下面这段代码从代码顺序来说，可能的结果是：(1, 0)，(0, 1)，(1, 1)。但还有可能是 (0, 0)。

```java
public class PossibleReordering {
  static int x = 0, y = 0;
  static int a = 0, b = 0;

  public static void main(String[] args) throws InterruptedException {
    // Thread A
    Thread one = new Thread(new Runnable() {
      public void run() {
        a = 1;
        x = b;
      }
    });
    // Thread B
    Thread other = new Thread(new Runnable() {
      public void run() {
        b = 1;
        y = a;
      }
    });
    one.start();
    other.start();
    one.join();
    other.join();
    System.out.println("( " + x + "," + y + ")");
  }
}
```

前面将了代码重排序的原因，实际上就算代码按顺序执行，因为cache刷新到主内存的时机也可能使B线程看到A是以相反顺序执行的。

```txt
Thread A  ---> x=b(0) ----------------------> a=1
Thread B  --------------> b=1 -----> y=a(0)
```

同步（synchronization）禁止了编译器、运行时和硬件对内存操作做出能够违反JMM要求的可见性保证的重排序。注意是可以重排序的，支持禁止了哪些会违反可见性保证的重排序。

happens-before：要确保操作B能够看到操作A的结果（不论A和B是否在相同线程中），它们必须有happens-before关系。如果没有happens-before，那么JVM可以随意重排序。

happens-before规则：

* 程序顺序规则：同一个线程里的操作happens-before程序顺序中的后一个操作。

* 内置锁规则：unlock 内置锁happens-before后续lock这个锁。

* volatile变量规则：对volatile变量的写happens-before后续对这个变量的读。

* 线程开始规则：线程start happens-before 这个线程里的动作。

* 线程终止：A线程里的动作 happens-before 侦测到这个线程终止的B线程的动作。Thread.join 和 Thread.isAlive 都适用该规则。

* 中断规则：A线程调用B线程的interrupt方法 happens-before B侦测到中断。B无论是收到InterruptedException，调用isInterrupted或者interrupted方法都适用该规则。

* Finalizer规则：构造函数的结束 happens-before 该对象finalizer的开始。

* 传递性规则：如果A happens-before B，B happens-before C，那么A也happens-before C。

扩展规则（接力式同步）：

* put item到线程安全集合happens-before在其他线程里从这个集合里get
* `countDown` `CountDownLatch` happens-before 一个线程从 `await` 返回 （AQS的release）
* 释放一个`Semaphore`的`permit` happens-before 从这个`Semaphore`获取`permit` （AQS的release）
* Future代表的任务所执行的动作 happens-before 其他线程从Future.get返回
* 提交`Runnable` / `Callable` 到`Executor` happens-before 任务执行
* 一个线程到达 `CyclicBarrier`/`Exchanger` happens-before 从同一个barrier/exchanger释放到其他线程。如果`CyclicBarrier`使用barrier action，那么到达`CyclicBarrier` happens-before barrier action，进而happens-before 从barrier释放到线程。

注意传递性规则，看这个图，线程A的所有操作happens-before 线程B的所有操作：

```txt
 [Thread A]
    y=1
  lock M
    x=1                        [Thread B]
  unlock M ------------------>   lock M
                                  i=x
                                 unlock M
                                  j=y
```

### 接力式同步

把一个happens-before规则和另一个happens-before规则结合起来，一般都是volatile变量 或者 内置锁，使得对一个变量的访问有序。不过这个技巧对语句的顺序很敏感，也容易被破坏，所以这个是榨取性能的最后武器，一般不推荐使用。

下面这段代码看不到什么锁，但是能够保证不被重排序是因为间接的使用了同一个volatile变量：

```java
  private final class Sync extends AbstractQueuedSynchronizer {
    /** State value representing that task is ready to run */
    private static final int READY   = 0;
    /** State value representing that task is running */
    private static final int RUNNING   = 1;
    /** State value representing that task ran */
    private static final int RAN     = 2;
    /** State value representing that task was cancelled */
    private static final int CANCELLED = 4;
    /** The result to return from get() */
    private V result;
    /** The exception to throw from get() */
    private Throwable exception;

    V innerGet() throws InterruptedException, ExecutionException {
      // 间接调用了tryAcquireShared -> 读取 volatile state变量
      acquireSharedInterruptibly(0);
      if (getState() == CANCELLED)
        throw new CancellationException();
      if (exception != null)
        throw new ExecutionException(exception);
      return result;
    }

    void innerSet(V v) {
      for (;;) {
        int s = getState();
        if (s == RAN)
          return;
        if (s == CANCELLED) {
          // 间接调用了tryReleaseShared -> 写 volatile state变量
          releaseShared(0);
          return;
        }
        if (compareAndSetState(s, RAN)) {
          result = v;
          // 间接调用了tryReleaseShared -> 写 volatile state变量
          releaseShared(0);
          done();
          return;
        }
      }
    }
  }
```

## 发布

不正确发布的风险正是发布共享对象的线程和访问该对象的线程缺少happens-before的结果。

### 不安全发布

看下面这段代码，`new Resource()`里有对Resource内部属性的写，发布这个对象则是对`resource`变量的写，两者之间缺乏happens-before关系，那么就意味着这些操作可能会重排序，也就意味着其他线程可能会看到一个构造不完全的对象：

```java
@NotThreadSafe
public class UnsafeLazyInitialization {
    private static Resource resource;

    public static Resource getInstance() {
        if (resource == null)
            resource = new Resource(); // unsafe publication
        return resource;
    }

    static class Resource {
    }
}
```

### 安全发布

举个队列的例子，如果A放X到队列的动作happens-before B从队列中取出B，那么不仅B能看到A所留下的X的状态，B也能看到A在传递X之前的所有动作。

### 安全法发布惯用法

添加了`synchronized`（用的是内置锁规则）：

```java
@ThreadSafe
public class SafeLazyInitialization {
    private static Resource resource;
  
    public synchronized static Resource getInstance() {
        if (resource == null)
            resource = new Resource();
        return resource;
    }

    static class Resource {
    }
}
```

也可以利用JVM初始化类时，初始化其静态变量串行话（使用了锁）的事实：

```java
@ThreadSafe
public class EagerInitialization {
    private static Resource resource = new Resource();

    public static Resource getResource() {
        return resource;
    }

    static class Resource {
    }
}
```

再Hack一点，弄个懒加载：

```java
@ThreadSafe
public class ResourceFactory {
    private static class ResourceHolder {
        public static Resource resource = new Resource();
    }

    public static Resource getResource() {
        return ResourceFactory.ResourceHolder.resource;
    }

    static class Resource {
    }
}
```

### Double-checked locking

下面这段代码就是臭名昭著的DCL：

```java
@NotThreadSafe
public class DoubleCheckedLocking {
    private static Resource resource;

    public static Resource getInstance() {
        if (resource == null) {  // 这行代码并未同步，因此会看到构造不完全的对象
            synchronized (DoubleCheckedLocking.class) {
                if (resource == null)
                    resource = new Resource();
            }
        }
        return resource;
    }

    static class Resource {

    }
}
```

JDK 1.5之后，可以把resource变量变成`volatile`解决这个问题（因为有了Happens-before）

### 初始化安全

“初始化安全”的保证，允许正确构建的不可变对象，安全的在线程间共享，而不需要同步，且不用考虑这个对象是如何发布的。也就是说如果上面代码`Resource`是不可变的，那就没有DCL的问题。

对于对象的final属性，初始化安全机制禁止对任何构造函数的代码和初始加载该对象引用做重排序。例外：

* 非final属性没有这个保证
* 在构造期间对象逃逸了，也没有这个保证
* 这个保证只针对于可以通过final属性得到的值有效，可认为具有传递性

下面代码是安全发布的，可以看到`SafeStates`是不可变的，`states`也只不过是`HashMap`，但`SafeStates`依然能够以和前面的`Resource`一样的形式安全发布：

```java
@ThreadSafe
public class SafeStates {
    private final Map<String, String> states;

    public SafeStates() {
        states = new HashMap<String, String>();
        states.put("alaska", "AK");
        states.put("alabama", "AL");
        /*...*/
        states.put("wyoming", "WY");
    }

    public String getAbbreviation(String s) {
        return states.get(s);
    }
}
```

