---
title: "netstat实用脚本"
author: "颇忒脱"
tags: ["linux", "cheatsheet"]
date: 2021-09-07T11:33:22+08:00
---

<!--more-->

## 根据连接状态分类统计

```bash
$ netstat -antpl | gawk -F' ' '{ print $6 }' | sort | uniq -c
      1 established)
      5 ESTABLISHED
      1 Foreign
      4 LISTEN
      2 TIME_WAIT
```

