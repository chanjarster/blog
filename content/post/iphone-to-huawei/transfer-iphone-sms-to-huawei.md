---
title: "迁移iPhone手机短信到华为手机"
author: "颇忒脱"
tags: ["iphone", "华为", "苹果", "ios"]
date: 2019-10-04T14:29:58+08:00
---

如何将Iphone的短信迁移到华为手机的方法。

<!--more-->

传统的办法是使用[isms2droid][isms2droid]，但是在写本文时[isms2droid][isms2droid]无法使用，可能与谷歌禁止华为安装谷歌服务有关。因此采用了另一种方法。

注意：本文中提到的有些网站需要梯子才可以访问。

## 第一步

还是按照[isms2droid][isms2droid]的方法，提取到`3d0d7e5fb2ce288813306e4d4636395e047a3d28`文件，一定要注意，在备份Iphone到本机到时候不要加密备份。

1. iPhone 连到电脑，采用**非加密**备份。
2. 到（Windows）`C:\Users[YourUsername]\AppData\Roaming\Apple Computer\MobileSync\Backup\` 
或者（OS X）`~/Library/Application Support/MobileSync/Backup/` （你得在 Finder 中使用 `Cmd + Shift + G` 打开 `前往文件夹` 才能进入该目录）
搜索对应文件。
3. 找到 `3d0d7e5fb2ce288813306e4d4636395e047a3d28` 文件复制出来。

## 第二步

其实`3d0d7e5fb2ce288813306e4d4636395e047a3d28`就是一个SQLite3的dump文件，因此可以导入它然后将其输出成“SMS Backup and Restore”的xml格式文件。

本文采用的是[这篇文章][article]所提供的php脚本，不过它的脚本存在一些bug，导出的短信时间存在问题（这个问题在[这篇文章][article2]里也有提到过）。因此我作了一些修改，代码在[gist][gist]。

也可以直接复制这里的：

```php
#!/usr/bin/php5
<?php

if (count($argv) <> 2) {
    print "Usage: ".$argv[0]." iPhone-SMS-DB (Usually 3d0d7e5fb2ce288813306e4d4636395e047a3d28.*)\n";
    exit -1;
}

$DBfile = $argv[1];

if (! is_readable($DBfile)) {
    print "File $DBfile is not readable!\n";
    exit -2;
}

try {
    $sqlite = new SQLite3($DBfile);
} catch (Exception $exception) {
    echo '<p>There was an error connecting to the database!</p>';
    echo $exception->getMessage();
    exit -3;
}

$query  = "
    SELECT datetime(message.date / 1000000000, 'unixepoch', '+31 years') AS Datum, 
	   CAST(strftime('%s', datetime(message.date / 1000000000, 'unixepoch', '+31 years')) AS INT) * 1000 AS Date,
     message.is_from_me, 
	   handle.id AS Contact, 
	   message.text,
	   message.service
    FROM message, handle 
    WHERE message.handle_id = handle.ROWID;
";

$sqliteResult = $sqlite->query($query);
if (!$sqliteResult) {
    // the query failed and debugging is enabled
    echo "There was an error in query: $query\n";
    echo $sqlite->lastErrorMsg();
    exit -4;
}


$smses = array();
while ($record = $sqliteResult->fetchArray()) {
    $sms = array();
    $sms['Datum'] = $record['Datum'];
    $sms['Date'] = $record['Date'];
    $sms['is_from_me'] = $record['is_from_me'];
    $sms['Contact'] = $record['Contact'];
    $sms['text'] = $record['text'];
    $sms['service'] = $record['service'];
    $smses[] = $sms;
}

$sqliteResult->finalize();
$sqlite->close();

print "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\n";
print "<?xml-stylesheet type='text/xsl' href='sms.xsl'?>\n";
print "<smses count=\"".count($smses)."\">\n";
foreach ($smses as $key => $sms) {
    $body = $sms['text'];
    $body = str_replace('&', '&amp;', $body);
    $body = str_replace('"', '&quot;', $body);
    $body = str_replace("\n", '&#10;', $body);
    print '  <sms ';
    print 'address="';
    print $sms['Contact'];
    print '" date="';
    print $sms['Date'];
    print '" type="';
    print ++$sms['is_from_me'];
    print '" body="';
    print $body;
    print '" readable_date="';
    print $sms['Datum'];
    print '" service="';
    print $sms['service'];
    print '" />';
    print "\n";
}
print "</smses>\n";
```

执行：

```shell
php iphone-sms-xml.php 3d0d7e5fb2ce288813306e4d4636395e047a3d28 > sms.xml
```

得到sms.xml文件。

## 第三步

在你的华为手机上安装“SMS Backup and Restore”，需要注意的是这个软件在华为应用市场上是找不到的，你需要自行找一个地方下载APK文件安装。我是在[这个网站][download]下载到的。

## 第四步

把前面的sms.xml传到你的手机上，然后运行“SMS Backup and Restore”恢复短信。

恢复过程中会提示你把 “SMS Backup and Restore” 作为默认短信应用，照做就是。

恢复完成后，打开系统自带的短信，把它设置会默认短信应用即可。

大功告成！

[isms2droid]: https://isms2droid.com
[article]: https://www.kolmann.at/2017/05/export-iphone-messages-to-xml/
[gist]: https://gist.github.com/chanjarster/ff93d2bb65a64eb438b35a5cf946d6ec
[article2]: https://github.com/HenryYang/Blog/blob/37ffbab84be093434ec575df49042268b7e1644a/content/posts/ios_sms_to_android.md
[download]: https://sms-backup-and-restore.en.uptodown.com/android