---
title: "启用IPVS的K8S集群无法从Pod经外部访问自己的排障"
author: "颇忒脱"
tags: ["k8s"]
date: 2019-10-21T08:52:21+08:00
---

阿里云上的启用IPVS的K8S集群，无法从Pod经外部访问自己的排障流水账。

<!--more-->

问题描述：

* 阿里云上的托管版K8S集群（下面简称ACK），启用了IPVS
* 集群中有两个应用Foo和Bar，Bar使用Ingress暴露外网地址，bar.xxx.com
* Foo应用无法访问 bar.xxx.com ，得到的错误是 Connection refused 

## 初步排障

### 在集群外部测试

curl http://bar.xx.com 能够返回结果

ping bar.xxx.com，能够ping通：

```txt
PING xxx.bar.com (<SLB-IP>): 56 data bytes
64 bytes from <SLB-IP>: icmp_seq=0 ttl=91 time=3.091 ms
64 bytes from <SLB-IP>: icmp_seq=1 ttl=91 time=3.212 ms
64 bytes from <SLB-IP>: icmp_seq=2 ttl=91 time=3.267 ms
```

注意：

* 解析得到的IP是ACK创建时自动创建的SLB实例的公网IP。

  

### 在集群内部测试

在K8S集群中启动一个临时Pod，nicolaka/netshoot

curl http://bar.xxx.com 

得到错误：`curl: (7) Failed to connect to bar.xxx.com port 80: Connection refused`

ping bar.xxx.com，能够ping通，得到结果

```txt
PING xxx.bar.com (<SLB-IP>) 56(84) bytes of data.
64 bytes from nginx-ingress-lb.kube-system.svc.cluster.local (<SLB-IP>): icmp_seq=1 ttl=64 time=0.035 ms
64 bytes from nginx-ingress-lb.kube-system.svc.cluster.local (<SLB-IP>): icmp_seq=2 ttl=64 time=0.036 ms
```

注意：

* 得到的IP同样是SLB实例的公网IP
* 解析得到名字是Ingress Controller在集群内部的SVC的DNS Name。

用tcpdump抓包：

tcpdump -nn host bar.xxx.com，得到 port 80 unreachable的结果

```txt
02:23:25.524028 IP 172.20.1.88.57138 > <SLB-IP>.80: Flags [S], seq 1634983746, win 29200, options [mss 1460,sackOK,TS val 3961214492 ecr 0,nop,wscale 9], length 0
02:23:25.525043 IP <SLB-IP> > 172.20.1.88: ICMP 139.224.167.163 tcp port 80 unreachable, length 68
```

## 和阿里同学沟通

建了工单描述了情况，得到的反馈如下：

Ingress Controller Service的externalTrafficPolicy这个为Local（ACK初始化的默认值）的时候跨节点访问SVC SLB地址就是不行，这个和Nginx Ingress Controller没有关系。**这个行为在ipvs和kube-proxy实现的service集群上行为是一致的**，如果之前是好的，现在不行了，只有一种可能，就是之前访问Ingress入口Url的Pod和两个Nginx Ingress Controller Pod在一个节点上。建议把externalTrafficPolicy改成Cluster。

## 解决办法

把externalTrafficPolicy改成Cluster之后的确解决了这个问题。

不过[K8S文档][k8s-doc]里说到如果这样设置，那么Pod就得不到客户端的源IP了，要得到客户端源IP只能设置为Local，但是Local又有无法访问的问题。

阿里的同学说到过：

> 如果之前是好的，现在不行了，只有一种可能，就是之前访问Ingress入口Url的Pod和两个Nginx Ingress Controller Pod在一个节点上

就是说如果发起请求的Pod和Ingress Controller的Pod在同一个节点上的话，访问是没有问题的。我实验了一下果然如此。

于是我**把Ingress Controller从Deployment改成DaemonSet**，让每个节点上都跑一个Ingress Controller Pod，于是问题解决。

## 其他资料

关于这个问题又找了一些资料，不过看不太明白：

* [[从service的externalTrafficPolicy到podAntiAffinity](https://segmentfault.com/a/1190000016033076)][art-1]
* [访问 externalTrafficPolicy 为 Local 的 Service 对应 LB 有时超时][art-2]

另外注意到，用Rancher部署的K8S集群的Ingress Controller都是DaemonSet的。




[k8s-doc]: https://kubernetes.io/zh/docs/tutorials/services/source-ip/
[art-1]: https://segmentfault.com/a/1190000016033076#articleHeader2
[art-2]: https://imroc.io/posts/kubernetes/troubleshooting-with-kubernetes-network/#%E8%AE%BF%E9%97%AE-externaltrafficpolicy-%E4%B8%BA-local-%E7%9A%84-service-%E5%AF%B9%E5%BA%94-lb-%E6%9C%89%E6%97%B6%E8%B6%85%E6%97%B6