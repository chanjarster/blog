---
title: "Building Custom Synchronizers"
author: "颇忒脱"
tags: ["并发编程"]
date: 2019-11-21T20:40:29+08:00
---

<!--more-->

## 状态依赖的类

* 某些操作具有基于状态的前置条件的类
* 比如：FutureTask、Semaphore、BlockingQueue
* 比如：你不能从空队列中移除item，不能在任务结束前得到结果

构建状态依赖的类最简单的办法就是利用已有的状态依赖的类。比如使用`CountDownLatch`，或者自己构建同步器。自己构建同步器可以利用：内置条件队列（intrinsic condition queues）、显式`Condition`对象、`AbstractQueuedSynchronizer`框架。

## 管理状态依赖

使用polling（轮询）和sleeping来出来状态依赖是很痛苦的。所以不推荐。

阻塞的状态依赖动作的结构：

```java
acquire lock on object state
while (precondition does not hold) {
  release lock
  wait until precondition might hold
  optionally fail if interrupted or timeout expires
  reacquire lock
}
perform action
release lock
```

下面是一个有届的Buffer的基类，用的是循环数组，后面有些例子会用它来说明：

```java
@ThreadSafe
public abstract class BaseBoundedBuffer <V> {
    @GuardedBy("this") private final V[] buf;
    @GuardedBy("this") private int tail;
    @GuardedBy("this") private int head;
    @GuardedBy("this") private int count;

    protected BaseBoundedBuffer(int capacity) {
        this.buf = (V[]) new Object[capacity];
    }

    protected synchronized final void doPut(V v) {
        buf[tail] = v;
        if (++tail == buf.length)
            tail = 0;
        ++count;
    }

    protected synchronized final V doTake() {
        V v = buf[head];
        buf[head] = null;
        if (++head == buf.length)
            head = 0;
        --count;
        return v;
    }

    public synchronized final boolean isFull() {
        return count == buf.length;
    }

    public synchronized final boolean isEmpty() {
        return count == 0;
    }
}
```

### 例子：传播前置条件失败给调用方（不要）

下面这个例子不要的地方在于：

* Full和Empty是两个正常状态，抛异常不好
* 调用方得捕获异常，然后还要自己重试，重试的方式有两种
  * sleep，但是sleep时长很难掌握，会造成响应度不够
  * 不sleep直接重试，这个就是所谓的busy waiting或者spin waiting，浪费CPU
* 调用方处理前置条件失败

```java
@ThreadSafe
public class GrumpyBoundedBuffer <V> extends BaseBoundedBuffer<V> {
    public GrumpyBoundedBuffer(int size) {
        super(size);
    }

    public synchronized void put(V v) throws BufferFullException {
        if (isFull())
            throw new BufferFullException();
        doPut(v);
    }

    public synchronized V take() throws BufferEmptyException {
        if (isEmpty())
            throw new BufferEmptyException();
        return doTake();
    }
}

class ExampleUsage {
    private GrumpyBoundedBuffer<String> buffer;
    int SLEEP_GRANULARITY = 50;

    void useBuffer() throws InterruptedException {
        while (true) {
            try {
                String item = buffer.take();
                // use item
                break;
            } catch (BufferEmptyException e) {
                Thread.sleep(SLEEP_GRANULARITY);
            }
        }
    }
}

class BufferFullException extends RuntimeException {
}

class BufferEmptyException extends RuntimeException {
}
```

不用异常也可以，比如通过返回一个Error结果，但是问题的本质没有变

### 例子：用轮询和睡眠来阻塞

这个例子稍微好点，自己处理前置条件失败：

```java
@ThreadSafe
public class SleepyBoundedBuffer <V> extends BaseBoundedBuffer<V> {
    int SLEEP_GRANULARITY = 60;

    public SleepyBoundedBuffer() {
        this(100);
    }

    public SleepyBoundedBuffer(int size) {
        super(size);
    }

    public void put(V v) throws InterruptedException {
        while (true) {
            synchronized (this) {
                if (!isFull()) {
                    doPut(v);
                    return;
                }
            }
            Thread.sleep(SLEEP_GRANULARITY);
        }
    }

    public V take() throws InterruptedException {
        while (true) {
            synchronized (this) {
                if (!isEmpty())
                    return doTake();
            }
            Thread.sleep(SLEEP_GRANULARITY);
        }
    }
}
```

