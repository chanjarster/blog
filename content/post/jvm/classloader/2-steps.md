---
title: "ClassLoader（二）- 加载过程"
author: "颇忒脱"
tags: ["ClassLoader", "JVM"]
date: 2019-01-25T21:36:01+08:00
---

<!--more-->

本文源代码在[Github][github]。

在前一篇文章[初步了解ClassLoader](../class-loader)里提到了委托模型（又称双亲委派模型），解释了ClassLoader hierarchy（层级）处理类加载的过程。那么class文件是如何变成Class对象的呢？

## Class的加载过程

Class加载分为这几步：

1. 创建和加载（Creation and Loading）
1. 链接（Linking）
  1. 验证（Verification）
  1. 准备（Preparation）
  1. 解析（Resolution），此步骤可选
1. 初始化（Initialization）

注: 前面说了数组类是虚拟机直接创建的，以上过程不适用于数组类。

## 创建和加载（Creation and Loading）

何时会触发一个类的加载？

[Java Language Specification - 12.1.1. Load the Class Test][jls-12.1.1]：

> The initial attempt to execute the method `main` of class `Test` discovers that the class `Test` is not loaded - that is, that the Java Virtual Machine does not currently contain a binary representation for this class. The Java Virtual Machine then uses a class loader to attempt to find such a binary representation.

也就是说，当要用到一个类，JVM发现还没有包含这个类的二进制形式（字节）时，就会使用ClassLoader尝试查找这个类的二进制形式。

我们知道ClassLoader委托模型，也就是说实际触发加载的ClassLoader和真正加载的ClassLoader可能不是同一个，JVM将它们称之为`initiating loader`和`defining loader`（[Java Virtual Machine Specification - 5.3. Creation and Loading][jvms-5.3]）：

> A class loader `L` may create C by defining it directly or by delegating to another class loader. If `L` creates C directly, we say that `L` defines C or, equivalently, that `L` is the _defining loader_ of C.

> When one class loader delegates to another class loader, the loader that initiates the loading is not necessarily the same loader that completes the loading and defines the class. If `L` creates C, either by defining it directly or by delegation, we say that `L` initiates loading of C or, equivalently, that `L` is an _initiating loader_ of C.

那么当A类使用B类的时候，B类使用的是哪个ClassLoader呢？

[Java Virtual Machine Specification - 5.3. Creation and Loading][jvms-5.3]：

> The Java Virtual Machine uses one of three procedures to create class or interface C denoted by N:

> * If `N` denotes a nonarray class or an interface, one of the two following methods is used to load and thereby create C:
>   * If D was defined by the bootstrap class loader, then the bootstrap class loader initiates loading of C (§5.3.1).
>   * If D was defined by a user-defined class loader, then that same user-defined class loader initiates loading of C (§5.3.2).
> * Otherwise `N` denotes an array class. An array class is created directly by the Java Virtual Machine (§5.3.3), not by a class loader. However, the defining class loader of D is used in the process of creating array class C.

> 注：上文的C和D都是类，N则是C的名字。

也就说如果D用到C，且C还没有被加载，且C不是数组，那么：

1. 如果D的defining loader是bootstrap class loader，那么C的initiating loader就是bootstrap class loader。
1. 如果D的defining loader是自定义的class loader X，那么C的initiating loader就是X。

再总结一下就是：如果D用到C，且C还没有被加载，且C不是数组，那么C的initiating loader就是D的defining loader。

用下面的代码观察一下：

```java
// 把这个项目打包然后放到/tmp目录下
public class CreationAndLoading {
  public static void main(String[] args) throws Exception {
    // ucl1的parent是bootstrap class loader
    URLClassLoader ucl1 = new NamedURLClassLoader("user-defined 1", new URL[] { new URL("file:///tmp/classloader.jar") }, null);
    // ucl1是ucl2的parent
    URLClassLoader ucl2 = new NamedURLClassLoader("user-defined 2", new URL[0], ucl1);
    Class<?> fooClass2 = ucl2.loadClass("me.chanjar.javarelearn.classloader.Foo");
    fooClass2.newInstance();
  }
}

public class Foo {
  public Foo() {
    System.out.println("Foo's classLoader: " + Foo.class.getClassLoader());
    System.out.println("Bar's classLoader: " + Bar.class.getClassLoader());
  }
}

public class NamedURLClassLoader extends URLClassLoader {
  private String name;
  public NamedURLClassLoader(String name, URL[] urls, ClassLoader parent) {
    super(urls, parent);
    this.name = name;
  }
  @Override
  protected Class<?> findClass(String name) throws ClassNotFoundException {
    System.out.println("ClassLoader: " + this.name + " findClass(" + name + ")");
    return super.findClass(name);
  }
  @Override
  public Class<?> loadClass(String name) throws ClassNotFoundException {
    System.out.println("ClassLoader: " + this.name + " loadClass(" + name + ")");
    return super.loadClass(name);
  }
  @Override
  public String toString() {
    return name;
  }
}
```

