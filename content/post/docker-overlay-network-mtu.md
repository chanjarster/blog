---
title: "Docker Overlay网络的MTU"
author: "颇忒脱"
tags: ["docker"]
date: 2019-01-11T14:20:16+08:00
---

[Docker Daemon生产环境配置][docker-daemon-prod]提到了MTU设置，但是这只是针对于名为`bridge`的docker bridge network，对于overlay network是无效的。

<!--more-->

**如果docker host machine的网卡MTU为1500，则不需要此步骤**

## 设置`ingress`和`docker_gwbridge`的MTU

**以下步骤得在swarm init或join之前做**

假设你有三个机器，manager、worker-1、worker-2，准备搞一个Docker swarm集群

1) [manager] `docker swarm init`

2) [manager] 获得`docker_gwbridge`的参数，注意`Subnet`

```bash
$ docker network inspect docker_gwbridge
[
    {
        "Name": "docker_gwbridge",
        ...
        "IPAM": {
            ...
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    ...
                }
            ]
        },
        ...
    }
]
```


3) [manager] `docker swarm leave --force`

4) [manager] 停掉docker `sudo systemctl stop docker.service`

5) [manager] 删掉虚拟网卡`docker_gwbridge`

```bash
$ sudo ip link set docker_gwbridge down
$ sudo ip link del dev docker_gwbridge
```

6) [manager] 启动docker `sudo systemctl start docker.service`

7) [manager] 重建`docker_gwbridge`，

记得设置之前得到的`Subnet`参数和正确的MTU值

```bash
$ docker network rm docker_gwbridge
$ docker network create \
  --subnet 172.18.0.0/16 \
  --opt com.docker.network.bridge.name=docker_gwbridge \
  --opt com.docker.network.bridge.enable_icc=false \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  --opt com.docker.network.driver.mtu=1450 \
  docker_gwbridge
```

再到worker-1和worker-2上执行相同的命令。

8) [manager] `docker swarm init`

9) [manager] 先观察`ingress` network的参数，注意`Subnet`和`Gateway`：

```bash
$ docker network inspect ingress
[
    {
        "Name": "ingress",
        ...
        "IPAM": {
            ...
            "Config": [
                {
                    "Subnet": "10.255.0.0/16",
                    "Gateway": "10.255.0.1"
                }
            ]
        },
        ...
    }
]
```

10) [manager] 删除`ingress` network，`docker network rm ingress`。

11) [manager] 重新创建`ingress` network，记得填写之前得到的`Subnet`和`Gateway`，以及正确的MTU值：

```bash
$ docker network create \
  --driver overlay \
  --ingress \
  --subnet=10.255.0.0/16 \
  --gateway=10.255.0.1 \
  --opt com.docker.network.driver.mtu=1450 \
  ingress
```

12) [worker-1] [worker-2] join `docker swarm join ...`

**注意：新机器在join到swarm之前，得先执行第7步**

验证：

1) 启动一个swarm service，`docker service create -td --name busybox busybox`

2) 观察虚拟网卡

发现MTU都是1450：

```bash
$ ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether fa:16:3e:71:09:f5 brd ff:ff:ff:ff:ff:ff
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP mode DEFAULT group default
    link/ether 02:42:6b:de:95:71 brd ff:ff:ff:ff:ff:ff
298: docker_gwbridge: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP mode DEFAULT group default
    link/ether 02:42:ae:7b:cd:b4 brd ff:ff:ff:ff:ff:ff
309: veth7e0f9e5@if308: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker_gwbridge state UP mode DEFAULT group default
    link/ether 16:ca:8f:c7:d3:7f brd ff:ff:ff:ff:ff:ff link-netnsid 1
311: vethcb94fec@if310: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker0 state UP mode DEFAULT group default
    link/ether 9a:aa:de:7b:4f:d4 brd ff:ff:ff:ff:ff:ff link-netnsid 2
```

3) 观察容器内网卡

网卡MTU也是1450：

```bash
$ docker exec b.1.pdsdgghzyy5rhqkk5et59qa3o ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
310: eth0@if311: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
```

## 自建overlay network的MTU

### 方法一：在docker compose file设置

```yaml
...

networks:                                
  my-overlay:                               
    driver: bridge                       
    driver_opts:                         
      com.docker.network.driver.mtu: 1450
```

不过这样不好，因为这样就把docker compose file的内容和生产环境绑定了，换了个环境这个MTU值未必合适。

### 方法二：外部创建时设置

```bash
docker network create \
  -d overlay \
  --opt com.docker.network.driver.mtu=1450 \
  --attachable \
  my-overlay
```

用法：

1. 在docker compose file里这样用：
    ```yaml
    ...
    
    networks:
      app-net:
        external: true
        name: my-overlay
    ```
1. `docker run --network my-overlay ...`
1. `docker service create --network my-overlay ...`

## 参考资料

* [Use overlay networks][use-overlay-networks]
* [Docker MTU issues and solutions][docker-mtu-solutions]
* [docker network create][docker-network-create]

[docker-daemon-prod]: ../docker-daemon-prod/
[use-overlay-networks]: https://docs.docker.com/network/overlay
[docker-mtu-solutions]: https://mlohr.com/docker-mtu/
[docker-network-create]: https://docs.docker.com/engine/reference/commandline/network_create/
