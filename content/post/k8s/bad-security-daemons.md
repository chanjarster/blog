---
title: "可能引起 K8S 集群故障的安全软件"
date: 2022-11-21T09:24:45+08:00
tags: ["k8s", "troubleshooting"]
author: "颇忒脱"
---

<!--more-->


* `ds_agent`
* `qaxsafed`，奇安信，查下 qax 看看有没有其他的
* `secdog`，也查下 dog 和 sec
* `sangfor_watchdog`，这个不影响，但是有它基本是深信服的虚拟化环境，会和flannel的8472端口冲突，见[这篇文章][2]
* `YDservice`
* `Symantec`
* `start360su_safed`，推荐 ps aux | grep safe 先查下，再查 360 字样
* `gov_defence_service`
* `gov_defence_guard` 
* `wsssr_defence_daemon`，奇安信服务器安全加固系统，和下面是一起的。目前遇到过影响 socat 运行和容器进程访问另一个机器上的mysql端口
* `wsssr_defence_service`
* `wsssr_defence_agent`，影响pod网络
* `ics_agent`
  * `/opt/nubosh/vmsec-host/intedrity/bin/icsintedrity`，docker -p 的都无法访问
  * `/opt/nubosh/vmsec-host/file/bin/icsfilesec`
* `edr_sec_plan`，深信服的 edr ，这个会下发 iptables 规则，配置错了会影响 node 之间，以及 pod 和 pod 之间通信
* `titanagent`，青藤云安全软件


[参考资料][1]

[1]: https://p.wpseco.cn/wiki/doc/621f2dfef6368a2f9e5c9903
[2]: https://p.wpseco.cn/wiki/doc/626a0269352c70b82e6ac9fa

