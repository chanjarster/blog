---
title: "迁移Iphone手机短信到华为手机"
author: "颇忒脱"
tags: ["数码"]
date: 2019-10-04T14:29:58+08:00
---

如何将Iphone的短信迁移到华为手机的方法。

<!--more-->

传统的办法是使用[isms2droid][isms2droid]，但是在写本文时[isms2droid][isms2droid]无法使用，可能与谷歌禁止华为安装谷歌服务有关。因此采用了另一种方法。

注意：本文中提到的有些网站需要梯子才可以访问。

## 第一步

还是按照[isms2droid][isms2droid]的方法，提取到`3d0d7e5fb2ce288813306e4d4636395e047a3d28`文件，一定要注意，在备份Iphone到本机到时候不要加密备份。

## 第二步

其实`3d0d7e5fb2ce288813306e4d4636395e047a3d28`就是一个SQLite3的dump文件，因此可以导入它然后将其输出成“SMS Backup and Restore”的xml格式文件。

本文采用的是[这篇文章][article]所提供的php脚本，不过它的脚本存在一些bug，导出的短信时间存在问题（这个问题在[这篇文章][article2]里也有提到过）。因此我作了一些修改，代码在[gist][gist]。

执行：

```bash
php iphone-sms-xml.php 3d0d7e5fb2ce288813306e4d4636395e047a3d28 > sms.xml
```

得到sms.xml文件。

## 第三步

在你的华为手机上安装“SMS Backup and Restore”，需要注意的是这个软件在华为应用市场上是找不到的，你需要自行找一个地方下载APK文件安装。我是在[这个网站][download]下载到的。

## 第四步

把前面的sms.xml传到你的手机上，然后运行“SMS Backup and Restore”恢复短信，大功告成。

[isms2droid]: https://isms2droid.com
[article]: https://www.kolmann.at/2017/05/export-iphone-messages-to-xml/
[gist]: https://gist.github.com/chanjarster/ff93d2bb65a64eb438b35a5cf946d6ec
[article2]: https://github.com/HenryYang/Blog/blob/37ffbab84be093434ec575df49042268b7e1644a/content/posts/ios_sms_to_android.md
[download]: https://sms-backup-and-restore.en.uptodown.com/android