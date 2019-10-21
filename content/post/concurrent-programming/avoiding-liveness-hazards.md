---
title: "Avoiding Liveness Hazards"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "并发编程"]
date: 2019-10-21T21:40:29+08:00
---

<!--more-->

![](avoiding-liveness-hazards.png)

### Lock-ordering deadlocks

不同线程，获得获得相同多个锁的顺序不同导致死锁：

```java
public class LeftRightDeadlock {
  private final Object left = new Object();
  private final Object right = new Object();
  public void leftRight() {
    synchronized (left) {
      synchronized (right) {
        doSomething();
      }
    }
  }
  public void rightLeft() {
    synchronized (right) {
      synchronized (left) {
        doSomething();
      }
    }
  }
}
```

### Dynamic lock order deadlocks

根据参数来决定locking顺序同样有死锁风险：

```java
public void transferMoney(Account from, Account to, double amount) {
  synchronized (from) {
    synchronized (to) {
      doSomething();
    }
  }
}
```

解决办法：根据参数来推导出固定的locking顺序：

```java
priate static final Object tieLock = new Object();

public void transferMoney(Account from, Account to, double amount) {
  long fromHash = System.identityHashCode(from);
  long toHash = System.identityHashCode(to);
  if (fromHash < toHash) {
    synchronized (from) {
      synchronized (to) {
        doSomething();
      }
    }
  } else if (toHash < fromHash) {
    synchronized (to) {
      synchronized (from) {
        doSomething();
      }
    }
  } else {
    synchronized (tieLock) {
      // 当出现hash相同的情况时，全部都穿行到tieLock下执行
      synchronized (from) {
        synchronized (to) {
          doSomething();
        }
      }
    }
  }
}
```

### Deadlocks between cooperating object

因为多个对象的协作导致的比较隐蔽的死锁：

```java
class Taxi {
  private final Dispatcher dispatcher;
  public synchronized Point getLocation() {
    // ...
  }
  public synchronized void setLocation(Point location) {
    this.location = location;
    // alien method
    dispatcher.notifyAvailable(this);
  }
}
class Dispatcher {
  private final Set<Taxi> taxis;
  public synchronized void notifyAvailable(Taxi taxi) {
    // ...
  }
  public synchronized Image getImage() {
    Image image = new Image();
    for (Taxi taxi : taxis) {
      // alien method
      image.drawMarker(taxi.getLocation());
    }
    return image;
  }
}
```

### Open calls

用Open calls改造，

```java
class Taxi {
  private final Dispatcher dispatcher;
  public synchronized Point getLocation() {
    // ...
  }
  public void setLocation(Point location) {
    synchronized (this) {
      this.location = location;      
    }
    // alien method
    dispatcher.notifyAvailable(this);
  }
}
class Dispatcher {
  private final Set<Taxi> taxis;
  public synchronized void notifyAvailable(Taxi taxi) {
    // ...
  }
  public Image getImage() {
		Set<Taxi> copy;
    // 限制了在调用alien方法时，本身不持有锁
    synchronized (this) {
      copy = new HashSet<>(taxis);
    }
    Image image = new Image();
    for (Taxi taxi : copy) {
      // alien method
      image.drawMarker(taxi.getLocation());
    }
    return image;
  }
}
```

