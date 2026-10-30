---
title: "Spring、JDK、Maven 版本兼容性表格"
author: "颇忒脱"
tags: ["java", "springboot"]
date: 2025-01-27T12:00:47+08:00
---

<!--more-->

## 升级概述

* JDK 升级到 21 LTS（因为是当前支持周期最长的版本）
* Maven 升级到 3.9.9
* Spring Boot 升级到 3.4.1（因为是当前的最新版）

## JDK

### Oracle Java SE

JDK 21 下载地址：https://www.oracle.com/java/technologies/downloads/?er=221886#jdk21-mac

支持计划：https://www.oracle.com/hk/java/technologies/java-se-support-roadmap.html

| Release    | GA Date       | Premier Support Until | Extended Support Until | Sustaining Support |
|------------|---------------|-----------------------|------------------------|--------------------|
| 8 (LTS)**  | March 2014    | March 2022            | December 2030*****     | Indefinite         |
| 11 (LTS)   | September 2018| September 2023        | January 2032*****      | Indefinite         |
| 17 (LTS)   | September 2021| September 2026*****   | September 2029*****    | Indefinite         |
| 21 (LTS)   | September 2023| September 2028*****   | September 2031*****    | Indefinite         |
| 25 (LTS)***| September 2025| September 2030        | September 2033         | Indefinite         |

## Eclipse Temurin

官方网站：https://adoptium.net/

支持计划：https://adoptium.net/support/

Docker 镜像：https://hub.docker.com/_/eclipse-temurin

| Java Version | First Release | Latest Release | Next Release | End of Availability |
|--------------|---------------|----------------|--------------|---------------------|
| Java 21 LTS  | Sep 2023      | 15 Oct 2024 (jdk-21.0.5+11) | 21 Jan 2025 (jdk-21.0.6) | At least Dec 2029 |
| Java 17 LTS  | Sep 2021      | 15 Oct 2024 (jdk-17.0.13+11) | 21 Jan 2025 (jdk-17.0.14) | At least Oct 2027 |
| Java 11 LTS  | Sep 2018      | 15 Oct 2024 (jdk-11.0.25+9) | 21 Jan 2025 (jdk-11.0.26) | At least Oct 2027 |
| Java 8 LTS   | Mar 2014      | 15 Oct 2024 (jdk8u432-b06) | 21 Jan 2025 (jdk8u441) | At least Nov 2026 |

### Amazon Corretto

官方网站：https://aws.amazon.com/cn/corretto/

支持计划：https://aws.amazon.com/cn/corretto/faqs/

Docker 镜像：https://hub.docker.com/_/amazoncorretto

| Corretto 发行版 | 发行版类型 | GA 日期         | 上次计划更新 | 生命周期终止 |
|-----------------|------------|-----------------|--------------|--------------|
| 21              | LTS        | 2023 年 9 月 21 日 | 2030 年 7 月  | 2030 年 10 月 |
| 17              | LTS        | 2021 年 9 月 16 日 | 2029 年 7 月  | 2029 年 10 月 |
| 11              | LTS        | 2019 年 3 月 15 日 | 2031 年 10 月 | 2032 年 1 月  |
| 8               | LTS        | 2019 年 1 月 31 日 | 2030 年 10 月 | 2030 年 12 月 |

### Dragonwell JDK

官方网站：https://www.aliyun.com/product/dragonwell

支持计划：https://github.com/dragonwell-project/dragonwell21/wiki/Alibaba-Dragonwell%E6%94%AF%E6%8C%81

Docker 镜像：https://github.com/dragonwell-project/dragonwell21/wiki/Use-Dragonwell-21-docker-images

| Dragonwell版本 | 发布说明          | 更新截至       |
|----------------|-------------------|----------------|
| 8              | [Extended][d-8-e], [Standard][d-8-s] | 至少2026年6月  |
| 11             | [Extended][d-11-e], [Standard][d-11-s] | 至少2027年9月  |
| 17             | [Standard][d-17-s]           | 至少2027年9月  |
| 21             | [Standard][d-21-s]           | 至少2029年11月 |

[d-8-e]: https://github.com/alibaba/dragonwell8/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell8-Extended%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E
[d-8-s]: https://github.com/alibaba/dragonwell8/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell8-Standard%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E
[d-11-e]: https://github.com/alibaba/dragonwell11/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell11-Extended%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E
[d-11-s]: https://github.com/alibaba/dragonwell11/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell11-Standard%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E
[d-17-s]: https://github.com/alibaba/dragonwell17/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell17-Standard%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E
[d-21-s]: https://github.com/dragonwell-project/dragonwell21/wiki/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Dragonwell21-Standard%E5%8F%91%E5%B8%83%E8%AF%B4%E6%98%8E

### 毕升 JDK

官方网站：https://www.openeuler.org/zh/other/projects/bishengjdk/

支持计划：https://gitee.com/openeuler/bishengjdk-8/wikis/%E4%B8%AD%E6%96%87%E6%96%87%E6%A1%A3/LifeCycle?sort_id=4848276

Docker 镜像：无

| 毕昇JDK LTS版本    | End of Support |
|--------------------|----------------|
| BiSheng JDK 8 (LTS) | 2029-12[1]     |
| BiSheng JDK 11 (LTS)| 2024-12[1]     |
| BiSheng JDK 17 (LTS)| 2029-12[1]     |
| BiSheng JDK 21 (LTS)| 2031-9[1]      |

注[1]：通常情况，OpenJDK 社区持续GA的话，BiSheng JDK也会持续发行二进制LTS 版本。

## Apache Maven

JDK 版本兼容情况：https://maven.apache.org/docs/history.html

| Version           | Required Java |
|-------------------|---------------|
| 4.0.0-rc-2        | Java 17       |
| 3.9.x (最新 3.9.9) | Java 8        |
| 3.8.x             | Java 7        |

## Spring Framekwork

支持计划：https://spring.io/projects/spring-framework#support

当前正在维护的版本分支：6.1.x、6.2.x

要求的 JDK 版本：https://github.com/spring-projects/spring-framework/wiki/Spring-Framework-Versions

* Spring Framework 7.0.x: JDK 17-27 (expected)
* Spring Framework 6.2.x: JDK 17-25 (expected)
* Spring Framework 6.1.x: JDK 17-23
* Spring Framework 6.0.x: JDK 17-21
* Spring Framework 5.3.x: JDK 8-21 (as of 5.3.26)

## Spring Boot

支持计划：https://spring.io/projects/spring-boot#support

当前正在维护的版本分支：3.3.x、3.4.x

| Spring Boot（维护结束期） | Spring Framework（维护结束期） | Java           |
|--------------------------|------------------------------|----------------|
| 3.4.1 (2025-11-21)       | 6.2.1 (2026-08-31)           | JDK17-25(expected) |
| 3.3.7 (2025-05-23)       | 6.1.16 (2025-08-31)          | JDK17-23       |
| 3.2.12（已结束）         | 6.1.15 (2025-08-31)          | JDK17-23       |
| 3.1.12（已结束）         | 6.0.21（已结束）             | JDK17-21       |
| 3.0.13（已结束）         | 6.0.14（已结束）             | JDK17-21       |
| 2.7.18（已结束）         | 5.3.31（已结束）             | JDK8-21(asof5.3.26) |

## Spring Cloud

https://spring.io/projects/spring-cloud

| Spring Cloud           | Spring Boot |
|-------------------|---------------|
| 2024.0.x aka Moorgate        | 3.4.x       |
| 2023.0.x aka Leyton | 3.3.x, 3.2.x       |