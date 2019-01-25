---
title: "ClassLoader"
author: "颇忒脱"
tags: ["重学Java", "ClassLoader"]
date: 2019-01-24T20:25:52+08:00
---

<!--more-->

本文源代码在[Github][github]。

## 什么是ClassLoader

[javadoc ClassLoader][javadoc-class-loader]：

> A class loader is an object that is responsible for loading classes. 
> ...
> Given the binary name of a class, a class loader should attempt to locate or generate data that constitutes a definition for the class.
> A typical strategy is to transform the name into a file name and then read a "class file" of that name from a file system.

简单来说：

1. ClassLoader是一个负责加载Class的对象。
1. 给ClassLoader一个类名（需符合Java语言规范），那么它就应该尝试**定位**，或者**生成**包含该类定义的数据。
1. 一个典型的定位策略是把类名转换成class文件名，然后从文件系统里读取这个class文件。

### 三种ClassLoader实现

讲到bootstrap class loader就不得不说三种常见的ClassLoader实现。

执行下面代码会看到三种类型的ClassLoader实现：

```java
import com.sun.javafx.util.Logging;
import java.util.ArrayList;
public class PrintClassLoader {
  public static void main(String[] args) {
    System.out.println("Classloader for ArrayList: " + ArrayList.class.getClassLoader());
    System.out.println("Classloader for Logging: " + Logging.class.getClassLoader());
    System.out.println("Classloader for this class: " + PrintClassLoader.class.getClassLoader());
  }
}
```

结果如下：

```txt
Classloader for ArrayList: null
Classloader for Logging: sun.misc.Launcher$ExtClassLoader@5e2de80c
Classloader for this class: sun.misc.Launcher$AppClassLoader@18b4aac2
```

* Bootstrap class loader。bootstrap class loader是native code写的。它是所有ClassLoader的祖先，它是顶级ClassLoader。它负责加载JDK的内部类型，一般来说就是位于`$JAVA_HOME/jre/lib`下的核心库和`rt.jar`。
* Extension class loader。即Extension class loader，负责加载Java核心类的扩展，加载`$JAVA_HOME/lib/ext`目录和System Property `java.ext.dirs`所指定目录下的类（见[Java Extension Mechanism Architecture][java-extension]）。
* System class loader，又称Application class loader。它的parent class loader是extension class loader（可以从`sun.misc.Launcher`的构造函数里看到），负责加载`CLASSPATH`环境变量、`-classpath/-cp`启动参数指定路径下的类。

### 类的ClassLoader

每个Class对象引用了当初加载自己的ClassLoader（[javadoc ClassLoader][javadoc-class-loader]）：

> Every Class object contains a reference to the ClassLoader that defined it.

其实Class对象的`getClassLoader()`方法就能够得到这个ClassLoader，并且说了如果该方法返回空，则说明此Class对象是被bootstrap class loader加载的，见[getClassLoader() javadoc][javadoc-class-getclassloader]：

> Returns the class loader for the class. Some implementations may use null to represent the bootstrap class loader. This method will return null in such implementations if this class was loaded by the bootstrap class loader.

### Array类的ClassLoader

> Class objects for array classes are not created by class loaders, but are created automatically as required by the Java runtime. The class loader for an array class, as returned by Class.getClassLoader() is the same as the class loader for its element type; if the element type is a primitive type, then the array class has no class loader.

简单来说说了三点：

1. Array也是类，但是它的Class对象不是由ClassLoader创建的，而是由Java runtime根据需要自动创建的。
2. `Array.getClassLoader()`的结果同其元素类型的ClassLoader
3. 如果元素是基础类型，则Array类没有ClassLoader

下面是一段实验代码：

```java
import com.sun.javafx.util.Logging;
public class PrintArrayClassLoader {
  public static void main(String[] args) {
    System.out.println("ClassLoader for int[]: " + new int[0].getClass().getClassLoader());
    System.out.println("ClassLoader for string[]: " + new String[0].getClass().getClassLoader());
    System.out.println("ClassLoader for Logging[]: " + new Logging[0].getClass().getClassLoader());
    System.out.println("ClassLoader for this class[]: " + new PrintArrayClassLoader[0].getClass().getClassLoader());
  }
}
```

得到的结果如下，符合上面的说法：

```txt
ClassLoader for int[]: null
ClassLoader for string[]: null
ClassLoader for Logging[]: sun.misc.Launcher$ExtClassLoader@5e2de80c
ClassLoader for this class[]: sun.misc.Launcher$AppClassLoader@18b4aac2
```

那如果是二维数组会怎样呢？下面是实验代码：

