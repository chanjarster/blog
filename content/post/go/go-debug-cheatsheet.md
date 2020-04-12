---
title: "Go Debug Cheatsheet"
date: 2020-04-12T20:23:08+08:00
tags: ["go"]
author: "颇忒脱"
---

<!--more-->

## 运行时环境变量

### GODEBUG

`GODEBUG`是一个控制其他debugging变量的变量。它的值是逗号分割的`name=val`，比如`GCDEBUG=name1=val1,name2=val2`。

[runtime包的GODEBUG][rt-env]，包含的内容比较广，这里只列举部分：

```bash
GODEBUG=gctrace=1         # print gc logs
GODEBUG=gcpacertrace=1    #causes the garbage collector to
print information about the internal state of the concurrent pacer.
GODEBUG=memprofilerate=X  # update the value of runtime.MemProfileRate
```

[net包的GODEBUG][net-godebug]

```txt
GODEBUG=netdns=go    # DNS相关，force pure Go resolver
GODEBUG=netdns=cgo   # DNS相关，force cgo resolver
GODEBUG=netdns=1     # DNS相关，print its decisions，这个比较有用会告诉你合适发生了DNS解析，以及DNS解析的尝试顺序
```

[net/http包的GODEBUG][net-http-godebug]:

```txt
GODEBUG=http2client=0  # disable HTTP/2 client support
GODEBUG=http2server=0  # disable HTTP/2 server support
GODEBUG=http2debug=1   # enable verbose HTTP/2 debug logs
GODEBUG=http2debug=2   # ... even more verbose, with frame dumps
```

### `GODEBUG=gctrace=1`

如何解读gctrace见[Garbage Collection In Go : Part II - GC Traces][gc-gctrace]。

### `GODEBUG=gcpacertrace=1`

TODO

### GOGC

`GOGC`是初始的垃圾回收目标百分比，默认100。GOGC的意思是“新分配的数据尺寸“对”上次GC剩下的live data的数据尺寸“之比，如果这个比，比如说，达到了100%，也就是1:1，那么久触发GC。

举个具体点的例子，上次GC上下了4M，那么现在新分配的数据也已经达到了4M，也就是说现在的内存总共占用了8M，这个时候触发GC。

如果`GOGC=off`，那么就彻底关掉了GC。

关于`GOGC`的更详细说明见[runtime包][rt-env]。也可见[Garbage Collection In Go : Part II - GC Traces][gc-gctrace]。

## pprof相关

pprof是go提供的profile工具，你可以很方便的得到CPU、内存、阻塞等方面的profile数据并分析。有以下几个[profile类型][profile-types]：

```txt
goroutine    - stack traces of all current goroutines
heap         - a sampling of memory allocations of live objects
allocs       - a sampling of all past memory allocations
threadcreate - stack traces that led to the creation of new OS threads
block        - stack traces that led to blocking on synchronization primitives
mutex        - stack traces of holders of contended mutexes
```

BlockProfile和MutexProfile需要设置采集频率才能采集到数据，因为它们默认不采集，相关文档如下：

```bash
$ go doc runtime.SetBlockProfileRate
package runtime // import "runtime"

func SetBlockProfileRate(rate int)
    SetBlockProfileRate controls the fraction of goroutine blocking events that
    are reported in the blocking profile. The profiler aims to sample an average
    of one blocking event per rate nanoseconds spent blocked.

    To include every blocking event in the profile, pass rate = 1. To turn off
    profiling entirely, pass rate <= 0.

$ go doc runtime.SetMutexProfileFraction
package runtime // import "runtime"

func SetMutexProfileFraction(rate int) int
    SetMutexProfileFraction controls the fraction of mutex contention events
    that are reported in the mutex profile. On average 1/rate events are
    reported. The previous rate is returned.

    To turn off profiling entirely, pass rate 0. To just read the current rate,
    pass rate < 0. (For n>1 the details of sampling may change.)  
```

MemoryProfile频率也是可以设置的（默认是开启的，因此可以不动），同时`GODEBUG=memprofilerate=X`也可以控制这个参数：

```bash
$ go doc runtime.MemProfileRate
package runtime // import "runtime"

var MemProfileRate int = 512 * 1024
    MemProfileRate controls the fraction of memory allocations that are recorded
    and reported in the memory profile. The profiler aims to sample an average
    of one allocation per MemProfileRate bytes allocated.

    To include every allocated block in the profile, set MemProfileRate to 1. To
    turn off profiling entirely, set MemProfileRate to 0.

    The tools that process the memory profiles assume that the profile rate is
    constant across the lifetime of the program and equal to the current value.
    Programs that change the memory profiling rate should do so just once, as
    early as possible in the execution of the program (for example, at the
    beginning of main).
```

如何读懂pprof报告参考[解读pprof报告](../pprof-explained/)。

### go tool pprof

go tool pprof用来分析profile文件的

```bash
# 读取profile，cli交互式
# source可以是文件，比如cpu-profile.out，也可以是一个url，看下面“程序中内嵌profile server”
go tool pprof <source>
# 读取profile，并在http://localhost:1234 提供web ui供你查看
go tool pprof -http=:1234 <profile file>
# 分析的同时提供程序的二进制文件，用于在分析时反编译（disasemble）
go tool pprof <binary> <source>
# 实时采集基于时间的profile，一般是url
go tool pprof -seconds <source>
```

**在pprof中看到源码**

执行go tool pprof时所在目录为源码目录，那么可以在pprof里看到源码，比如：

