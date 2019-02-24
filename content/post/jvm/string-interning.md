---
title: "JVM - String Interning"
author: "颇忒脱"
tags: ["ARTS", "ARTS-T", "jvm"]
date: 2019-02-24T19:55:08+08:00
---

<!--more-->

[String interning][wiki-string-interning]（字符串拘留？），是一项把相同字符串值只保存一份copy的方法，比如 `"abc"`和`"abc"`虽然是两个字符串，但是因为其值相同，所以只存留一份copy。String interning能够使得处理字符串的任务在时间上或空间上更有效率。不同字符串值保存在所谓**string intern pool**里。

Java语言规定所有字符串字面量（string literals）和所有结果为字符串的常量表达式（string-valued constant expression）都被自动interned。或者也可以通过调用`String#intern()`方法来手动interned。而interened字符串具有这个特性：当且仅当`a.equals(b)==true`，那么`a.intern() == b.intern()`。

下面是一个例子来说明：

```java
package testPackage;
class Test {
    public static void main(String[] args) {
        String hello = "Hello", lo = "lo";
        System.out.print((hello == "Hello") + " ");
        System.out.print((Other.hello == hello) + " ");
        System.out.print((other.Other.hello == hello) + " ");
        System.out.print((hello == ("Hel"+"lo")) + " ");
        System.out.print((hello == ("Hel"+lo)) + " ");
        System.out.println(hello == ("Hel"+lo).intern());
    }
}
class Other { static String hello = "Hello"; }
```

```java
package other;
public class Other { public static String hello = "Hello"; }
```

运行结果是：

```txt
true true true true false true
```

* 同类、同包的string literals引用相同的`String`对象。
* 不同类、同包的string literals指向相同的`String`对象。
* 不同类、不同包的string literals指向相同的`String`对象。
* 由constant expression计算得到的字符串是在编译期被计算出来的，被视同为string literal处理。
* 在运行期通过串接计算得到的字符串则是新创建的，所以不是同一个对象。
* 显式得intern一个计算得到的字符串的结果，和已经存在的具有相同内容的string literal一样。

## 参考资料

* [String interning][wiki-string-interning]
* [Java Language Spec - 3.10.5. String Literals][jls-3.10.5]
* [Java Language Spec - 15.28. Constant Expressions][jls-15.28]
* [String#intern()][String#intern()]

[wiki-string-interning]: https://en.wikipedia.org/wiki/String_interning
[String#intern()]: https://docs.oracle.com/javase/8/docs/api/java/lang/String.html#intern--
[jls-3.10.5]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-3.html#jls-3.10.5
[jls-15.28]: https://docs.oracle.com/javase/specs/jls/se8/html/jls-15.html#jls-15.28
