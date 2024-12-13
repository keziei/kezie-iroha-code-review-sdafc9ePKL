#!/bin/bash
# Kezie Iroha v0.1 25/01/2024 - This has not been tested yet

# Input file containing the list of hosts
HOSTS_FILE="hosts_list.txt"

# Path to the oracle environment script
ORAENV_PATH="/usr/local/bin/oraenv"

# Log directory
LOG_DIR="/tmp"
DATE=$(date '+%Y-%m-%d_%H:%M')
LOGFILE="${LOG_DIR}/check_oracle_service_${DATE}.log"

# Oracle port
ORACLE_PORT=1521

# Function to check host accessibility
check_host_accessibility() {
    ping -c 1 $1 &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Host $1 Accessible"
    else
        echo "Host $1 is Not Accessible"
        exit 1
    fi
}

# Function to check Oracle listener accessibility
check_listener() {
    nc -z -w3 $1 $ORACLE_PORT &>/dev/null
    if [ ! $? -eq 0 ]; then
        echo "Host $1 is not accessible on port $ORACLE_PORT"
        exit 1
    fi

    tnsping_output=$(ssh oracle@$1 "tnsping localhost $ORACLE_PORT")
    if [[ $tnsping_output == *"OK (0 msec)"* ]]; then
        echo "Tnsping OK"
    else
        echo "Tnsping Failed"
        exit 1
    fi
}

# Function to get Oracle connection count summary
get_connection_count_summary() {
    ssh oracle@$1 /bin/bash << EOF
        export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
        export ORACLE_SID=\$(grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print \$1}')
        source $ORAENV_PATH << EOF1
        \$ORACLE_SID
EOF1
        sqlplus -s / as sysdba << EOF2
        set lines 1000 pages 200
        col machine for a50
        col username for a20
        col service_name for a15
        col osuser for a10
        select machine, osuser, username, service_name, count(*) num_connections
        from v\$session
        group by machine, osuser, username, service_name order by 2 asc;
EOF2
EOF
}

# Main script execution
exec > >(tee -a $LOGFILE) 2>&1

while read -r host; do
    echo "Checking host: $host"
    check_host_accessibility $host
    check_listener $host
    get_connection_count_summary $host
done < $HOSTS_FILE

echo "Script execution completed. Check logs in $LOGFILE"

