---
title: "Nginx 反向代理吞吐量砍半之谜"
author: "颇忒脱"
tags: ["nginx", "troubleshooting", "linux"]
date: 2023-02-15T08:02:45+08:00
draft: true
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
        keepalive 500;
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
    Latency    62.59ms   55.90ms 734.80ms   84.47%
    Req/Sec     2.30k   426.21     4.09k    75.95%
  Latency Distribution
     50%   47.14ms
     75%   91.74ms
     90%  128.89ms
     99%  264.21ms
  548199 requests in 1.00m, 47.64GB read
Requests/sec:   9122.52
Transfer/sec:    811.76MB
```

压 Nginx：

```shell
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   145.33ms  130.15ms   1.69s    81.29%
    Req/Sec     1.00k   177.16     1.43k    73.07%
  Latency Distribution
     50%  129.99ms
     75%  199.58ms
     90%  304.58ms
     99%  595.59ms
  237912 requests in 1.00m, 20.69GB read
Requests/sec:   3959.57
Transfer/sec:    352.68MB
```

## 排查过程

看 top，发现压测期间 cpu 使用率只有 50% 左右：

```
top - 10:02:00 up 1 day, 18:49,  1 user,  load average: 1.45, 0.91, 0.45
Tasks: 154 total,   4 running, 150 sleeping,   0 stopped,   0 zombie
%Cpu(s):  6.5 us, 16.5 sy,  0.0 ni, 48.8 id,  0.0 wa,  0.0 hi, 27.4 si,  0.8 st
MiB Mem :   3708.1 total,   1912.4 free,    272.5 used,   1523.2 buff/cache
MiB Swap:   4032.0 total,   4032.0 free,      0.0 used.   3206.9 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
3379959 nginx     20   0   81668  12272   4432 R  30.6   0.3   1:04.68 nginx
3379958 nginx     20   0   82336  13072   4432 R  29.9   0.3   0:59.11 nginx
3379957 nginx     20   0   80680  11552   4432 R  25.9   0.3   0:52.61 nginx
3379956 nginx     20   0   81240  11972   4428 S  25.2   0.3   0:53.03 nginx
```

看 pidstat 查看 Nginx 进程的 CPU 利用率和进程上下文切换情况，发现存在较高的 %wait，以及比较稳定的 cswch/s：

* %wait: Percentage of CPU spent by the task while waiting to run.
* cswch/s: Total number of voluntary context switches the task made per second.  A voluntary context switch occurs when a task blocks because it requires a resource that is unavailable.

```shell
pidstat -G nginx -u -w 1

10时05分17秒     USER       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
10时05分18秒    nginx   3379956    5.00   18.00    0.00   16.00   23.00     0  nginx
10时05分18秒    nginx   3379957    6.00   20.00    0.00   16.00   26.00     1  nginx
10时05分18秒    nginx   3379958    5.00   23.00    0.00   18.00   28.00     2  nginx
10时05分18秒    nginx   3379959    6.00   24.00    0.00   16.00   30.00     3  nginx

10时05分17秒     USER       PID   cswch/s nvcswch/s  Command
10时05分18秒    nginx   3379956    938.00      0.00  nginx
10时05分18秒    nginx   3379957    969.00      0.00  nginx
10时05分18秒    nginx   3379958    802.00      0.00  nginx
10时05分18秒    nginx   3379959    827.00      0.00  nginx
```

用 strace 统计单个 nginx 进程的系统调用：

```shell
strace -c -p $(pgrep -nx nginx)
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 54.72    6.549331          14    443758        12 writev
 31.62    3.784297           9    391982           readv
  6.20    0.742566          10     70953        30 recvfrom
  3.30    0.394956          11     35554           write
  1.36    0.162781           3     48934           ioctl
  1.20    0.144111          27      5253           epoll_wait
  1.08    0.129113           3     35528           getsockopt
  0.14    0.017326           3      5253           clock_gettime
  0.14    0.017254           3      5253           gettimeofday
  0.12    0.014294          27       520           close
  0.05    0.006141          20       296       296 connect
  0.03    0.003547          11       296           socket
  0.01    0.001592           5       296           epoll_ctl
  0.00    0.000468          19        24           brk