运行结果是：

```txt
ClassLoader: user-defined 2 loadClass(me.chanjar.javarelearn.classloader.Foo)
ClassLoader: user-defined 1 findClass(me.chanjar.javarelearn.classloader.Foo)
ClassLoader: user-defined 1 loadClass(java.lang.Object)
ClassLoader: user-defined 1 loadClass(java.lang.System)
ClassLoader: user-defined 1 loadClass(java.lang.StringBuilder)
ClassLoader: user-defined 1 loadClass(java.lang.Class)
ClassLoader: user-defined 1 loadClass(java.io.PrintStream)
Foo's classLoader: user-defined 1
ClassLoader: user-defined 1 loadClass(me.chanjar.javarelearn.classloader.Bar)
ClassLoader: user-defined 1 findClass(me.chanjar.javarelearn.classloader.Bar)
Bar's classLoader: user-defined 1
```

可以注意到`Foo`的initiating loader是user-defined 2，但是defining loader是user-defined 1。而`Bar`的initiating loader与defining loader则直接是user-defined 1，绕过了user-defined 2。观察结果符合预期。

## 链接

### 验证（Verification）

验证类的二进制形式在结构上是否正确。

### 准备（Preparation）

为类创建静态字段，并且为这些静态字段初始化默认值。

### 解析（Resolution）

JVM在运行时会为每个类维护一个run-time constant pool，run-time constant pool构建自类的二进制形式里的`constant_pool`表。run-time constant pool里的所有引用一开始都是符号引用（symbolic reference）（见[Java Virutal Machine Specification - 5.1. The Run-Time Constant Pool][jvms-5.1]）。符号引用就是并非真正引用（即引用内存地址），只是指向了一个名字而已（就是字符串）。解析阶段做的事情就是将符号引用转变成实际引用）。

[Java Virutal Machine Specification - 5.4. Linking][jvms-5.4]：

> This specification allows an implementation flexibility as to when linking activities (and, because of recursion, loading) take place, provided that all of the following properties are maintained:

> 1. A class or interface is completely loaded before it is linked.

> 1. A class or interface is completely verified and prepared before it is initialized.

也就是说仅要求：

1. 一个类在被链接之前得是完全加载的。
2. 一个类在被初始化之前得是被完全验证和准备的。

所以对于解析的时机JVM Spec没有作出太多规定，只说了以下JVM指令在执行之前需要解析符号引用：_anewarray_, _checkcast_, _getfield_, _getstatic_, _instanceof_, _invokedynamic_, _invokeinterface_, _invokespecial_, _invokestatic_, _invokevirtual_, _ldc_, _ldc\_w_, _multianewarray_, _new_, _putfield_ 和 _putstatic_ 。

看不懂没关系，大致意思就是，用到字段、用到方法、用到静态方法、new类等时候需要解析符号引用。

## 初始化

如果直接赋值的静态字段被 final 所修饰，并且它的类型是基本类型或字符串时，那么该字段便会被 Java 编译器标记成常量值（ConstantValue），其初始化直接由 Java 虚拟机完成。除此之外的直接赋值操作，以及所有静态代码块中的代码，则会被 Java 编译器置于同一方法中，并把它命为 `<clinit>`（**cl**ass **init**）。

JVM 规范枚举了下述类的初始化时机是：

1. 当虚拟机启动时，初始化用户指定的主类； 
1. new 某个类的时候
1. 调用某类的静态方法时
1. 访问某类的静态字段时
1. 子类初始化会触发父类初始化
1. 用反射API对某个类进行调用时
1. 一个接口定义了default方法（原文是non-abstract、non-static方法），某个实现了这个接口的类被初始化，那么这个接口也会被初始化
1. 初次调用 MethodHandle 实例时

注意：这里没有提到new 数组的情况，所以new 数组的时候不会初始化类。

同时类的初始化过程是线程安全的，下面是一个利用上述时机4和线程安全特性做的延迟加载的Singleton的例子：

```java
public class Singleton {
  private Singleton() {}
  private static class LazyHolder {
    static final Singleton INSTANCE = new Singleton();
  }
  public static Singleton getInstance() {
    return LazyHolder.INSTANCE;
  }
}
```

这种做法被称为[Initialization-on-demand holder idiom][wiki-idhi]。

## 类加载常见异常

### ClassNotFoundException

[Java Virutal Machine Specification - 5.3.1. Loading Using the Bootstrap Class Loader][jvms-5.3.1]：

> If no purported representation of C is found, loading throws an instance of `ClassNotFoundException`.

[Java Virutal Machine Specification - 5.3.2. Loading Using a User-defined Class Loader][jvms-5.3.2]：

> When the `loadClass` method of the class loader `L` is invoked with the name `N` of a class or interface C to be loaded, `L` must perform one of the following two operations in order to load C:

