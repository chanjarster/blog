---
title: "批量导出 iCloud 照片到本地"
author: "颇忒脱"
tags: ["iphone", "华为", "苹果", "ios"]
date: 2023-09-01T14:20:58+08:00
---

阻止 iPhone 用户切换到华为用户的最大障碍就是 iCloud 上的照片无法导出。

<!--more-->

> 8月29日，华为 Mate60 Pro正式开售。

本文讲解怎么在 OS X 上使用 [boredazfcuk/icloudpd][icloudpd] 把 iCloud 的照片全部导出，再配合 [迁移iPhone手机短信到华为手机](../transfer-iphone-sms-to-huawei/)，可以让你无痛切换到华为手机。

## 步骤

1) 先随便进入到一个目录，新建 icloud 目录

```shell
# 1 先随便进入到一个目录，新建 icloud 目录
mkdir icloud
chmod 777 icloud
```

2) 创建 Docker 容器，并进入容器，之后的步骤都在容器内执行

```shell
docker network create \
   --driver=bridge \
   --subnet=192.168.115.0/24 \
   --gateway=192.168.115.254 \
   --opt com.docker.network.bridge.name=icloudpd_br0 \
   icloudpd_bridge

docker run -it \
   --name icloudpd \
   --hostname icloudpd_boredazfcuk \
   --network icloudpd_bridge \
   --restart=always \
   --env TZ=Asia/Shanghai \
   --volume icloudpd_config:/config \
   --volume $(pwd)/icloud:/home/qianjia/iCloud \
   boredazfcuk/icloudpd \
   /bin/sh
```

3) 创建配置文件，注意 `apple_id` 参数，这个需要你自己填写

```shell
cat <<EOF > /config/icloudpd.conf
download_path=/home/user/iCloud
user=user
apple_id=
TZ=Asia/Shanghai
icloud_china=True
auth_china=True
authentication_type=2FA
convert_heic_to_jpeg=True
jpeg_quality=100
delete_accompanying=False
EOF
```

4) 初始化 iCloud cookie，这一步可能会失败，那就 `rm -rf /config/*` 然后重复此步骤

```shell
sync-icloud.sh --Initialise
```

程序运行会出现以下提示，按照提示输入

```shell
Enter iCloud password for xxxx: 输入 apple 账号密码 <回车>
Save password in keyring? [y/N]: 输入 y <回车>
Two-factor authentication required.
Enter the code you received of one of your approved devices: 输入验证码 <回车>
Code validation result: True
```

出现以下提示则说明获取 cookie 成功

```
2023-09-01 14:23:18 INFO     Two factor authentication cookie generated. Sync should now be successful
2023-09-01 14:23:18 INFO     Container initialisation complete
```

5) 下载 iCloud 照片

```shell
touch /home/user/iCloud/.mounted
sync-icloud.sh
```

6) 使用华为手机助手，把导出的照片导入到华为手机。

## 清理

如果你想重新来过，则可以：

```shell
docker rm -f icloudpd
docker volume rm icloudpd_config
rm -rf icloud/*
```

[icloudpd]: https://github.com/boredazfcuk/docker-icloudpd/blob/master/CONFIGURATION.md