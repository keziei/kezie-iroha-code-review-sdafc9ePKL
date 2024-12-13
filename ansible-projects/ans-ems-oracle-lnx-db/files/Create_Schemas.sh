#!/bin/bash
#
#KI Create Database Schemas 
#KI added check for oracle user
#KI added execute on dbms_sql required for arcusr
#KI removed oracle_home param
#KI removed oracle_sid, added default password with expire

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
export app_schema=$1
export app_pass='Temp7Change7Me#'
export DATE=`/bin/date '+%Y-%m-%d_%H:%M'`
export LOGFILE=/tmp/create_${app_schema}_user_${DATE}.log
exec > >(tee -a $LOGFILE)

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
if [ -z $v_sid ] | [ -z $app_schema ]; then
    echo Usage: $0 "<SCHEMA_NAME> "
    exit 1
fi

## Check oracle software is installed
if [ ! -x $ORACLE_HOME/bin/sqlplus ]; then
   echo "Could not find ORACLE_HOME! Please verify path to ORACLE_HOME"
   exit 1
fi

echo +++++++++++++++++++++++++++++++++++++++
echo Creating $app_schema Database Schema ..
echo LOGFILE is $LOGFILE
echo +++++++++++++++++++++++++++++++++++++++

${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
prompt Creating bigfile tablespace ${app_schema}_DATA ..
CREATE BIGFILE TABLESPACE ${app_schema}_DATA DATAFILE '/U04/${ORACLE_SID}/oradata/${app_schema}_DATA_01.dbf' SIZE 50M AUTOEXTEND ON NEXT 256M MAXSIZE 40G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO
/
prompt Creating bigfile tablespace ${app_schema}_INDEX ..
CREATE BIGFILE TABLESPACE ${app_schema}_INDEX DATAFILE '/U04/${ORACLE_SID}/oradata/${app_schema}_INDEX_01.dbf' SIZE 50M AUTOEXTEND ON NEXT 256M MAXSIZE 40G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO
/
prompt Creating Database User: ${app_schema} ..
CREATE USER ${app_schema} PROFILE SERVICE_ACCOUNT IDENTIFIED BY ${app_pass} DEFAULT TABLESPACE ${app_schema}_DATA TEMPORARY TABLESPACE TEMP QUOTA UNLIMITED ON ${app_schema}_DATA QUOTA UNLIMITED ON ${app_schema}_INDEX ACCOUNT UNLOCK PASSWORD EXPIRE;

prompt Creating ${app_schema} Grants ..
GRANT CONNECT TO ${app_schema};
GRANT RESOURCE TO ${app_schema};
GRANT CREATE ANY OUTLINE TO ${app_schema};
GRANT CREATE CLUSTER TO ${app_schema};
GRANT CREATE INDEXTYPE TO ${app_schema};
GRANT CREATE MATERIALIZED VIEW TO ${app_schema};
GRANT CREATE OPERATOR TO ${app_schema};
GRANT CREATE PROFILE TO ${app_schema};
GRANT CREATE PROCEDURE TO ${app_schema};
GRANT CREATE SEQUENCE TO ${app_schema};
GRANT CREATE SESSION TO ${app_schema};    
GRANT CREATE SYNONYM TO ${app_schema};    
GRANT CREATE TABLE TO ${app_schema};
GRANT CREATE TRIGGER TO ${app_schema};
GRANT CREATE TYPE TO ${app_schema}; 
GRANT CREATE VIEW TO ${app_schema};   
GRANT SELECT ANY DICTIONARY TO ${app_schema};
GRANT SET CONTAINER TO ${app_schema};
GRANT UNLIMITED TABLESPACE TO ${app_schema};
GRANT EXECUTE ON sys.DBMS_SQL TO ${app_schema};
GRANT EXECUTE ON sys.DBMS_LOCK TO ${app_schema};
GRANT EXECUTE ON sys.DBMS_METADATA TO ${app_schema}; 
EOF

# Removal requested in JIRA: OTDS-9538
#
#echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#echo Creating Schema Gather Stats Procedure: exec ${app_schema}.RUN_DBSTAT 
#echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
#CREATE OR REPLACE PROCEDURE ${app_schema}.RUN_DBSTAT
#AS
#BEGIN
#   /* Activating Function Based Indexes */
#   FOR REC IN (SELECT DISTINCT TABLE_NAME FROM ALL_IND_EXPRESSIONS WHERE TABLE_OWNER='${app_schema}')
#   loop
#      DBMS_STATS.GATHER_TABLE_STATS(ownname=> '${app_schema}', tabname=>''||rec.table_name||'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, method_opt=>'FOR ALL HIDDEN COLUMNS SIZE 1',cascade=> TRUE, degree=> DBMS_STATS.AUTO_DEGREE);
#   end loop;
#
#    /* Statistics on the Content Server Schema */
#    DBMS_STATS.GATHER_SCHEMA_STATS(ownname=>'${app_schema}', 
#    cascade=> TRUE,
#    estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
#    degree=> DBMS_STATS.AUTO_DEGREE,
#    no_invalidate=> FALSE,
#    granularity=> 'AUTO',
#    method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
#    options=> 'GATHER');
#
#   DBMS_OUTPUT.PUT_LINE ('${app_schema} Schema and Function Based Index statistics gathered!');
#
#END;
#/
#EOF

echo
echo "******************************** READ ME ********************************"
echo "Schema Created using default password: Temp7Change7Me#"
echo "Password is expired, so end user will need to change password via sqlplus"
echo "*************************************************************************"