不过问题也差不多：睡眠的粒度很难把握，短了浪费CPU，长了增加响应度，

### 条件队列（Condition queues）

起名为Condition queue是因为它给一组线程——称为wait set——等待特定的条件变为true。这个队列中的元素是等待条件的线程。

每个对象可以作为condition queue，`Object`的`wait`、`notify`、`notifyAll`方法构成了内置条件队列的API。

对象内置锁和内置条件队列是关联的：

* 你要调用条件队列方法必须先获得对象锁。
* 你不能等待条件除非你能检查状态，你不能把其他线程从条件等待中释放除非你能够修改状态。

下面这个例子更简单，也更高效，响应度更高。

```java
@ThreadSafe
public class BoundedBuffer <V> extends BaseBoundedBuffer<V> {
    // CONDITION PREDICATE: not-full (!isFull())
    // CONDITION PREDICATE: not-empty (!isEmpty())
    public BoundedBuffer() {
        this(100);
    }

    public BoundedBuffer(int size) {
        super(size);
    }

    // BLOCKS-UNTIL: not-full
    public synchronized void put(V v) throws InterruptedException {
        while (isFull())
            wait();
        doPut(v);
        notifyAll();
    }

    // BLOCKS-UNTIL: not-empty
    public synchronized V take() throws InterruptedException {
        while (isEmpty())
            wait();
        V v = doTake();
        notifyAll();
        return v;
    }

    // BLOCKS-UNTIL: not-full
    // Alternate form of put() using conditional notification
    // 减少notifyAll的次数
    public synchronized void alternatePut(V v) throws InterruptedException {
        while (isFull())
            wait();
        boolean wasEmpty = isEmpty();
        doPut(v);
        if (wasEmpty)
            notifyAll();
    }
}
```

## 使用条件队列

### 条件判断 The condition predicate

* 正确使用条件队列的关键是识别对象所等待的condition predicates。
* contidition predicates是使得操作依赖于状态的前置条件。
* 比如`take`的condition predicate是buffer不为空、`put`的则是buffer没有满

condition wait牵涉三个：加锁、`wait`方法、被锁保护的状态变量。测试condition predicate之前要得到锁，锁对象和条件队列对象得是同一个。

`wait`方法：释放锁，阻塞当前线程，等待——直到或超过规定时间、或线程被中断、或线程被通知唤醒。线程被唤醒后和其他线程再次争抢锁。

### 醒得太快 waking up too soon

从`wait`中醒来不代表condition predicate变成true了，所以醒过来后一定要判断条件。

一个内置条件队列可能被多个condition predicate使用，因此如果有人调用了`notifyAll`不代表你等待的condition predicate变成true了。而且`wait`还会虚假的醒来，即并没有人调用`notify`。

下面是经典用法：

```java
void stateDependentMethod() throws InterruptedException {
  synchronized(lock) {
    while (!conditionPredicate()) {
      lock.wait();
    }
    // object is no in desired state
  }
}
```

使用`Object.wait`或`Condition.await`要记牢：

* 总是得有一个condition predicate
* 在`wait`之前，和从`wait`唤醒之后要测试condition predicate
* 总是在循环中调用`wait`
* 保证condition predicate所用的状态变量被condition queue的相同锁保护
* 调用`wait`、`notify`、`notifyAll`之前要持有锁
* 在检查condition predicate之后但在对其进行操作之前，请勿释放锁

### 漏掉的信号

漏掉信号发生在：一个线程必须等待一个已经是true的条件，但是在等待之前没能检查condition predicate。

如果A 先`notify`，而B在后面`wait`，那么B是不会得到A发出的信号的，所以在`wait`之前一定要检查condition predicate。用前面的代码结构就能解决这个问题。

### 通知

如果你在等待一个条件，那么确保肯定有其他人会在条件变成true的时候发出通知。

通知也需要得到锁，所以而且通知线程释放锁越快越好。大部分情况下要用`notifyAll`而不是`notify`，因为`notify`只通知一个线程，如果这个线程等待的condition没有变成true，那么这次通知就浪费了，那么其他线程就没有机会了，也就是这个信号被劫持了。

