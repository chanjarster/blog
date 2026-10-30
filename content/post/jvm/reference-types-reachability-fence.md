---
title: "JVM - 强软弱虚引用以及Reachability Fence"
author: "颇忒脱"
tags: ["jvm"]
date: 2020-05-19T14:18:08+08:00
---

<!--more-->

## 强软弱虚引用

四种引用类型分别对应了四种可达性：

* 强可达：一个线程可以通过强引用达到一个对象，而不是通过软弱虚引用对象达到。
* 软可达：不是强可达，但是可以通过SoftReference达到
* 弱可达：不是强可达，也不是弱可达，可以通过WeakReference达到。当一个弱可达对象被清理了，那么它就变成了“可被finalization”
* 虚可达：对象不是以上三种可达，但是已经被finalized，然后有一些虚引用引用它。
* 不可达：不是以上四种可达，“可被回收”。

## 引用队列（ReferenceQueue）

当引用对象（软、弱、虚对象）的可达性发生变化的时候，它们就会被注册到[ReferenceQueue][1]里。

当一个软引用、弱引用被GC清理的时候（`get()`会返回null），他们会被追加到引用队列中。所以软、弱引用配合队列使用一般用处不大。除非你做了一个软、弱引用的子类，并且在里面添加了一些属性：

```java
ReferenceQueue<Foo> fooQueue = new ReferenceQueue<Foo>();

class ReferenceWithCleanup extends WeakReference<Foo> {
  Bar bar;
  ReferenceWithCleanup(Foo foo, Bar bar) {
    super(foo, fooQueue);
    this.bar = bar;
  }
  public void cleanUp() {
    bar.cleanUp();
  }
}

public Thread cleanupThread = new Thread() {
  public void run() {
    while(true) {
      ReferenceWithCleanup ref = (ReferenceWithCleanup)fooQueue.remove();
      ref.cleanUp();
    }
  }
}
```

当一个对象编程虚可达的时候，它的虚引用就会被添加到引用队列，当虚引用对象被清理或者虚引用对象变得不可达的时候，对象就才会变成不可达。

### 强引用（Strong Reference）

一般的引用

### 软引用（Soft Reference）

当要发生OOM之前，JVM会回收[SoftReference][2]所引用的对象。

软引用一般用来实现Cache，这样实现的Cache不会对内存造成压力，因为会被回收掉。

### 弱引用（Weak Reference）

[WeakReference][3]完全不影响垃圾回收，该回收的时候还是会被回收。

弱引用的特性用代码表示是：

```java
Object referent3 = weakReference2.get();
if (referent3 != null) {
    // GC hasn't removed the instance yet
} else {
    // GC has cleared the instance
}
```

你可以用来实现，如果你不想保持对A对象的强引用，同时如果A对象没有被回收，那么我就可以干活，如果A对象被回收了，那我也无所谓的逻辑。

### 虚引用（Phantom Reference）

[PhantomReference][4]完全不影响垃圾回收，该回收的时候还是会被回收。同时也无法得到所引用的对象，`get()`方法永远返回null。虚引用一定要配合ReferenceQueue来使用：

```java
Object counter = new Object();
ReferenceQueue refQueue = new ReferenceQueue<>();
PhantomReference<Object> p = new PhantomReference<>(counter, refQueue);
counter = null;
System.gc();
try {
    // Remove是一个阻塞方法，可以指定timeout，或者选择一直阻塞
    Reference<Object> ref = refQueue.remove(1000L);
    if (ref != null) {
        // do something
    }
} catch (InterruptedException e) {
    // Handle it
}
```

前面可达性已经说了，“虚可达”后面的状态是“不可达”，那么一个对象变成“虚可达”的意思就是它现在已经被finalized，但是还没有被回收，配合ReferenceQueue，就能够得到“对象该清理的都清理了，都已经被finalized了，即将被回收”的事件。

## Reachability Fence

[`java.lang.ref.Reference#reachabilityFence(Object ref)][5]静态方法用来将ref所指向的对象设置为强引用。

这个是因为Java在垃圾回收的时候，会把下面的对象回收掉：

```java
new Foo().action()；
```

因为GC依赖的是可达性分析，而Foo对象实际上并不可达，就算它在调用方法，也是不可达的。为了避免在`action()`方法执行时被回收，可以添加这段代码：

```java
public void action() {
  try {
    // do some work
  } finally {
    Reference.reachabilityFence(this);
  }
}
```

这段代码的意思是在`action()`方法返回之前，Foo对象会保持强引用状态（虽然你会觉得代码位置不是应该放在第一行吗？但文档里是这么说的）。

## 参考资料

* [强引用、软引用、弱引用、幻象引用有什么区别？][6]
* [ReferenceQueue][1]
* [SoftReference][2]
* [WeakReference][3]
* [PhantomReference][4]
* [reachabilityFence][5]
* [Reachability][6]

[1]: https://docs.oracle.com/javase/8/docs/api/java/lang/ref/ReferenceQueue.html
[2]: https://docs.oracle.com/javase/7/docs/api/java/lang/ref/SoftReference.html
[3]: https://docs.oracle.com/javase/8/docs/api/java/lang/ref/WeakReference.html
[4]: https://docs.oracle.com/javase/8/docs/api/java/lang/ref/PhantomReference.html
[5]: https://docs.oracle.com/javase/9/docs/api/java/lang/ref/Reference.html#reachabilityFence-java.lang.Object-
[6]: https://time.geekbang.org/column/article/6970
[7]: https://docs.oracle.com/javase/8/docs/api/java/lang/ref/package-summary.html#reachability