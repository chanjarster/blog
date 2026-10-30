---
title: "JVM - 对象内存布局"
author: "颇忒脱"
tags: ["jvm"]
date: 2020-05-11T20:55:08+08:00
---

<!--more-->

## 一般对象

* 对象头
  * Mark word：
  * 类型指针（Class Pointer）：
* 实例数据（instance data）
* 对齐填充（padding）



### 对象头

Mark word：hashCode、GC信息、锁信息。32位上4个字节，64位上8字节。

类型指针（Class Pointer）：指向类信息。同样是4字节/8字节。在64位上开启指针压缩（-XX:+UseCompressedOops，默认开启）则是4字节。

32位下的Mark word：

```txt
|-------------------------------------------------------|--------------------|
|                  Mark Word (32 bits)                  |       State        |
|-------------------------------------------------------|--------------------|
| identity_hashcode:25 | age:4 | biased_lock:1 | lock:2 |       Normal       |
|-------------------------------------------------------|--------------------|
|  thread:23 | epoch:2 | age:4 | biased_lock:1 | lock:2 |       Biased       |
|-------------------------------------------------------|--------------------|
|               ptr_to_lock_record:30          | lock:2 | Lightweight Locked |
|-------------------------------------------------------|--------------------|
|               ptr_to_heavyweight_monitor:30  | lock:2 | Heavyweight Locked |
|-------------------------------------------------------|--------------------|
|                                              | lock:2 |    Marked for GC   |
|-------------------------------------------------------|--------------------|
```

64位下的Mark word:

```txt
|------------------------------------------------------------------------------|--------------------|
|                                  Mark Word (64 bits)                         |       State        |
|------------------------------------------------------------------------------|--------------------|
| unused:25 | identity_hashcode:31 | unused:1 | age:4 | biased_lock:1 | lock:2 |       Normal       |
|------------------------------------------------------------------------------|--------------------|
| thread:54 |       epoch:2        | unused:1 | age:4 | biased_lock:1 | lock:2 |       Biased       |
|------------------------------------------------------------------------------|--------------------|
|                       ptr_to_lock_record:62                         | lock:2 | Lightweight Locked |
|------------------------------------------------------------------------------|--------------------|
|                     ptr_to_heavyweight_monitor:62                   | lock:2 | Heavyweight Locked |
|------------------------------------------------------------------------------|--------------------|
|                                                                     | lock:2 |    Marked for GC   |
|------------------------------------------------------------------------------|--------------------|
```

各部分含义：

| biased_lock | lock |   状态   |
| :---------: | :--: | :------: |
|      0      |  01  |   无锁   |
|      1      |  01  |  偏向锁  |
|      0      |  00  | 轻量级锁 |
|      0      |  10  | 重量级锁 |
|      0      |  11  |  GC标记  |

* **biased_lock**：对象是否启用偏向锁标记，只占1个二进制位。为1时表示对象启用偏向锁，为0时表示对象没有偏向锁。
* **age**：4位的Java对象年龄。在GC中，如果对象在Survivor区复制一次，年龄增加1。当对象达到设定的阈值时，将会晋升到老年代。默认情况下，并行GC的年龄阈值为15，并发GC的年龄阈值为6。由于age只有4位，所以最大值为15，这就是`-XX:MaxTenuringThreshold`选项最大值为15的原因。
* **identity_hashcode**：25位的对象标识Hash码，采用延迟加载技术。调用方法`System.identityHashCode()`计算，并会将结果写到该对象头中。当对象被锁定时，该值会移动到管程Monitor中。
* **thread**：持有偏向锁的线程ID。
* **epoch**：偏向时间戳。
* **ptr_to_lock_record**：指向栈中锁记录的指针。
* **ptr_to_heavyweight_monitor**：指向管程Monitor的指针。

### 实例数据

实例数据中的字段并非按照代码定义的顺序排列的，会JVM被重排序的（-XX:FieldsAllocationStyle）

一个字段的起始位置（在对象内的偏移量），必须是其类型大小的整数倍，比如一个long字段的位置只能是0、8、16。如果开启指针压缩，那么对象头占了12字节，那么这个long字段只能放在16字节的位置。

对于父子类，子类继承的父类的字段的布局肯定和父类一样，然后自己的第一个字段偏移量是4字节的倍数（开启指针压缩）或者8自己的倍数（关闭指针压缩）。下面验证一下：

```xml
<dependency>
  <groupId>org.openjdk.jol</groupId>
  <artifactId>jol-core</artifactId>
  <version>0.9</version>
</dependency>
```

```java
import org.openjdk.jol.info.ClassLayout;
import org.openjdk.jol.vm.VM;

/**
 * java 对象内存分布
 */

class A{
    long i;
}
class B extends  A{
    int  j;
}
public class MemoryLayoutTest {
    public static void main(String[] args){
        System.out.println(VM.current().details());
        System.out.println(ClassLayout.parseClass(A.class).toPrintable());
        System.out.println(ClassLayout.parseClass(B.class).toPrintable());
    }
}
```

你可以看到：

```txt
memory.A object internals:
 OFFSET  SIZE   TYPE DESCRIPTION                               VALUE
      0    12        (object header)                           N/A
     12     4        (alignment/padding gap)                  
     16     8   long A.i                                       N/A
Instance size: 24 bytes
Space losses: 4 bytes internal + 0 bytes external = 4 bytes total
```

A.i字段偏移量为其类型（long）的倍数。

```text
memory.B object internals:
 OFFSET  SIZE   TYPE DESCRIPTION                               VALUE
      0    12        (object header)                           N/A
     12     4        (alignment/padding gap)                  
     16     8   long A.i                                       N/A
     24     4    int B.j                                       N/A
     28     4        (loss due to the next object alignment)
Instance size: 32 bytes
Space losses: 4 bytes internal + 4 bytes external = 8 bytes total
```

B从A继承来的字段偏移量和A一模一样，并且B.j的偏移量为4的倍数（默认开启了指针压缩）。

### 对齐填充

JVM要求对象按照8字节对齐填充，及对象的尺寸为8字节的倍数，如果不足则填充。这个前面已经看到过了。


## 数组对象

数组对象比在对象头上多了一个长度信息（Length）

* 对象头
  * Mark word：
  * 类型指针（Class Pointer）
  * 长度（Length）：4字节
* 实际数据（array data）
* 对齐填充（padding）

## 参考资料

* [聊聊java对象内存布局](https://zhuanlan.zhihu.com/p/50984945)
* [Java对象头详解](https://www.jianshu.com/p/3d38cba67f8b)

