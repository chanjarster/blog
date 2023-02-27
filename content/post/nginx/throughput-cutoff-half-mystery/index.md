---
title: "Nginx 反向代理吞吐量砍半之谜"
author: "颇忒脱"
tags: ["nginx", "troubleshooting", "linux"]
date: 2023-02-22T15:02:45+08:00
draft: false
---

<!--more-->

## 现象

一日闲来无事对 Nginx 作为反向代理的性能做测试，发现相比直压，经过 Nginx 这么一转手，吞吐量减半，延迟加倍。

基本环境情况：

* 拓扑：`Wrk --> Nginx --> Tomcat`
* 三者是部署在同一个物理服务器上的 3 个虚拟机
* 三者都是 4c 4g配置
* 三者操作系统相同，都是 Anolis Linux 8.6
* 三者之间的带宽实用 iperf3 测试过，可达 18Gbits/s

软件版本：

* [wrk](https://github.com/wg/wrk) master 最新版
* Nginx 1.23.3
* Tomcat 8.5.85，配置了 `-Xms2G -Xmx2G` 去除了垃圾收集的影响
* 测试的是 Tomcat 下的 `/docs/config/filter.html` 地址，这个地址响应大小在 ~91K，而且这个地址本身吞吐量也不高

测试脚本：

```shell
./wrk -c 500 -t 4 -d 1m --latency  http://<tomcat-ip>:8080/docs/config/filter.html
./wrk -c 500 -t 4 -d 1m --latency  http://<nginx-ip>:8080/docs/config/filter.html
```

nginx 配置：

```
user  nginx;
worker_processes  4;
worker_cpu_affinity 0001 0010 0100 1000;

worker_rlimit_nofile 30000;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    use epoll;
    multi_accept on;
    worker_connections  7500;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;
    keepalive_requests 1000;

    proxy_connect_timeout 15s;
    proxy_read_timeout 10s;

    proxy_send_timeout 10s;
    proxy_buffering on;

    upstream tomcat_server {
        server <tomcat-ip>:8080 max_fails=20;
        keepalive 1000;
    }
    
    server {
        listen       8080 reuseport;
        server_name  localhost;

        location / {
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass http://tomcat_server;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_read_timeout 900s;
        }
    }
}
```

直压 Tomcat：

```shell
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    61.10ms  104.69ms 964.53ms   86.61%
    Req/Sec     6.36k     1.15k    9.96k    73.61%
  Latency Distribution
     50%   13.71ms
     75%   43.46ms
     90%  213.47ms
     99%  465.04ms
  1491946 requests in 1.00m, 129.60GB read
Requests/sec:  24822.44
Transfer/sec:      2.16GB
```

压 Nginx：

```shell
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    43.34ms   45.88ms   1.11s    97.63%
    Req/Sec     3.23k   463.18     4.62k    76.46%
  Latency Distribution
     50%   37.20ms
     75%   46.17ms
     90%   57.18ms
     99%  232.57ms
  764342 requests in 1.00m, 66.43GB read
Requests/sec:  12722.92
Transfer/sec:      1.11GB
```

对比一下性能指标：

|         |   基准值      |  未优化              |
|:-------:|:------------:|:-------------------:|
| 50%     | 13.71ms      | 37.20ms   (+ 171%)  |
| 75%     | 43.46ms      | 46.17ms   (+ 6.2%)  |
| 90%     | 213.47ms     | 57.18ms   (- 73.2%) |
| 99%     | 465.04ms     | 232.57ms  (- 49.9%) |
| Avg     | 61.10ms      | 43.34ms   (- 29%)   |
| Max     | 964.53ms     | 1.11s     (+ 15%)   |
| RPS     | 24822.44     | 12722.92  (- 48.7%) |


## 排查过程

压测期间 Nginx 的 CPU 表现：

```
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 5  0   7424 1977308   2044 1698108    0    0     0     0 73333  642 15 84  0  0  0
 4  0   7424 1975424   2044 1699728    0    0     0     0 65583  733 15 85  0  0  0
 5  0   7424 1965804   2044 1700800    0    0     0     0 53537 1013 12 60 29  0  0
 5  0   7424 1978396   2044 1702180    0    0     0     0 72517  626 16 84  0  0  0
 9  0   7424 1979584   2044 1703756    0    0     0     0 71537 1031 16 83  0  0  0
 5  0   7424 1978852   2044 1705108    0    0     0     0 71340 1281 16 83  1  0  0
 5  0   7424 1977956   2044 1706696    0    0     0     0 70989  693 15 85  0  0  0
 2  0   7424 1966884   2044 1708136    0    0     0     0 70589  672 15 85  0  0  0
 6  0   7424 1953472   2044 1709608    0    0     0     0 72448  630 17 83  0  0  0
 5  0   7424 1960272   2044 1710964    0    0     0 41920 72081  668 16 84  0  0  0
 6  0   7424 1959320   2044 1712124    0    0     0     0 71234  705 16 82  2  0  0
10  0   7424 1970128   2044 1713612    0    0     0     0 70968 1173 17 82  0  0  0
 4  0   7424 1949780   2044 1714608    0    0     0     0 69815 1120 17 83  0  0  0
 6  0   7424 1945680   2044 1716060    0    0     0     0 70618  789 16 83  0  0  0
```

可以看到 CPU 是用足的，但是 sy （系统调用）比较高，有 80% 左右。

用 strace 统计 30s 内单个 nginx 进程的系统调用：

```shell
$ timeout 30 strace -c -p $(pgrep -nx nginx)
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 53.49    4.035007          11    365710           writev
 30.32    2.287248           7    305123           readv
  7.61    0.574073           9     60984           recvfrom
  4.57    0.344557          11     30471           write
  1.46    0.110045           3     30516           getsockopt
  1.36    0.102238           3     30879           ioctl
  0.85    0.064290          95       674           epoll_wait
  0.11    0.008300          29       286           close
  0.07    0.004944          14       337       337 connect
  0.05    0.003852           7       514           epoll_ctl
  0.05    0.003714          11       337           socket
  0.03    0.002279           3       674           clock_gettime
  0.02    0.001784           2       674           gettimeofday
  0.01    0.000838           7       116        26 accept4
  0.00    0.000330           4        78           setsockopt
  0.00    0.000313           3        87           getsockname
------ ----------- ----------- --------- --------- ----------------
100.00    7.543812           9    827460       363 total
```

可以看到 readv 和 writev 有 30.5w 次和 36.5w 次调用。

`man 2 readv` 可以直到这两个系统调用是干什么的，简而言之就是和 TCP 读写有关（因为 socket 也是 fd）：

> The readv() system call reads iovcnt buffers from the file associated with the file descriptor fd into the buffers described by iov ("scatter input").
>
> The writev() system call writes iovcnt buffers of data described by iov to the file associated with the file descriptor fd ("gather output").

接着再用 strace 详细采集一下 readv,writev 的系统调用都做了些啥：

```shell
$ timeout 30 strace -e trace=readv,writev -p $(pgrep -nx nginx) -o output.unopt.txt
```

查看 output.unopt.txt，每行最后面的 `=` 指的是读 / 写的字节数：

```
...
readv(85, [{iov_base="ST /rest/resources/addResource H"..., iov_len=4096}], 1) = 4096
...
writev(47, [{iov_base="rg</code>.\n        <strong>Defau"..., iov_len=4096}, {iov_base="e&gt;true&lt;/param-value&gt;\n  "..., iov_len=4096}], 2) = 8192
```

统计下 readv 每次读的字节数，绝大多数 readv 一次只读 4k，最多一次读 36k（36864 字节）：

```shell
$ grep 'readv' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 144120 4096
  18007 36864
  17796 19540
    205 19559
    196 0
      9 3895
      3 1843
      3 17697
      2 6113
      2 395
$ grep 'readv' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
36864
```

统计下 writev 写的字节数，发现绝大多数 writev 一次只写 8k，最多一次写 35.08k（35924 字节）：

```shell
$ grep 'writev' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 126115 8192
  36032 4096
  18028 143
  17811 8238
  17797 19540
    205 8219
    205 19559
      5 3156
      3 35924
      3 15444

$ grep 'writev' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
35924
```

## 第一次优化

nginx 关于代理缓冲的参数有 [`proxy_buffers`][n1] 和 [`proxy_buffer_size`][n2] ，他们的默认值是 `proxy_buffer_size 4k|8k` 和 `proxy_buffers 8 4k|8k`。

因为当前平台内存页大小是 4K（通过 `getconf PAGE_SIZE` 可以得到），因此实际上是：`proxy_buffer_size 4k` 和 `proxy_buffers 8 4k`，正好是 36k，和 `readv` 的结果不谋而合。

`proxy_buffer_size` 是读取 upstream 单个响应的第一个部分的响应头的缓冲区大小，通常这个部分会包含响应头，如果响应头比较少也会包含响应体，甚至于整个响应。

`proxy_buffers` 则是读取 upstream 完整响应的缓冲区，默认值总尺寸是 32k。

因为压测 URL 的响应尺寸在 ~91K 左右，那么我们放大一下 `proxy_buffers`，看看有没有效果：

```conf
http {
    proxy_buffers 128 4k;
}
```

压一把，吞吐量提升了，从 1.2w 提升到了 1.4w

```shell
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    39.12ms   48.03ms   1.11s    97.22%
    Req/Sec     3.68k   510.09     5.00k    76.49%
  Latency Distribution
     50%   32.05ms
     75%   40.66ms
     90%   53.17ms
     99%  226.92ms
  871572 requests in 1.00m, 75.75GB read
Requests/sec:  14510.78
Transfer/sec:      1.26GB
```

对比一下性能指标：

|         |   基准值      |  未优化              |  第一次优化           |
|:-------:|:------------:|:-------------------:|:-------------------:|
| 50%     | 13.71ms      | 37.20ms  (+ 171%)  | 32.05ms  (+ 133%)    |
| 75%     | 43.46ms      | 46.17ms  (+ 6.2%)  | 40.66ms  (- 0.64%)   |
| 90%     | 213.47ms     | 57.18ms  (- 73.2%) | 53.17ms  (- 75.0%)   |
| 99%     | 465.04ms     | 232.57ms (- 49.9%) | 226.92ms (- 50.2%)   |
| Avg     | 61.10ms      | 43.34ms  (- 29%)   | 39.12ms  (- 35.9%)   |
| Max     | 964.53ms     | 1.11s    (+ 15%)   | 1.11s    (+ 15%)     |
| RPS     | 24822.44     | 12722.92 (- 48.7%) | 14510.78 (- 41.5%)   |

吞吐量略微提升。


统计一下 readv,writev 的调用次数：

```shell
$ timeout 30 strace -c -p $(pgrep -nx nginx)
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 53.19    3.534995           5    691405           readv
 28.61    1.901240          23     81985           writev
  8.56    0.569164           8     63561           recvfrom
  4.88    0.324340          10     31742           write
  1.72    0.114049           3     31820           getsockopt
  1.67    0.111064           3     32146           ioctl
  0.99    0.065817         119       553           epoll_wait
  0.10    0.006479          22       282           close
  0.07    0.004570          12       364       364 connect
  0.06    0.003871          10       364           socket
  0.05    0.003311           5       580           epoll_ctl
  0.02    0.001509          11       136           brk
  0.02    0.001504          11       130        22 accept4
  0.02    0.001466           2       553           gettimeofday
  0.02    0.001312           2       553           clock_gettime
  0.01    0.000512           4       108           setsockopt
  0.01    0.000375           3       108           getsockname
------ ----------- ----------- --------- --------- ----------------
100.00    6.645578           7    936390       386 total
```

目前可以看到效果显著：

|  syscall      |   未优化          |    第一次优化    |
|:-------------:|:----------------:|:--------------:|
| readv         | 305123 (2.28s)   | 691405 (3.53s) |
| writev        | 365710 (4.03s)   | 81985  (1.90s) |
| recvfrom      | 60984  (0.57s)   | 63561  (0.56s) |
| 总耗时         | 7.54s            | 6.64s          |

采集一下 readv,writev 的实际调用参数：

```shell
$ timeout 30 strace -e trace=readv,writev -p $(pgrep -nx nginx) -o output.opt1.txt

$ grep 'readv' output.opt1.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 482455 4096
  22416 3156
    226 3175
    222 0
     79 7252
     71 11348
     68 15444
     48 19540
     33 23636
     29 27732

$ grep 'readv' output.opt1.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
48179

$ grep 'writev' output.opt1.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
  23152 143
  22520 93314
   4308 8192
    546 8238
    254 4096
     94 3156
     83 7252
     77 11348
     70 15444
     53 19540

$ grep 'writev' output.opt1.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
93314
```

目前可以看到：

* readv 每次读的字节数，绝大多数一次只读 4k，最多一次读 ~47k（48179字节）。
* writev 每次写的字节数，绝大多数一次写 143 字节和 ~91k（93314字节），最多一次写 ~91k（93314字节）。

readv 怎么会数量激增，看看 strace 的可以看到这个：


```shell
readv(420, [{iov_base="nitialisation parameters</a></li"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="e_'x-forwarded-for'\">Basic confi"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="_Class_Name\">Filter Class Name</"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="rg</code>.\n        <strong>Defau"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="e&gt;true&lt;/param-value&gt;\n  "..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base=" <p>The number of previously iss"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="ST /rest/resources/addResource H"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="ocument's\n    validity and persi"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="m&gt;\n &lt;param-name&gt;Expires"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="useful to ease usage of <code>Ex"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="\n         <div class=\"codeBox\"><"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="ation parameters.</p>\n\n  </div><"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="rotectionEnabled</code></td><td>"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="\n        &lt;param-value&gt;127\\"..., iov_len=4096}], 1) = 4096
readv(420, [{iov_base="i><code>Order</code> will always"..., iov_len=4096}], 1) = 4096
```

可以看到每次从 upstream 读取响应的时候，只利用了一个 buffer (4K)，而且分了好几次读取。

writev 的 143 字节是怎么回事呢，看看，原来是转发请求到 upstream 的时候发生的动作：

```shell
writev(516, [{iov_base="GET /docs/config/filter.html HTT"..., iov_len=143}], 1) = 143
```

writev 的 ~91k（93314字节）也看看，发现是把 upstream 的响应返回给 client 时发生的，这个倒是一口气全部写出去的：

```shell
writev(53, [
    {iov_base="HTTP/1.1 200 \r\nServer: nginx/1.2"..., iov_len=247}, 
    {iov_base="<!DOCTYPE html SYSTEM \"about:leg"..., iov_len=3895}, 
    {iov_base="nitialisation parameters</a></li"..., iov_len=4096},
    ...
    ],
    1)  = 93314
```

## 第二次优化

那么到现在问题很明确了，readv 一次读取的数据量太小，导致分了很多次读，形成了比较多的系统调用，那么再优化 `proxy_buffers`，总容量不变，减少 buffer 数量，扩充单个 buffer 的尺寸：

```conf
http {
    proxy_buffers 4 128k;
}
```

压一把看看：

```
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    42.06ms   55.45ms   1.14s    93.33%
    Req/Sec     3.91k   578.27     5.73k    78.55%
  Latency Distribution
     50%   28.55ms
     75%   40.53ms
     90%   68.06ms
     99%  286.52ms
  924858 requests in 1.00m, 80.38GB read
  Non-2xx or 3xx responses: 1
Requests/sec:  15390.49
Transfer/sec:      1.34GB
```

对比一下性能指标：

|         |   基准值      |  未优化              |  第一次优化           |  第二次优化           |
|:-------:|:------------:|:-------------------:|:-------------------:|:-------------------:|
| 50%     | 13.71ms      | 37.20ms  (+ 171%)  | 32.05ms  (+ 133%)    | 28.55ms  (+ 108%)    |
| 75%     | 43.46ms      | 46.17ms  (+ 6.2%)  | 40.66ms  (- 0.64%)   | 40.53ms  (- 0.67%)   |
| 90%     | 213.47ms     | 57.18ms  (- 73.2%) | 53.17ms  (- 75.0%)   | 68.06ms  (- 68.1%)   |
| 99%     | 465.04ms     | 232.57ms (- 49.9%) | 226.92ms (- 50.2%)   | 286.52ms (- 38.3%)   |
| Avg     | 61.10ms      | 43.34ms  (- 29%)   | 39.12ms  (- 35.9%)   | 42.06ms  (- 31.1%)   |
| Max     | 964.53ms     | 1.11s    (+ 15%)   | 1.11s    (+ 15%)     | 1.14s    (+ 18.1%)   |
| RPS     | 24822.44     | 12722.92 (- 48.7%) | 14510.78 (- 41.5%)   | 15390.49 (- 37.9%)   |

吞吐量比之前有所提升。

看看系统调用次数：

```shell
$ timeout 30 strace -c -p $(pgrep -nx nginx)
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 36.25    3.749784          29    126213           writev
 35.87    3.710298          52     70403           readv
 15.03    1.554814          13    115917           recvfrom
  5.49    0.567726           9     57932           write
  2.30    0.237950           4     57974           getsockopt
  2.13    0.220522           3     58524           ioctl
  1.83    0.188874         165      1144           epoll_wait
  0.67    0.069087          20      3314           brk
  0.14    0.014583          25       572           close
  0.10    0.010315          17       585       585 connect
  0.07    0.007178          12       585           socket
  0.05    0.004685           6       719           epoll_ctl
  0.03    0.003239           2      1144           clock_gettime
  0.03    0.003082           2      1144           gettimeofday
  0.01    0.001498          13       110        42 accept4
  0.00    0.000284           4        66           setsockopt
  0.00    0.000173           2        66           getsockname
------ ----------- ----------- --------- --------- ----------------
100.00   10.344092          20    496412       627 total
```

目前可以看到：

|  syscall      |   未优化          |    第一次优化    |    第二次优化   |
|:-------------:|:----------------:|:--------------:|:--------------:|
| readv         | 305123 (2.28s)   | 691405 (3.53s) | 70403 （3.71s) | 
| writev        | 365710 (4.03s)   | 81985  (1.90s) | 126213 (3.74s) | 
| recvfrom      | 60984  (0.57s)   | 63561  (0.56s) | 115917 (1.55s) |
| 总耗时         | 7.54s            | 6.64s          | 10.34s         |

