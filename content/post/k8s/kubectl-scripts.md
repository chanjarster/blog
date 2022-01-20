---
title: "Kubectl 实用小脚本"
date: 2020-09-10T10:24:45+08:00
tags: ["k8s", "cheatsheet"]
author: "颇忒脱"
---

<!--more-->

## 查找没有设置Resources Limits的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{- if eq .status.phase "Running" -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- range .spec.containers }}
{{- if or (not .resources) (not .resources.limits) }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
  Container: {{ .name }}
  Resources: {{ .resources }}
{{ end -}}
{{- end -}}
{{- end -}}
{{ end }}'
```

## 查找没有设置CPU Limits的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{- if eq .status.phase "Running" -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- range .spec.containers }}
{{- if or (not .resources) (not .resources.limits) (not .resources.limits.cpu) }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
  Container: {{ .name }}
  Resources: {{ .resources }}
{{ end -}}
{{- end -}}
{{- end -}}
{{ end }}'
```

## 查找没有设置Memory Limits的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{- if eq .status.phase "Running" -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- range .spec.containers }}
{{- if or (not .resources) (not .resources.limits) (not .resources.limits.memory) }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
  Container: {{ .name }}
  Resources: {{ .resources }}
{{ end -}}
{{- end -}}
{{- end -}}
{{ end }}'
```

## 查找设置了Requests CPU的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
{{- if eq .status.phase "Running" -}}
{{ $pod := .metadata.name -}}
{{ $ns := .metadata.namespace -}}
{{- range .spec.containers }}
{{- if and (.resources) (.resources.requests) (.resources.requests.cpu) }}
NAMESPACE: {{ $ns }} POD: {{ $pod }}
  Container: {{ .name }}
  Resources: {{ .resources }}
{{ end -}}
{{- end -}}
{{- end -}}
{{ end }}'
```

## 查找没有设置CPU Limits、Memory Limits、Memory Requests的Pod

```bash
kubectl get --all-namespaces pods -o go-template='
{{ range .items -}}
  {{- if eq .status.phase "Running" -}}
    {{- $pod := .metadata.name -}}
    {{- $ns := .metadata.namespace -}}
    {{- range .spec.containers }}
      {{- if or (not .resources) (not .resources.limits) (not .resources.limits.cpu) (not .resources.limits.memory) (not .resources.requests) (not .resources.requests.cpu) (not .resources.requests.memory) }}
NAMESPACE: {{ $ns }}
  POD: {{ $pod }}
  Container: {{ .name }}
        {{- if not .resources }}
  Problem: resources not set
        {{- else -}}
          {{- if not .resources.limits }}
  Problem: resources.limits not set
          {{- else if not .resources.limits.cpu }}
  Problem: resources.limits.cpu not set
          {{- else if not .resources.limits.memory }}
  Problem: resources.limits.memory not set
          {{- end -}}
          {{- if not .resources.requests }}
  Problem: resources.requests not set
          {{- else if not .resources.requests.cpu }}
  Problem: resources.requests.cpu not set
          {{- else if not .resources.requests.memory }}
  Problem: resources.requests.memory not set
          {{- end -}}
        {{- end }}
      {{ end -}}
    {{ end }}
  {{- end -}}
{{ end }}'
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

## 查找运行在某个Node上的pod

```bash
kubectl get --all-namespaces pods --field-selector=spec.nodeName=<node name>
```