> 1. The class loader `L` can create an array of bytes representing C as the bytes of a ClassFile structure (§4.1); it then must invoke the method `defineClass` of class ClassLoader. Invoking defineClass causes the Java Virtual Machine to derive a class or interface denoted by `N` using `L` from the array of bytes using the algorithm found in §5.3.5.

> 1. The class loader `L` can delegate the loading of C to some other class loader L'. This is accomplished by passing the argument `N` directly or indirectly to an invocation of a method on `L'` (typically the `loadClass` method). The result of the invocation is C.

> In either (1) or (2), if the class loader `L` is unable to load a class or interface denoted by `N` for any reason, it must throw an instance of ClassNotFoundException.

所以，`ClassNotFoundException`发生在【加载阶段】：

1. 如果用的是bootstrap class loader，则当找不到其该类的二进制形式时抛出`ClassNotFoundException`
2. 如果用的是用户自定义class loader，不管是自己创建二进制（这里包括从文件读取或者内存中创建），还是代理给其他class loader，只要出现无法加载的情况，都要抛出`ClassNotFoundException`

### NoClassDefFoundError

[Java Virtual Machine Specification - 5.3. Creation and Loading][jvms-5.3]

> If the Java Virtual Machine ever attempts to load a class C during verification (§5.4.1) or resolution (§5.4.3) (but not initialization (§5.5)), and the class loader that is used to initiate loading of C throws an instance of `ClassNotFoundException`, then the Java Virtual Machine must throw an instance of `NoClassDefFoundError` whose cause is the instance of `ClassNotFoundException`.

> (A subtlety here is that recursive class loading to load superclasses is performed as part of resolution (§5.3.5, step 3). Therefore, a `ClassNotFoundException` that results from a class loader failing to load a superclass must be wrapped in a `NoClassDefFoundError`.)

[Java Virtual Machine Specification - 5.3.5. Deriving a Class from a class File Representation][jvms-5.3.5]

> Otherwise, if the purported representation does not actually represent a class named `N`, loading throws an instance of `NoClassDefFoundError` or an instance of one of its subclasses.

[Java Virtual Machine Specification - 5.5. Initialization][jvms-5.5]

> If the Class object for C is in an erroneous state, then initialization is not possible. Release `LC` and throw a `NoClassDefFoundError`.

所以，`NoClassDefFoundError`发生在：

1. 【加载阶段】，因其他类的【验证】or【解析】触发对C类的【加载】，此时发生了`ClassNotFoundException`，那么就要抛出`NoClassDefFoundError`，cause 是`ClassNotFoundException`。
1. 【加载阶段】，在【解析】superclass的过程中发生的`ClassNotFoundException`也必须包在`NoClassDefFoundError`里。
1. 【加载阶段】，发现找到的二进制里的类名和要找的类名不一致时，抛出`NoClassDefFoundError`
1. 【初始化阶段】，如果C类的Class对象处于错误状态，那么抛出`NoClassDefFoundError`

## 追踪类的加载

可以在JVM启动时添加`-verbose:class`来打印类加载过程。

## 参考资料

* [Java Language Specification - Chapter 12. Execution][jls-12]
* [Java Virtual Machine Specification - Chapter 5. Loading, Linking, and Initializing][jvms-5]
* [极客时间 - 深入拆解Java虚拟机 - 03 Java虚拟机是如何加载Java类的?][geektime-jvm-03]（专栏文章，需付费购买）
* [CS-Note 类加载机制][cs-note-class-load]
* [深入理解JVM(八)——类加载的时机][dxrcmm-jvm-8]
* [深入理解JVM(九)——类加载的过程][dxrcmm-jvm-9]

[geektime-jvm-03]: https://time.geekbang.org/column/article/11523
[cs-note-class-load]: https://cyc2018.github.io/CS-Notes/#/notes/Java%20%E8%99%9A%E6%8B%9F%E6%9C%BA?id=%E5%9B%9B%E3%80%81%E7%B1%BB%E5%8A%A0%E8%BD%BD%E6%9C%BA%E5%88%B6
[dxrcmm-jvm-8]: https://blog.csdn.net/u010425776/article/details/51251430
[dxrcmm-jvm-9]: https://blog.csdn.net/u010425776/article/details/51254858
[jls-12]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-12.html
[jls-12.1.1]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-12.html#jls-12.1.1
[jvms-5]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html
[jvms-5.1]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.1
[jvms-5.3]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.3
[jvms-5.3.1]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.3.1
[jvms-5.3.2]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.3.2
[jvms-5.3.5]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.3.5
[jvms-5.4]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.5
[jvms-5.5]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.5
[github]: https://github.com/chanjarster/java-relearn/tree/master/classloader
[wiki-idhi]: https://en.wikipedia.org/wiki/Initialization-on-demand_holder_idiom