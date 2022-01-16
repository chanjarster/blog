---
title: "JVM执行方法调用（二）- 指令"
author: "颇忒脱"
tags: ["JVM", "ARTS-T"]
date: 2020-05-11T21:10:52+08:00
---

<!--more-->

JVM Spec中关于方法调用的指令有：

* invokedynamic，1.7加入，对于基于JVM的动态语言有用
* invokeinterface，当前变量形式类型是接口时，用以调用接口方法，在运行时搜索一个实现了这个接口方法的对象，找出适合的方法进行调用。
* invokespecial，用于调用一些需要特殊处理的实例方法，包括静态代码块，实例构造函数、实例初始化代码块、私有方法和父类方法。
* invokestatic，用于调用类静态方法
* invokevirtual，用于调用对象的实例方法，根据对象的实际类型进行分派



例子代码：

```java
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.util.Arrays;
import java.util.List;

public class JVMMethodInstruction implements Runnable {

    static {
        System.out.println("<clinit>");
    }

    {
        System.out.println("<init block>");
    }

    public JVMMethodInstruction() {}
    static void staticMethod() {}
    static void staticForMethodHandle(String str) {}
    private void privateMethod() {}
    void instanceMethod() {}
    public void forMethodHandle(String str) {}

    @Override
    public void run() {}

    public static void main(String[] args) throws Throwable {
        /**
         * invoke special
         */
        JVMMethodInstruction test = new JVMMethodInstruction();
        /**
         * invoke special
         */
        test.privateMethod();
        /**
         * invoke virtual
         */
        test.instanceMethod();
        /**
         * invoke static
         */
        staticMethod();
        /**
         * invoke interface
         */
        Runnable r = test;
        r.run();
        /**
         * invoke dynamic instance method
         */
        MethodHandles.Lookup lookup = MethodHandles.lookup();
        MethodHandle mh = lookup
            .findVirtual(JVMMethodInstruction.class, "forMethodHandle",
                MethodType.methodType(void.class, String.class));
        System.out.println(mh);
        mh.bindTo(test).invoke("a");
        /**
         * invoke dynamic static method
         */
        mh = lookup.findStatic(JVMMethodInstruction.class, "staticForMethodHandle",
            MethodType.methodType(void.class, String.class));
        mh.invoke("static");
        /**
         * Java 8中，lambda表达式和默认方法时，底层会生成和使用invoke dynamic
         * invoke dynamic
         */
        List<Integer> list = Arrays.asList(1, 2, 3, 4);
        list.stream().forEach(System.out::println);

    }
}
```

编译然后反编译：

```bash
javac JVMMethodInstruction.java
javap -c JVMMethodInstruction
```

得到反编译结果：

```java
  public JVMMethodInstruction();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
       7: ldc           #3                  // String <init block>
       9: invokevirtual #4                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      12: return
  public static void main(java.lang.String[]) throws java.lang.Throwable;
    Code:
       0: new           #5                  // class JVMMethodInstruction
       3: dup
       4: invokespecial #6                  // Method "<init>":()V
       7: astore_1
       8: aload_1
       9: invokespecial #7                  // Method privateMethod:()V
      12: aload_1
      13: invokevirtual #8                  // Method instanceMethod:()V
      16: invokestatic  #9                  // Method staticMethod:()V
      19: aload_1
      20: astore_2
      21: aload_2
      22: invokeinterface #10,  1           // InterfaceMethod java/lang/Runnable.run:()V
      27: invokestatic  #11                 // Method java/lang/invoke/MethodHandles.lookup:()Ljava/lang/invoke/MethodHandles$Lookup;
      30: astore_3
      31: aload_3
      32: ldc           #5                  // class JVMMethodInstruction
      34: ldc           #12                 // String forMethodHandle
      36: getstatic     #13                 // Field java/lang/Void.TYPE:Ljava/lang/Class;
      39: ldc           #14                 // class java/lang/String
      41: invokestatic  #15                 // Method java/lang/invoke/MethodType.methodType:(Ljava/lang/Class;Ljava/lang/Class;)Ljava/lang/invoke/MethodType;
      44: invokevirtual #16                 // Method java/lang/invoke/MethodHandles$Lookup.findVirtual:(Ljava/lang/Class;Ljava/lang/String;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/MethodHandle;
      47: astore        4
      49: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
      52: aload         4
      54: invokevirtual #17                 // Method java/io/PrintStream.println:(Ljava/lang/Object;)V
      57: aload         4
      59: aload_1
      60: invokevirtual #18                 // Method java/lang/invoke/MethodHandle.bindTo:(Ljava/lang/Object;)Ljava/lang/invoke/MethodHandle;
      63: ldc           #19                 // String a
      65: invokevirtual #20                 // Method java/lang/invoke/MethodHandle.invoke:(Ljava/lang/String;)V
      68: aload_3
      69: ldc           #5                  // class JVMMethodInstruction
      71: ldc           #21                 // String staticForMethodHandle
      73: getstatic     #13                 // Field java/lang/Void.TYPE:Ljava/lang/Class;
      76: ldc           #14                 // class java/lang/String
      78: invokestatic  #15                 // Method java/lang/invoke/MethodType.methodType:(Ljava/lang/Class;Ljava/lang/Class;)Ljava/lang/invoke/MethodType;
      81: invokevirtual #22                 // Method java/lang/invoke/MethodHandles$Lookup.findStatic:(Ljava/lang/Class;Ljava/lang/String;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/MethodHandle;
      84: astore        4
      86: aload         4
      88: ldc           #23                 // String static
      90: invokevirtual #20                 // Method java/lang/invoke/MethodHandle.invoke:(Ljava/lang/String;)V
      93: iconst_4
      94: anewarray     #24                 // class java/lang/Integer
      97: dup
      98: iconst_0
      99: iconst_1
     100: invokestatic  #25                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
     103: aastore
     104: dup
     105: iconst_1
     106: iconst_2
     107: invokestatic  #25                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
     110: aastore
     111: dup
     112: iconst_2
     113: iconst_3
     114: invokestatic  #25                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
     117: aastore
     118: dup
     119: iconst_3
     120: iconst_4
     121: invokestatic  #25                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
     124: aastore
     125: invokestatic  #26                 // Method java/util/Arrays.asList:([Ljava/lang/Object;)Ljava/util/List;
     128: astore        5
     130: aload         5
     132: invokeinterface #27,  1           // InterfaceMethod java/util/List.stream:()Ljava/util/stream/Stream;
     137: getstatic     #2                  // Field java/lang/System.out:Ljava/io/PrintStream;
     140: dup
     141: invokevirtual #28                 // Method java/lang/Object.getClass:()Ljava/lang/Class;
     144: pop
     145: invokedynamic #29,  0             // InvokeDynamic #0:accept:(Ljava/io/PrintStream;)Ljava/util/function/Consumer;
     150: invokeinterface #30,  2           // InterfaceMethod java/util/stream/Stream.forEach:(Ljava/util/function/Consumer;)V
     155: return
```