`notify`可以作为性能优化的手段，但还是那句老话，先做对再做好。

### 例子：gate class

下面是一个gate例子，gate关闭的时候线程等待，gate打开的时候线程通过：

```java
@ThreadSafe
public class ThreadGate {
    // CONDITION-PREDICATE: opened-since(n) (isOpen || generation>n)
    @GuardedBy("this") private boolean isOpen;
    @GuardedBy("this") private int generation;

    public synchronized void close() {
        isOpen = false;
    }

    public synchronized void open() {
        ++generation;
        isOpen = true;
        notifyAll();
    }

    // BLOCKS-UNTIL: opened-since(generation on entry)
    public synchronized void await() throws InterruptedException {
        int arrivalGeneration = generation;
        while (!isOpen && arrivalGeneration == generation)
            wait();
    }
}
```

解释一下这段：

```java
while (!isOpen && arrivalGeneration == generation)
  wait();
```

如果大门关闭 且 线程进入时的代数和门的代数一样，就要等待。反过来的意思是，如果大门开放，或者线程进入时的代数比门的代数更老，则通过。为什么？

因为在从`wait`唤醒到再次进入while之间门可能会被关闭，如果只看`open`状态，那么有一部分线程就会通不过，这个是有问题的，因为Gate设计的本来意是如果大门打开，那么就同时释放。

### 子类安全性问题

一个依赖状态的类应该要么完全暴露（并文档）它的等待和通知协议给子类，要么压根防止子类参与进来。

### 封装Condition queues

最好封装条件队列，这样在类层级外部就不会访问到它。

### 进入和退出协议

略。

## 显式条件对象

`Condition`对象关联一个`Lock`对象，一个`Lock`对象可以有很多`Condition`对象。`Condition`对象继承了`Lock`对象的公平性。

下面是`Condition`接口：

```java
void await()
boolean await(long time, TimeUnit unit)
long awaitNanos(long nanosTimeout)
void awaitUninterruptibly()
boolean awaitUntil(Date deadline)
void signal()
void signalAll()
```

下面是一个例子：

```java
@ThreadSafe
public class ConditionBoundedBuffer <T> {
    protected final Lock lock = new ReentrantLock();
    // CONDITION PREDICATE: notFull (count < items.length)
    private final Condition notFull = lock.newCondition();
    // CONDITION PREDICATE: notEmpty (count > 0)
    private final Condition notEmpty = lock.newCondition();
    private static final int BUFFER_SIZE = 100;
    @GuardedBy("lock") private final T[] items = (T[]) new Object[BUFFER_SIZE];
    @GuardedBy("lock") private int tail, head, count;

    // BLOCKS-UNTIL: notFull
    public void put(T x) throws InterruptedException {
        lock.lock();
        try {
            while (count == items.length)
                notFull.await();
            items[tail] = x;
            if (++tail == items.length)
                tail = 0;
            ++count;
            notEmpty.signal();
        } finally {
            lock.unlock();
        }
    }

    // BLOCKS-UNTIL: notEmpty
    public T take() throws InterruptedException {
        lock.lock();
        try {
            while (count == 0)
                notEmpty.await();
            T x = items[head];
            items[head] = null;
            if (++head == items.length)
                head = 0;
            --count;
            notFull.signal();
            return x;
        } finally {
            lock.unlock();
        }
    }
}
```



## 解剖同步器

像`ReentrantLock`、`Semaphore`、`CountDownLatch`、`FutureTask`，都是利用了`AbstractQueuedSynchronizer` (AQS)。

## AbstractQueuedSynchronizer

基于AQS的同步器执行的操作是`acquire`和`release`的变种：

* 获取（acquire）是状态依赖的操作，而且总是会阻塞
* 释放（release）不是一个阻塞操作，一次释放可能会允许阻塞在acquire的线程通过。

AQS管理同步器的状态，通过`getState`、`setState`、`compareAndSetState`方法。比如：

