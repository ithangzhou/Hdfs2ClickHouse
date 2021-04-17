#!/bin/bash

# author: Tom Bombadil
# desc:load hive data from hdfs files to ClickHouse table.

# function for log output
## $1-log level,support INFO,ERROR,WARN
## $2-log content
function log(){
    echo -e "[`date  "+%Y-%m-%d %H:%M:%S.%3N"`] $1 - $2"
}

# start main workflow:

# step 1:
# init input params
prompt="name: hdfs2ClickHouse.sh 
desc: load hive data from hdfs files to ClickHouse table. 
author: Tom Bombadil 
usage:
hdfs2ClickHouse.sh [-s clickhouse-server] [-u clickhouse-user] [-p clickhouse-password] [-t clickhouse-temp-table] [-H hive-table-hdfs-path] [-f hive-storage-format] [-q config-sql-path] [-c params-config-file]
optional args:
-s  clickhouse-server address,default:[localhost];support multi servers such as [clickhouse-server-ip1,clickhouse-server-ip2,...](seperated by comma[,]),but only one server will be choosed randomly for exeuting job
-u  clickhouse user,default:[default]
-p  clickhouse password,default: []
-t  clickhouse temp-table used for storing hdfs data,it is a mirror table of the original hive table
-H  hdfs path for source hive table,should be started with [hdfs://];partion column path can also be appended, eg:[hdfs://hadoop-cluster/hive_dw/app/test_clickhouse_source/date_id=2021-01-31]
-f  hdfs format for source hive table,default:[Parquet];please visit [https://clickhouse.tech/docs/en/interfaces/formats/] to see full list of supported formats.However,only [Parquet] format is tested by author currently 
-q  local file path for config sql,default:[config/load.sql]
-c  params config file,used to provide params by local file other than command-line;if it is not empty,params passed by command-line will be overwrited. default:[]"

if [[ $# -eq 0 ]];then
    log ERROR "params should not be empty,exit now!"
    log INFO "${prompt}"
    exit 100
fi

## clickhouse-server: [clickhouse-server-ip1,clickhouse-server-ip2,...]
server="localhost"

## user account for clickhouse with required privileges
user="default"

## user password
passwd=""

## clickhouse temp table for data storage from hdfs files,it is a mirror table of the original hive table 
temp_table=""

## hdfs directory for source hive table,can be extracted by execute [desc formatted hive_table_name] in hive-sql client
hdfs_path=""

## hive-table format for hdfs-files
## please visit [https://clickhouse.tech/docs/en/interfaces/formats/] to see full list of supported formats
format="Parquet"

## local file path for config sql
sql_path=""

## params config file,used to provide params by local file other than command-line
cfg_file=""

while getopts ":s:u:p:t:H:f:q:c:" opt
do 
    case $opt in
        s)
            server=$OPTARG
            ;;
        u)
            user=$OPTARG
            ;;
        p)
            passwd=$OPTARG
            ;;
        t)
            temp_table=$OPTARG
            ;;
        H)
            hdfs_path=$OPTARG
            ;;
        f)
            format=$OPTARG
            ;;
        q)
            sql_path=$OPTARG
            ;;
        c)
            cfg_file=$OPTARG
            ;;
        ?)
            log WARN "unknown param:[$OPTARG],program will exit!"
            log INFO "${prompt}"
            exit 0
            ;;
    esac
done

