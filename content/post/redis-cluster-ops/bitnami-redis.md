---
title: "Redis 集群运维笔记 - 利用 bitnami/redis 部署 Redis Cluster"
author: "颇忒脱"
tags: ["redis"]
date: 2024-01-27T12:02:32+08:00
---

<!--more-->

本文介绍如何使用 [bitnami/redis helm chart][1] 组成 Redis Cluster。

虽然有 [bitnami/redis-cluster helm chart][2] 可以使用，但是它是自动组成 Redis Cluster 的，缺少了一定的灵活性，因此没有选它。

## 拓扑

先做好[高可用架构规划](../ha-arch)，然后再来看 K8S 对应的解决方案：

* master 和 slave 共享服务器：不需要特别设置。
* master 和 slave 共享服务器，Pod 错开：做不到。
* master Pod 散布开：[Pod Topology Spread Constraints][pod-spread](k8s >= v1.19)。
* slave Pod 散布开：同上。
* master 和 slave 服务器分离：[Inter-pod anti-affinity][inter-pod-anti-affinity]。
* slave 和 slave 共享服务器，Pod 错开：做不到。

总结来说就是：

* 服务器分离：[Inter-pod anti-affinity][inter-pod-anti-affinity]。
* Pod 散布开：[Pod Topology Spread Constraints][pod-spread]。
* Pod 错开：只能人工处理。

本方案默认 Redis Cluster 由两个 StatefulSets 组成，一个是 Master （默认3副本），一个是 Slave （默认3副本）。

## 步骤

clone bitnami charts 仓库：

```bash
git clone https://github.com/bitnami/charts.git bitnami-charts
cd bitnami-charts/bitnami
```

1）部署 Master 和 Slave StatefulSets

Release 名字叫做 `rc-master` 和 `rc-slave`：

rc-master-values.yaml:

```yaml
architecture: standalone

auth:
  enabled: true
  # 密码
  password: foobarloozoo
  # 用户名
  username: default

global:
  imageRegistry: harbor2.supwisdom.com
  # imagePullSecrets:
  #   - harbor-ipr
  storageClass: nfs-client

image:
  repository: bitnami/redis
  tag: 6.2
  pullPolicy: Always

# 自定义的
roleLabels:
  master:
    redis-cluster/role: master
  slave:
    redis-cluster/role: slave

master:
  configuration: |-
    # append to redis.conf
    cluster-enabled yes
    cluster-config-file {{ .Values.master.persistence.path }}/nodes.conf
    aclfile /data/users.acl
    maxmemory 1024mb
  
  initContainers: |-
    - name: aclfile-init
      image: '{{ include "redis.sysctl.image" . }}'
      imagePullPolicy: IfNotPresent
      command:
        - /bin/bash
        - -ec
        - |
          echo 'write {{ .Values.master.persistence.path }}/users-default.acl'
          echo 'user {{ .Values.auth.username }} on #{{ sha256sum .Values.auth.password }} ~* &* +@all' > {{ .Values.master.persistence.path }}/users-default.acl
      volumeMounts:
        - name: redis-data
          mountPath: "{{ .Values.master.persistence.path }}"
          subPath: "{{ .Values.master.persistence.subPath }}"

  preExecCmds: |-
    if [[ ! -e  "$DATA_DIR/users.acl" ]]; then
      echo "Initialize $DATA_DIR/users.acl"
      cat "$DATA_DIR/users-default.acl" > "$DATA_DIR/users.acl"
    else
      echo "Skipping initialize $DATA_DIR/users.acl, because it already exists"
    fi
  
  extraEnvVars: |-
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: DATA_DIR
      value: {{ .Values.master.persistence.path }}
  
  extraFlags:
    - --cluster-announce-ip $POD_IP

  persistence:
    size: 2Gi

  resources:
    requests:
      cpu: 500m
      memory: 128Mi
    limits:
      cpu: 2
      memory: 1088Mi
  
  podLabels: |-
    {{ .Values.roleLabels.master | toYaml }}
  
  # 尽量不和 slave pod 在一起
  podAntiAffinityPreset: soft
  affinity: |-
    podAntiAffinity: 
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchLabels:
              {{ .Values.roleLabels.slave | toYaml | nindent 12 }}
          topologyKey: kubernetes.io/hostname
        weight: 1
    
  # 强制分散分布
  topologySpreadConstraints: |-
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels: {{- (include "common.labels.matchLabels" $) | nindent 6 }}
          {{ .Values.roleLabels.master | toYaml | nindent 6 }}
          app.kubernetes.io/component: master

sysctl:
  enabled: true
  image:
    repository: bitnami/bitnami-shell
    tag: 10-debian-10
    pullPolicy: Always
  command:
    - /bin/bash
    - -ec
    - |
      sysctl -w net.core.somaxconn=512
  resources:
    limits:
      cpu: 500m
      memory: 128Mi

metrics:
  enabled: true
  image:
    repository: bitnami/redis-exporter
    tag: 1-debian-10
    pullPolicy: Always
  resources:
    limits:
      cpu: 500m
      memory: 128Mi
```

