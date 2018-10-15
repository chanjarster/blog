---
title: "利用VisualVm和JMX远程监控K8S里的Java进程"
author: "颇忒脱"
tags: ["java", "visualvm", "jmx", "k8s"]
date: 2018-10-15T09:55:12+08:00
---

在[利用VisualVm和JMX远程监控Java进程][visualvm-remote-monitoring-jmx]和[VisualVm利用SSL连接JMX的方法][visualvm-remote-monitoring-jmx-ssl]里介绍了如何使用VisualVm+JMX监控远程Java进程的方法。那么如何监控一个运行在K8S集群中的Java进程呢？其实大致方法也是类似的。

<!--more-->

## 非SSL JMX连接

如果采用非SSL JMX连接，那么你只需要这么几步就可以让你本地的VisualVm连接到K8S集群里的Java进程了。

**Step1 修改Deployment.yaml，添加以下System Properties**
   
```bash
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.port=1100
-Dcom.sun.management.jmxremote.rmi.port=1100
-Djava.rmi.server.hostname=localhost
```

注意，`-Djava.rmi.server.hostname`一定要设置成`localhost`

**Step2 修改Deployment.yaml，添加Container Port**

```yaml
containers:
- name: ...
  image: ...
  ports:
  - containerPort: 1100
    name: tcp-jmx
```

**Step3 部署Deployment**

**Step4 利用kubectl转发端口**
   
```bash
kubectl -n <namespace> port-forward <pod-name> 1100
```

**Step5 启动VisualVm，创建JMX连接`localhost:1100`**

## SSL JMX连接

启用SSL JMX连接，那么需要增加三个步骤，步骤就稍微复杂一些，假设你已经根据[VisualVm利用SSL连接JMX的方法][visualvm-remote-monitoring-jmx-ssl]创建好了`java-app`和`visualvm`的keystore和truststore。

**Step1 创建一个Secret包含`java-app.keystore`和`java-app.truststore`**

```bash
kubectl -n <namespace> create secret generic jmx-ssl \
  --from-file=java-app.keystore \
  --from-file=java-app.truststore
```

**Step2 修改Deployment.yaml，把Secret挂载到容器内的`/jmx-ssl`目录下**

```yaml

 containers:
 - name: ...
   image: ...
   volumeMounts:
   - name: jmx-ssl-vol
     mountPath: /jmx-ssl
 volumes:
 - name: jmx-ssl-vol
   secret:
     secretName: jmx-ssl
```

**Step3 修改Deployment.yaml，添加以下System Properties**
   
```bash
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=1100
-Dcom.sun.management.jmxremote.rmi.port=1100
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=true
-Dcom.sun.management.jmxremote.registry.ssl=true
-Dcom.sun.management.jmxremote.ssl.need.client.auth=true
-Djavax.net.ssl.keyStore=/jmx-ssl/java-app.keystore
-Djavax.net.ssl.keyStorePassword=<keystore password>
-Djavax.net.ssl.trustStore=/jmx-ssl/java-app.truststore
-Djavax.net.ssl.trustStorePassword=<truststore password>
-Djava.rmi.server.hostname=localhost
```

注意，`-Djava.rmi.server.hostname`一定要设置成`localhost`

**Step4 修改Deployment.yaml，添加Container Port**
   
```yaml
containers:
- name: ...
  image: ...
  ports:
  - containerPort: 1100
    name: tcp-jmx
  ...
```

**Step5 部署Deployment**

**Step6 利用kubectl转发端口**
   
```bash
kubectl -n <namespace> port-forward <pod-name> 1100
```

**Step7 启动VisualVm，创建JMX连接`localhost:1100`**

```bash
jvisualvm -J-Djavax.net.ssl.keyStore=<path to visualvm.keystore> \
  -J-Djavax.net.ssl.keyStorePassword=<visualvm.keystore的密码> \
  -J-Djavax.net.ssl.trustStore=<path to visualvm.truststore> \
  -J-Djavax.net.ssl.trustStorePassword=<visualvm.truststore的密码>
```

## K8S样例配置文件

相关K8S样例配置文件在[这里][gist-tomcat-jmx-non-ssl]（用tomcat做的例子）。

## 参考文档

* [Why Java opens 3 ports when JMX is configured?][so-1]
* [How can I connect to JMX through Kubernetes managed Docker containers?][so-2]

[visualvm-remote-monitoring-jmx]: ../visualvm-remote-monitoring-jmx/
[visualvm-remote-monitoring-jmx-ssl]: ../visualvm-remote-monitoring-jmx-ssl/
[gist-tomcat-jmx-non-ssl]: https://gist.github.com/chanjarster/c8de40ef4086cded378df122bea6fe7d
[so-1]: https://stackoverflow.com/a/21552812/1287790
[so-2]: https://stackoverflow.com/questions/41069686/how-can-i-connect-to-jmx-through-kubernetes-managed-docker-containers