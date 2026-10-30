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

> 再次注意，本文是在 Mac 上试验的，Linux 也许可以直接用，Windows 我就不知道了。

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
   --volume $(pwd)/icloud:/home/user/iCloud \
   boredazfcuk/icloudpd \
   /bin/sh
```

3) 注意观察 `/home/user/iCloud` 这个目录的权限，
因为这个目录的卷是 host 上的目录
（注意上面的 `--volume $(pwd)/icloud:/home/user/iCloud` 参数)：

比如下面得到 `/home/user/iCloud` 目录所属用户的 `uid` 是 501、所属用户组是 `dialout`。

```shell
$ ls -l /home/user
total 4
drwx------ 1 501 dialout 480 Sep 11 13:41 iCloud
```

接下来你要定好 `uid`、`用户名`、`gid`、`用户组名` 这4个参数：

* 如果直接看到了 `uid`，说明用户不存在，那`用户名`可以定死为 `tmp_user`。
* 如果直接看到了 `gid`，说明用户组不存在，那么`用户组名`可以定死为 `tmp_group`。
* 如果看到了`用户名`，那么 `uid` 通过下面脚本得到，即使用容器系统原有的用户，下面的 `501` 就是 `uid`：

```shell
$ cat /etc/passwd | grep 用户名
用户名: x:501:20::/home/somebody:/bin/ash
```

* 如果看到了`用户组名`，那么 `gid` 通过下面脚本得到，即使用容器系统原有的用户组，下面的 `20` 就是 `gid`：

```shell
$ cat /etc/group | grep 用户组名
用户组名: x:20:root
```

把结果填写在这张表里：

| user | uid  | group | gid  |
|:----:|:----:|:-----:|:----:|
|      |      |       |      |

4) 创建脚本配置文件，你需要填写的部分是：

* `apple_id`，这个是你的 apple 账号的名称，比如手机号或者邮箱号，自行在手机的设置界面里查看
* `uesr`，填写之前确定的 `用户名`
* `user_id`，填写之前确定的`uid`
* `group`，填写之前确定的 `用户组名`
* `group_id`，填写之前确定的 `gid`

```shell
cat <<EOF > /config/icloudpd.conf
download_path=/home/user/iCloud
apple_id=
user=user
user_id=501
group=dialout
group_id=20
TZ=Asia/Shanghai
icloud_china=True
auth_china=True
authentication_type=2FA
jpeg_quality=100
delete_accompanying=False
convert_heic_to_jpeg=False
EOF
```

有两个参数可以调整：

* `convert_heic_to_jpeg=True/False`，是否把 HEIC 格式的照片转换一份为 JPEG 格式，
  * 我的华为 Mate60 Pro 支持 HEIC 格式照片，所以就无须转换了。
* `photo_album`，指定下载哪个相册
  * 这个参数不提供就是下载所有照片，下载的照片的文件夹结构是 `年/月/日`，而不是相名。
  * 如果要下载相册，则必须是这种格式的 `photo_album="相册1,相册2,相册名称带 空格 3"`

5) 初始化 iCloud cookie，这一步可能会失败，那就 `rm -rf /config/*` 然后重复此步骤

```shell
sync-icloud.sh --Initialise
```

程序运行会出现以下提示，按照提示输入，注意这是一个模拟登陆的过程，有可能会让你输入两次验证码，照输就是：

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

6) 下载 iCloud 照片

先给 `home/user/iCloud` 目录建一个文件，否则脚本不会用户组名照片：

```shell
touch /home/user/iCloud/.mounted
```

然后开始下载，过程很漫长，我8千张照片下载了10个小时：

```shell
sync-icloud.sh
```

7) 整理目录结构

因为下载的照片目录结构是按照年月日分级的：

```shell
.
├── 2021
└── 2022
    ├── 09
    │   ├── 11
    │   └── 12
    └── 10
        ├── 01
        └── 28
```

想办法扁平化一些，比如就按照年份来。

那就先按照年份创建一套新目录，比如：

```shell
mkdir -p flat/2021 flat/2022
```

按照年份把一个一个照片复制过去：

```shell
export yr=2021; find $yr -type f -not -name '.DS_Store' | xargs -n1 -I{} cp {} flat/$yr/
```

之后所有文件都在 `flat` 目录下，且目录结构如下：

```shell
flat
  ├── 2019
  ├── 2021
  ├── 2022
  └── 2023
```

注意，不过这样做有风险，因为 iCloud 上的照片可能重名，会导致丢失文件，通过下面命令检查一下扁平化前后文件数量是否一致：

```shell
# 扁平化之前的文件数量
export yr=2021; find $yr -type f -not -name '.DS_Store' | wc -l
# 扁平化之后的文件数量
export yr=2021; find flat/$yr -type f -not -name '.DS_Store' | wc -l
```

8) 使用在 Mac 上安装华为手机助手，把导出的照片上传到华为手机上的 `Pictures` 目录，有 4 个坑：

* Mac 上的华为手机助手无法直接上传目录
* Mac 上的华为手机助手照片传了千把张之后，就再也无法传上去了，提示失败
* 你得找一个真 USB 3.2/3.1 的数据线，否则传输速度很慢（也许是 USB 2.0 的速度，我8千张照片+视频传了5个小时）
* 你可以通过网络上传，毕竟比 USB 2.0 的速度快多了，但是：
  * 在华为手机上开启 华为分享-共享至电脑，然后 Mac 打开 Finder - 网络，通过 SMB 协议访问华为手机是不行的
  * 但是，在 Mac 上 系统偏好设置 - 共享 -  文件共享 - 选项 - 使用 SMB 共享，然后华为手机 文件管理 - 网络邻居 访问 Mac 是可以的

## 如何清理

如果你想重新来过，在宿主机上执行以下命令：

```shell
docker rm -f icloudpd
docker volume rm icloudpd_config
rm -rf icloud/*
```

[icloudpd]: https://github.com/boredazfcuk/docker-icloudpd/blob/master/CONFIGURATION.md