可以看见，第二次优化效果显著，但是 recvfrom 的调用次数有较大的增加。
  
采集一下系统调用的详细信息看看：


```
$ timeout 30 strace -e trace=readv,writev,recvfrom -p $(pgrep -nx nginx) -o output.opt2.txt

$ grep 'readv' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
  39932 89172
    783 3895
    416 0
    412 89191
    304 1843
    301 395
    298 4739
    297 87329
    292 88777
    290 84433

$ grep 'readv' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
89191

$ grep 'writev' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
  45971 143
  40343 93314
   5561 89172
   5561 4142
     24 89191
     24 4123

$ grep 'writev' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
93314

$ grep 'recvfrom' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
  45971 67
  45137 4096
    754 201
      9 220

$ grep 'recvfrom' output.opt2.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort -rn | head -1
4096
```

目前可以看到：

* readv 每次读的字节数，绝大多数一次只读 ~87k（89172字节），说明我们的配置起到了作用。
* writev 每次写的字节数，和之前一样，绝大多数一次写 143 字节和 ~91k（93314字节），最多一次写 ~91k（93314字节）。
* recvfrom 没次读的字节数，绝大多数是 67 字节 和 4k（4096字节）

再看看 readv 的系统调用详情，可以发现读取 upstream 的响应时就读了 1 次，每次都是使用 128k buffer 读的：