```java
import com.sun.javafx.util.Logging;
public class PrintArrayArrayClassLoader {
  public static void main(String[] args) {
    System.out.println("ClassLoader for int[][]: " + new int[0][].getClass().getClassLoader());
    System.out.println("ClassLoader for string[][]: " + new String[0][].getClass().getClassLoader());
    System.out.println("ClassLoader for Logging[][]: " + new Logging[0][].getClass().getClassLoader());
    System.out.println("ClassLoader for this class[][]: " + new PrintArrayClassLoader[0][].getClass().getClassLoader());
    System.out.println("ClassLoader for this Object[][] of this class[]: " + new Object[][]{new PrintArrayArrayClassLoader[0]}.getClass().getClassLoader());
  }
}
```

结果是：

```txt
ClassLoader for int[][]: null
ClassLoader for string[][]: null
ClassLoader for Logging[][]: sun.misc.Launcher$ExtClassLoader@5e2de80c
ClassLoader for this class[][]: sun.misc.Launcher$AppClassLoader@18b4aac2
ClassLoader for this Object[][] of this class[]: null
```

注意第四行的结果，我们构建了一个`Object[][]`，里面放的是`PrintArrayArrayClassLoader[]`，但结果依然是null。所以：

1. 二维数组的ClassLoader和其定义的类型的ClassLoader相同。
2. 与其实际内部存放的类型无关。

### ClassLoader类的ClassLoader

ClassLoader本身也是类，那么是谁加载它们的呢？实际上ClassLoader类的ClassLoader就是bootstrap class loader。下面是实验代码：

```java
import com.sun.javafx.util.Logging;
public class PrintClassLoaderClassLoader {
  public static void main(String[] args) {
    // Launcher$ExtClassLoader
    System.out.println("ClassLoader for Logging's ClassLoader: " + Logging.class.getClassLoader().getClass().getClassLoader());
    // Launcher$AppClassLoader
    System.out.println("ClassLoader for this class's ClassLoader: " + PrintClassLoaderClassLoader.class.getClassLoader().getClass().getClassLoader());
    // 自定义ClassLoader
    System.out.println("ClassLoader for custom ClassLoader: " + DummyClassLoader.class.getClassLoader().getClass().getClassLoader());
  }
  public static class DummyClassLoader extends ClassLoader {
  }
}
```

结果是：

```txt
ClassLoader for Logging's ClassLoader: null
ClassLoader for this class's ClassLoader: null
ClassLoader for custom ClassLoader: null
```

## ClassLoader解决了什么问题

简单来说ClassLoader就是解决类加载问题的，当然这是一句废话。JDK里的ClassLoader是一个抽象类，这样做的目的是能够让应用开发者定制自己的ClassLoader实现（比如添加解密/加密），我认为这才是ClassLoader存在的最大意义。

## ClassLoader的工作原理

还是看[javadoc的说法][javadoc-class-loader]：

> The ClassLoader class uses a delegation model to search for classes and resources. Each instance of ClassLoader has an associated parent class loader. When requested to find a class or resource, a ClassLoader instance will delegate the search for the class or resource to its parent class loader before attempting to find the class or resource itself. The virtual machine's built-in class loader, called the "bootstrap class loader", does not itself have a parent but may serve as the parent of a ClassLoader instance.

简单来说：

1. ClassLoader使用委托模型（国内普遍称之为双亲委派模型）查找Class或Resource。
1. 每个 ClassLoader 实例都有一个parent ClassLoader。
1. 当要查找Class或者Resource的时候，递归委托给parent，如果parent找不到，才会自己找。举例说明：如果ClassLoader层级关系是这样A->B->C，如果被查找Class只能被A找到，那么过程是A-delegate->B-delegate->C(not found)->B(not found)->A(found)。
1. JVM有一个内置的顶级ClassLoader，叫做bootstrap class loader，它没有parent，它是老祖宗。

## ContextClassLoader

ClassLoader的委托模型存在这么一个问题：子ClassLoader能够看见父ClassLoader所加载的类，而父ClassLoader看不到子ClassLoader所加载的类。

这个问题出现在Java提供的SPI上，简单举例说明：

1. Java核心库提供了SPI A
2. 尝试提供了自己的实现 B
3. SPI A尝试查找实现B，结果找不到

这是因为B一般都是在Classpath中的，它是被System class loader加载的，而SPI A是在核心库里的，它是被bootstrap class loader加载的，而bootstrap class loader是顶级ClassLoader，它不能向下委托给System class loader，所以SPI A是找不到实现B的。

这个时候可以通过`java.lang.Thread#getContextClassLoader()`和`java.lang.Thread#setContextClassLoader`来让SPI A加载到B。

