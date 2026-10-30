---
title: "QoderCN 切换账号后迁移会话历史"
author: "颇忒脱"
tags: ["qoder", "agent"]
date: 2026-10-28T21:55:10+08:00
---

<!--more-->
## 背景

QoderCN 的会话历史存储在本地 SQLite 数据库中，与用户账号绑定。当需要切换账号但保留会话历史时，需要手动修改数据库中的用户信息。

## 数据库位置

```
~/Library/Application Support/QoderCN/SharedClientCache/cache/db/local.db
```

## 操作步骤

### 1. 关闭 QoderCN

确保 QoderCN 应用已完全关闭，避免数据库被占用。

### 2. 查看当前用户信息

使用 SQLite 工具打开数据库，查询当前的用户信息：

```bash
sqlite3 ~/Library/Application\ Support/QoderCN/SharedClientCache/cache/db/local.db
```

在 SQLite 命令行中执行：

```sql
SELECT DISTINCT user_id, user_name FROM chat_session;
```

### 3. 确定迁移方向

假设需要在以下两个账号之间切换：

| 账号 | user_id | user_name |
|------|---------|-----------|
| 账号 A | 01a084c7-xxx-xxx-xxx-f7caxxcc10f | foo |
| 账号 B | 019f92a6-xxx-xxx-xxx-fdc2xxx1e89 | bar |

### 4. 执行迁移 SQL

将账号 A 的会话迁移给账号 B

```sql
UPDATE chat_session 
SET user_id='<帐号B user_id>', 
    user_name='<帐号B user_name>' 
WHERE user_name='<帐号A user_name>';
```


### 5. 验证迁移结果

```sql
SELECT DISTINCT user_id, user_name FROM chat_session;
```

确认用户信息已正确更新后，退出 SQLite：

```sql
.quit
```

### 6. 重新启动 QoderCN

打开 QoderCN，使用目标账号登录，检查会话历史是否已正确迁移。

## 注意事项

1. **备份数据库**：操作前建议备份 `local.db` 文件，防止误操作
   ```bash
   cp ~/Library/Application\ Support/QoderCN/SharedClientCache/cache/db/local.db \
      ~/Library/Application\ Support/QoderCN/SharedClientCache/cache/db/local.db.backup
   ```

2. **完全关闭应用**：确保 QoderCN 已完全退出（包括后台进程），否则数据库可能被锁定

3. **用户 ID 格式**：`user_id` 是 UUID 格式，修改时必须完全匹配

4. **会话归属**：迁移后，会话将完全归属于目标账号，原账号无法再查看这些会话

5. **跨设备同步**：此方法仅适用于本地会话历史，不涉及云端同步数据

## 相关命令

### 查看数据库表结构

```sql
.schema chat_session
```

### 查看会话数量统计

```sql
SELECT user_name, COUNT(*) as session_count 
FROM chat_session 
GROUP BY user_name;
```

### 导出迁移前的会话列表

```bash
sqlite3 ~/Library/Application\ Support/QoderCN/SharedClientCache/cache/db/local.db \
  "SELECT user_id, user_name, COUNT(*) FROM chat_session GROUP BY user_name;" > session_backup.txt
```