* `ReentrantLock`使用它来记录拥有锁的线程获得锁的次数（可重入的关系）
* `Semaphore`使用它来代表剩余的permits
* `FutureTask`用它来表示任务的状态：没开始、运行中、完成、取消。

同步器也可以保存其他状态，比入`ReentrantLock`保存了lock owner线程，用来确保只有owner可以释放锁。



`acquire`可能是独占的（exclusive），比如`ReentrantLock`。也可以是非独占的（non-exclusive)，比如`Sempaphore`和`CountDownLatch`。

一次`acquire`的包含两个部分：

* 第一部分
  1. 判断当前状态是否允许获取
  2. 如果允许，线程通过。如果不允许，线程阻塞或者失败。

* 第二部分：更新同步器状态。

`acquire`和`release`的经典形式：

```java
boolean acquire() throws InterruptedException {
  while (state does not permit acquire) {
    if (blocking acquisition requested) {
      enqueue current thread if not already queued
      block current thread
    }
    else
      return failure
  }
  possibly update synchronization state
  dequeue thread if it was queued
  return success
}
void release() {
  update synchronization state
  if (new state may permit a blocked thread to acquire) 
    unblock one or more queued threads
}
```

实现AQS：

* 支持独占式获取的同步器要实现：`tryAcquire`、 `tryRelease`、 `isheldExclusively`方法。
* 支持非独占获取的同步器要实现：`tryAcquireShared`、`tryReleaseShared`。
* AQS的`acquire`、`acquireShared`、`release`、`releaseShared`会调用上面的`try*`方法。

`tryAcquireShared`方法返回值说明：

* < 0，获取失败
* = 0，独占式获取成功
* &gt; 0，非独占式获取成功

`tryRelease`和`tryReleaseShared`返回值说明：

* true，可以释放阻塞在获取操作的线程
* false，不释放线程

### 简单的Latch

```java
@ThreadSafe
public class OneShotLatch {
    private final Sync sync = new Sync();

    public void signal() {
        sync.releaseShared(0);
    }

    public void await() throws InterruptedException {
        sync.acquireSharedInterruptibly(0);
    }

    private class Sync extends AbstractQueuedSynchronizer {
        protected int tryAcquireShared(int ignored) {
            // Succeed if latch is open (state == 1), else fail
            return (getState() == 1) ? 1 : -1;
        }

        protected boolean tryReleaseShared(int ignored) {
            setState(1); // Latch is now open
            return true; // Other threads may now be able to acquire

        }
    }
}
```

一般来说不会直接继承AQS，而是弄一个私有内部类来继承，这样可以保证封装。

## AQS在JUC同步器中的运用

### ReentrantLock

```java
protected boolean tryAcquire(int ignored) {
  find Thread current = Thread.currentThread();
  int c = getState();
  if (c == 0) {
    if (compareAndSetState(0, 1)) {   // 这里的整段代码不是同步的
      owner = current;                // 没成功说明被别的线程抢了，会跑到最后的return false
      return true;
    }
  } else if (current == owner) {
    setState(c + 1);
    return true
  }
  return false;
}
```

### Semaphore和CountDownLatch

在Semaphore中的运用：

```java
protected int tryAcquireShared(int acquires) {
  while (true) {
    int available = getState();
    int remaining = available - acquires;
    if (remaining < 0 || compareAndSetState(available, remaining))
      /* > 0: 我拿别人也能拿，非独占
         = 0: 我拿别人拿不了，独占
         < 0: 谁都拿不了
       */
      return remaining;
  }
}
protected boolean tryReleaseShared(int releases) {
  while (true) {
    int p = getState();
    if (compareAndSetState(p, p + releases))
      return true;
  }
}
```

在CountDownLatch中的运用：

无

### FutureTask

state保存任务状态：running、completed、cancelled，同时保存计算结果或抛出的异常，还维护了一个运行这个任务的线程（为了能够cancel）

### ReentrantReadWriteLock

同时使用了shared和非shared两种方法。

AQS内部维护了一个等待线程的队列，跟踪每个线程是请求独占还是非独占。在ReentrantReadWriteLock里，当锁可用式，如果队列头的线程请求写锁，它会得到它。如果队列头线程请求读锁，则会释放它和后面的线程，直到碰到一个请求写锁的线程。