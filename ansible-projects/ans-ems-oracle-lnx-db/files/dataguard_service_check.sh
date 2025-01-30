#!/bin/bash
#######################################################################
#
# Kezie Iroha 2024
# script name: dataguard_service_check.sh
#
# program description:
# This script will check the role of the database and ensure any variation of HA (e.g., _HA, HA, ha, _ha) is running on the Primary
# and any variation of REP (e.g., _REP, REP, rep, _rep) is running on the standby.
# Additionally, it checks if all services defined in the listener.ora file are running, and attempts to start any that are not using dbms_service.start_service('service_name').
# It also validates service status using the ALL_SERVICES or CDB_SERVICES view.
#

# Determine Oracle Home and SID
export ORACLE_SID=$(ps -ef | grep -oP 'ora_pmon_\K\w+' | grep -v grep)
[ -z "$ORACLE_SID" ] && { echo "No instance found"; exit 1; }
export ORACLE_HOME=$(grep -oP "^$ORACLE_SID:\K[^:]*" /etc/oratab)
[ -z "$ORACLE_HOME" ] && { echo "Oracle Home not found for SID $ORACLE_SID"; exit 1; }
export PATH=$ORACLE_HOME/bin:$PATH

# Function to set Oracle environment
set_oraenv() {
  ORAENV_ASK=NO
  . /usr/local/bin/oraenv
}

# Function to determine if database is CDB
is_cdb() {
  sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT cdb FROM v\$database;
EXIT;
EOF
}

# Function to get services from ALL_SERVICES or CDB_SERVICES
get_services() {
  local services
  local is_cdb_result

  is_cdb_result=$(is_cdb)

  if [[ "$is_cdb_result" == "YES" ]]; then
    services=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT NETWORK_NAME FROM CDB_SERVICES WHERE PDB IS NOT NULL AND CON_ID > 2;
EXIT;
EOF
)
  else
    services=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT NETWORK_NAME FROM ALL_SERVICES;
EXIT;
EOF
)
  fi

  echo "$services"
}

# Function to check HA and REP services
check_ha_rep_services() {
  local services
  local db_role
  local status="OK"

  db_role=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT database_role FROM v\$database;
EXIT;
EOF
)

  services=$(get_services)

  if [[ "$db_role" == "PRIMARY" ]]; then
    echo "$services" | grep -i -E "(_HA|HA|ha|_ha)" >/dev/null
    if [[ $? -ne 0 ]]; then
      echo "Alert: HA service not running on PRIMARY"
      status="ERROR"
    fi
    echo "$services" | grep -i -E "(_REP|REP|rep|_rep)" >/dev/null
    if [[ $? -eq 0 ]]; then
      echo "Alert: REP service running on PRIMARY"
      status="ERROR"
    fi
  elif [[ "$db_role" == "PHYSICAL STANDBY" ]]; then
    echo "$services" | grep -i -E "(_REP|REP|rep|_rep)" >/dev/null
    if [[ $? -ne 0 ]]; then
      echo "Alert: REP service not running on PHYSICAL STANDBY"
      status="ERROR"
    fi
    echo "$services" | grep -i -E "(_HA|HA|ha|_ha)" >/dev/null
    if [[ $? -eq 0 ]]; then
      echo "Alert: HA service running on PHYSICAL STANDBY"
      status="ERROR"
    fi
  else
    echo "Unknown database role: $db_role"
    status="ERROR"
  fi

  echo "$status"
}

# Function to check all services defined in listener.ora
check_all_services() {
  local listener_ora_path="$1"
  if [[ ! -f "$listener_ora_path" ]]; then
    echo "Listener.ora file not found: $listener_ora_path"
    exit 1
  fi

  local services
  services=$(grep -oP 'SERVICE_NAME\s*=\s*\K\S+' "$listener_ora_path")

  local status="OK"

  for service in $services; do
    lsnrctl status | grep -i "^Service\s\"$service\"" >/dev/null
    if [[ $? -ne 0 ]]; then
      echo "Service $service is not running, attempting to start it."
      sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
EXEC DBMS_SERVICE.START_SERVICE('$service');
EXIT;
EOF
      if [[ $? -ne 0 ]]; then
        echo "Failed to start service $service"
        status="ERROR"
      fi
    fi

    # Validate service status using ALL_SERVICES view
    local service_status
    service_status=$(sqlplus -s / as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM ALL_SERVICES WHERE SERVICE_NAME = '$service';
EXIT;
EOF
)
    if [[ "$service_status" -eq 0 ]]; then
      echo "Service $service does not appear in ALL_SERVICES view, indicating it is not running."
      status="ERROR"
    fi
  done

  echo "$status"
}

# Main script execution
check_type="$1"
listener_ora_path="${2:-$ORACLE_HOME/network/admin/listener.ora}"

if [[ "$check_type" == "check_ha_rep_services" ]]; then
  set_oraenv
  status=$(check_ha_rep_services)
elif [[ "$check_type" == "check_all_services" ]]; then
  set_oraenv
  status=$(check_all_services "$listener_ora_path")
else
  echo "Invalid argument. Use 'check_ha_rep_services' or 'check_all_services'."
  exit 1
fi

# Exit with appropriate code
if [ "$status" = "OK" ]; then
  exit 0
else
  exit 1
fi
