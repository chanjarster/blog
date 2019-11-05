---
title: "Explicit Locks"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "并发编程"]
date: 2019-11-05T20:40:29+08:00
---

<!--more-->

![](explicit-locks.png)

## Lock和ReentrantLock

Lock接口：

```java
public interface Lock {
  void lock();
  void lockInterruptibly() throws InterruptedException;
  boolean tryLock();
  boolean tryLock(long timeout, TimeUnit unit) throws InterruptedException;
  void unlock();
  Condition newCondition();
}
```

Lock的典型用法：

```java
Lock lock = new ReentrantLock();
...
lock.lock();
try {
  // update object state
  // catch exceptions and restore invariants if necessary
} finally {
  lock.unlock();
}
```

### 轮询的和定时的获得锁

一个死锁重试的例子：

```java
/**
 * DeadlockAvoidance
 * <p/>
 * Avoiding lock-ordering deadlock using tryLock
 *
 * @author Brian Goetz and Tim Peierls
 */
public class DeadlockAvoidance {
  private static Random rnd = new Random();

  public boolean transferMoney(Account fromAcct,
                 Account toAcct,
                 DollarAmount amount,
                 long timeout,
                 TimeUnit unit)
      throws InsufficientFundsException, InterruptedException {
    long fixedDelay = getFixedDelayComponentNanos(timeout, unit);
    long randMod = getRandomDelayModulusNanos(timeout, unit);
    long stopTime = System.nanoTime() + unit.toNanos(timeout);

    while (true) {
      if (fromAcct.lock.tryLock()) {  // 注意这个if，true就是成功获得，false反之
        try {
          if (toAcct.lock.tryLock()) {
            try {
              if (fromAcct.getBalance().compareTo(amount) < 0)
                throw new InsufficientFundsException();
              else {
                fromAcct.debit(amount);
                toAcct.credit(amount);
                // 成功得到锁在这里会返回
                return true;
              }
            } finally {
              toAcct.lock.unlock();
            }
          }
        } finally {
          fromAcct.lock.unlock();
        }
      }
      // 到这里说明没有成功
      if (System.nanoTime() < stopTime)
        return false;
      // 随机sleep避免再次冲突
      NANOSECONDS.sleep(fixedDelay + rnd.nextLong() % randMod);
    }
  }

  private static final int DELAY_FIXED = 1;
  private static final int DELAY_RANDOM = 2;

  static long getFixedDelayComponentNanos(long timeout, TimeUnit unit) {
    return DELAY_FIXED;
  }

  static long getRandomDelayModulusNanos(long timeout, TimeUnit unit) {
    return DELAY_RANDOM;
  }

  static class DollarAmount implements Comparable<DollarAmount> {
    public int compareTo(DollarAmount other) {
      return 0;
    }

    DollarAmount(int dollars) {
    }
  }

  class Account {
    public Lock lock;

    void debit(DollarAmount d) {
    }

    void credit(DollarAmount d) {
    }

    DollarAmount getBalance() {
      return null;
    }
  }

  class InsufficientFundsException extends Exception {
  }
}
```

下面实际上是一个单线程程序，同时为了避免永久等待，引入了超时：

```java
/**
 * TimedLocking
 * <p/>
 * Locking with a time budget
 *
 * @author Brian Goetz and Tim Peierls
 */
public class TimedLocking {
  private Lock lock = new ReentrantLock();

  public boolean trySendOnSharedLine(String message,
                     long timeout, TimeUnit unit)
      throws InterruptedException {
    long nanosToLock = unit.toNanos(timeout)
        - estimatedNanosToSend(message); // 这个很重要，能让超时时间更准确一些
    if (!lock.tryLock(nanosToLock, NANOSECONDS))
      return false;
    try {
      return sendOnSharedLine(message);
    } finally {
      lock.unlock();
    }
  }

  private boolean sendOnSharedLine(String message) {
    /* send something */
    return true;
  }

  long estimatedNanosToSend(String message) {
    return message.length();
  }
}
```

## 读写锁

```java
public interface ReadWriteLock {
  Lock readLock();
  Lock writeLock();
}
```

例子代码（实际上更推荐ConcurrentHashMap，这里只是一个例子）：

```java
/**
 * ReadWriteMap
 * <p/>
 * Wrapping a Map with a read-write lock
 *
 * @author Brian Goetz and Tim Peierls
 */
public class ReadWriteMap <K,V> {
  private final Map<K, V> map;
  private final ReadWriteLock lock = new ReentrantReadWriteLock();
  private final Lock r = lock.readLock();
  private final Lock w = lock.writeLock();

  public ReadWriteMap(Map<K, V> map) {
    this.map = map;
  }

  public V put(K key, V value) {
    w.lock();
    try {
      return map.put(key, value);
    } finally {
      w.unlock();
    }
  }

  public V remove(Object key) {
    w.lock();
    try {
      return map.remove(key);
    } finally {
      w.unlock();
    }
  }

  public void putAll(Map<? extends K, ? extends V> m) {
    w.lock();
    try {
      map.putAll(m);
    } finally {
      w.unlock();
    }
  }

  public void clear() {
    w.lock();
    try {
      map.clear();
    } finally {
      w.unlock();
    }
  }

  public V get(Object key) {
    r.lock();
    try {
      return map.get(key);
    } finally {
      r.unlock();
    }
  }

  public int size() {
    r.lock();
    try {
      return map.size();
    } finally {
      r.unlock();
    }
  }

  public boolean isEmpty() {
    r.lock();
    try {
      return map.isEmpty();
    } finally {
      r.unlock();
    }
  }

  public boolean containsKey(Object key) {
    r.lock();
    try {
      return map.containsKey(key);
    } finally {
      r.unlock();
    }
  }

  public boolean containsValue(Object value) {
    r.lock();
    try {
      return map.containsValue(value);
    } finally {
      r.unlock();
    }
  }
}
```

