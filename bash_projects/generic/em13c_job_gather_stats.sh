#!/bin/bash
## Author: Kezie Iroha Gather Missing Oracle Stats

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
export DATE=`/bin/date '+%%Y-%%m-%%d_%%H:%%M'`
export LOGFILE=/tmp/gather_missing_stats_${ORACLE_SID}_${DATE}.log
#exec 1> >(tee -a $LOGFILE) 2>&1
#echo LOGFILE Is: $LOGFILE

. oraenv << EOF1
${v_sid}
EOF1

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

# Gather DB Stats
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo "Gathering Database, Dictionary, Function Based Index and Fixed Object Stats, please wait .."
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
options=> 'GATHER EMPTY');

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
