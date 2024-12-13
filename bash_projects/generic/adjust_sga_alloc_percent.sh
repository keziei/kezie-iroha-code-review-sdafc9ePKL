#!/bin/bash
# Author: Kezie Iroha Adjust memory settings for database
# percent of ram for oracle / allocated to sga, pga
# Author: Kezie Iroha os_alloc_percent=.8 to allocate 80% of memory for oracle and 20% for OS as standard
# Author: Kezie Iroha This requires the Build Ops oracle cookbook ratio also set to 80%

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export SW_VER=`echo $ORACLE_HOME | awk -F "/" '{print $6}' | awk -F "." '{print $1}'`;
export v_sid=$1
export DATE=`/bin/date '+%Y-%m-%d_%H:%M'`
export LOGFILE=/tmp/adjust_sga_${ORACLE_SID}_${DATE}.log
export os_alloc_percent=0.80 

exec > >(tee -a $LOGFILE)
echo LOGFILE Is: $LOGFILE

. oraenv << EOF1
${v_sid}
EOF1

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

## Check parameters
if [ -z $v_sid ]; then
    echo Usage: $0 "<ORACLE_SID>"
    exit 1
fi

os_memG ()
{ echo "(`grep MemTotal /proc/meminfo | awk '{print $2}'` /1024 )" | bc
}


# Set Additional DB Parameters
echo ++++++++++++++++++++++++++++++++
echo  DB Parameters
echo ++++++++++++++++++++++++++++++++
FAST_SIZE ()
{ echo "( `df -P /Fast_Recovery | awk 'NR==2 {print $2}'` /1024/1024 )" | bc
}

# oracle allocation
os_ora ()
{ echo "(`os_memG` * $os_alloc_percent)" | bc
}

#sga rounding /1
os_sga ()
{ echo "(`os_ora` * .80) /1" | bc
}

#db cache rounding /1
os_dcz ()
 { echo "(`os_sga` * .35)  /1" | bc
}

#shared pool rounding /1
os_spz ()
 { echo "(`os_sga` * .15 ) /1" | bc
}

if [ $SW_VER -ne 11 ]; then
    #pga >11g use one third, doubled for pga_limit
    os_pgz ()
    { echo "(`os_ora` * .20) * .333 /1" | bc
    }
else
    #pga 11g does not have pga_limit
    os_pgz ()
    { echo "(`os_ora` * .80 /1" | bc
    }
fi

os_pgzlim ()
 { echo "(`os_pgz` * 2 )" | bc
}

if [ `os_pgzlim` -le 3096 ]; then
    os_pgzlimz=3096
    else 
    os_pgzlimz=`os_pgzlim`
fi

os_alloc_percent2=`echo "($os_alloc_percent * 100)" | bc`

echo Total Memory GB `os_memG`
echo "Memory allocation % is:" $os_alloc_percent2
echo SGA MB `os_sga`
echo Buffer Cache MB `os_dcz`
echo Shared Pool MB `os_spz`
echo PGA Target MB `os_pgz`
if [ $SW_VER -ne 11 ]; then
echo PGA Aggregate Limit MB $os_pgzlimz
else
echo "PGA Aggregate Limit will not be set"
fi

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set db_recovery_file_dest_size
alter system set db_recovery_file_dest_size=`FAST_SIZE`G scope=spfile sid='*';

Prompt set java_pool_size
alter system set java_pool_size=32M scope=spfile sid='*';

Prompt set large_pool_size
alter system set large_pool_size=64M scope=spfile sid='*';
EOF

echo Set SGA_Target
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set sga_target
alter system set sga_target=`os_sga`M scope=spfile sid='*';
EOF

echo Set SGA_Max_Size
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set sga_max_size
alter system set sga_max_size=`os_sga`M scope=spfile sid='*';
EOF

echo Set Shared_Pool_Size
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set shared_pool_size
alter system set shared_pool_size=`os_spz`M scope=spfile sid='*';
EOF

echo Set DB_Cache_Size
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set db_cache_size
alter system set db_cache_size=`os_dcz`M scope=spfile sid='*';
EOF

echo Set PGA_Aggregate_Target
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set pga_aggregate_target
alter system set pga_aggregate_target=`os_pgz`M scope=spfile sid='*';
EOF

# Restart the database
echo +++++++++++++++++++++++++++++++++++++++
echo Restarting the Database, please wait ..
echo +++++++++++++++++++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
-- Restart the Database
conn / as sysdba
shutdown immediate;
startup open;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

# Gather DB Stats
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo "Gathering Database, Dictionary, Function Based Index and Fixed Object Stats, please wait .."
echo "You may alternatively proceed and bring up the apps, whilst monitoring the stats gather in EM13c"
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
--Gather DB, FBI, Dictionary and Fixed Object stats
begin
dbms_stats.gather_database_stats(
cascade=> TRUE,
gather_sys=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 2,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_database_stats(
cascade=> TRUE,
gather_sys=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 2,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL HIDDEN COLUMNS SIZE 1',
options=> 'GATHER');

dbms_stats.gather_dictionary_stats(
cascade=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 2,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_fixed_objects_stats();
end;
/
EOF
