# Hdfs2ClickHouse

[中文](README_zh.md)

A set of scripts focus on loading data from hive tables in hdfs-system to ClickHouse database with low dependencies and high efficiency

## shell/Hdfs2ClickHouse.sh

- a light-weight shell script for loading hive data from hdfs to ClickHouse database.


### Pre-requirements

- Linux OS server with hdfs-client and ClickHouse-client installed already
- Hardware: Cpu with 2cores and Memory with 4Gbytes at least,the more the better!
- finaly, a user account which can execute both *hdfs* and *clickhouse-client* commands

### Usage

login in a linux server which has *hdfs-client* and *ClickHouse-client* installed,then execute the following command:

```shell
hdfs2ClickHouse.sh [-s clickhouse-server] [-u clickhouse-user] [-p clickhouse-password] [-t clickhouse-temp-table] [-H hive-table-hdfs-path] [-f hive-storage-format] [-q config-sql-path] [-c params-config-file]
```

parameters instruction as bellow:

```
optional args:
-s  clickhouse-server address,default:[localhost];support multi servers such as [clickhouse-server-ip1,clickhouse-server-ip2,...](seperated by comma[,]),but only one server will be choosed randomly for exeuting job
-u  clickhouse user,default:[default]
-p  clickhouse password,default: []
-t  clickhouse temp-table used for storing hdfs data,it is a mirror table of the original hive table
-H  hdfs path for source hive table,should be started with [hdfs://];partion column path can also be appended, eg:[hdfs://hadoop-cluster/hive_dw/app/test_clickhouse_source/date_id=2021-01-31]
-f  hdfs format for source hive table,default:[Parquet];please visit [https://clickhouse.tech/docs/en/interfaces/formats/] to see full list of supported formats.However,only [Parquet] format is tested by author currently 
-q  local file path for config sql,default:[config/load.sql]
-c  params config file,used to provide params by local file other than command-line;if it is not empty,params passed by command-line will be overwrited. default:[]
```

### Design Concept
this script was designed for loading data from hive table to ClickHouse database,but with very low dependencies and high efficiency,and can be integrated by other job-schedule system easily (such as  Crontab in Linux OS,Apache DolphinScheduler, Apache Airflow,etc.)

### Compare to  other solutions
We have lots of solutions for loading hive data to ClickHouse ,but why does this script still came out?
For now,you can choose many solutions such as Alibaba DataX/ WaterDrop/SparkSQL/Java-api/JDBC;But all these solutions have heavy dependecies or low effiency(For example,solutions based on JDBC interface can not avoid such transformation like *column-format data --> row-format data --> finally column-format data * ). So we just make it simple and ligth-weight,straightly load column format data from hive to ClickHouse database
