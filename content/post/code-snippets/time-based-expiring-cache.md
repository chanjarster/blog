---
title: "算法 - 基于时间过期策略的缓存"
author: "颇忒脱"
tags: ["ARTS", "ARTS-A", "缓存"]
date: 2020-02-20T14:17:46+08:00
---

<!--more-->

有这么一个要求，实现一个缓存，缓存的key在5分钟之后过期，清除可以在另一个线程中做。

实现思路：

* 一个Map<K, V>保存缓存
* 一个Queue用来保存put操作，并记录每个put动作所发生的时间
* 在对缓存put的时候，不仅对Map<K, V> put，也对Queue add。那么这个Queue就变成了一个按照时间顺序存放的队列。
* 弄一个线程定时
  1. peek Queue
  1. 如果Queue是空的，啥都不做
  1. 如果头元素记录的时间已经距离当前时间超过5分钟，那么就remove它，然后重复第一步
  1. 如果不是，则结束

代码实现如下：

ExpiryPolicy：

```java
public class ExpiryPolicy {

  private long ttlMillis;

  private Cache cache;

  private ConcurrentLinkedQueue<Node> writeQueues = new ConcurrentLinkedQueue<>();

  private ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor();

  public ExpiryPolicy(long ttlMillis, Cache cache) {
    this.ttlMillis = ttlMillis;
    this.cache = cache;
  }

  public void writeNode(Node node) {
    writeQueues.add(node);
  }

  public void start() {
    executor.scheduleWithFixedDelay(new ExpiringTask(), 
                                    ttlMillis, ttlMillis, TimeUnit.MILLISECONDS);
  }

  class ExpiringTask implements Runnable {
    @Override
    public void run() {
      System.out.println("Start purge expired keys");
      while (true) {
        long now = System.currentTimeMillis();
        Node node = ExpiryPolicy.this.writeQueues.peek();
        if (node == null || now - node.getWriteTimestamp() < ttlMillis) {
          break;
        }
        System.out.println("Remove expired key: " + node.getKey());
        ExpiryPolicy.this.writeQueues.remove(node);
        ExpiryPolicy.this.cache.remove(node.getKey());
      }
    }
  }
}
```

Cache：

```java
public class Cache<K, V> {

  private ConcurrentHashMap<K, Node<K, V>> cacheMap = new ConcurrentHashMap<>();

  private ExpiryPolicy expiryPolicy;

  public void put(K key, V value) {
    Node<K, V> node = new Node<>(key, value);
    cacheMap.put(key, node);
    expiryPolicy.writeNode(node);
  }

  public V remove(K key) {
    Node<K, V> node = cacheMap.remove(key);
    return node == null ? null : node.getValue();
  }

  public V get(K key) {
    Node<K, V> node = cacheMap.get(key);
    return node == null ? null : node.getValue();
  }

  public void setExpiryPolicy(ExpiryPolicy expiryPolicy) {
    this.expiryPolicy = expiryPolicy;
  }

}
```

Node：

```java
public class Node<K, V> {
  private K key;
  private V value;
  private long writeTimestamp;

  public Node(K key, V value) {
    this.key = key;
    this.value = value;
    this.writeTimestamp = System.currentTimeMillis();
  }
  
  // getters, equals, hashCode
}
```

用法：

```java
public class CacheTest {

  @Test
  public void test() throws InterruptedException {
    Cache<String, Integer> cache = new Cache<>();
    ExpiryPolicy expiryPolicy = new ExpiryPolicy(TimeUnit.SECONDS.toMillis(5), cache);
    cache.setExpiryPolicy(expiryPolicy);
    expiryPolicy.start();

    cache.put("foo", 1);
    cache.put("bar", 2);

    assertEquals(cache.get("foo"), Integer.valueOf(1));
    assertEquals(cache.get("bar"), Integer.valueOf(2));

    TimeUnit.SECONDS.sleep(8L);

    assertEquals(cache.get("foo"), null);
    assertEquals(cache.get("bar"), null);
  }

}
```

相关代码在[这里][1]。



[1]: https://github.com/chanjarster/code-snippets/tree/master/time-based-expiring-cache