rc-slave-values.yaml:

```yaml
architecture: standalone

auth:
  enabled: true
  # 密码
  password: foobarloozoo
  # 用户名
  username: default

global:
  imageRegistry: harbor2.supwisdom.com
  # imagePullSecrets:
  #   - harbor-ipr
  storageClass: nfs-client

image:
  repository: bitnami/redis
  tag: 6.2
  pullPolicy: Always

# 自定义的
roleLabels:
  master:
    redis-cluster/role: master
  slave:
    redis-cluster/role: slave

master:
  configuration: |-
    # append to redis.conf
    cluster-enabled yes
    cluster-config-file {{ .Values.master.persistence.path }}/nodes.conf
    aclfile /data/users.acl
    maxmemory 1024mb
  
  initContainers: |-
    - name: aclfile-init
      image: '{{ include "redis.sysctl.image" . }}'
      imagePullPolicy: IfNotPresent
      command:
        - /bin/bash
        - -ec
        - |
          echo 'write {{ .Values.master.persistence.path }}/users-default.acl'
          echo 'user {{ .Values.auth.username }} on #{{ sha256sum .Values.auth.password }} ~* &* +@all' > {{ .Values.master.persistence.path }}/users-default.acl
      volumeMounts:
        - name: redis-data
          mountPath: "{{ .Values.master.persistence.path }}"
          subPath: "{{ .Values.master.persistence.subPath }}"

  preExecCmds: |-
    if [[ ! -e  "$DATA_DIR/users.acl" ]]; then
      echo "Initialize $DATA_DIR/users.acl"
      cat "$DATA_DIR/users-default.acl" > "$DATA_DIR/users.acl"
    else
      echo "Skipping initialize $DATA_DIR/users.acl, because it already exists"
    fi
  
  extraEnvVars: |-
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: DATA_DIR
      value: {{ .Values.master.persistence.path }}
  
  extraFlags:
    - --cluster-announce-ip $POD_IP

  persistence:
    size: 2Gi

  resources:
    requests:
      cpu: 500m
      memory: 128Mi
    limits:
      cpu: 2
      memory: 1088Mi
  
  podLabels: |-
    {{ .Values.roleLabels.slave | toYaml }}
  
  # 尽量不和 slave pod 在一起
  podAntiAffinityPreset: soft
  affinity: |-
    podAntiAffinity: 
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchLabels:
              {{ .Values.roleLabels.master | toYaml | nindent 12 }}
          topologyKey: kubernetes.io/hostname
        weight: 1

  # 强制分散分布
  topologySpreadConstraints: |-
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels: {{- (include "common.labels.matchLabels" $) | nindent 6 }}
          {{ .Values.roleLabels.slave | toYaml | nindent 6 }}
          app.kubernetes.io/component: master

sysctl:
  enabled: true
  image:
    repository: bitnami/bitnami-shell
    tag: 10-debian-10
    pullPolicy: Always
  command:
    - /bin/bash
    - -ec
    - |
      sysctl -w net.core.somaxconn=512
  resources:
    limits:
      cpu: 500m
      memory: 128Mi

metrics:
  enabled: true
  image:
    repository: bitnami/redis-exporter
    tag: 1-debian-10
    pullPolicy: Always
  resources:
    limits:
      cpu: 500m
      memory: 128Mi
```

```bash
helm install -n <namespace> \
  -f bitnami-redis/rc-master-values.yaml \
  --set fullnameOverride=rc-master \
  rc-master \
  /path/to/bitnami-charts/bitnami/redis

helm install -n <namespace> \
  -f bitnami-redis/rc-slave-values.yaml \
  --set fullnameOverride=rc-slave \
  rc-slave \
  /path/to/bitnami-charts/bitnami/redis
```

