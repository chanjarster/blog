---
title: "Atomic Variables and Nonblocking Synchronization"
author: "颇忒脱"
tags: ["ARTS-T", "并发编程"]
date: 2019-11-24T22:06:29+08:00
---

<!--more-->

非阻塞算法比基于锁的算法设计起来和实现起来更复杂，但是

* 它们能够提供巨大的伸缩性和liveness优势。
* 它们在一个更细粒度的层级上协作，能够极大降低调度的开销。
* 对死锁和其他liveness问题免疫。

## CAS和锁的优劣

### 锁的劣势

如果多个线程同时请求锁，JVM会请求操作系统的帮助：

* 一些线程会被挂起（suspended），在后面还不得不恢复（resumed）——上下文切换。
* 线程恢复的时候，它还得等其他线程把它们的时间片用完，然后才能轮到它——调度。

基于锁的类在细粒度的操作上，如果竞争频繁，那么调度开销对实际工作的比率是非常高的。

锁的其他劣势：

* 当一个线程在等待锁的时候，它干不了别的事情
* 优先级倒置（priority inversion），高优先级线程等待一个被低优先线程占用的锁。
* 锁对于细粒度操作比如++来说，还是太重量级了

### 锁的优势

* 用起来方便，语法紧凑
* 可以方便的组合复杂操作

### CAS的优势

* 在【少量竞争】和【没有竞争】的情况下基于CAS的表现要比基于锁的好，因为：
  * 无竞争锁获取的fast path，包括至少一个CAS操作
  * 大多数情况下CAS能够成功，硬件可以预测分支，降低控制逻辑的开销
  * 锁虽然在语法上紧凑，但实际上包含了相对复杂的JVM代码，并且可能使用操作系统级别的locking、线程挂起、上下文切换。这些CAS没有。

### CAS的劣势

* 把处理竞争的工作交给了调用方：是重试，然是backing off，还是放弃。
* 对细粒度操作比较友好

## 硬件对并发的支持

对于细粒度操作来说可以用一种乐观的机制（锁是悲观的），这种机制依赖于“冲突检测”，检查在操作期间是否有其他线程插入进来，如果有则操作失败，然后可以选择重试还是不重试。

处理器支持的指令：

* test-and-set
* fetch-and-increment
* compare-and-swap
* load-linked/store-conditional

### Compare and swap

CAS有三个操作数：内存地址V、预期的旧值A、新值B

语义：如果V中的值等于A，那么就更新为B，否则啥都不做

返回值：V中的值

CAS操作失败的线程不会阻塞，它可自行决定是否重试，或者其他措施。

下面是一个模拟的CAS：

```java
@ThreadSafe
public class SimulatedCAS {
  @GuardedBy("this") private int value;

  public synchronized int get() {
    return value;
  }

  public synchronized int compareAndSwap(int expectedValue,
                       int newValue) {
    int oldValue = value;
    if (oldValue == expectedValue)
      value = newValue;
    return oldValue;
  }

  public synchronized boolean compareAndSet(int expectedValue,
                        int newValue) {
    return (expectedValue
        == compareAndSwap(expectedValue, newValue));
  }
}
```

### 一个非阻塞的计数器

下面是一个非阻塞的计数器的例子：

```java
@ThreadSafe
public class CasCounter {
  private SimulatedCAS value;

  public int getValue() {
    return value.get();
  }

  public int increment() {
    int v;
    do {
      v = value.get();
    } while (v != value.compareAndSwap(v, v + 1));
    return v + 1;
  }
}
```

## Atomic Variable classes

更新一个原子变量的

* fast path（无竞争）不比获得锁的fast path慢，并且通常更快。
* slow path（有竞争）绝对比获得锁的slow path快，因为没有线程挂起和调度开销。

### Atomics vs “better volatiles”

```java
@ThreadSafe
public class CasNumberRange {
  @Immutable
  private static class IntPair {
    // INVARIANT: lower <= upper
    final int lower;
    final int upper;

    public IntPair(int lower, int upper) {
      this.lower = lower;
      this.upper = upper;
    }
  }

  private final AtomicReference<IntPair> values =
      new AtomicReference<IntPair>(new IntPair(0, 0));

  public int getLower() {
    return values.get().lower;
  }

  public int getUpper() {
    return values.get().upper;
  }
  
  // 单改lower，所以用AtomicReference
  public void setLower(int i) {
    while (true) {
  /*see*/ IntPair oldv = values.get();
      if (i > oldv.upper)
        throw new IllegalArgumentException("Can't set lower to " + i + " > upper");
  /*see*/ IntPair newv = new IntPair(i, oldv.upper);
  /*see*/ if (values.compareAndSet(oldv, newv))
        return;
    }
  }

  public void setUpper(int i) {
    while (true) {
      IntPair oldv = values.get();
      if (i < oldv.lower)
        throw new IllegalArgumentException("Can't set upper to " + i + " < lower");
      IntPair newv = new IntPair(oldv.lower, i);
      if (values.compareAndSet(oldv, newv))
        return;
    }
  }
}
```

### 锁和原子变量

代码就不贴了，说结论：

