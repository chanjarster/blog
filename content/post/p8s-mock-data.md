---
title: "安利一个造Prometheus假数据的工具"
author: "破忒脱"
tags: ["prometheus"]
date: 2018-12-28T17:06:59+08:00
---

学习Prometheus各种函数的时候最好能够造一些我们想要的数据来测试，但是Prometheus没有提供直接操作其数据库的功能，所以在这里安利一个工具。

<!--more-->

下面讲一下步骤：

## 提供假指标数据

我做了一个提供假指标的工具[prometheus-mock-data][prometheus-mock-data]。利用这个工具我们可以提供给Prometheus我们想提供给它的指标，这样便于后面的测试。

新建一个文件`scrape-data.txt`，内容见[gist][gist-scrape-data]，这个文件里定义了每次Prometheus抓指标的时候所能抓到的值，这个工具会依次提供这些指标（当然你也可以写自己的假数据）。

运行：

```bash
docker run -d --rm \
  --name=mock-metrics \
  -v $(pwd)/scrape-data.txt:/home/java-app/etc/scrape-data.txt \
  -p 8080:8080 \
  chanjarster/prometheus-mock-data:latest
```

用浏览器访问：`http://localhost:8080/metrics`，刷新几次，能够看到指标数据在循环显示。

## 启动Prometheus

新建配置文件：

```yaml
scrape_configs:
  - job_name: 'mock'
    scrape_interval: 15s
    static_configs:
    - targets:
      - '<docker-host-machine-ip>:8080'
```

注意：Data point的间隔通过`scrape_interval`参数控制。

启动：

```bash
docker run -d \
    --name=prometheus \
    -p 9090:9090 \
    -v $(pwd)/prom-config.yml:/prometheus-config/prom-config.yml \
    prom/prometheus --config.file=/prometheus-config/prom-config.yml
```

打开`http://localhost:9090`看看是不是抓到指标了。
    
## 启动Grafana

```bash
docker run -d \
    --name=grafana \
    -p 3000:3000 \
    grafana/grafana
```

在Grafana里配置Prometheus数据源，然后作图。

[prometheus-mock-data]: https://github.com/chanjarster/prometheus-mock-data
[gist-scrape-data]: https://gist.github.com/chanjarster/ae4b092d59fea9c7dc316e18cf7b56c7
