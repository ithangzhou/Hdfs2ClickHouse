# Hdfs2ClickHouse

[English](README.md)

本项目包含一系列将hive表数据加载到ClickHouse数据库的轻量级脚本工具

## shell/Hdfs2ClickHouse.sh 简介

- 轻量级shell脚本，用于将Hive表数据加载到ClickHouse数据库


### 环境需求

- 预装有hdfs客户端和ClickHouse数据库客户端的Linux服务器
- 硬件：最低要求2核CPU/4G内存
- 当然，还需要预创建一个能同时执行hdfs和clickhouse-client命令的用户账号

### 使用说明

登录预装有*hdfs-client* 以及 *ClickHouse-client* 的linux服务器，然后执行下面的命令：

```shell
hdfs2ClickHouse.sh [-s clickhouse-server] [-u clickhouse-user] [-p clickhouse-password] [-t clickhouse-temp-table] [-H hive-table-hdfs-path] [-f hive-storage-format] [-q config-sql-path] 
```

参数提示如下：

```
可选参数:
-s clickhouse服务器地址，可以有多个，但是要用英文逗号隔开。实际执行时会随机挑选一个节点用于执行SQL命令。默认为[localhost]
-u 有权限登录clickhouse服务器的账号，默认为[default]
-p 登录clickhouse服务器的账号密码
-t 用于保存hdfs数据的clickhouse临时表，要求该表结构和对应hive表完全一致（分区列除外）
-H 数据源hive表的hdfs文件路径，必须以[hdfs://]开头；分区列也可以包含在内，例如[hdfs://hadoop-cluster/hive_dw/app/test_clickhouse_source/date_id=2021-01-31]
-f 数据源hive表的hdfs存储格式，默认[Parquet]；其它格式请参见 [https://clickhouse.tech/docs/en/interfaces/formats/] 
-q 包含有前/后处理sql的本地文件路径；默认为空
```

### 设计理念
该shell脚本被设计用于加载hive数据到ClickHouse库，同时保持最低依赖及兼顾高效，同时它也能很容易被其它调度系统所集成（例如：Linux系统的Crontab,Apache DolphinScheduler, Apache Airflow等）

### 和其它方案对比
目前我们已经有很多可选的方案，用于加载hive数据到ClickHouse库中，但是为什么仍然要开发这么个脚本工具呢？
虽然你可以选用其它的工具，比如说 Alibaba DataX/ WaterDrop/SparkSQL/Java-api/JDBC 等，这些方案中有的依赖过重，而有的效率不高（比如，基于JDBC接口的一系列工具，基本都避不开*列式存储-->行式存储-->最终的列式存储* 这一系列的转换操作）。因此，我们捣鼓了这么个轻量同时又高效的简洁版工具，直接将hive的列存数据加载到ClickHouse中。