```bash
go tool pprof <source>
(pprof) list <search string>
ROUTINE ======================== institute.supwisdom.com/poa/gateway/util.init.0.func1 in util/jsonencoderpool.go
         0   512.03kB (flat, cum) 0.091% of Total
         .          .     26:	return UnsafeB2s(e.bf.B)
         .          .     27:}
         .          .     28:
         .          .     29:func init() {
         .          .     30:	jsonEncoderPool.New = func() interface{} {
         .   512.03kB     31:		bf := bytebufferpool.Get()
         .          .     32:		return &JsonEncoder{
         .          .     33:			bf:  bf,
         .          .     34:			enc: json.NewEncoder(bf),
         .          .     35:		}
         .          .     36:	}
```

但有时候会找不到源码：

```bash
Error: open /gateway/apihandler/logging.go: no such file or directory
```

这个是因为编译时使用的源码目录和执行go tool pprof的目录不一样，一般来说都是前缀不同，你可以使用`-trim_path`将编译源码目录前缀删掉，比如这样：

```bash
go tool pprof -trim_path=/gateway <source>
```

这样pprof就会去搜索`/apihandler/logging.go`，而如果你的当前目录正好有`apihandler/logging.go`，那么就能够得到源码了。

**二进制文件的搜索路径**

```txt
PPROF_BINARY_PATH  Search path for local binary files
                      default: $HOME/pprof/binaries
                      searches $name, $path, $buildid/$name, $path/$buildid
```

**更多用法**

更多用法参见`go tool pprof -help`

### go test时产生profile

你可以在go test的时候启用profile，输出的文件可以给pprof食用，[相关flag][testing-flags]：

```bash
-benchmem
    Print memory allocation statistics for benchmarks.

-blockprofile block.out
    Write a goroutine blocking profile to the specified file
    when all tests are complete.
    Writes test binary as -c would.

-blockprofilerate n
    Control the detail provided in goroutine blocking profiles by
    calling runtime.SetBlockProfileRate with n.
    See 'go doc runtime.SetBlockProfileRate'.
    The profiler aims to sample, on average, one blocking event every
    n nanoseconds the program spends blocked. By default,
    if -test.blockprofile is set without this flag, all blocking events
    are recorded, equivalent to -test.blockprofilerate=1.

-cpuprofile cpu.out
    Write a CPU profile to the specified file before exiting.
    Writes test binary as -c would.

-memprofile mem.out
    Write an allocation profile to the file after all tests have passed.
    Writes test binary as -c would.

-memprofilerate n
    Enable more precise (and expensive) memory allocation profiles by
    setting runtime.MemProfileRate. See 'go doc runtime.MemProfileRate'.
    To profile all memory allocations, use -test.memprofilerate=1.

-mutexprofile mutex.out
    Write a mutex contention profile to the specified file
    when all tests are complete.
    Writes test binary as -c would.

-mutexprofilefraction n
    Sample 1 in n stack traces of goroutines holding a
    contended mutex.
```

### http程序中内嵌profile

在你的包中引入[net/http/pprof][net-pprof]，就可以给go tool pprof提供profile数据网页端：

```go
import _ "net/http/pprof"
go func() {
	log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

用它来配合`go tool pprof`可以很方便的采集profile数据。

总页面：
```bash
http://localhost:6060/debug/pprof/ 
```

heap：

```
http://localhost:6060/debug/pprof/heap
```

cpu:

```bash
http://localhost:6060/debug/pprof/profile
```

block:

```
http://localhost:6060/debug/pprof/block
```

mutex:

```bash
http://localhost:6060/debug/pprof/mutex
```

### 程序中内嵌profile功能

你也可以在程序中内嵌生成profile的功能，详见[runtime/pprof][rt-pprof]

## Trace相关

### go tool trace

[cmd/trace][cmd-trace]

```bash
# 在浏览器中打开trace.out，如何得到trace.out下面会讲
go tool trace -http=:4231 trace.out
# 把trace文件转换成pprof文件，<TYPE>可以是
#  - net: network blocking profile
#  - sync: synchronization blocking profile
#  - syscall: syscall blocking profile
#  - sched: scheduler latency profile
go tool trace -pprof=<TYPE> trace.out
```

### http程序中内嵌trace

[net/http/pprof][net-pprof]中也提供了trace：

```bash
wget -O trace.out http://localhost:6060/debug/pprof/trace?seconds=5
```

### go test时产生trace

[相关flag][testing-flags]：

```bash
$ go test -trace=trace.out pkg

-trace trace.out
    Write an execution trace to the specified file before exiting.
```

## 参考资料

* [Profiling Go Programs][profiling-go]
* [Garbage Collection In Go : Part II - GC Traces][gc-gctrace]。


[rt-env]: https://golang.org/pkg/runtime/#hdr-Environment_Variables
[net-godebug]: https://golang.org/pkg/net/
[net-http-godebug]: https://golang.org/pkg/net/http/
[rt-pprof]: https://golang.org/pkg/runtime/pprof/
[net-pprof]: https://golang.org/pkg/net/http/pprof/
[profile-types]: https://golang.org/pkg/runtime/pprof/#Profile
[testing-flags]: https://golang.org/cmd/go/#hdr-Testing_flags
[profiling-go]: https://blog.golang.org/2011/06/profiling-go-programs.html
[cmd-trace]: https://golang.org/cmd/trace/
[gc-gctrace]: https://www.ardanlabs.com/blog/2019/05/garbage-collection-in-go-part2-gctraces.html