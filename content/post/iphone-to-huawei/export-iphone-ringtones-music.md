---
title: "怎么导出iPhone的铃声、录音、音乐"
author: "颇忒脱"
tags: ["iphone", "华为", "苹果", "ios"]
date: 2023-09-03T10:20:58+08:00
---

<!--more-->

> 8月29日，华为 Mate60 Pro正式开售。

> 注意，本文是在 Mac 上试验的，Windows 上的我不知道怎么弄，也许思路是一样的吧

## 步骤

1）把你的 iPhone 插到 Mac 上

2）打开 Mac 上的 **音乐** 

3）选择 文件 - 资料库 - 导出资料库，随便选一个位置保存资料库 xml 文件

  * 我有点不太确定，也可能是通过 Mac 备份 iPhone 到本地（非加密）产生的了下一步的文件，都试试吧

4）导出后，打开 Finder ，进入目录 音乐 - iTunes - iTunes Media，你会看到这么几个目录：
  
  * Apple Music，你在 iPhone 上购买 / 收藏的音乐，这个这是一个清单，没有实体音乐
  * Downloads-Music，这个是你 iPhone 上下载的音乐文件
  * Music，不太清楚，可能是你上传到 iPhone 的音乐文件
  * Tones，铃声文件，是 m4r 格式的，也许华为不认，你可以网上找工具转换成 mp3 格式
  * Voice Memos，语音备忘录，也就是录音文件


## 对应的华为目录

打开华为手机的 文件管理 - 内部存储：

* 录音文件，放到 Sounds 目录下
* 通话录音文件，放到 Sounds - CallRecord 目录下
* 音乐文件，放到 Music 目录下