注意这里使用了 `bitnami-redis/rc-master-values.yaml` 和 `bitnami-redis/rc-slave-values.yaml` 参数文件。

2）给 StatefulSets 打 patch：

`rc-master` 和 `rc-slave` 对应的 StatefulSets 名字叫做 `rc-master-master` 和 `rc-slave-master`，不要在乎结尾的 `-master` ，因为 bitnami/redis 写死了 StatefulSets 名字后面会加上 `-master`。

redis-patch.yaml:

```yaml
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: redis
        ports:
        - containerPort: 16379
          name: redis-bus
          protocol: TCP
```

patch 的功能：

1. 暴露 `16379` 端口
2. 副本数变为 3

```bash
kubectl -n <namespace> \
  patch statefulsets rc-master-master \
  --patch "$(cat bitnami-redis/redis-patch.yaml)"

kubectl -n <namespace> \
  patch statefulsets rc-slave-master \
  --patch "$(cat bitnami-redis/redis-patch.yaml)"
```

3）给 Service 打 patch：

redis-headless-svc-patch.yaml: 

```yaml
spec:
  ports:
  - name: tcp-redis-bus
    port: 16379
    protocol: TCP
    targetPort: redis-bus
```

patch 功能：

1. headless Service 暴露 `16379` 端口


```bash
kubectl -n <namespace> \
  patch service rc-master-headless \
  --patch "$(cat bitnami-redis/redis-headless-svc-patch.yaml)"

kubectl -n <namespace> \
  patch service rc-slave-headless \
  --patch "$(cat bitnami-redis/redis-headless-svc-patch.yaml)"
```

4）组建集群，两种方式，任选一种：

* [redis-cli 方式](../ops-cli/new-cluster)
* [Redis Command 方式](../ops-cmd/new-cluster)

## StatefulSets 升级注意事项

先了解以下几个事实：

* StatefulSets 的滚动升级策略是从最后一个 Pod 开始挨个升级
* StatefulSets 的升级方式是先重建 Pod：先删除，再创建
* Redis Cluster 只认 NodeID，节点的 IP 端口变化无所谓
* Redis Cluster 的自动 failover 策略具有一定时延

所以升级时会出现以下现象：

* 因为 Pod 在重建，而时间比较短，无法触发自动 failover，部分节点出现短暂不可用
* Pod 重建失败，那么在短暂不可用之后，redis cluster 触发自动 failover
* Pod 重建之后可能破坏高可用架构

因此建议的做法是：

1. 先通过 failover 把所有 slave 升格为 master，这样 master 就变成了 slave
2. 对原 master（现在降格为 slave 了）StatefulSets 做升级
3. 升级完成后，再通过 failover 把角色变回原来的样子
4. 对 slave StatefulSets 做升级
5. 如果重建 Pod 运行位置破坏了 [高可用部署架构](../ha-arch)，则还需要手工处理。


## 节点 IP:PORT 变化后重新加入

根据 [Creating and using a Redis Cluster][creat-new-cluster] ：

> Every node remembers every other node using this IDs, and not by IP or port. IP addresses and ports may change, but the unique node identifier will never change for all the life of the node. We call this identifier simply **Node ID**.

所以，只要 nodes.conf 信息不丢失，IP port 随便怎么变都可以。

本方案中，nodes.conf 应存放在持久卷中。

如果 Pod 重建发生 IP 变更，那么分情况说明：

**情况1：**

N 个 Pod 中只有 1 个重建，那么问题不大，因为重启后 Pod 会把自己连接到集群的其他节点，然后 redis 会通过 gossip 协议把 Pod 的新 IP 传播到其他节点上。

**情况2：**

所有 Pod 都重建了，那么这个集群肯定会 fail，因为每个 Pod 都无法使用原来的 IP 和其他 Pod 通信了。

处理方式，按照新建集群的步骤（[redis-cli方式](../ops-cli/new-cluster) 或 [Redis Command方式](../ops-cmd/new-cluster)），把所有节点都再加一遍。

当然，加入后，你还得保持[高可用部署架构](../ha-arch)。

[1]: https://github.com/bitnami/charts/tree/master/bitnami/redis
[2]: https://github.com/bitnami/charts/tree/master/bitnami/redis-cluster

[inter-pod-anti-affinity]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
[pod-spread]: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/
[creat-new-cluster]: https://redis.io/topics/cluster-tutorial#creating-and-using-a-redis-cluster