```
readv(250, [{iov_base="nitialisation parameters</a></li"..., iov_len=131072}], 1) = 89172
readv(159, [{iov_base="nitialisation parameters</a></li"..., iov_len=131072}], 1) = 89172
```

看看 recvfrom 的系统调用详情：

```
recvfrom(105, "GET /docs/config/filter.html HTT"..., 1024, 0, NULL, NULL) = 67
recvfrom(159, "GET /docs/config/filter.html HTT"..., 1024, 0, NULL, NULL) = 67
recvfrom(264, "HTTP/1.1 200 \r\nAccept-Ranges: by"..., 4096, 0, NULL, NULL) = 4096
recvfrom(226, "HTTP/1.1 200 \r\nAccept-Ranges: by"..., 4096, 0, NULL, NULL) = 4096
```

可以发现：

* 读取 67 字节的是来自 client（wrk） 的请求，用的是 1024 的 buf，具体参数参考（`man 2 recvfrom`）
* 读取 4096 字节的是来自 upstream 的响应，用的是 4096 的 buffer

实际上这两个缓冲区的大小分别由 [`client_header_buffer_size 1k`][n3] 和 [`proxy_buffer_size 4k`][n2]，调整这两个参数可以影响 recvfrom 的调用。
本人对此这个做过实验，确认的确如此，有兴趣的同学可以自行实验。

