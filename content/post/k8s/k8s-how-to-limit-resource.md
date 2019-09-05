---
title: "K8S如何限制资源使用"
author: "颇忒脱"
tags: ["k8s"]
date: 2018-10-22T10:15:20+08:00
---

本文介绍几种在K8S中限制资源使用的几种方法。

<!--more-->

## 资源类型

在K8S中可以对两类资源进行限制：cpu和内存。

CPU的单位有：

* `正实数`，代表分配几颗CPU，可以是小数点，比如`0.5`代表0.5颗CPU，意思是一颗CPU的一半时间。`2`代表两颗CPU。
* `正整数m`，也代表`1000m=1`，所以`500m`等价于`0.5`。

内存的单位：

* `正整数`，直接的数字代表Byte
* `k`、`K`、`Ki`，Kilobyte
* `m`、`M`、`Mi`，Megabyte
* `g`、`G`、`Gi`，Gigabyte
* `t`、`T`、`Ti`，Terabyte
* `p`、`P`、`Pi`，Petabyte

## 方法一：在Pod Container Spec中设定资源限制

在K8S中，对于资源的设定是落在Pod里的Container上的，主要有两类，`limits`控制上限，`requests`控制下限。其位置在：

* `spec.containers[].resources.limits.cpu`
* `spec.containers[].resources.limits.memory`
* `spec.containers[].resources.requests.cpu`
* `spec.containers[].resources.requests.memory`

举例：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: ...
    image: ...
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

## 方法二：在Namespace中限定

方法一虽然很好，但是其不是强制性的，因此很容易出现因忘记设定`limits`/`request`，导致Host资源使用过度的情形，因此我们需要一种全局性的资源限制设定，以防止这种情况发生。K8S通过在`Namespace`设定`LimitRange`来达成这一目的。

### 配置默认`request`/`limit`：

如果配置里默认的`request`/`limit`，那么当Pod Spec没有设定`request`/`limit`的时候，会使用这个配置，有效避免无限使用资源的情况。

配置位置在：

* `spec.limits[].default.cpu`，default limit
* `spec.limits[].default.memory`，同上
* `spec.limits[].defaultRequest.cpu`，default request
* `spec.limits[].defaultRequest.memory`，同上

例子：

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: <name>
spec:
  limits:
  - default:
      memory: 512Mi
      cpu: 1
    defaultRequest:
      memory: 256Mi
      cpu: 0.5
    type: Container
```

### 配置`request`/`limit`的约束

我们还可以在K8S里对`request`/`limit`进行以下限定：

* 某资源的`request`必须`>=某值`
* 某资源的`limit`必须`<=某值`

这样的话就能有效避免Pod Spec中乱设`limit`导致资源耗尽的情况，或者乱设`request`导致Pod无法得到足够资源的情况。

配置位置在：

* `spec.limits[].max.cpu`，`limit`必须`<=某值`
* `spec.limits[].max.memory`，同上
* `spec.limits[].min.cpu`，`request`必须`>=某值`
* `spec.limits[].min.memory`，同上

例子：

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: <name>
spec:
  limits:
  - max:
      memory: 1Gi
      cpu: 800m
    min:
      memory: 500Mi
      cpu: 200m
    type: Container
```


## 参考资料

* [Managing Compute Resources for Containers][manage-compute-resources-container]
* [Configure Default Memory Requests and Limits for a Namespace][memory-default-namespace]
* [Configure Default CPU Requests and Limits for a Namespace][cpu-default-namespace]
* [Configure Minimum and Maximum Memory Constraints for a Namespace][memory-constraint-namespace]
* [Configure Minimum and Maximum CPU Constraints for a Namespace][cpu-constraint-namespace]

[manage-compute-resources-container]: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
[memory-default-namespace]: https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/memory-default-namespace/
[cpu-default-namespace]: https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/
[memory-constraint-namespace]: https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/memory-constraint-namespace/
[cpu-constraint-namespace]: https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-constraint-namespace/