---
title: "调用API时如何做JOIN查询"
author: "颇忒脱"
tags: ["微服务"]
date: 2020-02-19T14:21:24+08:00
---

<!--more-->

## 数据同步方案

数据同步方案简单来说就是把数据从API提供方哪里复制到自己这里。

这类方案的好处是：

* 不需要修改你原来的查询语句。

坏处：

* 同步的实时性问题

### 方案一：利用ETL工具做数据同步

如果你可以将从API提供方的数据库同步到你自己的库中，可以采用ELT工具定时同步的方法。

### 方案二：使用时同步

这个方案和前一个方案案差不多，但数据同步的时机不一样。举个例子说明：

有一个用户API，它是权威数据源。你的业务库中也有用户表，这张表当然现在什么数据都没有，你还有一张订单表关联了用户表。

现在你的业务产生了一个订单，此时你得到了用户ID，但是用户的其他信息没有得到。那么在产生订单的时候，调用用户API，把用户数据同步到你自己的用户表中。这个是第一次同步的情况。

你还有一个业务是查询订单详情，详情中要显示用户信息，你可以在这个时候调用用户API来更新一下用户表中的数据。这个则是同步用户数据更新的情况。

总之，你可以根据自己的实际情况决定什么时候做第一次同步，什么时候做数据更新同步。

## 自己模拟JOIN

这个方案的思路总体来说就是自己模拟数据库JOIN拼接结果。

这个方案的好处是：

* 你不需要自己的表了，按照前面的例子来说就是你不需要用户表了。

缺点是：

* 有些复杂查询可能会无法支持
* 查询能力受制于API支持何种类型的查询
* 需要修改你的查询代码，有些场景下可能还很复杂

下面以查询订单详情为例，提供一些代码例子，在给代码之前先列出这个模拟JOIN所做的工作：


1. 在你自己的库中查询到一系列订单
1. 收集这些订单所关联的用户ID
1. 拿着这些用户ID去用户API查询得到一系列用户对象
1. 构建订单详情对象，将订单和用户对象按照原来的关系装配起来
1. 返回订单详情对象

OderDetailService，负责查询订单详情：

```java
public class OrderDetailService {

  private UserService userService;

  private OrderService orderService;

  public List<OrderDetailDto> findByUserId(String userId) {
    List<Order> orders = orderService.findByUserId(userId);
    // 收集订单中的用户Id
    Set<String> userIds = orders.stream().map(Order::getUserId).collect(Collectors.toSet());
    // 查询到用户
    List<User> users = userService.findByIds(userIds);
    // 构建用户id->用户的map
    Map<String, User> userId2UserMap = users.stream().collect(Collectors.toMap(User::getId, Function.identity()));
    // 构建订单详情对象
    return orders.stream().map(order -> {
      User user = userId2UserMap.get(order.getUserId());
      OrderDetailDto orderDetail = new OrderDetailDto();
      orderDetail.setOrder(order);
      orderDetail.setUser(user);
      return orderDetail;
    }).collect(Collectors.toList());
  }

}
```

订单详情对象：

```java
public class OrderDetailDto {
  private Order order;
  private User user;
}
```

订单对象：

```java
public class Order {
  private String userId;
  private Date createdAt;
  private Double price;
  private String productName;
  private String productUrl;
}
```

用户对象：

```java
public class User {
  private String name;
  private String id;
}
```

订单Service接口：

```java
public interface OrderService {
   List<Order> findByUserId(String userId);
}
```

用户Service接口，你可以提供一个调用API的实现：

```java
public interface UserService {
  List<User> findByIds(Set<String> userIds);
}
```

事实上只要你是基于接口编程的，你可以很方便的把任意Service改成调用API，只要它们的接收参数和返回结果一致就行了。