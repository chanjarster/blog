---
title: "K8S Node无法注册故障排查"
date: 2021-09-01T14:24:45+08:00
tags: ["k8s", "troubleshooting"]
author: "颇忒脱"
---

<!--more-->

## 现象

机房断电，通电后，K8S集群的某些Node一直处于NotReady状态。

## 查看kubelet日志

到Node上，查看Kubelet日志：

```bash
$ journalctl -u kubelet

Sep 01 09:24:20 node30 kubelet[1399]: I0901 09:24:20.953854    1399 csi_plugin.go:945] Failed to contact API server when waiting for CSINode publishing: Unauthorized
Sep 01 09:24:20 node30 kubelet[1399]: E0901 09:24:20.960125    1399 controller.go:136] failed to ensure node lease exists, will retry in 3.2s, error: Unauthorized
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.051942    1399 kubelet.go:2267] node "node30" not found
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.152071    1399 kubelet.go:2267] node "node30" not found
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.152502    1399 kubelet_node_status.go:294] Setting node annotation to enable volume controller attach/detach
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.152782    1399 setters.go:77] Using node IP: "210.45.193.149"
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.177629    1399 kubelet_node_status.go:486] Recording NodeHasSufficientMemory event message for node node30
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.177658    1399 kubelet_node_status.go:486] Recording NodeHasNoDiskPressure event message for node node30
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.177666    1399 kubelet_node_status.go:486] Recording NodeHasSufficientPID event message for node node30
Sep 01 09:24:21 node30 kubelet[1399]: I0901 09:24:21.177686    1399 kubelet_node_status.go:70] Attempting to register node node30
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.179746    1399 kubelet_node_status.go:92] Unable to register node "node30" with API server: Unauthorized
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.184238    1399 reflector.go:178] k8s.io/client-go/informers/factory.go:135: Failed to list *v1.CSIDriver: Unauthorized
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.252222    1399 kubelet.go:2267] node "node30" not found
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.340245    1399 reflector.go:178] k8s.io/kubernetes/pkg/kubelet/kubelet.go:526: Failed to list *v1.Node: Unauthorized
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.352382    1399 kubelet.go:2267] node "node30" not found
```

注意到关键日志：

```bash
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.179746    1399 kubelet_node_status.go:92] Unable to register node "node30" with API server: Unauthorized
```

意思是Node无法注册到Api Server，初步判断是这个原因导致的Node一直处于NotReady状态。

## 重启kubelet

```bash
systemctl restart kubelet
```

问题依旧。

## 查资料

查询资料，没有找到类似问题，也没有解决办法。

## 探究为何与Api Server通信被拒绝

```bash
Sep 01 09:24:21 node30 kubelet[1399]: E0901 09:24:21.179746    1399 kubelet_node_status.go:92] Unable to register node "node30" with API server: Unauthorized
```

日志的意思上看，是kubelet和Api Server通信的时候被拒绝了，拒绝原因是未授权。

那么kubelet的和Api Server的通信配置在哪里呢？

```bash
$ ps -ef | grep kubelet

/usr/local/bin/kubelet --logtostderr=true --v=2 --node-ip=... 
--hostname-override=node30 
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf 
--config=/etc/kubernetes/kubelet-config.yaml 
--kubeconfig=/etc/kubernetes/kubelet.conf 
--pod-infra-container-image=harbor.supwisdom.com/gcr-image/pause:3.2 
--runtime-cgroups=/systemd/system.slice 
--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin
```

注意到`--kubeconfig=/etc/kubernetes/kubelet.conf`，查看这个文件内容：

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: [Base64]
    server: https://localhost:6443
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    namespace: default
    user: default-auth
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users:
- name: default-auth
  user:
    client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
    client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
```

对比其他好的Node的`certificate-authority-data`字段，发现是一样的。

再对比其他好的Node的`/var/lib/kubelet/pki/kubelet-client-current.pem`，发现是不一样的，问题可能出在这个文件里。推测每个Node作为一个独立的Api Server客户端有自己独特的证书。

## 查看kubelet-client-current.pem

这个文件是一个x509证书，显然Api Server用来做客户端认证的，kubelet也是Api Server的客户端，看一下这个文件。

```bash
$ ls -l /var/lib/kubelet/pki/
-rw-------. 1 root root 1090 Nov  6  2020 kubelet-client-2020-11-06-02-48-49.pem
-rw-------. 1 root root 1090 Sep  1  2021 kubelet-client-2021-09-01-13-21-24.pem
lrwxrwxrwx. 1 root root   59 Sep  1  2021 kubelet-client-current.pem -> /var/lib/kubelet/pki/kubelet-client-2021-09-01-13-21-24.pem
-rw-r--r--. 1 root root 2279 Nov  6  2020 kubelet.crt
-rw-------. 1 root root 1679 Nov  6  2020 kubelet.key
```

发现这个文件是一个软连接，指向的是`kubelet-client-2021-09-01-13-21-24.pem`，但笔者在排查问题时的时间是9月1日早上11点左右，这个文件显然是超前了。

再查看这个文件内容：

```bash
openssl x509 -in kubelet-client-2021-09-01-13-21-24.pem -noout -text

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            [hex block]
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: Sep  1 05:11:39 2021 GMT
            Not After : Sep  1 05:11:39 2022 GMT
        Subject: O = system:nodes, CN = system:node:node30.eams.supwisdom.com
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    [hex block]
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
    Signature Algorithm: sha256WithRSAEncryption
         [hex block]
```

发现证书有效期从 2021年9月1日13:11:39 ～2022年9月1日13:11:39（GMT转换成东八区），这个是不对的。

## 解决办法

因为同目录下还有一个 `kubelet-client-2020-11-06-02-48-49.pem`，所以尝试把软连接指向这个文件，然后再启动kubelet试试。

```bash
$ rm /var/lib/kubelet/pki/kubelet-client-current.pem
$ ln -s /var/lib/kubelet/pki/kubelet-client-2020-11-06-02-48-49.pem  /var/lib/kubelet/pki/kubelet-client-current.pem
$ systemctl restart kubelet
```

问题解决，Node恢复成Ready状态。

## 后续

因为Node上的还有断电前的容器，为了把Node清理干净，把kubelet停止，删除所有容器，再启动kubelet。
