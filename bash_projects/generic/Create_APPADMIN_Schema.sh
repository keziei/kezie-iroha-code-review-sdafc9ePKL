#!/bin/bash
#
# Author: Kezie Iroha Create Database Schemas
# Author: Kezie Iroha added check for oracle user
# Author: Kezie Iroha added execute on dbms_sql required for arcusr
# Author: Kezie Iroha removed oracle_home param
# Author: Kezie Iroha removed oracle_sid, added default password with expire

# Set environment paths
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin

# Validate input parameters (app_schema and v_sid)
app_schema=$1
v_sid=$(grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}')

if [[ -z "$app_schema" || -z "$v_sid" ]]; then
    echo "Usage: $0 <SCHEMA_NAME>"
    exit 1
fi

# Prompt for password securely (masking input)
read -sp "Enter password for schema $app_schema (or press Enter for default 'ChangeMe'): " app_pass
app_pass=${app_pass:-'ChangeMe'}
echo # Ensure newline after password prompt

# Logging setup with timestamps
export DATE=$(date '+%Y-%m-%d_%H:%M')
export LOGFILE="/tmp/create_${app_schema}_user_${DATE}.log"
exec > >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee -a $LOGFILE)

# Source Oracle environment
. oraenv <<< "$v_sid"
if [[ $? -ne 0 ]]; then
    echo "Failed to set Oracle environment for SID: $v_sid"
    exit 1
fi

# Check if running as oracle user
if [[ $(whoami) != "oracle" ]]; then
    echo "$0: Should run as the oracle user"
    exit 1
fi

# Validate ORACLE_HOME and sqlplus existence
if [[ ! -x "$ORACLE_HOME/bin/sqlplus" ]]; then
    echo "Could not find ORACLE_HOME or sqlplus! Please verify ORACLE_HOME."
    exit 1
fi

# Log start of schema creation
echo +++++++++++++++++++++++++++++++++++++++
echo "Creating $app_schema Database Schema .."
echo "Log file is $LOGFILE"
echo +++++++++++++++++++++++++++++++++++++++

# Create tablespaces and user in Oracle
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
prompt Creating bigfile tablespace ${app_schema}_DATA ..
CREATE BIGFILE TABLESPACE ${app_schema}_DATA 
DATAFILE '/U04/${ORACLE_SID}/oradata/${app_schema}_DATA_01.dbf' 
SIZE 50M AUTOEXTEND ON NEXT 256M MAXSIZE 40G 
LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
/
prompt Creating bigfile tablespace ${app_schema}_INDEX ..
CREATE BIGFILE TABLESPACE ${app_schema}_INDEX 
DATAFILE '/U04/${ORACLE_SID}/oradata/${app_schema}_INDEX_01.dbf' 
SIZE 50M AUTOEXTEND ON NEXT 256M MAXSIZE 40G 
LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
/
prompt Creating Database User: ${app_schema} ..
CREATE USER ${app_schema} PROFILE SERVICE_ACCOUNT IDENTIFIED BY "${app_pass}" 
DEFAULT TABLESPACE ${app_schema}_DATA 
TEMPORARY TABLESPACE TEMP 
QUOTA UNLIMITED ON ${app_schema}_DATA 
QUOTA UNLIMITED ON ${app_schema}_INDEX 
ACCOUNT UNLOCK PASSWORD EXPIRE;

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

# Check for errors in SQL execution
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create schema or grant permissions for $app_schema."
    exit 1
fi

# Removal requested in JIRA: OTDS-9538
# (Add relevant code here if needed in the future)

# Summary message to user
echo
echo "******************************** READ ME ********************************"
echo "Schema $app_schema created with default password: ${app_pass}"
echo "Password is expired, and the end user will need to change it via sqlplus."
echo "*************************************************************************"
