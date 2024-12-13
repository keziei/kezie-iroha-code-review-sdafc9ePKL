#!/bin/bash
#
#KI Create Database Schemas 
#KI added check for oracle user
#KI added execute on dbms_sql required for arcusr
#KI removed oracle_home param
#KI removed oracle_sid, added default password with expire

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
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

## Check oracle software is installed
if [ ! -x $ORACLE_HOME/bin/sqlplus ]; then
   echo "Could not find ORACLE_HOME! Please verify path to ORACLE_HOME"
   exit 1
fi

echo +++++++++++++++++++++++++++++++++++++++
echo Creating APPADMIN Database Schema ..
echo LOGFILE is $LOGFILE
echo +++++++++++++++++++++++++++++++++++++++

${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
CREATE USER APPADMIN PROFILE "DEFAULT" IDENTIFIED BY ${app_pass} DEFAULT TABLESPACE "USERS" TEMPORARY TABLESPACE "TEMP" PASSWORD EXPIRE; 
GRANT ALTER ANY OUTLINE TO APPADMIN;  
GRANT ALTER USER TO APPADMIN;
GRANT ALTER TABLESPACE TO APPADMIN; 
GRANT CONNECT TO APPADMIN with admin option;
GRANT CREATE ANY OUTLINE TO APPADMIN with admin option;
GRANT CREATE CLUSTER TO APPADMIN with admin option;
GRANT CREATE INDEXTYPE TO APPADMIN with admin option;
GRANT CREATE MATERIALIZED VIEW TO APPADMIN with admin option;
GRANT CREATE OPERATOR TO APPADMIN with admin option;
GRANT CREATE PROFILE TO APPADMIN with admin option;
GRANT CREATE PROCEDURE TO APPADMIN with admin option;
GRANT CREATE SEQUENCE TO APPADMIN with admin option;
GRANT CREATE SESSION TO APPADMIN with admin option;
GRANT CREATE SYNONYM TO APPADMIN with admin option;
GRANT CREATE TABLESPACE TO APPADMIN;
GRANT CREATE TABLE TO APPADMIN with admin option;
GRANT CREATE TRIGGER TO APPADMIN with admin option;
GRANT CREATE TYPE TO APPADMIN with admin option;
GRANT CREATE USER TO APPADMIN;
GRANT CREATE VIEW TO APPADMIN with admin option;
GRANT DROP ANY OUTLINE TO APPADMIN;
GRANT RESOURCE TO APPADMIN with admin option;;
GRANT SELECT ANY DICTIONARY TO APPADMIN with admin option;
GRANT SET CONTAINER TO APPADMIN with admin option;
GRANT UNLIMITED TABLESPACE TO APPADMIN with admin option;
GRANT EXECUTE ON sys.DBMS_SQL TO APPADMIN with grant option;
GRANT EXECUTE ON sys.DBMS_LOCK TO APPADMIN with grant option;
GRANT EXECUTE ON sys.DBMS_METADATA TO APPADMIN with grant option;    
GRANT GRANT ANY PRIVILEGE TO APPADMIN;
GRANT GRANT ANY OBJECT PRIVILEGE TO APPADMIN;
GRANT EXECUTE ANY PROCEDURE TO APPADMIN;
EOF

echo
echo "******************************** READ ME ********************************"
echo "Schema Created using default password: Temp7Change7Me#"
echo "Password is expired, so end user will need to change password via sqlplus"
echo "*************************************************************************"
