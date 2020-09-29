---
title: "解决Rancher自带监控CPU和内存显示用量为实际用量的2倍的方法"
date: 2020-09-29T10:44:26+08:00
tags: ["k8s", "prometheus", "rancher"]
author: "颇忒脱"
---

<!--more-->

Rancher中启动监控后，Prometheus采集到的cpu、memory、network的指标存在重复，见这个[issue][1]，该问题在2.3.0～2.4.x中都存在。下面讲解决办法：


先设置Grafana的admin密码，进入System项目，cattle-prometheus命名空间，找到grafana-cluster-monitoring，进入其Shell：

{{< figure src="step-4.png" width="100%">}}

执行：

```bash
grafana-cli admin reset-admin-password <新密码>
```

然后随便进入一个Deployment/StatefulSets，进入Grafana：

{{< figure src="step-5.png" width="100%">}}

用admin账号和你刚才设置的密码登录进去，进入管理页面导入Dashboard：

{{< figure src="step-6.png" width="100%">}}


导入修正后的Dashboard：

  * ID 13087，[Rancher DaemonSet(fixed)][2]
  * ID 13088，[Rancher Deployment(fixed)][3]
  * ID 13089，[Rancher Pods(fixed)][4]
  * ID 13090，[Rancher StatefulSet(fixed)][5]



[1]: https://github.com/rancher/rancher/issues/24343
[2]: https://grafana.com/grafana/dashboards/13087
[3]: https://grafana.com/grafana/dashboards/13088
[4]: https://grafana.com/grafana/dashboards/13089
[5]: https://grafana.com/grafana/dashboards/13090