------ ----------- ----------- --------- --------- ----------------
100.00   11.967777          11   1043900       338 total
```

可以看到：

* 总的 syscall 在单个 nginx 进程上耗时 17秒，总体不高
* readv 和 writev 有较多的调用（关于 readv, writev 可以 `man 2 readv` 查看）

详细采集一下 readv,writev 的系统调用都做了些啥：

```shell
strace -e trace=readv,writev -p $(pgrep -nx nginx) -o output.unopt.txt
```

查看 output.unopt.txt，每行最后面的 `=` 指的是读 / 写的字节数：

```
...
readv(209, [{iov_base="_Class_Name\">Filter Class Name</"..., iov_len=4096}], 1) = 945
...
writev(54, [{iov_base="e_'x-forwarded-for'\">Basic confi"..., iov_len=4096}], 1) = 4096
```

统计下 readv,writev 每次读/写字节数，发现绝大多数 writev 一次只写 8k，绝大多数 readv 一次只读 4k：

```shell
$ grep 'writev' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 337515 8192
  99268 4096
  47105 143
  46472 8238
  16175 19540
   5582 7252
   5215 11348
   4842 3156
   3257 23636
   3179 15444


$ grep 'readv' output.unopt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 364062 4096
  19862 36864
  13031 19540
   3127 3156
   2784 7252
   2126 5792
   1885 8688
   1883 2896
   1796 11348
   1672 11584
```

优化一下 Nginx：

```
...
  # 加大读取上游服务器响应的 buffer 尺寸，默认 8 4k
  proxy_buffers 8 128k;
  # 加大写到下游客户端的 buffer 尺寸，默认 8k
  proxy_busy_buffers_size 128k;
...
```

重启 nginx 再统计一次：

```shell
strace -c -p $(pgrep -nx nginx)
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 50.70    8.343907          12    681345           readv
 31.02    5.105203          22    223353         1 writev
  7.33    1.205871           8    149436        48 recvfrom
  3.46    0.569587          17     31695           epoll_wait
  3.42    0.562130           7     74686           write
  1.33    0.218460           2     75497           ioctl
  1.32    0.217599           2     74754           getsockopt
  0.56    0.091542           2     31696           clock_gettime
  0.52    0.085991           2     31696           gettimeofday
  0.10    0.016032          18       885           close
  0.09    0.015248          18       811       811 connect
  0.06    0.010170          12       811           socket
  0.06    0.009189          10       904           brk
  0.03    0.005516           5      1077           epoll_ctl
  0.00    0.000614           4       135         2 accept4
  0.00    0.000478           3       133           setsockopt
  0.00    0.000358           2       133           getsockname
------ ----------- ----------- --------- --------- ----------------
100.00   16.457895          11   1379047       862 total
```

发现 syscall 没有显著变化，但是压测结果吞吐量提升了 22%，响应延迟也降低了：

```
  4 threads and 500 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   116.70ms  101.24ms   1.39s    77.44%
    Req/Sec     1.23k   194.56     1.92k    74.44%
  Latency Distribution
     50%  108.57ms
     75%  154.83ms
     90%  235.66ms
     99%  473.26ms
  292245 requests in 1.00m, 25.40GB read
Requests/sec:   4864.97
Transfer/sec:    432.97MB
```

再次分析 readv,writev 的缓冲区大小：

```shell
$ strace -e trace=readv,writev -p $(pgrep -nx nginx) -o output.opt.txt

$ grep 'writev' output.opt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
  62422 143
  61296 4142
  61239 89172
    558 93314
    557 89191
    557 4123

$ grep 'readv' output.opt.txt | awk 'BEGIN{FS=" = "}; {print $2}' | sort | uniq -c | sort -rn | head
 202366 2896
  41072 5792
  13181 4344
  12423 1448
  12072 8688
   9016 11584
   9006 1897
   8164 1843
   8148 999
   8042 17376

```

