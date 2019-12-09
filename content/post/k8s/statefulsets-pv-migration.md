---
title: "StatefulSets迁移PV的方法"
author: "颇忒脱"
tags: ["k8s"]
date: 2019-12-09T10:59:27+08:00
---

<!--more-->

先说说场景，你有一个StatefulSets，通过`volumeClaimTemplate`创建了PVC。现在这些PVC所关联的PV对你来说不够用了，你希望能够使用更大的PVC。

大致步骤如下：

1. 先把StatefulSets的Yaml备份下来。
2. 利用busybox复制数据。
3. 使用新PVC。
4. 清理PVC。

下面是详细步骤：

## 备份StatefulSets

把StatefulSets的Yaml备份下来，下面是代码片段，注意volumeClaimTemplate和volumeMounts部分：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
  # ...
spec:
  # ...
  template:
    # ...
    spec:
      containers:
      - image: ranchercharts/confluentinc-cp-zookeeper:5.3.0
        # ...
        volumeMounts:
        - mountPath: /var/lib/zookeeper/data
          name: datadir
  # ...
  volumeClaimTemplates:
  - metadata:
      name: datadir
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
      volumeMode: Filesystem
```

然后删掉它，删掉StatefulSets不会删除对应的PVC。

## 复制数据

StatefulSets的volumeClaimTemplate所生成的PVC的名字是这样的格式：`{volume-name}-{statefulsets-name}-数字`，比如`datadir-zookeeper-0`。

所以我们可以创建一个busybox StatefulSets，名字也是zookeeper，并且它的volumeClaimTemplate和原来的一样，这样它就可以使用旧PVC了。同时它还得创建一个新的volumeClaimTemplate来创建新的PVC。

注意replicas得和原来的一样。

下面是例子：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
spec:
  podManagementPolicy: OrderedReady
  # 得和原来的一样
  replicas: 3
  selector:
    matchLabels:
      app: busybox-pvc-migration
  serviceName: portal-cp-zookeeper
  template:
    metadata:
      labels:
        app: busybox-pvc-migration
    spec:
      containers:
      - image: busybox
        imagePullPolicy: Always
        name: zookeeper
        stdin: true
        tty: true
        volumeMounts:
        # 旧PVC
        - mountPath: /datadir-old
          name: datadir
        # 新PVC
        - mountPath: /datadir-new
          name: datadir-new
      dnsPolicy: ClusterFirst
      restartPolicy: Always
  updateStrategy:
    type: RollingUpdate
  volumeClaimTemplates:
  # 旧claim
  - metadata:
      name: datadir
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
      volumeMode: Filesystem
   # 新claim
  - metadata:
      name: datadir-new
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      volumeMode: Filesystem
```

进入每个busybox的shell，复制旧PVC的内容到新的PVC：

```bash
cp -r /datadir-old/* /datadir-new/
```

复制完之后注意检查一下文件的权限和所属用户与用户组。

最后删除busybox。同理，它所新建的PVC也不会被删除，这些PVC后面要被使用。

## 使用新PVC

修改之前备份下来的Yaml，让它使用新的PVC，修改volumeClaimTemplate和volumeMounts部分：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
  # ...
spec:
  # ...
  template:
    # ...
    spec:
      containers:
      - image: ranchercharts/confluentinc-cp-zookeeper:5.3.0
        # ...
        volumeMounts:
        - mountPath: /var/lib/zookeeper/data
          # 使用了新的PVC
          name: datadir-new
  # ...
  volumeClaimTemplates:
  - metadata:
      # 使用了新的PVC
      name: datadir-new
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      volumeMode: Filesystem
```

## 清理PVC

确认没有问题后，可以清理掉旧的PVC。