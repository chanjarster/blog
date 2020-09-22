---
title: "Kubectl 实用小脚本"
date: 2020-09-10T10:24:45+08:00
tags: ["k8s"]
author: "颇忒脱"
---

`kubectl`实用小脚本集锦

<!--more-->

## 查找没有设置Resources Quota(Limits)的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- range .spec.containers }}
{{- if or (not .resources) (not .resources.limits) }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
  Container: {{ .name }}
  Resources: {{ .resources }}
{{ end }}
{{- end }}
{{- end }}'
```

## 查找运行在某个Host上的Pod

替换下面脚本的IP：

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- if eq .status.hostIP "IP" }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
{{- end }}
{{- end }}'
```