## 第三次优化

应该还有优化空间。

压测的时候用 pidstat 观察一下：

```shell
$ pidstat -u -w -G nginx 1 30
...
平均时间:   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
平均时间:   990   4038174   15.52   75.77    0.00    4.92   91.29     -  nginx
平均时间:   990   4038175   15.39   74.14    0.00    5.98   89.53     -  nginx
平均时间:   990   4038176   15.15   70.92    0.00    8.18   86.08     -  nginx
平均时间:   990   4038177   15.39   73.55    0.00    7.28   88.93     -  nginx

平均时间:   UID       PID   cswch/s nvcswch/s  Command
平均时间:   990   4038174     80.72     54.50  nginx
平均时间:   990   4038175    127.95     53.94  nginx
平均时间:   990   4038176    154.34     54.57  nginx
平均时间:   990   4038177     94.08     48.75  nginx
```

可以看到 CPU 占用率是比较高的，其中系统调用是占的比较多，自愿上下文切换和非资源上下文切换在正常数值内。

那么利用 [openresty-systemtap-toolkit][or-1] 来采集一下 CPU 火焰图：

```shell
$ /root/openresty-systemtap-toolkit/sample-bt -p $(pgrep -nx nginx) -t 30 -u -k -a '-D MAXMAPENTRIES=100000' > openresty-oncpu.bt \
&& /root/FlameGraph/stackcollapse-stap.pl openresty-oncpu.bt > openresty-oncpu.cbt \
&& /root/FlameGraph/flamegraph.pl --title="Openresty On-CPU Time Flame Graph (user/kernel)" < openresty-oncpu.cbt > /usr/share/nginx/html/openresty-oncpu.svg
```

