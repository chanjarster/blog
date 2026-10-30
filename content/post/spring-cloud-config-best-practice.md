---
title: "Spring Cloud Config配置文件最佳实践"
author: "颇忒脱"
tags: ["微服务", "Spring Cloud", "k8s"]
date: 2018-09-10T19:51:11+08:00
---

大多数Spring Cloud项目都会使用Spring Cloud Config来管理应用启动时的配置文件，同时开发人员面临着多样化的程序启动方式：操作系统进程启动、docker启动、k8s启动。那么如何规划这些配置文件以适应多种启动方式呢？本文尝试给出一些建议

<!--more-->

## 先讲几个规则

1. 程序打包时，要将`bootstrap.properties`和`application.properties`（或者它们的yaml变种）打到包里。
1. `bootstrap.properties`里，要针对可变配置项做环境变量化。
1. `application.properties`里，要针对可变配置项做环境变量化。
1. Spring Cloud应用关于Config Server的配置要放在`bootstrap.properties`里，并且要做环境变量化。
1. Config Server所提供的`application-*.properties`里不得有环境变量。因为既然直接提供配置了，那么就不应该再使用环境变量。

### 要针对可变配置项做环境变量化

这句话对应[The 12-factor App的Config章节][12-factors-config]。具体做法是在配置文件里使用[placeholder][spring-boot-placeholder]。下面是两种方式：

```
app.name=${APP_NAME}
app.description=${APP_DESC:Default description}
```

第一种方式Spring Boot/Cloud应用在启动时，会根据[这个顺序][spring-boot-external-config]找`APP_NAME`的值，如果找不到程序启动会报错。

第二种方式和第一种方式的不同在于如果找不到，则使用`application.properties`里定义的默认值。

而程序在启动时应该通过环境变量的方式将这些值传递进去。

在真实应用中应该尽量多的使用第二种方式，只有少数的配置才是程序启动时必须提供的，一般来说都是一些数据库连接字符串、用户名密码等信息。

### Spring Cloud应用关于Config Server的配置要放在`bootstrap.properties`里，并且要做环境变量化

比如这样：

```
spring.cloud.config.enabled=${CONFIG_ENABLED:true}
spring.cloud.config.profile=${CONFIG_PROFILE:production}
spring.cloud.config.label=${CONFIG_LABEL:master}
spring.cloud.config.uri=${CONFIG_SERVER_URL:http://config-server:8080/}
```

上面这个配置可以控制是否连接config server，因为在开发环境下我们可能并不需要config server。也提供了可以config server启动程序的可能。
同时也控制了如果连接config server，应该使用哪个`application.properties`。

需要注意的是，如果我们选择程序启动的时候连接config server，那么在程序启动时提供的环境变量就只能是和config server相关的环境变量（在这个例子里就是上面的`CONFIG_*`），这些配置用来控制如何获得`application.properties`。

因为此时程序所使用的配置都来自于config server，如果config server提供一些，环境变量又提供一些则会造成运维上的混乱。

## 各种启动方式

下面讲讲各种启动方式如何传递环境变量。

### 以操作系统进程启动

直接以操作系统进程启动的方法是类似于这样的：

```
APP_NAME=my-app APP_DESC="My App Desc" java -jar spring-cloud-app.jar
```

### 用Docker启动

用docker启动则是这样的，参见[Docker ENV (environment variables)][docker-run-env]：

```
docker run --name my-app -e APP_NAME=my-app -e APP_DESC="My App Desc" spring-cloud-app:latest
```

### 在K8S里启动

定义ConfigMap或Secret（用在密码类配置上），然后在Deployment spec里使用`configMapRef`或者`secretRef`或者`configMapKeyRef `或者`secretKeyRef`，比如下面的例子：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: <namespace>
spec:
  ...
  template:
    ...
    spec:
      containers:
      - name: my-app
        image: <image repository>
        ...
        envFrom:
        - configMapRef:
            name: my-app-config
        - secretRef:
            name: my-app-secret
        env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: my-app-config
              key: APP_NAME
        - name: APP_DESC
          valueFrom:
            secretKeyRef:
              name: my-app-secret
              key: APP_DESC
```

详见[Configure a Pod to Use a ConfigMap][k8s-config-map]、[Secrets][k8s-secrets]和[Load env variables from ConfigMaps and Secrets upon Pod boot][blog-load-from]。

[spring-cloud-config]: https://cloud.spring.io/spring-cloud-config/
[spring-boot-placeholder]: https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#boot-features-external-config-placeholders-in-properties
[spring-boot-external-config]: https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#boot-features-external-config
[12-factors-config]: https://12factor.net/config
[docker-run-env]: https://docs.docker.com/engine/reference/run/#env-environment-variables
[k8s-config-map]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/
[k8s-secrets]: https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod
[blog-load-from]: https://dchua.com/2017/04/21/load-env-variables-from-configmaps-and-secrets-upon-pod-boot/