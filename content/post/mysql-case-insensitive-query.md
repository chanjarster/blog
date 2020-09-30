---
title: "Mysql字符串字段查询默认大小写不敏感"
date: 2020-09-30T10:57:31+08:00
tags: ["mysql"]
author: "颇忒脱"
---

<!--more-->

MySQL默认对于字符串类型字段的查询大小写不敏感，比如字段值为`ABC`，你查询`WHERE COL='abc' `也能够查询到。

MySQL的这个行为大多数情况下问题不大，这个行为对于查询来说是很便利的，比如你可以直接`LIKE 'a%' `就能够查询到`ABC`。

但是要注意，如果你有一个UNIQUE的字段，那么在插入`A0001`和`a0001`的时候，会告诉你违反唯一约束。

如果你的UNIQUE字段在业务上需要通过大小写来区分，那么你需要在建表时给字段添加上`CHARACTER SET utf8 COLLATE utf8_bin NOT NULL UNIQUE`，比如：

```sql
CREATE TABLE WORDS (
    WORD VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL UNIQUE, 
);
```

如果你的UNIQUE字段在业务上不需要/不应该通过大小写来区分，那么就什么都不需要做，因为在这种业务下，`a0001`可以认为是一种错误数据。

参考资料：

https://stackoverflow.com/questions/6448825/sql-unique-varchar-case-sensitivity-question