> openresty-systemap-toolkit 依赖于 SystemTap，安装的坑在[这篇文章里有写](../../linux/stap-kernel-debug-mismatch)。

火焰图如下：

![](openresty-oncpu.svg?s=tcp)

这里还看不清，点击[此处进入交互界面](openresty-oncpu.svg?s=tcp)，可以发现 `tcp_` 收发相关的系统调用占了绝大部分。

用 bcc netqtop 看一下网卡队列：

```shell
$ /usr/share/bcc/tools/netqtop -n ens18 -t
TX
 QueueID    avg_size   [0, 64)    [64, 512)  [512, 2K)  [2K, 16K)  [16K, 64K) BPS        PPS
 0          16.8K      0          12.01K     94         1.07K      7.68K      350.16M    20.84K
 1          16.8K      0          13.91K     248        1.05K      9.03K      406.93M    24.23K
 2          16.67K     0          13.95K     124        867        8.6K       391.95M    23.52K
 3          16.22K     0          12.21K     118        1.04K      7.4K       336.94M    20.78K
 Total      16.63K     0          52.07K     584        4.01K      32.71K     1485.89M   89.36K

RX
 QueueID    avg_size   [0, 64)    [64, 512)  [512, 2K)  [2K, 16K)  [16K, 64K) BPS        PPS
 0          8.48K      26.14K     34.26K     5.23K      82.44K     25.28K     1462.63M   172.58K
 1          0          0          0          0          0          0          0.0        0.0
 2          0          0          0          0          0          0          0.0        0.0
 3          0          0          0          0          0          0          0.0        0.0
 Total      8.48K      26.14K     34.26K     5.23K      82.44K     25.28K     1462.63M   172.57K
-----------------------------------------------------------------------------------------------
```

