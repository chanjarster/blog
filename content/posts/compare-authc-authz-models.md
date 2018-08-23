---
title: "多种认证、授权模型的比较"
date: 2018-08-22T13:25:35+08:00
draft: false
---
本文主要列举在如今前后端分离、手机App大行其道的现状下，用户认证、授权的几种做法及对比。

PS. 本文假设你已经理解了各种认证模式的具体细节。

## OAuth2.0的几种模式

OAuth2.0是一个被广泛采用的事实标准，它同时包含认证和授权两种模式，我们来看一下它有几种模式：

| Grant type                                           | Client owner  | User context?| Client type               | App type    |
|------------------------------------------------------|---------------|--------------|---------------------------|-------------|
| Authorization Code                                   | Third-party   | Y            | confidential              | Web app     |
| Authorization Code, without client secret            | Third-party   | Y            | public                    | User-agent app |
| Authorization Code, without client secret, with PKCE | Third-party   | Y            | public                    | Native app  |
| OAuth2 Implicit(deprecated)                          | Third-party   | Y            | public                    | User-agent app, Native app |
| Password                                             | First-party   | Y            | both                      | Web app, User-agent app, Native app |
| Client Credentials                                   | Third-party   | N            | confidential              | Web app     |

名词定义：

* **User**: 自然人。
* **Client**: 索要Authorization Code和Access Token的程序。

Client owner:

* **First-party**: 第一方client，即client开发者/厂商和Resource Server是同一个人/厂商。
* **Third-party**: 第三方client，即client开发者/厂商和Resource Server不是同一个人/厂商。OAuth 2.0主要解决的是第三方client的授权问题。

User context:

* **Y**: 代表被授权的资源是和当前User相关的。
* **N**: 代表被授权的资源是和Client相关的。

Client type:

* **Confidential**: 这类Client和Authorization Server/Resource Server的通信是秘密进行的。
* **Public**: 这类Client和Authorization Server/Resource Server的通信是公开进行的。

App type:

* **web app**: 这类App的代码在服务器上执行，用户通过User-Agent（浏览器）下载App渲染的HTML页面，并与之交互。比如，传统的MVC应用。
* **user-agent app**: 这类App的代码是直接下载到User-Agent（浏览器）里执行的。比如，前后端分离App、SPA。
* **native app**: 这类App安装在用户的设备上，可以认为这类App内部存储的credential信息是有可能被提取的。比如，手机App、桌面App。

## 仅做认证的模式

| Mode     | Client belong | User Context | App type                            |
|----------|---------------|--------------|-------------------------------------|
| Session  | First-party   | Y            | Web app                             |
| SSO      | First-party   | Y            | Web app                             |
| JWT      | First-party   | Y            | Web app, User-agent app, Native app | 

详细说明以上三种模式：

**Session模式**: 就是我们传统的Web app所使用的技术，用户输入账号和密码登录系统，服务端返回一个名字叫做`SESSIONID`的`Cookie`，之后User-agent和服务端每次交互都会携带这个`Cookie`，通过这种方式来做到用户登录状态的保持。

**SSO模式**: 其实是**Session模式**的变种，只不过把认证从**Session模式**的本地认证变成了利用**SSO服务器**做认证。已知SSO类型有：CAS、SAML。

**JWT模式**: 它和**Session模式**的区别在于:

1. 用户会话信息不通过`Cookie`携带，而是放在`Header`里，这个信息我们叫做`Token`。
1. `Token`里包含了加密的、不可篡改的当前登录用户的信息，`SESSIONID`只是一个代号，是没有这个信息的。
1. 服务端可以做到无状态，因为用户信息在`Token`里已经存在，再也不需要维护Session了。

**JWT模式**可以使用SSO吗？答案是可以的，但是有条件，在SSO认证流程的最后一步——获取用户信息——的通信必须是confidential的。

对于Web app来说只要它接入了SSO，获取用户信息的通信本来就是confidential的，它获得用户信息之后构造JWT并返回就可以了。

对于User-agent app和Native app来说，需要为它做一个中介Web app，这个Web app和SSO通信，然后构造JWT返回给User-agent app。

## 参考资料

* [OAuth 2.0 official site][1]
* [OAuth 2.0 - Written by Aaron Parecki][2]
* [JWT official site][3]
* [SSO的一种 - CAS Protocol][4]

[1]: https://oauth.net/2/
[2]: https://www.oauth.com/
[3]: https://jwt.io/
[4]: https://apereo.github.io/cas/4.2.x/protocol/CAS-Protocol.html