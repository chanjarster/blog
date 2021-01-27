---
title: "Kibana Alerting的实现分析"
date: 2021-01-27T09:14:35+08:00
tags: ["elasticsearch", "kibana"]
author: "颇忒脱"
---

<!--more-->

本文分析[Kibana Alerting][k-alert]的实现。

## Alerting的配置

### 基本信息

* Name，报警的名称。
* Tags，可选。
* Check every `N` second/minute/hour/day，隔多久检查一次，这个应该是fixed rate（固定频率，不管上一次是否执行完成，因此可能产生重叠），而不是fixed delay（上次执行完成后等待固定时间再执行）。
* Notify every `N` second/minute/hour/day，在报警激活的情况下，隔多久发送一次通知。

### Index 求值配置

* Index，被查询的Index名字或者Index Pattern，可以是多个。
  * time field，[date类型][e-date]的字段
* When，配置怎么计算值，有count、average、sum、min、max：
  * Of，聚合字段，必须是[keyword mapping][e-keyword]的，count时不需要填
* Over/Group Over，有两种：
  * all documents，不对结果进行分组
  * top `N` by `field`，根据`field`字段对结果进行分组，取doc数量前`N`个的组。`field`字段必须是[keyword mapping][e-keyword]的。报警会根据每个组的情况分别触发。

### Index 阈值触发条件

* Threshold，`is above`, `is above or equals`, `is below`, `is below or equals`, 和 `is between`，然后是具体值`value`。
* 时间窗口，只支持For the last `N` second/minute/hour/day，即从当前时间开始往前推多少时间的数据。其实就是[range query][e-range-query]加上[date math][e-date-math]（注意不需要做rounding）：

```json
GET /<index>/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lt": "now"
      }
    }
  }
}
```

## Alerting配置的要点

* 不是所有Index都支持配置Alerting，必须得有[date类型][e-date]字段才行。
* 只支持对最近的数据进行统计，从`now-duration`到`now`的范围内的数据做一些统计工作。

## Index求值模式

Index求值模式由两个维度组成，共四种：

* 是否分组，如果分组则用到[terms agg][e-term-agg]和[sub aggregation][e-sub-agg]
* 是否聚合

### 不分组，不聚合

count是唯一不聚合的查询，就是取返回结果的total count，对应的ES Query DSL：

```json
GET /<index>/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lt": "now"
      }
    }
  },
  "size": 0
}
```

因为我们只对total count感兴趣不需要具体的doc，所以设置`"size": 0`。

返回的结果，注意看`hits.total.value`字段，同时`hits.hits`数组是空的，因为我们设置了`size=0`：

```json
{
  ...
  "hits" : {
    "total" : {
      "value" : 9339,
      "relation" : "eq"
    },
    "hits" : [ ],
    ...
  }
}
```

### 不分组，聚合

[average][e-avg]、[sum][e-sum]、[min][e-min]、[max][e-max]都是聚合查询，需要配置聚合字段，字段必须是[keyword mapping][e-keyword]的，比如：

```json
GET /<index>/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lt": "now"
      }
    }
  },
  "size": 0,
  "aggs": {
    "avg_timeElapse": {
       "avg": { "field": "api_call.timeElapse" }
    }
  }
}
```

响应结果，我们不需要看`hits`字段，只要看`aggregations.avg_timeElapse.value`字段就行了：

```json
{
  ...
  "aggregations" : {
    "avg_timeElapse" : {
      "value" : 240.7022207635926
    }
  }
}
```

### 分组，不聚合

因为count不是聚合查询，所以只需要用[terms agg][e-term-agg]分组，同样分组的字段必须是[keyword mapping][e-keyword]的，同时配置了`aggs.apiSvcPerOp_buck.terms.size=2`对应top `N`语义：

```json
GET /<index>/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lt": "now"
      }
    }
  },
  "size": 0,
  "aggs": {
    "apiSvcPerOp_buck": {
      "terms": {
        "field": "api_call.apiSvcVerOp.keyword",
        "size": 2
      }
    }
  }
}

```

注意看结果的`aggregations.apiSvcPerOp_buck.buckets[].doc_count`，可以看到返回了各个keyword的`doc_count`

```json
{
  ...
  "aggregations" : {
    "apiSvcPerOp_buck" : {
      "doc_count_error_upper_bound" : 52,
      "sum_other_doc_count" : 4739,
      "buckets" : [
        {
          "key" : "user_v1_loadUserInfoByAccountName",
          "doc_count" : 1829
        },
        {
          "key" : "user_v1_listAccountGroups",
          "doc_count" : 1297
        }
      ]
    }
  }
}
```

### 分组，聚合

针对[average][e-avg]、[sum][e-sum]、[min][e-min]、[max][e-max]的分组查询则是，先用[terms agg][e-term-agg]然后把avg等作为它的[sub aggregation][e-sub-agg]：

```json
GET /<index>/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-1h",
        "lt": "now"
      }
    }
  },
  "size": 0,
  "aggs": {
    "apiSvcPerOp_buck": {
      "terms": {
        "field": "api_call.apiSvcVerOp.keyword",
        "size": 3
      },
      "aggs": {
        "avg_timeElapse": {
          "avg": { "field": "api_call.timeElapse" }
        }  
      }
    }
  }
}
```

注意结果中的`aggregations.apiSvcPerOp_buck.buckets[*].avg_timeElapse.value`字段，就是每个分组的聚合结果：

```json
{
  ...
  "aggregations" : {
    "apiSvcPerOp_buck" : {
      "doc_count_error_upper_bound" : 52,
      "sum_other_doc_count" : 4739,
      "buckets" : [
        {
          "key" : "user_v1_loadUserInfoByAccountName",
          "doc_count" : 1829,
          "avg_timeElapse" : {
            "value" : 51.38928376161837
          }
        },
        {
          "key" : "user_v1_listAccountGroups",
          "doc_count" : 1297,
          "avg_timeElapse" : {
            "value" : 445.27370855821124
          }
        }
      ]
    }
  }
}
```



[k-alert]: https://www.elastic.co/guide/en/kibana/7.10/alert-types.html
[e-query-dsl]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/query-dsl.html
[e-date]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/date.html
[e-keyword]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/keyword.html
[e-date-math]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/common-options.html#date-math
[e-range-query]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/query-dsl-range-query.html
[e-avg]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations-metrics-avg-aggregation.html
[e-max]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations-metrics-max-aggregation.html
[e-min]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations-metrics-min-aggregation.html
[e-sum]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations-metrics-sum-aggregation.html
[e-sub-agg]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations.html#run-sub-aggs
[e-term-agg]: https://www.elastic.co/guide/en/elasticsearch/reference/7.10/search-aggregations-bucket-terms-aggregation.html