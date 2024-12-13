#!/bin/bash
#Author: Kezie Iroha Drop database and cleanup data file directories
#Author: Kezie Iroha Removed software removal, this will go in a separate software cleanup script

export ORACLE_SID=$1
export VERSION=$2

# Prompt for SYSDBA password securely
read -sp "Enter SYSDBA password: " SYSPASS
echo

# Logging setup with timestamps
export DATE=$(date '+%Y-%m-%d_%H:%M')
export LOGFILE="/tmp/Cleanup_Build_${DATE}.log"
exec > >(while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done | tee -a $LOGFILE)

# Check if running as oracle
WHOAMI=$(whoami)
if [ "$WHOAMI" != "oracle" ]; then
    echo "$0: Should run as the oracle user"
    exit 1
fi

# Check parameters and ensure valid version
if [[ -z "$ORACLE_SID" || -z "$VERSION" || ! "$VERSION" =~ ^(11G|12CR1|12CR2|18C|19C)$ ]]; then
    echo "Usage: $0 <ORACLE_SID> <11G|12CR1|12CR2|18C|19C>"
    echo "This cleanup script will remove the specified database and its backups!"
    exit 1
fi

# Set ORACLE_HOME based on version
case "$VERSION" in
    "11G") DB_HOME="/U01/app/oracle/product/11.2.0.4/db_1" ;;
    "12CR1") DB_HOME="/U01/app/oracle/product/12.1.0.2/db_1" ;;
    "12CR2") DB_HOME="/U01/app/oracle/product/12.2.0.1/db_1" ;;
    "18C") DB_HOME="/U01/app/oracle/product/18.0.0/db_1" ;;
    "19C") DB_HOME="/U01/app/oracle/product/19.0.0/db_1" ;;
esac

export ORACLE_HOME=$DB_HOME

# Validate ORACLE_HOME
if [ ! -d "$ORACLE_HOME" ]; then  
    echo "Error: Oracle Home not found at $ORACLE_HOME!"
    exit 1
fi

# Dropping database
echo "++++++++++++++++++++++++++++++++++++"
echo "Dropping database please wait..."
echo "Log file: $LOGFILE"
echo "++++++++++++++++++++++++++++++++++++"
${ORACLE_HOME}/bin/lsnrctl stop
${ORACLE_HOME}/bin/dbca -silent -deleteDatabase -sourceDB "$ORACLE_SID" -sysDBAUserName SYS -sysDBAPassword "$SYSPASS"

if [ $? -ne 0 ]; then
    echo "Error: Failed to delete the database $ORACLE_SID."
    exit 1
fi

# Clean up directories related to ORACLE_SID
echo "+++++++++++++++++++++++++++++++"
echo "Cleaning DB datafile directories"
echo "+++++++++++++++++++++++++++++++"
for dir in /U01 /U02 /U03 /U04 /U05 /U06 /Fast_Recovery /Export /$ORACLE_HOME/dbs /$ORACLE_HOME/network/admin; do
    find "$dir" -maxdepth 1 -name "*${ORACLE_SID}*" -ls -exec rm -rfv {} \;
done

# Backup crontab
echo "Backing up crontab to /tmp"
crontab -l > "/tmp/$(date +%Y%m%d).crontab"
echo " " | crontab -