* 在高竞争等级下，锁要比原子变量好那么一点点（吞吐量）。为什么？因为原子变量的版本在失败后立马又重试了，反而加剧了竞争。
* 但是现实中竞争等级没有那么高，所以原子变量比锁要好挺多（吞吐量）。

总结：

* 在低竞争等级下，原子变量提供了更好的伸缩性。
* 在高竞争等级下，锁提供了更好的竞争规避

## 非阻塞算法

如果一个算法是“非阻塞”的，那么当一个线程失败或者挂起的时候，都不会导致其他线程的失败或挂起（你可以认为没有死锁）。

如果一个算法是“无锁”的，那么在每一步上，总有一些线程可以取得进展。

### 一个非阻塞栈

注意：`compareAndSet`同时提供了可见性和原子性。

```java
@ThreadSafe
  public class ConcurrentStack <E> {
  AtomicReference<Node<E>> top = new AtomicReference<Node<E>>();

  public void push(E item) {
    Node<E> newHead = new Node<E>(item);
    Node<E> oldHead;
    do {
      oldHead = top.get();
      newHead.next = oldHead;
    } while (!top.compareAndSet(oldHead, newHead));
  }

  public E pop() {
    Node<E> oldHead;
    Node<E> newHead;
    do {
      oldHead = top.get();
      if (oldHead == null)
        return null;
      newHead = oldHead.next;
    } while (!top.compareAndSet(oldHead, newHead)); // 看top是否变更过
    return oldHead.item;
  }

  private static class Node <E> {
    public final E item;
    public Node<E> next;

    public Node(E item) {
      this.item = item;
    }
  }
}
```

### 一个非阻塞链表

构建非阻塞的算法的关键在于限定原子性变更仅限定在单个变量上，如果有多个变量要原子性更新，那么需要一些技巧：

第一个技巧，保证数据结构总是处于一致性的状态下，就算在一个多步骤更新的当中也是如此。如果A更新到一半B进来了，B可以知道这个情况，并且不会立即做自己的更新，B可以等待A完成，这样两个就不会互相影响了。

如果A操作在半当中失败了，那么B操作就永远没法获得进展，这个时候就可以有第二个技巧来确保一个线程的失败不会导致另一个线程无法进展。

第二，如果B操作发现数据结构处于A操作当中状态时，B有足够的信息帮助A把接下来的事情完成，然后在把自己的事情做掉。当A回来的时候会发现自己没做完的事情已经被B做了。

下面是一个LinkedQueue的例子，具体讲解要看书，这里点两个关键：

* 当结构处在完整状态时，tail.next是不为null的
* 当结构处在中间状态时，tail.next是为null的

```java
@ThreadSafe
public class LinkedQueue <E> {

  private static class Node <E> {
    final E item;
    final AtomicReference<LinkedQueue.Node<E>> next;

    public Node(E item, LinkedQueue.Node<E> next) {
      this.item = item;
      this.next = new AtomicReference<LinkedQueue.Node<E>>(next);
    }
  }

  private final LinkedQueue.Node<E> dummy = new LinkedQueue.Node<E>(null, null);
  private final AtomicReference<LinkedQueue.Node<E>> head
      = new AtomicReference<LinkedQueue.Node<E>>(dummy);
  private final AtomicReference<LinkedQueue.Node<E>> tail
      = new AtomicReference<LinkedQueue.Node<E>>(dummy);

  public boolean put(E item) {
    LinkedQueue.Node<E> newNode = new LinkedQueue.Node<E>(item, null);
    while (true) {
      LinkedQueue.Node<E> curTail = tail.get();
      LinkedQueue.Node<E> tailNext = curTail.next.get();
      if (curTail == tail.get()) {
 /*A*/  if (tailNext != null) {
          // Queue in intermediate state, advance tail
 /*B*/    tail.compareAndSet(curTail, tailNext);
        } else {
          // In quiescent state, try inserting new node
 /*C*/    if (curTail.next.compareAndSet(null, newNode)) {
            // Insertion succeeded, try advancing tail
 /*D*/      tail.compareAndSet(curTail, newNode);
            return true;
          }
        }
      }
    }
  }
}
```

### Atomic field updaters

`AtomicReferenceFieldUpdater`：

```java
private class Node<E> {
  private final E item;
  private volatile Node<E> next;
}
private static AtomicReferenceFieldUpdater<Node, Node> nextUpdater
  = AtomicReferenceFieldUpdater.newUpdater(Node.class, Node.class, "next");
```

Atomic field updater代表了一个对volatile字段的反射视图，然后你可以利用它使用CAS。

为何要用Atomic field updater是因为性能原因：

* 对于频繁创建的，短命的对象（比如队列的Node），每次都创建`AtomicReference`是一笔开销，用Atomic field updater则免去了这个开销。

另外Atomic field updater还可以帮助你保留对象的序列化形式。

### ABA问题

CAS解决的是“V的值是否依然是A？”，但如果V的值再很短的时间内变成过B，又变回A，那么这个就是ABA问题。

在大多数情况下ABA无所谓，但是有些情况下则不行，比如对于链表来说，head依然指向某个node不代表这个链表没有变过。

解决办法，在更新值的同时更新版本号，对比的时候连值和版本号一起对比。`AtomicStampedReference`可以干这个，`AtomicMarkableReference`也差不多。