为何SPI A不直接使用System class loader来加载呢？我想这是因为如果写死了System class loader那就缺少灵活性的关系吧。

## Class的唯一性

如果一个类被一个ClassLoader加载两次，那么两次的结果应该是一致的，并且这个加载过程是线程安全的，见ClassLoader.java源码：

```java
protected Class<?> loadClass(String name, boolean resolve)
      throws ClassNotFoundException
{
  synchronized (getClassLoadingLock(name)) {
    // First, check if the class has already been loaded
    Class<?> c = findLoadedClass(name);
    if (c == null) {
      // ...
    }
    // ...
    return c;
  }
}
```

如果一个类被两个不同的ClassLoader加载会怎样呢？结果就是会得到两个不同的Class，同时这个类所使用的其他类也会是两份，见这段代码：

```java
public class ClassUniqueness {

  public static void main(String[] args) throws Exception {

    System.out.println("1st Foo class: loaded by application class loader");
    Class<?> fooClass1 = Class.forName("me.chanjar.javarelearn.classloader.Foo");
    fooClass1.newInstance();

    System.out.println();

    System.out.println("2st Foo class: loaded by URLClassLoader");
    // 故意将parent class loader设置为null，否则就是SystemClassLoader（即ApplicationClassLoader）
    URLClassLoader ucl = new URLClassLoader(new URL[] { new URL("file:///tmp/classloader.jar") }, null);
    Class<?> fooClass2 = ucl.loadClass("me.chanjar.javarelearn.classloader.Foo");
    fooClass2.newInstance();

    System.out.println();

    System.out.println("1st Foo class == 2nd Foo class? : " + fooClass1.equals(fooClass2));
  }

}

public class Foo {

  public Foo() {
    System.out.println("Foo's ClassLoader: " + Foo.class.getClassLoader());
    System.out.println("Bar's ClassLoader: " + Bar.class.getClassLoader());
  }

}

public class Bar {
}
```

结果你会发现Foo和Bar的ClassLoader分别是Application class loader和我们自己使用的URLClassLoader，并且两者并不相同：

```txt
1st Foo class: loaded by application class loader
Foo's ClassLoader: sun.misc.Launcher$AppClassLoader@18b4aac2
Bar's ClassLoader: sun.misc.Launcher$AppClassLoader@18b4aac2

2st Foo class: loaded by URLClassLoader
Foo's ClassLoader: java.net.URLClassLoader@66d3c617
Bar's ClassLoader: java.net.URLClassLoader@66d3c617

1st Foo class == 2nd Foo class? : false
```

通过上面代码可以观察到两点：

1. 一个Class的唯一性不仅仅是其全限定名（Fully-qualified-name），而是 加载其的ClassLoader + 其全限定名。
2. 除非特别指定，否则一个Class所使用的其他类型的ClassLoader与加载其的ClassLoader相同。

这种机制对于解决诸如类冲突问题非常有用，类冲突问题就是在运行时存在同一个类的两个不同版本，同时代码里又都需要使用这两个不同版本的类。解决这个问题的思路就是使用不同的ClassLoader加载这两个版本的类。事实上OSGi或者Web容器就是这样做的。

## 参考文档

* [JDK Javadoc - ClassLoader][javadoc-class-loader]
* [JDK Javadoc - Class][javadoc-class-getclassloader]
* [Java虚拟机是如何加载Java类的?][geektime-jvm-classloader]（极客时间专栏，需付费购买）
* [Class Loaders in Java][java-class-loaders]
* [深入探讨Java类加载器][deep-in-class-loader]
* [Java Language Specification - Chapter 12. Execution][jls-execution]
* [Java Virtual Machine Specification - Chapter 5. Loading, Linking, and Initializing][jvms-loading-linking-initializing]

[javadoc-class-loader]: https://docs.oracle.com/javase/7/docs/api/java/lang/ClassLoader.html
[javadoc-class-getclassloader]: https://docs.oracle.com/javase/7/docs/api/java/lang/Class.html#getClassLoader()
[geektime-jvm-classloader]: https://time.geekbang.org/column/article/11523
[java-extension]: https://docs.oracle.com/javase/6/docs/technotes/guides/extensions/spec.htm
[deep-in-class-loader]: https://www.ibm.com/developerworks/cn/java/j-lo-classloader/index.html
[java-class-loaders]: https://www.baeldung.com/java-classloaders
[jls-execution]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-12.html
[jvms-loading-linking-initializing]: https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html
[github]: https://github.com/chanjarster/java-relearn/tree/master/classloader