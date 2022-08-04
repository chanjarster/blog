---
title: "删除无法删掉的namespace"
author: "颇忒脱"
tags: ["k8s"]
date: 2022-08-04T09:30:27+08:00
---

<!--more-->

删除一直删不掉的Namespace。

参考资料：https://aws.amazon.com/cn/premiumsupport/knowledge-center/eks-terminated-namespaces/


1）保存一个与以下类似的 JSON 文件：

```
kubectl get namespace <terminating-namespace> -o json > tempfile.json
```

2）编辑该 JSON 文件，找到 finalizer 数组，清空它。


3）要应用更改，请运行一个与以下类似的命令：

```
kubectl replace --raw "/api/v1/namespaces/<terminating-namespace>/finalize" -f ./tempfile.json
```

4）验证是否已经删除了正在终止的命名空间：

```
kubectl get namespaces
```

对所有卡在 Terminating（正在终止）状态的其他命名空间重复这些步骤。


