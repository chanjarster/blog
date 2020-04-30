---
title: "JVM执行方法调用（一）- 重载与重写"
author: "颇忒脱"
tags: ["JVM", "ARTS", "ARTS-T"]
date: 2019-02-08T10:28:52+08:00
---

回顾Java语言中的重载与重写，并且看看JVM是怎么处理它们的。

<!--more-->

## 重载Overload

定义：

* 在同一个类中有多个方法，它们的名字相同，但是参数类型不同。
* 或者，父子类中，子类有一个方法与父类非私有方法名字相同，但是参数类型不同。那么子类的这个方法对父类方法构成重载。

JVM是怎么处理重载的？其实是编译阶段编译器就已经决定好调用哪一个重载方法。看下面代码：

```java
class Overload {
  void invoke(Object obj, Object... args) { }
  void invoke(String s, Object obj, Object... args) { }

  void test1() {
    // 调用第二个 invoke 方法
    invoke(null, 1);    
  }
  void test2() {
    // 调用第二个 invoke 方法
    invoke(null, 1, 2); 
  }
  void test3() {
    // 只有手动绕开可变长参数的语法糖，才能调用第一个invoke方法
    invoke(null, new Object[]{1}); 
  }
}
```

上面的注释告诉了我们结果，那么怎么才能证明上面的注释呢？我们利用`javap`观察字节码可以知道。

```bash
$ javac Overload.java
$ javap -c Overload.java

Compiled from "Overload.java"
class Overload {
  ...
  void invoke(java.lang.Object, java.lang.Object...);
    Code:
       0: return
  void invoke(java.lang.String, java.lang.Object, java.lang.Object...);
    Code:
       0: return
  void test1();
    Code:
      ...
      10: invokevirtual #4  // Method invoke:(Ljava/lang/String;Ljava/lang/Object;[Ljava/lang/Object;)V
      13: return
  void test2();
    Code:
      ...
      17: invokevirtual #4  // Method invoke:(Ljava/lang/String;Ljava/lang/Object;[Ljava/lang/Object;)V
      20: return
  void test3();
    Code:
      ...
      13: invokevirtual #5  // Method invoke:(Ljava/lang/Object;[Ljava/lang/Object;)V
      16: return
}
```

这里面有很多JVM指令，你暂且不用关心，我们看`test1`、`test2`、`test3`方法调用的是哪个方法：


```txt
  void test1();
    Code:
      ...
      10: invokevirtual #4  // Method invoke:(Ljava/lang/String;Ljava/lang/Object;[Ljava/lang/Object;)V
      13: return
```

`invoke`是方法名，`(Ljava/lang/String;Ljava/lang/Object;[Ljava/lang/Object;)V`则是方法描述符。这里翻译过来就是`void invoke(String, Object, Object[])`，Java的可变长参数实际上就是数组，所以等同于`void invoke(String, Object, Object...)`。同理，`test2`调用的是`void invoke(String, Object, Object...)`，`test3`调用的是`void invoke(Object, Object...)`。关于方法描述符的详参[JVM Spec - 4.3.2. Field Descriptors][jvms-4.3.2]和[JVM Spec - 4.3.3. Method Descriptors][jvms-4.3.3]。

所以重载方法的选择是在编译过程中就已经决定的，下面是编译器的匹配步骤：

1.	不允许自动拆装箱，不允许可变长参数，尝试匹配
1. 如果没有匹配到，则允许自动拆装箱，不允许可变长参数，尝试匹配
1. 如果没有匹配到，则允许自动拆装箱，允许可变长参数，尝试匹配

**注意：编译器是根据实参类型来匹配，实参类型和实际类型不是一个概念**

如果在一个步骤里匹配到了多个方法，则根据形参类型来找最贴切的。在上面的例子中第一个`invoke`的参数是`Object, Object...`，第二个`invoke`的参数是`String, Object, Object...`，两个方法的第一个参数`String`是`Object`的子类，因此更为贴切，所以`invoke(null, 1, 2)`会匹配到第二个`invoke`方法上。
	
## 重写Override

Java语言中的定义：

* 子类方法有一个方法与父类方法的名字相同且参数类型相同。
* 父类方法的返回值可以替换掉子类方法的返回值。也就是说父类方法的返回值类型：
   * 要么和子类方法返回值类型一样。
   * 要么是子类方法返回值类型的父类。
* 两者都是非私有、非静态方法。

（更多详细信息可参考[Java Language Spec - 8.4.8. Inheritance, Overriding, and Hiding][jls-8.4.8]，这里除了有更精确详细的重写的定义，同时包含了范型方法的重写定义。）

但是JVM中对于重写的定义则有点不同：

* 子类方法的名字与**方法描述符**与父类方法相同。
* 两者都是非私有、非静态方法。

（更多详细信息可参考[JVM Spec - 5.4.5. Overriding][jvms-5.4.5]）

注意上面提到的方法描述符，前面讲过方法描述符包含了参数类型及返回值，JVM要求这两个必须完全相同才可以，但是Java语言说的是参数类型相同但是返回值类型可以不同。Java编译器通过创建Bridge Method来解决这个问题，看下面代码：

```java
class A {
  Object f() {
    return null;
  }
}
class C extends A {
  Integer f() {
    return null;
  }
}
```

然后用`javap`查看编译结果：

```bash
$ javac Override.java
$ javap -v C.class
class C extends A
...
{
  java.lang.Integer f();
    descriptor: ()Ljava/lang/Integer;
    flags:
    Code:
      stack=1, locals=1, args_size=1
         0: aconst_null
         1: areturn
  ...
  java.lang.Object f();
    descriptor: ()Ljava/lang/Object;
    flags: ACC_BRIDGE, ACC_SYNTHETIC
    Code:
      stack=1, locals=1, args_size=1
         0: aload_0
         1: invokevirtual #2                  // Method f:()Ljava/lang/Integer;
         4: areturn
      LineNumberTable:
        line 7: 0
}
```

可以看到编译器替我们创建了一个`Object f()`的Bridge Method，它调用的是`Integer f()`，这样就构成了JVM所定义的重写。

## 思维导图

<img src="../overload-override.png" style="zoom:50%" />

## 参考文档

* [极客时间 - 深入拆解 Java 虚拟机 - 04 | JVM是如何执行方法调用的？（上）][geektime]
* [JVM Spec - 4.3.2. Field Descriptors][jvms-4.3.2]
* [JVM Spec - 4.3.3. Method Descriptors][jvms-4.3.3]
* [Java Language Spec - 8.4.8. Inheritance, Overriding, and Hiding][jls-8.4.8]
* [Java Language Spec - 8.4.9. Overloading][jls-8.4.9]
* [JVM Spec - 5.4.5. Overriding][jvms-5.4.5]
* [Effects of Type Erasure and Bridge Methods][type-erasure-bridge-methods]

[geektime]: https://time.geekbang.org/column/article/11539
[jvms-4.3.2]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.3.2
[jvms-4.3.3]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.3.3

[jls-8.4.8]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-8.html#jls-8.4.8
[jls-8.4.9]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-8.html#jls-8.4.9
[jvms-5.4.5]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.4.5

[type-erasure-bridge-methods]: https://docs.oracle.com/javase/tutorial/java/generics/bridgeMethods.html