if [[ "${hdfs_path}" != hdfs://* ]]; then
    log ERROR "invalid param : argument option is [-H],current value is [${hdfs_path}],must be started with [hdfs://]!"
    exit 200
fi

if [ -z "$temp_table" ]; then
    log ERROR  "invalid param : argument option is [-t],current value is [${temp_table}],must not be empty!"
    exit 200
fi

log INFO "input param : server is [$server]"
log INFO "input param : user is [$user]"
log INFO "input param : passwd is [*****]"
log INFO "input param : temp_table is [$temp_table]"
log INFO "input param : hdfs_path is [$hdfs_path]"
log INFO "input param : format is [$format]"
log INFO "input param : sql_path is [$sql_path]"
log INFO "input param : cfg_file is [$cfg_file]"

# step 2:
# traverse all hdfs files in hdfs directory [hdfs_path],then load data from each hdfs file to ClickHouse temp-table
# caution:
# The ClickHouse temp-table must have same schema with source hive table(only [partion by] columns can be ignored 
# or set as materialized columns ),which means all column name and order must be the same as the source hive table and field-type in ClickHouse table  match with type in hive-schema.

## sub-step 2.1:
## validate the hdfs directory and get hdfs file list
hdfs_list_str=`hdfs dfs -ls -C ${hdfs_path}`
hdfs_list=(${hdfs_list_str})
if [ ${#hdfs_list[*]} -eq 0 ]; then
    log WARN "hdfs file list is empty,check the hdfs_path [${hdfs_path}] if it's an empty directory.Current job terminated now!"
    exit 0
fi

## sub-step 2.2:
## do some initiate job before hdfs data-loading,such as create a temp table if not exists in ClickHouse  database,
## truncate the temp table if it already has some deprecated data
## test data source configuration
## and so on ...
## users can provide serveral orderd sql-fragments seperated by semicolon [;] which will define the initiating-workflow.

pre_sql=""
post_sql=""
if [ ! -f "${sql_path}" ]; then
    log INFO "config sql file not exists,no init-sql provided!!!"
else 
    config_sql=`cat ${sql_path}`
    pre_sql_tmp=${config_sql%post_sql:*}
    pre_sql=${pre_sql_tmp/pre_sql:/}
    post_sql=${config_sql#*post_sql:}
fi
log INFO "config sql:pre_sql is [${pre_sql}],post_sql is [${post_sql}]"

## clickhouse-server selection,choose a server node from server list randomly each time 
server_list=${server//,/ }
server_number=${#server_list[@]}
current_server=${server_list[${server_number}]}
log INFO "select server [${current_server}] from provided servers [${server}] for sql-execution"

if [ -n "${pre_sql}" ];then
    log INFO "init job before loading hdfs data into ClickHouse.Initiate sqls:[${pre_sql}]"
    clickhouse-client -h ${current_server} -u ${user} --password ${passwd} -n --query="${pre_sql}"
    res_code=$?
    if [ $res_code -ne 0 ]; then
        log ERROR "execute clickhouse-sql [${pre_sql}] on host [${current_server}] ERROR,exit now!!!"
        exit 400
    fi
fi

## sub step 2.3:
## load data from hdfs file to temp table in ClickHouse database
for file in ${hdfs_list}
do
    log INFO "start loading data from hdfs file [${file}] to ClickHouse temp-table [${temp_table}]"
    log INFO "This process may take a while,so please just be patient with waitting until it's finished"
    load_sql="insert into ${temp_table}  FORMAT ${format} "
    hdfs dfs -cat ${file} | clickhouse-client -h ${current_server} -u ${user} --password ${passwd}  -n --query="${load_sql}"
    res_code=$?
    if [ $res_code -ne 0 ]; then
        log ERROR "loading data from hdfs file [${file}] to ClickHouse temp-table [${temp_table}] ERROR,load-sql is [${load_sql}].current job terminated now!!!"
        exit 500
    fi
done

# step 3:
# select data from ClickHouse temp-table to final table
# normaly,there can be little difference between source hive-table struture and final table struture in ClickHouse.
# So this step is designed for such situation,you can use sql:[insert into `final_table` select ... from `temp_table` where {pre-condition expr} ] 
# to extract data to your target table with doing some transformation and filtering job at the same time.

if [ -n "${post_sql}" ];then
    log INFO "post treatment job after loading hdfs data into temp-table in ClickHouse.Provided sql:[${post_sql}]"
    clickhouse-client -h ${current_server} -u ${user} --password ${passwd}  -n --query="${post_sql}"
    res_code=$?
    if [ $res_code -ne 0 ]; then
        log ERROR "execute clickhouse-sql [${post_sql}] on host [${current_server}] ERROR,exit now!!!"
        exit 600
    fi
fi

log INFO "Congratulations! You have finished loading data from hdfs to ClickHouse."
exit 0
