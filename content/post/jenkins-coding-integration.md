---
title: "Coding集成Jenkins流水账"
author: "颇忒脱"
tags: ["CI/CD", "Jenkins"]
date: 2018-11-29T13:06:05+08:00
---

Coding集成Jenkins流水账。

<!--more-->

本文有以下假设和要求：

1. 你的项目源代码的根目录已经存在Jenkinsfile
1. 你的项目是一个Maven项目
1. 你的Jenkins能够从公网访问

本文参考自官方文档[使用Jenkins构建Coding项目](https://open.coding.net/ci/jenkins/)

# 【Jenkins】新建文件夹

![](1-new-folder-1.png)![](1-new-folder-2.png)![](1-new-folder-3.png)

# 【Jenkins】配置SSH key pair

运行下列命令生成SSH key pair，生成两个文件`deploykey`和`deploykey.pub`：

```bash
ssh-keygen -f deploykey
```

进入刚刚创建的文件夹，按下图添加SSH Username with private key凭据：

![](2-ssh-key-1.png)
![](2-ssh-key-2.png)

把`deploykey`的内容贴到下面这个页面里：
![](2-ssh-key-3.png)

把`deploykey.pub`的内容贴到Coding项目的部署公钥里：
![](2-ssh-key-4.png)

# 【Jenkins】配置Maven settings.xml

根据[创建Jenkins Pipeline流水账 - 配置Maven settings.xml](../jenkins-pipeline/#配置maven-settings-xml)操作

# 【Coding】创建个人访问令牌

![](3-personal-token-1.png)![](3-personal-token-2.png)

把令牌复制下来，注意这个页面是你能够复制令牌的唯一一次机会，如果把这个页面关了，那只能重新创建令牌了：
![](3-personal-token-3.png)

# 【Jenkins】新建流水线

到刚才创建的文件夹里创建流水线：

![](4-new-pipeline-1.png)
![](4-new-pipeline-2.png)

做这么几件事情：

1. 把Webhook地址复制下来
2. 设置Webhook令牌，这个相当于密码，你自己随便输。
3. 把之前创建的个人访问令牌贴到【访问令牌】输入框。
4. 然后按照下图方式配置。
![](5-config-pipeline-1.png)

点击下图所示问号能看到以下帮助文档，注意我们是私有项目看红框内容：
![](5-config-pipeline-2.png)

在Pipeline部分配置仓库：

1. Credential使用之前创建的SSH key
2. Name和Refspec是根据前面帮助文档里要求的填写的
![](5-config-pipeline-3.png)

在Branches to build里添加两项：

1. `refs/remotes/origin/*`
2. `refs/remotes/origin/merge/*`

其实这两个值是帮助文档里提到的而来，注意两个refspec里冒号后面的部分：

> 如果是私有项目, 设置 refspec 为 `+refs/heads/*:refs/remotes/origin/* +refs/merge/*/MERGE:refs/remotes/origin/merge/*`
![](5-config-pipeline-4.png)

添加两个Additional Behaviours：
![](5-config-pipeline-5.png)

去掉Lightweight checkout的勾：
![](5-config-pipeline-6.png)

在Pipeline Maven Configuration部分选择刚才创建的Maven settings.xml：

![](../jenkins-pipeline/config-pipeline-4.png)

# 【Coding】配置Webhook

到项目的 设置 -> WebHook 页面，添加Webhook：

![](6-coding-webhook-1.png)

按下图配置：
![](6-coding-webhook-2.png)

# 效果

至此大功告成。

你可以通过提交commit的方式触发Jenkins构建，然后可以在项目的这个页面看到构建结果：

![](7-final-1.png)![](7-final-2.png)

你也可以创建合并请求，Coding会触发Jenkins构建并且把构建结果添加到合并请求里：
![](7-final-3.png)