可以发现 TX 的4个队列在工作，RX 只有一个队列在工作，不平衡。
但是经过调查发现是 virtio 网卡驱动的问题，它会把所有 RX 队列都归到一个上面，详情见[这里](https://github.com/iovisor/bcc/blob/master/tools/netqtop.c#L105)。

看一下网卡到底有几个队列：

```shell
ethtool -S ens18 |  grep -i queue
    rx_queue_0_...: 
    rx_queue_1_...:
    rx_queue_2_...: 
    rx_queue_3_...:
    tx_queue_0_...: 
    tx_queue_1_...:
    tx_queue_2_...: 
    tx_queue_3_...:
```

可以看到有 4 个 TX 队列，4 个 RX 队列，再用 `ethtool` 看看：

```shell
ethtool --show-channels ens18
Channel parameters for ens18:
Pre-set maximums:
RX:	        0
TX:	        0
Other:	    0
Combined:	4
Current hardware settings:
RX:	        0
TX:	        0
Other:	    0
Combined:   4
```

可以发现 RX 和 TX 队列是 Combined 即共用的，也说明不了什么问题。

## 坑

后来又测了几次，居然吞吐量可以达到 `Requests/sec:  20891.36` 了，这么算起来性能损失在 15.8%，而配置什么都没有修改。

下面是 1.5w 吞吐量时 `vmstat 3` 采集到的数据：

```shell
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1  0   6200 422776   1280 3271276    0    0     3    12    2    3  1  3 96  0  0
 5  0   6200 380732   1280 3274324    0    0     0     0 33561 2501 10 50 40  0  0
 9  0   6200 349612   1280 3279556    0    0     0  2275 59441 1660 16 82  2  0  0
 4  0   6200 368204   1280 3284836    0    0     0     5 58715 2134 16 81  3  0  0
 5  0   6200 371488   1280 3289468    0    0     0    13 54830 1599 15 75 10  0  0
 6  0   6200 357684   1280 3294816    0    0     0     0 59379 2157 17 81  2  0  0
 6  0   6200 354924   1280 3299972    0    0     0     0 59001 1677 17 81  2  0  0
10  0   6200 359032   1280 3304804    0    0     0     0 60432 2165 17 80  3  0  0
 6  0   6200 335520   1280 3309564    0    0     0     0 53159 1683 15 74 11  0  0
 6  0   6200 342820   1280 3314876    0    0     0     0 60558 1521 17 82  1  0  0
 4  0   6200 329528   1280 3319996    0    0     0     0 57417 1976 16 81  2  0  0
10  0   6200 348536   1280 3325440    0    0     0     0 60811 2299 16 80  4  0  0
 5  0   6200 314668   1280 3330652    0    0     0 17367 61782 1985 17 81  2  0  0
 4  0   6200 329772   1280 3335264    0    0     0    29 53842 1498 15 75 10  0  0
 6  0   6200 327940   1280 3340432    0    0     0     0 62743 2704 17 80  3  0  0
 5  0   6200 299228   1280 3345844    0    0     0    13 56948 2376 16 81  3  0  0
 6  0   6200 298944   1280 3350860    0    0     0     0 60960 1778 17 81  2  0  0
 7  0   6200 280948   1280 3355664    0    0     0     0 53903 2091 15 74 12  0  0
 7  0   6200 294628   1280 3360996    0    0     0     0 57029 1866 17 82  1  0  0
 3  0   6200 307808   1280 3366352    0    0     0     0 59706 2799 17 80  3  0  0
12  0   6200 265816   1280 3371172    0    0     0     0 59362 2407 17 80  3  0  0
 0  0   6200 284128   1280 3373364    0    0     0     0 27776 1150  8 37 55  0  0
```

下面是 2.1w 吞吐量时 `vmstat 3` 采集到的数据：

```shell
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 9  0   5952 148496    884 3509644    0    0     3    13    5    8  1  3 96  0  0
 7  0   5952 164580    884 3516472    0    0     0     0 69482 2751 17 81  2  0  0
 5  0   5952 139616    884 3523108    0    0     0    13 65379 5684 14 70 16  0  0
 3  0   5952 152192    884 3513580    0    0     0    75 69451 4367 16 80  4  0  0
 5  0   5952 146492    884 3520968    0    0     0     0 70361 5948 15 78  7  0  0
 2  0   5952 166496    884 3515740    0    0     0     0 63169 4580 15 70 15  0  0
 7  0   5952 157008    884 3512172    0    0     0     0 69768 6346 15 77  8  0  0
 4  0   5952 176820    880 3494972    0    0     0     0 69968 3590 16 80  5  0  0
 8  0   5952 150888    880 3501996    0    0     0     1 69508 4486 16 78  6  0  0
 6  0   5952 154504    880 3507892    0    0     0     0 63143 3990 15 72 13  0  0
 6  0   5952 147676    880 3515340    0    0     0     0 70931 6194 15 79  7  0  0
12  0   5952 147828    880 3510848    0    0     0 26539 70144 4384 16 79  5  0  0
 6  0   5952 154528    880 3518252    0    0     0    13 70091 4694 16 79  5  0  0
 7  0   5952 157544    880 3513860    0    0     0     6 62106 4454 14 71 15  0  0
 4  0   5952 146288    880 3520860    0    0     0     0 69309 3647 16 80  4  0  0
 6  0   5952 150000    880 3522208    0    0     0     0 72404 5198 16 78  7  0  0
 7  0   5952 161044    876 3504304    0    0     0     0 67280 1994 16 81  2  0  0
 4  0   5952 163560    876 3510340    0    0     0     0 65055 2563 14 73 13  0  0
 7  0   5696 145280    876 3516980   61    0    77     0 69434 5042 17 77  5  1  0
 5  0   5696 146928    876 3524360    0    0     0     0 71610 5954 15 77  7  0  0
 1  0   5696 158960    876 3525224    0    0     0     1 7612 1255  3 10 88  0  0
 0  0   5696 159256    876 3525228    0    0     0 18723 1228  971  1  2 97  0  0
 0  0   5696 159516    876 3525228    0    0     0    13  859  647  1  1 98  0  0
```

可以看到，两次采集存在很明显的差距：

* 2.1w 时的 `in` 中断在 7w 左右，`cs` 在 1.9k ～ 6.3k 浮动。
* 1.5w 时的 `in` 中断在 6w 左右，`cs` 在 1.6k ～ 2.7k 浮动。

那么说明问题出在外部，要么是虚拟化平台的问题，要么是物理机的问题。

问题排查就此告一段落。

[n1]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers
[n2]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size
[n3]: https://nginx.org/en/docs/http/ngx_http_core_module.html#client_header_buffer_size
[or-1]: https://github.com/openresty/openresty-systemtap-toolkit







