---
title: "VisualVm利用SSL连接JMX的方法"
author: "颇忒脱"
tags: ["java", "visualvm", "jmx", "ssl"]
date: 2018-10-10T15:47:02+08:00
---

在[前一篇文章][visualvm-remote-monitoring-jmx]里提到在生产环境下应该使用SSL来创建JMX连接，本文就来讲一下具体怎么做。

<!--more-->

## 前导知识

先了解一下Java客户端程序在创建SSL连接的一些相关的事情：

1. Java client程序在做SSL连接的时候，会拉取server的证书，利用truststore去验证这个证书，如果不存在 or 证书过期 or 不是由可信CA签发，就意味着服务端不被信任，就不能连接。
1. 如果在程序启动时没有特别指定使用哪个truststore（通过System Property `javax.net.ssl.trustStore` 指定），那么就会使用`$JAVA_HOME/jre/lib/security/cacerts`。如果指定了，就会使用指定的truststore + cacerts来验证。
1. cacerts存放了JDK信任的CA证书（含有public key），它里面预先已经存放了已知的权威CA证书。你可以通过`keytool -list -keystore - $JAVA_HOME/jre/lib/security/cacerts`看到（让你输密码的时候直接回车就行了）

以上过程被称为server authentication，也就是说client验证server是否可信，server authentication是最常见的，https就是这种模式。

不过在用SSL连接JMX的时候，还要做client authentication，即server验证client是否可信。原理和上面提到的一样，只不过变成server用自己的truststore里验证client的证书是否可信。

## 第一步：制作keystore和truststore

上面提到的证书主要保存了一个public key，SSL是一个非对称加密协议，因此还有一个对应的private key，在java里private key和private key存放在keystore里。

下面我们来制作visualvm（client）和java app（server）的keystore和truststore。

先讲大致流程，然后再给出命令：

1. 生成visualvm的keystore，导出cert，把cert导入到java-app的truststore里
2. 生成java-app的keystore，导出cert，把cert导入到visualvm的truststore里

具体命令：

1. 生成visualvm的keystore

    ```bash
     keytool -genkeypair \
       -alias visualvm \
       -keyalg RSA \
       -validity 365 \
       -storetype pkcs12 \
       -keystore visualvm.keystore \
       -storepass <visualvm keystore的密码> \
       -keypass <同visualvm keystore的密码> \
       -dname "CN=<姓名>, OU=<组织下属单位>, O=<组织名称>, L=<城市>, S=<省份>, C=<国家2字母>"
    ```
1. 导出visualvm的cert

    ```bash
    keytool -exportcert \
      -alias visualvm \
      -storetype pkcs12 \
      -keystore visualvm.keystore \
      -file visualvm.cer \
      -storepass <visualvm keystore的密码>
    ```
1. 把visualvm的cert导入到java-app的truststore里，实际上就是生成了一个truststore

    ```bash
    keytool -importcert \
      -alias visualvm \
      -file visualvm.cer \
      -keystore java-app.truststore \
      -storepass <java-app truststore的密码> \
      -noprompt
    ```
1. 生成java-app的keystore

    ```bash
	 keytool -genkeypair \
	   -alias java-app \
	   -keyalg RSA \
	   -validity 365 \
	   -storetype pkcs12 \
	   -keystore java-app.keystore \
	   -storepass <java-app keystore的密码> \
	   -keypass <同java-app keystore的密码> \
	   -dname "CN=<姓名>, OU=<组织下属单位>, O=<组织名称>, L=<城市>, S=<省份>, C=<国家2字母>"
    ```
1. 导出java-app的cert
  
    ```bash
    keytool -exportcert \
      -alias java-app \
      -storetype pkcs12 \
      -keystore java-app.keystore \
      -file java-app.cer \
      -storepass <java-app keystore的密码>
    ```
1. 把java-app的cert导入到visualvm的truststore里
   
    ```bash
    keytool -importcert 
      -alias java-app \
      -file java-app.cer \
      -keystore visualvm.truststore \
      -storepass <visualvm truststore的密码> \
      -noprompt
    ```

所以最终得到的文件是这么几个：

1. visualvm.keystore，包含visualvm的public key和private key
1. visualvm.truststore，包含java-app cert
1. java-app.keystore，包含java-app的public key和private key
1. java-app.truststore，包含visualvm cert

## 第二步：启动Tomcat

我们还是用Tomcat做实验，给`CATALINA_OPTS`添加几个参数像下面这样，因为参数比较多，所以我们在`$TOMCAT/bin`下添加一个`setenv.sh`的文件（记得加上可执行权限）：

```bash
CATALINA_OPTS="-Dcom.sun.management.jmxremote"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.port=1100"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.rmi.port=1100"
CATALINA_OPTS="$CATALINA_OPTS -Djava.rmi.server.hostname=<host or ip>"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.ssl=true"
CATALINA_OPTS="$CATALINA_OPTS -Djavax.net.ssl.keyStore=<path to java-app.keystore>"
CATALINA_OPTS="$CATALINA_OPTS -Djavax.net.ssl.keyStorePassword=<java-app.keystore的密码>"
CATALINA_OPTS="$CATALINA_OPTS -Djavax.net.ssl.trustStore=<path to java-app.truststore>"
CATALINA_OPTS="$CATALINA_OPTS -Djavax.net.ssl.trustStorePassword=<java-app.truststore的密码>"
```

然后`$TOMCAT/bin/startup.sh`

## 第三步：启动visualvm

```bash
jvisualvm -J-Djavax.net.ssl.keyStore=<path to visualvm.keystore> \
  -J-Djavax.net.ssl.keyStorePassword=<visualvm.keystore的密码> \
  -J-Djavax.net.ssl.trustStore=<path to visualvm.truststore> \
  -J-Djavax.net.ssl.trustStorePassword=<visualvm.truststore的密码>
```

你可以不加参数启动jvisualvm，看看下一步创建JMX连接是否成功，如果配置正确应该是不会成功的。

## 第四步：创建JMX连接

加了上述参数启动jvisualvm后，和[利用VisualVm和JMX远程监控Java进程][visualvm-remote-monitoring-jmx]里提到的步骤一样创建JMX连接，只不过在创建JMX连接的时候**不要勾选【不要求SSL连接】**（不过经实测，勾不勾选都能连接成功的）。

## 参考资料

* [Monitoring and Management Using JMX Technology - Using SSL][visualvm-using-ssl]
* [Customizing the Default Keystores and Truststores, Store Types, and Store Passwords][jsse-customizing-stores]
* [Customizing JSSE][jsse-customizing-jsse]，这个表格列出了一些SSL相关的System Properties
* [Creating a Keystore to Use with JSSE][jsse-create-keystore]
* [keytool][keytool]
* [Monitor Java with JMX][monitor-java-with-jmx]
* [Java Secure Socket Extension (JSSE) Reference Guide][jsse]，这是Java对于SSL支持的最全的参考文档

[visualvm-remote-monitoring-jmx]: ../visualvm-remote-monitoring-jmx/

[jsse-customizing-stores]: https://docs.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html#CustomizingStores
[jsse-customizing-jsse]: https://docs.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html#InstallationAndCustomization
[jsse-create-keystore]: https://docs.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html#CreateKeystore
[keytool]: https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html
[monitor-java-with-jmx]: https://www.lullabot.com/articles/monitor-java-with-jmx
[visualvm-using-ssl]: https://docs.oracle.com/javase/8/docs/technotes/guides/management/agent.html#gdeoz
[jsse]: https://docs.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html