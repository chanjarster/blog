---
title: "Redis解决超卖问题的方案汇总"
author: "颇忒脱"
tags: ["redis", "高并发"]
date: 2019-12-03T15:22:23+08:00
---

<!--more-->

## 乐观锁

伪代码如下：

```bash
do {
  oldCount = getCount(itemid)
  if (oldCount <= 0) {
    return false
  }
  newCount = oldCount - 1;
} while (!compareAndSwap(itemid, newCount, oldCount))
return true
```

主要是解决check-then-act的问题，因此真正更新Redis的时候要检查oldCount是否有变化。

很遗憾，你无法使用Redis的[Optimistic locking using check-and-set][2]来实现`compareAndSet`，需要使用LUA脚本来：

```lua
-- Usage: EVAL "<this script>" 1 <key> <new-value> <old-value>
local key = KEYS[1]
local newValue = ARGV[1]
local expectedOldValue = ARGV[2]

local oldValue = redis.call('GET', key)

if oldValue == expectedOldValue then
  redis.call('SET', key, newValue)
  return "OK"
end
return nil
```

乐观锁的实现比较复杂，每次更新时都得判断数据是否发生变化，且多了几次查询动作，增加了网络开销。

## 利用List

有一个讨巧的思路是构建一个Redis List，一个商品有100个，那么List中就有100个元素，增加元素时`RPUSH`，删除元素时`LPOP`。当`LPOP`失败的时候，说明List空了，说明商品卖光了。

这个方法的优点在于只需要一次LPOP的动作，伪代码：

```bash
if (nil != redis.lpop(itemid)) {
  return true
}
return false
```

这个方法的缺陷在于浪费了Redis的空间，事先维护List也是一项工作。

## LUA脚本

还可以更激进一点，把整个秒杀逻辑放在LUA脚本里。因为Redis是单线程的，执行命令是串行的，在Redis里执行LUA脚本能够避免并发环境下的check-then-act错误。下面一个LUA脚本（[原始链接][1]）的例子：

```lua
-- Usage: EVAL "<this script>" 1 <good-id> <activity-id> <user-id>
-- KEYS [good-id]
-- ARGV [activity-id,user-id]
-- return -1:库存不足 0:重复购买 1:成功

local good = KEYS[1]
local activity = ARGV[1]
local uid = ARGV[2]
local gooduids = good .. ':' .. activity .. ':uids'

local isin = redis.call('SISMEMBER', gooduids, uid)

if isin > 0 then
  return 0
end

local goodstock = good .. ':' .. activity .. ':stock'
local stock = redis.call('GET', goodstock)

if not stock or tonumber(stock) <= 0 then
  return -1
end

redis.call('DECR', goodstock)
redis.call('SADD', gooduids, uid)
return 1
-- ————————————————
-- 版权声明：本文为CSDN博主「姚仔」的原创文章，遵循 CC 4.0 BY-SA 版权协议，转载请附上原文出处链接及本声明。
```

LUA脚本来实现业务和用数据库存储过程来实现业务一样，具有灵活性不够、难以维护的问题。如果秒杀业务再复制一点，相信LUA脚本就会变得难以维护。如果秒杀业务需要外部系统的信息，则LUA脚本就不能胜任了。

[1]: https://blog.csdn.net/weixin_39660145/article/details/85334457#redis_lua_36
[2]: https://redis.io/topics/transactions#optimistic-locking-using-check-and-set