---
title: "Redis Cluster设计学习总结"
author: "颇忒脱"
tags: ["redis", "分布式算法"]
date: 2019-07-12T09:02:19+08:00
draft: false
---

<!--more-->

## 概览

<img src="overview.png" style="zoom:50%" />

## 设计思路探究

用一系列问题和回答来探究Redis Cluster的设计思路，下图中绿色的是问题，蓝色的是回答，实现箭头代表由这个回答引申出新的问题，虚线尖头是两个回答之间存在关联。

<img src="q-and-a.png" style="zoom:50%" />