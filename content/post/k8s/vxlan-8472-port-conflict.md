---
title: "记一次K8S VXLAN Overlay网络8472端口冲突问题的排查"
date: 2020-11-10T08:49:44+08:00
tags: ["k8s", "rancher", "troubleshooting"]
author: "颇忒脱"
---

<!--more-->

## 环境

服务器：172.17.17.20-22 三个服务器 （深信服aCloud虚拟化平台）

操作系统版本：CentOS 7.8

内核版本：3.10

## 现象

在20-22三台上安装K8S集群（通过rancher的rke安装），安装完毕后，发现访问各个节点的80端口，只有20服务器能够正常返回，其余的都是Gateway Timeout。使用[Rancher的提供的这个办法][1]得知Overlay网络不通。

## 排查过程

### 排查网络通性
根据[Rancher文档上提到的][2]，Host的8472/udp端口是Flannel/Calico的VXLAN Overlay网络专用端口，即所有跨Host的容器间网络通信都走这个端口。因此：

在172.17.17.22上，用tcpdump抓发出的包：

```bash
tcpdump -nn 'udp and src host 172.17.17.22 and dst port 8472'
```

另开一个22的终端，执行 `curl http://localhost` 能够看到 22->20 的UDP包，见下图：

<img src="tcpdump-1.jpg" style="zoom:50%"/>

在172.17.17.20上，用tcpdump抓收到的包：

```bash
tcpdump -nn 'udp and src host 172.17.17.22 and dst port 8472'
```

结果是没有抓到任何包。

### 排查虚拟机网络安全组

合理怀疑虚拟机网络安全组没有放开8472/udp端口的访问权限，在22上使用netcat发送数据：

```bash
nc -u 172.17.17.20 8472
```

随便打点字回车传输，如下图：

<img src="tcpdump-2.jpg" style="zoom:50%"/>

结果在20上能够抓到收到的包：

<img src="tcpdump-3.jpg" style="zoom:50%"/>

这说明网络安全组并没有阻拦8472/udp端口的访问。

## 初步假设

怀疑这些数据在深信服aCloud虚拟化平台的网络中被过滤掉了。基于以下理由：

1. k8s使用的是基于VXLAN的Overlay network，VNI=1，并且是基于UDP协议。而深信服aCloud高概率也使用VXLAN做Overlay网络。
1. 普通的udp协议数据传输tcpdump能够抓到包（见前面）
1. tcpdump在网络栈中的位置inbound在iptables之前，outbound在iptables之后（[资料][3]）。如果tcpdump能够抓到发出的包，那么说明是真的发出了。如果inbound没有抓到接受的包，那么就说明这个包没有到达网卡。

## 解决办法

和深信服的同学沟通后，其确认是物理机也是用了8472/udp端口做Overlay网络，两者冲突了，因此当UDP包内包含了OTV数据内容后，先一步被aCloud拦截，结果就是虚拟机的8472/udp端口收不到数据。

将物理机的8472/udp端口改掉后，问题解决。

PS. 8472/udp还是一个[著名端口][4]

## 解决办法2

也可以在rke创建k8s集群的时候修改flannel的端口，需要修改cluster.yml（[参考文档][5]）。

如果你用的是canal网络插件（默认）：

```yaml
...
network:
  plugin: canal
  options:
    canal_flannel_backend_type: vxlan
    canal_flannel_backend_port: "8872"
  ...
```

如果用的是flannel网络插件：

```yaml
...
network:
  plugin: flannel
  options:
    flannel_backend_type: vxlan
    flannel_backend_port: "8872"
  ...
```



在Rancher中创建自定义集群的时候，需要自定义集群参数来修改端口（[参考文档][6]）。

如果用的是canal网络插件（默认）：

```yaml
rancher_kubernetes_engine_config:
  ...
  network:
    options:
      flannel_backend_type: vxlan
      flannel_backend_port: "8872"
    plugin: canal
```

如果用的是flannel网络插件：

```yaml
rancher_kubernetes_engine_config:
  ...
  network:
    options:
      flannel_backend_type: vxlan
      flannel_backend_port: "8872"
    plugin: flannel
```



[1]: https://docs.rancher.cn/docs/rancher2/troubleshooting/networking/_index/#%E6%A3%80%E6%9F%A5-overlay-%E7%BD%91%E7%BB%9C%E6%98%AF%E5%90%A6%E6%AD%A3%E5%B8%B8%E8%BF%90%E8%A1%8C
[2]: https://docs.rancher.cn/docs/rancher2/installation/requirements/ports/_index
[3]: https://superuser.com/a/925332/1239120
[4]: https://www.speedguide.net/port.php?port=8472
[5]: https://docs.rancher.cn/docs/rke/config-options/add-ons/network-plugins/_index#canal-%E6%8F%92%E4%BB%B6%E9%80%89%E9%A1%B9
[6]: https://docs.rancher.cn/docs/rancher2/cluster-provisioning/rke-clusters/options/_index