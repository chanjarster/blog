---
title: "Go Error 的处理最佳实践"
author: "颇忒脱"
tags: ["Go"]
date: 2022-09-07T14:29:07+08:00
---

<!--more-->

Go 的 error 和 Java 的 Exception 最明显的区别在于：

* 原生库不携带 stacktrace
* 原生库不支持 Wrap

这给程序 debug 带来了一些麻烦，因此我们会使用 `github.com/pkg/errors` 来替代原生 `errors` 包来处理 Error。

但又因第三方库的 error 大概率没有使用 `github.com/pkg/errors`，处理方式不一致会造成麻烦，下面定义一套规则来统一：


* 自己 new 的 error，根据情况包含 stacktrace
* 不要 wrap 自己代码返回的 error
* wrap 第三方库返回的 error
* 尽量只把 error 用作异常情况

下面详细解说。

## 自己 new 的 error，根据情况包含 stacktrace

如果把 error 当作一种返回值，那么这种情况下不需要 stacktrace，比如：

```go
import "errors"

// 关闭订单
func closeOrder(id string) error {
    ...
    if order.IsPaid {
        return errors.New("不允许关闭已支付订单")
    }
    ...
}
```

如果把 error 当作一种异常结果，那么就要携带 stacktrace：

```go
import "github.com/pkg/errors"

// 关闭订单
func closeOrder(id string) error {
    ...
    if dbDown {
        // github.com/pkg/errors New 函数会携带 stacktrace 信息
        return errors.New("数据库宕机")
    }
    ...
}
```

当然这个 error 到底是返回值，还是异常结果完全是你自己决定的。

## 不要 wrap 自己代码返回的 error

wrap error 的目的是给 error 包上 stacktrace。

而当你调用自己写的代码时，被调代码自身就已经决定了是否携带 stacktrace（见前一条），那么在这里就不用再 wrap 了。

```go
// 关闭订单
func closeOrder(id string) error {
    ...
}

// 批量关闭订单
func batchCloseOrder(ids []string) error {
    for _, id := range ids {
        err := closeOrder(id)
        if err != nil {
            // 这里不需要 wrap，直接上抛
            return err
        }
    }
}
```

## wrap 第三方库返回的 error

第三方库的代码绝大多数都没有使用 `github.com/pkg/errors`，而且它们的设计基本上是把 error 作为异常情况的。所以遇到这种情况，你应该 wrap 之后再上抛：

```go
import "github.com/pkg/errors"

_, err := db.ExecContext(ctx, query, ...)
if err != nil {
    // github.com/pkg/errors Wrap 函数会包上 stacktrace
    return errors.Wrap(err, "update Order failed")
}
// 如果简单点也可以这样
return errors.WithStack(err)
```

## 尽量只把 error 用作异常情况

[Error handling and Go][1] 中提到：

> Go code uses error values to indicate an abnormal state

所以尽量只把 error 用作异常情况，而不是一种返回值。

## 打印 error 的 stacktrace

`errors` 构造的 error 和大多数第三方库返回的 error 不携带 stacktrace，所以是打印不出来的：

```go
import "errors"

fmt.Print(errors.New("abc"))
// 结果
// abc

fmt.Printf("%v", errors.New("abc"))
// 结果
// abc
```

使用 `github.com/pkg/errors` 构造的 error 则需要特殊的方式才能打印出 stacktrace：

```go
import "github.com/pkg/errors"

fmt.Print(errors.New("abc"))
// 结果
// abc

fmt.Printf("%v", errors.New("abc"))
// 结果
// abc

fmt.Printf("%+v", errors.New("abc"))
// 结果
// abc
// somefunc
// 	/path/to/some_func.go:<line>
// testing.tRunner
// 	/usr/local/opt/go/libexec/src/testing/testing.go:1259
// runtime.goexit
// 	/usr/local/opt/go/libexec/src/runtime/asm_amd64.s:1581
```

可以看到使用 fmt format `%+v` 的时候才会打印出 stacktrace。

某些日志库，比如 [go.uber.org/zap][zap] 会[自动识别][zap-error]来自 `github.com/pkg/errors` 的 error，会打印 stacktrace（注意 `errVerbose` 字段）：

```go
import (
    "github.com/pkg/errors"
    "go.uber.org/zap"
)

logger.Errorw("errors.New", "err", errors.New("simple"))
// 结果
// {"level":"error","ts":"...","caller":"...","msg":"errors.New","err":"simple","errVerbose":"<stacktrace>"}

logger.Errorw("errors.New", zap.NamedError("err", errors.New("simple")))
// 结果和上面一样
```

[1]: https://go.dev/blog/error-handling-and-go
[zap]: https://pkg.go.dev/go.uber.org/zap
[zap-error]: https://pkg.go.dev/go.uber.org/zap#NamedError