---
title: "Spring Boot 3.4 升级过程记录"
author: "颇忒脱"
tags: ["java", "springboot"]
date: 2025-01-27T13:00:47+08:00
---

<!--more-->


按照下面的顺序升级，会让你减少一些痛苦。

如果你的代码包含单元测试和集成测试，那会减少很多痛苦。

## 升级到 2.4.13

相关文档：

* [2.4 Release Note](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-2.4-Release-Notes)
* [2.4 参考手册](https://docs.spring.io/spring-boot/docs/2.4.x/reference/htmlsingle/index.html)

### JUnit4 to JUnit5

2.4 开始就不直接支持 JUnit4 了，所以迁移到 JUnit5

#### 类名的变化

* `org.junit.Test` -> `org.junit.jupiter.api.Test`
* `org.junit.Assert.*` -> `org.junit.jupiter.api.Assertions.*`

#### Annotation 类变化

* `@org.junit.Ignore` -> `@org.junit.jupiter.api.Disabled`
* `@org.junit.Before` -> `@org.junit.jupiter.api.BeforeEach`
* `@org.junit.runner.RunWith(SpringRunner.class)` -> `@org.junit.jupiter.api.extension.ExtendWith(SpringExtension.class)`

#### 写法的变化

异常断言的变化：

```java
// JUnit4
@Test(expected = BarException.class)
public void fooMethod() {
  ...
}

// JUnit5
@Test
public void fooMethod() {
  BarException ex = assertThrows(BarException.class, () -{
    ...
  })
}
```

引入局部 Spring Configuration 的变化：

```java
// JUnit4
@ContextConfiguration(classes = FooConfiguration.class)
public class FooTest {
  @Test
  public void fooMethod() {
  }
}

// JUnit5
@ExtendWith(SpringExtension.class)
@ContextConfiguration(classes = FooConfiguration.class)
public class FooTest {
  @Test
  public void fooMethod() {
  }
}
```

## 升级到 2.7.18

相关文档：

* [2.7 Release Note](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-2.7-Release-Notes)
* [2.7 参考手册](https://docs.spring.io/spring-boot/docs/2.7.x/reference/htmlsingle/)

### Flyway

从 Spring Boot 2.7 开始，flyway 对于 MySQL 的支持分离到单独的包里，你需要额外引入：

```xml
<dependency>
  <groupId>org.flywaydb</groupId>
  <artifactId>flyway-core</artifactId>
</dependency>
<dependency>
  <groupId>org.flywaydb</groupId>
  <artifactId>flyway-mysql</artifactId>
</dependency>
```

### Webflux

#### 自定义 ErrorHandler 变化

从 Spring Boot 2.7 开始，DefaultErrorWebExceptionHandler 构造函数有了变化。

Spring Boot 2.6 [Error Handling 文档](https://docs.spring.io/spring-boot/docs/2.6.x/reference/htmlsingle/#web.reactive.webflux.error-handling)

```java
public DefaultErrorWebExceptionHandler(
  ErrorAttributes errorAttributes,
  Resources resources,
  ApplicationContext applicationContext,
  ServerCodecConfigurer serverCodecConfigurer
)
```

Spring Boot 2.7 [Error Handling 文档](https://docs.spring.io/spring-boot/docs/2.7.x/reference/htmlsingle/#web.reactive.webflux.error-handling)：

```java
public DefaultErrorWebExceptionHandler(
  ErrorAttributes errorAttributes,
  WebProperties webProperties,
  ApplicationContext applicationContext,
  ServerCodecConfigurer serverCodecConfigurer
)
```

### Bean 循环依赖问题

从 Spring Boot 2.6 开始，它 Spring Framework 就不支持循环依赖了（在[Spring Framework 文档][sf-doc-1]中搜索 circular reference 或者 circular dependenc）,下面的写法会报循环依赖错误 `BeanCurrentlyInCreationException: Is there an unresolvable circular reference?`。

举个例子：

```java
@Configuration
class ExampleConfiguration {
  @Bean public Foo foo() {
    return new Foo();    
  }
  @Bean public Bar bar() {
    return new Bar();
  }
}

class Foo implements ApplicationContextAware, InitializingBean {
  private Bar bar;
  private ApplicationContext applicationContext;
  @Override
  public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
    this.applicationContext = applicationContext;
  }
  @Override
  public void afterPropertiesSet() throws Exception {
    this.bar = applicationContext.getBean(Bar.class);
  }
}

class Bar implements ApplicationContextAware, InitializingBean {
  private Foo foo;
  private ApplicationContext applicationContext;
  @Override
  public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
    this.applicationContext = applicationContext;
  }
  @Override
  public void afterPropertiesSet() throws Exception {
    this.foo = applicationContext.getBean(Foo.class);
  }
}
```

改成：

```java
class Foo implements ApplicationContextAware, InitializingBean {
  private Bar bar;
  private ApplicationContext applicationContext;
  @Override
  public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
    this.applicationContext = applicationContext;
  }
  @Override
  public void afterPropertiesSet() throws Exception {
    this.bar = applicationContext.getBean(Bar.class);
    this.bar.setFoo(this);
  }
}

class Bar {
  private Foo foo;
  public void setFoo(Foo foo) {
    this.foo = foo;
  }
}
```

[sf-doc-1]: https://docs.spring.io/spring-framework/docs/5.3.39/reference/html/core.html#spring-core


## 升级到 3.0.13

相关文档：

* [3.0 Release Note](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.0-Release-Notes)
* [3.0 参考手册](https://docs.spring.io/spring-boot/docs/3.0.x/reference/htmlsingle/)

### 升级 JDK

把开发环境的 JDK 升级到 21。

### 升级 Maven

把 Maven 升级到 3.9.9。

### 调整 pom.xml

```xml
<properties>
  <java.version>21</java.version>
  <maven.compiler.source>${java.version}</maven.compiler.source>
  <maven.compiler.target>${java.version}</maven.compiler.target>
</properties>
```

### javax.validation 的变化

依赖的变化，原来：

```xml
<dependency>
  <groupId>javax.validation</groupId>
  <artifactId>validation-api</artifactId>
</dependency>
```

修改后：

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

类名的变化：

* `javax.validation.constraints.NotEmpty`-> `jakarta.validation.constraints.NotEmpty`
* `javax.validation.constraints.Positive` -> `jakarta.validation.constraints.Positive`

### Reactor 的变化

Thread And Schedulers [Reactor 文档](https://projectreactor.io/docs/core/release/reference/coreFeatures/schedulers.html)

```java
// 升级前
Schedulers.elastic()
// 升级后
Schedulers.boundedElastic()
```

### Webflux 的变化

#### 自定义 ErrorHandler 的变化

参考文档：javadoc

原本：

```java
AbstractErrorWebExceptionHandler.getErrorAttributes(request, true);
```

变更后：

```java
ErrorAttributeOptions options = ErrorAttributeOptions.defaults()
  .including(ErrorAttributeOptions.Include.STACK_TRACE);
AbstractErrorWebExceptionHandler.getErrorAttributes(request, options);
```

### Spring Test 的变化

类名的变化：

* `org.springframework.boot.web.server.LocalServerPort` -> `org.springframework.boot.test.web.server.LocalServerPort`

### flyway 的变化

从 Spring Boot 3.0 开始，`spring.flyway.clean-disabled` 默认值变为 true，意味着不允许执行`flyway.clean()`，如果你确实需要，把值改为 false 即可。

```yaml
spring:
  flyway:
    clean-disabled: false
```

### AutoConfiguration 的变化

从 Spring Boot 2.7 开始，AutoConfiguration 配置形式变化了，（[2.7 AutoConfiguration 文档][sb-a-1]，[AutoConfiguration 迁移说明][sb-a-2]）。

原本`/META-INF/spring.factories`：

```
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
classA,\
classB
```

要把`spring.factories`里的`EnableAutoConfiguration`这段删除掉，把内容移动到 `/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`文件里：

```
classA
classB
```

### application.yaml 属性的变化

在 pom.xml 中添加这个部份，它会在程序启动的时候提示你修改那些配置属性：

```xml
<dependency>
	<groupId>org.springframework.boot</groupId>
	<artifactId>spring-boot-properties-migrator</artifactId>
	<scope>runtime</scope>
</dependency>
```

### Spring Data Redis 的变化

从 Spring Boot 3.0 开始，增加了 `spring.data.redis.username`参数，该参数主要用于支持 Redis 6.0 开始的 ACL，Redis 6.0 开始，`AUTH`命令支持用户名参数。对于 Redis 6.0 之前的版本，无需设置该参数。下面是一个例子

```yaml
spring:
  data.redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT:6379}
    username: ${REDIS_USERNAME:}
    password: ${REDIS_PASSWORD}
    lettuce:
      pool:
        max-active: ${REDIS_POOL:100}
```

详见 [Redis AUTH 命令文档][redis-auth-cmd]。

### 调整 Jenkinsfile

把 Maven 和 JDK 参数调整至如下（公司 Jenkins 已经安装好这两个工具）：

```groovy
withMaven(
  maven: 'Maven3.9',
  jdk: 'JDK21',
  ...
) {
  ...
}
```

### 更换基础镜像

修改`Dockerfile`切换到 eclipse-temurin / amazon corretto JDK 21 镜像。


## 升级到 3.4.1

相关文档：

* [3.4 Release Note](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.4-Release-Notes)
* [3.4 参考手册](https://docs.spring.io/spring-boot/index.html)

### Http client 的变化

Spring Boot 的 BOM 里不再有 httpclient4：

```xml
<dependency>
  <groupId>org.apache.httpcomponents</groupId>
  <artifactId>httpclient</artifactId>
</dependency>
```

要改成：

```xml
<dependency>
  <groupId>org.apache.httpcomponents.client5</groupId>
  <artifactId>httpclient5</artifactId>
</dependency>
```

### Mockito 变化

[Deprecation of @MockBean and @SpyBean](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.4-Release-Notes#deprecation-of-mockbean-and-spybean)：

* `@MockBean` 替换成 Spring Framework 里的 `@MockitoBean`
* `@SpyBean` 替换成 Spring Framework 里的 `@MockitoSpyBean`

[Explicitly setting up instrumentation for inline mocking (Java 21+)](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#0.3)：

修改你的 pom.xml，给你的 maven-surefire-plugin（如有） 或 maven-failsafe-plugin（如有），添加 `-javaagent`参数，注意要和 maven-dependency-plugin 搭配。

```xml
 <plugin>
     <groupId>org.apache.maven.plugins</groupId>
     <artifactId>maven-dependency-plugin</artifactId>
     <executions>
         <execution>
             <goals>
                 <goal>properties</goal>
             </goals>
         </execution>
     </executions>
 </plugin>
 <plugin>
     <groupId>org.apache.maven.plugins</groupId>
     <artifactId>maven-surefire-plugin</artifactId>
     <configuration>
         <argLine>-javaagent:${org.mockito:mockito-core:jar}</argLine>
     </configuration>
 </plugin>
```

### Maven plugin 的变化

以下这些 maven plugin 的版本你再也不需要显式指定，指定了可能会出现编译错误：

```
maven-compiler-plugin
maven-surefire-plugin
maven-failsafe-plugin
maven-source-plugin
maven-javadoc-plugin
```

[sb-a-1]: https://docs.spring.io/spring-boot/docs/2.7.x/reference/htmlsingle/#features.developing-auto-configuration.locating-auto-configuration-candidates
[sb-a-2]: https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-2.7-Release-Notes#new-autoconfiguration-annotation
[redis-auth-cmd]: https://redis.io/docs/latest/commands/auth/