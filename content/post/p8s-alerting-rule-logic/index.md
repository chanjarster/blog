---
title: "Prometheus告警逻辑分析"
author: "颇忒脱"
tags: ["prometheus"]
date: 2021-02-26T09:42:05+08:00
---

<!--more-->

本文分析Prometheus的[Alerting Rule][1]的执行逻辑。

## 领域模型

在Prometheus的定义中，告警规则由AlertingRule来描述，而AlertingRule则被归到[Group][p8s-group]中，比如下面的配置文件例子：

```yaml
groups:
- name: example
  interval: 30s
  rules:
  - alert: HighRequestLatency
    expr: job:request_latency_seconds:mean5m{job="myjob"} > 0.5
    for: 10m
    labels:
      severity: page
    annotations:
      summary: High request latency
```

每个AlertingRule在运行时还维护具体的告警对象（Alert）。

下面是领域模型：

<img src="domain.png" style="zoom:50%" />

## 告警逻辑

Prometheus会根据`group.interval` (下图的 `check_interval`）定时执行AlertingRule（执行Eval方法），然后发送告警到Alertmanager，最后再更新AlertingRule的状态、Group的状态。

<img src="logic.png" style="zoom:65%" />

### 规则执行逻辑

上图已经说明了，执行告警规则第一步是执行表达式（`expr`属性），然后是根据表达式执行结果，管理Alert对象，逻辑如下：

<img src="alert-state.png" style="zoom:65%" />

Alert对象有三个状态：

* **Pending**：活跃但是还未发送给 Alertmanager，是所有 Alert 对象的初始状态。
* **Firing**：告警发送中，特指发送到 Alertmanager。
* **Inactive**：未激活，这类告警会保留 `resolved_retension` 规定的时间 (程序常量 15 分钟），而不是马上删除。
* 虚拟状态“被删除”，处于 Inactive 状态的告警超过 `resolved_retention` 规定的时间之后，就会被删除。

三种状态的迁移逻辑：

**Pending -> Firing**

Alert 对象当前处于 Pending，Eval 结果是 true，且距离初次活跃时间（`Alert.ActiveAt`）超过`<for>`（`AlertingRule.holdDuration`）的时长，那么这个Alert对象就会变成 **Firing** 状态。

**Pending -> 被删除**

Alert 对象当前处于 Pending 状态，Eval 结果是 false，那么这个 Alert 对象就直接被删除。

**Firing -> Inactive**

Alert 对象当前处于 Firing 状态，Eval 结果是 false，那么这个 Alert 对象会变成 **Inactive状态**。

**Inactive -> Pending**

Alert 对象当前处于 Inactive状态，Eval 结果是 true，那么这个 Alert 对象会重置为 **Pending** 状态。

**Inactive -> 被删除**

Alert对象当前处于Inactive状态，且保持超过了 `resolved_retention` （p8s里写死 15 分钟），则被删除。

### 告警发送的逻辑

AlertingRule 执行之后，会把 Firing / Inactive 状态的 Alert 发送出去，逻辑如下：

```go
func (a *Alert) needsSending(ts time.Time, resendDelay time.Duration) bool {
	if a.State == StatePending {
		return false
	}

	// if an alert has been resolved since the last send, resend it
	if a.ResolvedAt.After(a.LastSentAt) {
		return true
	}

	return a.LastSentAt.Add(resendDelay).Before(ts)
}
```

代码中的连个参数：

* ts，是当前时间
* resendDelay，是程序启动参数 `--rules.alert.resend-delay` 规定的，默认 `1m`。

Alert 发送之后会更新 `LastSentAt` 和 `ValidUntil` 字段：

```go
Alert.LastSentAt = ts
Alert.ValidUntil = max([check_interval], [resend_delay]) * 4
```

其实你可以看到，在 Prometheus 层面，告警消息是会重复发送给 Alertmanager 的，而 Alermanager 则通过 `route.repeat_interval` ([文档][2]) 来避免重复发送给 Receiver。 

### 更新AlertingRule规则

最后更新AlertingRule的状态，逻辑如下：

<img src="alerting-rule-state.png" style="zoom:65%" />


[1]: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
[p8s-group]: https://prometheus.io/docs/prometheus/2.25/configuration/recording_rules/#rule_group
[2]: https://prometheus.io/docs/alerting/latest/configuration/#route