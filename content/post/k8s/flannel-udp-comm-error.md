---
title: "Flannel VXLAN 通信异常问题排障记录"
author: "颇忒脱"
tags: ["k8s", "troubleshooting", "network"]
date: 2022-11-18T13:32:21+08:00
---

<!--more-->

## 现象

rancher 所在 k8s 集群（local 集群）间歇性挂，而其纳管的另一个生产 k8s 集群没有这个问题。

rancher 的 3 台服务器 rancher1（172.16.1.194）、rancher2（172.16.1.195）、rancher3（172.22.1.199）

注意到 rancher3 和 rancher1/2 不在一个网段。

## 排查

经过排查发现以下几个现象：

1) 浏览器不访问 rancher 没有事，访问一会儿就挂。

2) 挂的时候 etcd 集群不健康，存在 leader 丢失 ，节点间通信异常，查询响应缓慢（100ms～20s）

```shell
docker logs --tail 500 -f etcd
```

3) 挂的时候，tcpdump etcd 2380 端口，发现大量连接重置错误

```shell
docker logs --tail 500 -f etcd
```


4) 挂的时候，ping rancher2->rancher3 正常，但是 rancher3->rancher2 不正常。

5) 挂的时候，traceroute rancher2->rancher3 正常，但是 rancher3->rancher2 不正常。

6) 挂的时候，rancher3 同子网其他机器 ping rancher2 正常。

7) 挂的时候，rancher1/2 etcd cluster-health 看到rancher3 unhealthy，

rancher3 etcd cluster-health 看到 rancher1/2 dial 不通，然后看到自己 unhealthy。

恢复的时候，和 ping 一样，rancher 1/2 看到 rancher3 healthy，但是 rancher3 看到的问题依旧。

```shell
etcdctl \
  --cert-file /etc/kubernetes/ssl/kube-etcd-<ip>.pem \
  --key-file /etc/kubernetes/ssl/kube-etcd-<ip>-key.pem \
  --ca-file /etc/kubernetes/ssl/kube-ca.pem \
  --endpoint https://localhost:2379 \
  cluster-health
```

7.1）重装了 rancher3 操作系统，问题依旧

7.2）修改集群模式，当只有 rancher3 一个节点，没有什么问题

7.3）修改集群模式，rancher3 作为 master，rancher1/2 作为 worker，问题依旧

8）分别在 rancher1 和 3 上抓 flannel 8472 端口的包：

```
tcpdump -i ens160 -nn 'udp and port 8472' -w udp.pcap
```

然后用 wireshark 分析，发现 rancher3 上有时间跨度 90s 的包收发，rancher1 上只有 33s 的包收发，说明传输过程中数据丢失了。

flannel 用的是 UDP 协议，而传输问题出在 UDP 协议上，那么可以推测数据包超过某个大小时，故障就会发生。

9）测试 UDP 传输

在 rancher1 上启动 nc 监听 UDP 端口

```shell
nc -u -l -p 8888
```

在 rancher3 上同样用 nc 传输数据，经过测试发现，1472 字节是单次传输的最大尺寸了，超过这个尺寸 rancher1 就收不到了。

```shell
nc -u rancher1 8888 < 1473.log
```

而在 rancher2 上，传输一个 10M 的文件都没有问题。

注意：nc 在做过一次传输之后，服务端要重启，因为 nc 一次只能接收一个连接，要关掉重开才行。

10）虽然测出了超出 1472 字节的 UDP 数据传不过去，但是这时 rancher3 ping rancher1 依然是通的。

推测和流量有关，必须 UDP 流量达到一定程度，才会阻断 rancher3 -> rancher1 的所有通信。

在 rancher1 上启动 iperf3 服务端：

```shell
iperf3 -s
```

在 rancher3 上启动 iperf3 压测（流量 22100Kbit/sec）

```shell
iperf3 -c rancher1 -u -b 22100K
```

然后 rancher3 -> rancher1 就不通了，ping 也不通。

另外发现，rancher3 -> rancher1 ping 不通的时候，ping rancher2 也不同，实际上是阻断了 rancher3 -> 172.16.1.0/24 网段的所有流量。

## 结论

还是网络问题，UDP 流量稍大点的时候，某个触发了某个网络设备限流策略。