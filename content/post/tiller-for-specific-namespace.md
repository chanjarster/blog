---
title: "配置Tiller只能操作特定Namespace的方法"
author: "颇忒脱"
tags: ["k8s", "helm", "tiller"]
date: 2019-10-11T14:44:17+08:00
---

本文如何控制Tiller只能操作特定Namespace的方法。

<!--more-->

在Helm的官方文档介绍的安装方法里，会给Tiller的Service Account绑定cluster-admin集群角色，这就意味着只要你的Helm能够和Tiller通信，那么就能通过Tiller控制所有Namespace下的Release。

在更多情况下，我们希望能够按照Namespace把Tiller的权限分割开来，比如A用户只能通过Tiller来控制Namespace A的Release，B用户只能通过Tiller来控制Namespace B的Release。

[Configuring minimal RBAC permissions for Helm and Tiller][article-1]文章提供了解决办法，原理是给每个Namespace部署一个Tiller，然后给其分配一个只能操作这个Namespace的Service Account。

> 注意：Configuring ... 文章中提到了给CI/CD用的helm账号，本文没有涉及此内容。

我在这篇文章的基础上做了一些脚本，并列举一些常用的命令。

## 操作步骤

1）使用[`init-tiller-sa.sh`][gist-1]在Namespace下创建Service Account：

```bash
./init-tiller-sa.sh <namespace>
```

2）安装Tiller：

```bash
helm init --service-account tiller \
  --tiller-namespace <namespace> \
```

如果安装不成功，比如因为Tiller镜像Pull不下来，你可以这样：

```bash
helm init --service-account tiller \
  --tiller-namespace <namespace> \
  --upgrade \
  --tiller-image=<另外一个tiller的镜像>
```

3）使用Helm部署Charts，比如这样：

```bash
helm --tiller-namespace <namespace> \
  install <chart> \
  --name <release> \
  --namespace <namespace>
```

--namespace`参数可以不提供，如果不提供则和你kubectl的默认namespace相同。

**注意：**

所有的helm指令你都需要加上`--tiller-namespace`参数。

如果你要删除Tiller，则：

```bash
helm --tiller-namespace <namespace> reset
```

## 参考资料

* [Configuring minimal RBAC permissions for Helm and Tiller][article-1]
* [Helm - Role-based Access Control][article-2]

[article-1]: https://medium.com/@elijudah/configuring-minimal-rbac-permissions-for-helm-and-tiller-e7d792511d10
[article-2]: https://helm.sh/docs/using_helm/#role-based-access-control
[gist-1]: https://gist.github.com/chanjarster/d5116cad45e8643c2675f541b0aa1939