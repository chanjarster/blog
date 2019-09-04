---
title: "Interview Skills - Thread and Locks"
author: "颇忒脱"
tags: ["interview"]
date: 2019-09-02T20:40:46+08:00
---

<!--more-->

## Deadlocks and Deadlock Prevention

In order for a deadlock to occur, you must have all four of the following conditions met:

1. MutualExclusion:Onlyoneprocesscanaccessaresourceatagiventime.(Or, more accurately, there is limited access to a resource. A deadlock could also occur if a resource has limited quantity.)
2. Hold and Wait: Processes already holding a resource can request additional resources, without relinquishing their current resources.
3. No Preemption: One process cannot forcibly remove another process' resource.
4. Circular Wait: Two or more processes form a circular chain where each process is waiting on another resource in the chain.

Deadlock prevention entails removing any of the above conditions.

大部分方法都专注在解决第四点。