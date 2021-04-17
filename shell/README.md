# How to use

## Getting-started

### step 1

- prepare your hive souce table

```sql
--  Hive source table:
create table if not exists warehouse_app.fact_tb_in_parquet 
(
dimention_col1  int comment 'dimention column A'
, dimention_clo2  int comment 'dimention column B'
, pkid int comment 'record primary key'
)
comment '字典报表所有维度汇总'
stored as parquet
;
```

-  then prepare sample data

```sql
insert into warehouse_app.fact_tb_in_parquet
values 
(1,2,10),
(10,3,11),
(11,3,12),
(21,2,13),
(1111,10,14),
(123,10,15)
;
```

### step 2

- prepare hive mirror table in clickhouse
```sql
-- ClickHouse mirror table
-- Make sure table schema must be same as its hive source table
CREATE TABLE  if not exists warehouse_tmp.fact_tb_in_parquet
(
    `dimention_col1` Nullable(Int32) COMMENT 'dimention column A',
    `dimention_clo2` Nullable(Int32) COMMENT 'dimention column B',
    `pkid` Int32 COMMENT 'record primary key'
)
ENGINE = MergeTree()
ORDER BY (pkid)
;
```


- prepare sink table in ClickHouse

```sql
-- ClickHouse sink Table
CREATE TABLE if not exists warehouse_app_local.fact_tb_in_parquet
(
    `dimentionA` Int32 COMMENT 'dimention column A',
    `dimentionB` Int32 COMMENT 'dimention column B',
    `biz_pkid` Int32 COMMENT 'record primary key'
)
ENGINE = MergeTree()
ORDER BY (dimention_col1, dimention_clo2, pkid)
```

### step 3

- check if **hdfs-client** and **clickhouse-client** already installed

```shell
# check clickhouse-client
$ clickhouse-client --version
ClickHouse client version 20.8.6.6 (official build).
```

```shell
# check hdfs-client
$ hdfs version
Hadoop 2.6.0-cdh5.8.2
Compiled by nixuchi on 2017-06-05T03:49Z
```

### step 4

- prepare config sql file

```sql
pre_sql: use warehouse_tmp;
CREATE TABLE  if not exists warehouse_tmp.fact_tb_in_parquet
(
    `dimention_col1` Nullable(Int32) COMMENT 'dimention column A',
    `dimention_clo2` Nullable(Int32) COMMENT 'dimention column B',
    `pkid` Int32 COMMENT 'record primary key'
)
ENGINE = MergeTree()
ORDER BY (pkid)
;
truncate table warehouse_tmp.fact_tb_in_parquet;

post_sql:use warehouse_app_local;
insert into
warehouse_app_local.dict_dimention_total_count_local
select
 ifNull(dimention_col1   ,0)
,ifNull(dimention_clo2 ,0)
,ifNull(pkid        ,0)
from
warehouse_tmp.fact_tb_in_parquet
where
dimention_col1 > 0
and dimention_clo2 > 0
;
```

### step 5

- execute command

```shell
Hdfs2ClickHouse.sh  \
-s serverA,serverB,serverC   \
-u ch_user  \
-p ch_passwd  \
-t warehouse_tmp.fact_tb_in_parquet  \
-H hdfs://warehouse-cluster/data/hive/warehouse/warehouse_tmp/fact_tb_in_parquet \
-q config_sql.txt
```

### how does it works?

#### Basics

- As we known,ClickHouse can extract data from many kinds of datasource with different ways.For hive table or hdfs files,you can simplely execute command like this(please refer to official document website https://clickhouse.tech/docs/en/interfaces/formats/#data-format-parquet):
    
    ```shell
    $ cat {filename} | clickhouse-client --query="INSERT INTO {some_table} FORMAT Parquet"
    ```
- The command mentioned above is extremly hign efficiency and ligth-weight

#### main process of ETL

- the main process can be divided into 2-steps
- step 1,load hive data from hdfs to ClickHouse mirror table through file streaming
- step 2,load data from ClickHouse mirror table to target sink table by ClickHouse SQL
