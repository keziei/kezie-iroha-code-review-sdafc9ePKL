#!/bin/bash
# K Iroha
# Disable Daily Full Backup
# Enable Weekly L0/L1 backup strategy with logical checking, protected arch backups, block change tracking and oracle best practise for inc filesperset and section size
# Recovery window of 7 days
# Remove backup duplexing to disk to reduce customer storage billing. Single backup to disk has logical check

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
export DATE=`/bin/date '+%%Y-%%m-%%d_%%H:%%M'`
export SCRIPTDIR=/Export/staging/DBA_TOOLS/dba_scripts
export DBTOOLS=/Export/staging/DBA_TOOLS
export LOGFILE=/tmp/Modify_rman_${DATE}.log
#exec 1> >(tee -a $LOGFILE) 2>&1

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

. oraenv << EOF1
${v_sid}
EOF1

echo ++++++++++++++++++++++++++
echo Removing old full backups
echo ++++++++++++++++++++++++++
find /Fast_Recovery/$ORACLE_SID/ -name "DB_comp*" -type f | xargs rm -rf {} \;

echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo Creating Backup scripts in /Export/staging/DBA_TOOLS/dba_scripts
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
mkdir -p /Export/staging/DBA_TOOLS/dba_scripts/
mkdir -p /Fast_Recovery/$ORACLE_SID/rman_snap_cntrl/

# Set Rman config
echo +++++++++++++++++++++++++++++
echo Setting up RMAN configuration
echo +++++++++++++++++++++++++++++
echo Backup rman config if it pre-exists
mv ${SCRIPTDIR}/rman_config.rmn ${SCRIPTDIR}/rman_config.rmn.${DATE}
echo "An RMAN error will occur on versions <12c for command CONFIGURE RMAN OUTPUT TO KEEP. This can be ignored"
echo "--------------------------------------------------------------------------------------------------------"
echo "
run {
CONFIGURE CHANNEL DEVICE TYPE DISK CLEAR;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/Fast_Recovery/${ORACLE_SID}/%%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/Fast_Recovery/${ORACLE_SID}/%%U';
CONFIGURE MAXSETSIZE TO UNLIMITED;
CONFIGURE ENCRYPTION FOR DATABASE OFF;
CONFIGURE ENCRYPTION ALGORITHM 'AES128';
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/Fast_Recovery/$ORACLE_SID/rman_snap_cntrl/snap_$ORACLE_SID.cf';
CONFIGURE RMAN OUTPUT TO KEEP FOR 28 DAYS;
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DISK;
} " >> ${SCRIPTDIR}/rman_config.rmn
chmod 755 ${SCRIPTDIR}/rman_config.rmn
${ORACLE_HOME}/bin/rman "target / nocatalog" <<EOF
@${SCRIPTDIR}/rman_config.rmn
EOF

# Enable BCT
echo ++++++++++++++++++++++++++++++
echo Enabling Block Change Tracking
echo ++++++++++++++++++++++++++++++
mkdir -p /U04/${ORACLE_SID}/changetracking
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt seting create file dest for BCT
Prompt disable block change tracking
alter database disable block change tracking;
Prompt enable block change tracking
alter database enable block change tracking using file '/U04/${ORACLE_SID}/changetracking/bct_01.chg';
alter system set control_file_record_keep_time=16 scope=both sid='*';
EOF

## Old Full Backup
echo ++++++++++++++++++++++++++++++++
echo Creating Daily FULL Backup script
echo ++++++++++++++++++++++++++++++++
mv ${SCRIPTDIR}/comp_backup_$ORACLE_SID.sh ${SCRIPTDIR}/comp_backup_$ORACLE_SID.sh.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=$PATH:$ORACLE_HOME/bin
rman target / nocatalog @'${SCRIPTDIR}/full_backup_compressed_to_disk_${ORACLE_SID}.rmn'
" >> ${SCRIPTDIR}/comp_backup_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/comp_backup_$ORACLE_SID.sh

echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/full_backup_compressed_to_disk_$ORACLE_SID.rmn ${SCRIPTDIR}/full_backup_compressed_to_disk_$ORACLE_SID.rmn.${DATE}
echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_full_compressed.log' APPEND;
run {
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all completed before 'SYSDATE-3';
delete noprompt obsolete;
allocate channel ch01 type DISK;
backup as compressed backupset database format '/Fast_Recovery/${ORACLE_SID}/DB_comp_%%d_%%U_%%t_%%s' plus archivelog format '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%%d_%%U_%%t_%%s';
release channel ch01;
backup current controlfile format '/Fast_Recovery/${ORACLE_SID}/CFPRIM_comp_%%d_%%U_%%t_%%s';
backup current controlfile for standby format '/Fast_Recovery/${ORACLE_SID}/CFSTBY_comp_%%d_%%U_%%t_%%s';
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all completed before 'SYSDATE-3';
delete noprompt obsolete;
}" >> ${SCRIPTDIR}/full_backup_compressed_to_disk_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/full_backup_compressed_to_disk_$ORACLE_SID.rmn
#Backup script end

# L0 Backups
echo ++++++++++++++++++++++++++++++++++++++
echo Creating RMAN Weekly L0 Backup script
echo +++++++++++++++++++++++++++++++++++++++
echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.sh ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.sh.${DATE}
mv ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.rmn ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.rmn.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
rman target / nocatalog @'${SCRIPTDIR}/weekly_inc0_comp_backup_${ORACLE_SID}.rmn'
" >> ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.sh

echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_weekly_inc0_comp_backup.log' APPEND;
run {
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt obsolete;
allocate channel c1 type disk;
allocate channel c2 type disk;
backup check logical as compressed backupset incremental level 0 database tag 'LVL0_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL0_INCR_%%d_%%U_%%t_%%s';
backup check logical as compressed backupset archivelog all filesperset 32 not backed up delete input tag 'LVL0_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%%d_%%U_%%t_%%s';
delete noprompt obsolete;
release channel c1;
release channel c2;
}" >> ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.rmn

# L1 Backups
echo ++++++++++++++++++++++++++++++++++++++
echo Creating RMAN Daily L1 Backup script
echo +++++++++++++++++++++++++++++++++++++++
echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.sh ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.sh.${DATE}
mv ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.rmn ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.rmn.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
rman target / nocatalog @'${SCRIPTDIR}/daily_inc1_comp_backup_${ORACLE_SID}.rmn'
" >> ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.sh

echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_daily_inc1_comp_backup.log' APPEND;
run {
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt obsolete;
allocate channel c1 type disk;
allocate channel c2 type disk;
backup check logical as compressed backupset cumulative incremental level 1 database tag 'LVL1_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL1_INCR_%%d_%%U_%%t_%%s';
backup check logical as compressed backupset archivelog all filesperset 32 not backed up delete input tag 'LVL1_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%%d_%%U_%%t_%%s';
delete noprompt obsolete;
release channel c1;
release channel c2;
}" >> ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.rmn

# Merge Incremental Backups
echo +++++++++++++++++++++++++++++++++++++++++++++++++++
echo Creating RMAN Daily Merge Incremental Backup script
echo +++++++++++++++++++++++++++++++++++++++++++++++++++
echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.sh ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.sh.${DATE}
mv ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
rman target / nocatalog @'${SCRIPTDIR}/daily_inc_updated_backup_${ORACLE_SID}.rmn'
" >> ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.sh

echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_daily_inc_updated_backup.log' APPEND;
run {
crosscheck backup;  
crosscheck copy of database;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired copy of database;
delete noprompt expired archivelog all;
delete noprompt obsolete;
allocate channel c1 type disk;
allocate channel c2 type disk;
backup check logical as compressed backupset incremental level 1 copies=1 for recover of copy with tag 'LVL0_MERGE_INCR' database FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL0_MERGE_INCR_%%d_%%U_%%t_%%s';
recover copy of database with tag 'LVL0_MERGE_INCR' until time \"SYSDATE-3\" from tag 'LVL0_MERGE_INCR';
backup check logical as compressed backupset archivelog all not backed up 1 times delete input tag 'LVL0_MERGE_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%%d_%%U_%%t_%%s';
delete noprompt obsolete;
release channel c1;
release channel c2;
}" >> ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn

# Arch Backups
echo ++++++++++++++++++++++++++++++++++++++
echo Creating RMAN Archivelog Backup script
echo ++++++++++++++++++++++++++++++++++++++
echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.rmn ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.rmn.${DATE}
mv ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.sh ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.sh.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
export PATH=$PATH:$ORACLE_HOME/bin
rman target / nocatalog @'${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.rmn'
" >> ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.sh

echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_arch_backup_comp.log' APPEND;
run {
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all backed up 1 times to disk;
delete noprompt obsolete;
allocate channel c1 type DISK;
allocate channel c2 type DISK;
backup check logical as compressed backupset archivelog all filesperset 32 not backed up delete input tag 'DAY-ARCH' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%%d_%%U_%%t_%%s';
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all backed up 1 times to disk;
delete noprompt obsolete;
release channel c1;
release channel c2;
}" >> ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.rmn
#Arch Backup script end

#Backup existing crontab
echo Backing up existing crontab
crontab -l > /tmp/crontab_backup.{$DATE}
echo " " | crontab -

# Create crontab
echo +++++++++++++++++++++++++++++++++
echo Creating crontab for RMAN Backups
echo +++++++++++++++++++++++++++++++++
(crontab -l 2>/dev/null; echo "### DBA Team Oracle Crontab")| crontab -
(crontab -l 2>/dev/null; echo "#")| crontab -
(crontab -l 2>/dev/null; echo "# Weekly L0 Backup")| crontab -
(crontab -l 2>/dev/null; echo "0 2 * * 0 ${SCRIPTDIR}/weekly_inc0_comp_backup_$ORACLE_SID.sh")| crontab -
(crontab -l 2>/dev/null; echo "#")| crontab -
(crontab -l 2>/dev/null; echo "# Daily L1 Backup")| crontab -
(crontab -l 2>/dev/null; echo "0 2 * * 1-6 ${SCRIPTDIR}/daily_inc1_comp_backup_$ORACLE_SID.sh")| crontab -
(crontab -l 2>/dev/null; echo "#")| crontab -
(crontab -l 2>/dev/null; echo "# Hourly Archived Log Backup")| crontab -
(crontab -l 2>/dev/null; echo "00 7,18,20,22 * * * ${SCRIPTDIR}/arch_backup_comp_$ORACLE_SID.sh")| crontab -
(crontab -l 2>/dev/null; echo "#")| crontab -

echo
echo
echo RMAN Crontab has been set as follows
echo ------------------------------------
crontab -l
echo
