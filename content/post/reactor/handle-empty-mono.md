---
title: "处理Empty Mono<T>的方法"
author: "颇忒脱"
tags: ["reactor"]
date: 2019-04-19T09:44:52+08:00
---

<!--more-->

在[Reactor][reactor]编程中有时候我们需要对empty `Mono<T>`做一些特定业务逻辑。下面看一段非reactor编程的代码：

```java
public void oldCheck(Token token) {
  if (token == null) {
    // business logic
    return;
  }
  if (token.isExpired) {
    // business logic
    return;
  }
  // business logic
  return;
}
```

如果让你改成reactor你也许会改成这样：

```java
public Mono<Void> badCheck(Mono<Token> tokenMono) {
  return tokenMono
      .flatMap(token -> {
        if (token == null) {
          // CAUTION: You will never be in here
          // business logic
          return Mono.empty();
        }
        if (token.isExpired) {
          // business logic
          return Mono.empty();
        }
        // business logic
        return Mono.empty();
      });
}
```

上面的示例代码里的注释已经写了`if (token == null) {}`的这个条件是永远成立的，这是因为当`Mono<Token>`是empty时，它是不会触发`flatMap`的。诸如`flatMap`的绝大部分Operator都依赖于`Publisher`（`Mono`和`Flux`都是`Pubisher`）推送数据（详情请看[javadoc][reactor-javadoc]），如果`Publisher`本身无数据可推送，那么就不会触发Operator。换句话说`flatMap`内部是不可能得到null的。

那么怎么做才可以？你可以使用Java 8的`Optional`来作为中间值：

```java
public Mono<Void> goodCheck(Mono<Token> tokenMono) {
  return tokenMono
      // Transform Mono<Token> to Mono<Optional<Token>>.
      // If Mono<Token> is empty, flatMap will not be triggered,
      // then we will get a empty Mono<Optional<Token>>
      .flatMap(token -> Mono.just(Optional.of(token)))
      // If Mono<Optional<Token>> is empty, provide an empty Optional<Token>,
      // then we will get a non-empty Mono<Optional<Token>> anyway
      .defaultIfEmpty(Optional.empty())
      // Since Mono<Optional<Token>> is not empty, flatMap will always be triggered.
      .flatMap(tokenOptional -> {
        if (!tokenOptional.isPresent()) {
          // business logic
          return Mono.empty();
        }
        Token token = tokenOptional.get();
        if (token.isExpired) {
          // business logic
          return Mono.empty();
        }
        // business logic
        return Mono.empty();
      });
}
```

除了`defaultIfEmpty`之外，Reactor还提供了`switchIfEmpty`、`repeatWhenEmpty`来处理empty `Mono`/`Flux`。

[reactor]: https://projectreactor.io/
[reactor-javadoc]: https://projectreactor.io/docs/core/release/api/index.html?overview-summary.html