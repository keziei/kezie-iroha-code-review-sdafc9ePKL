#!/bin/bash
# Create and Configure a database after software installation
# Author: Kezie Iroha Kezie Iroha, DBA Team
# Author: Kezie Iroha v1.01 Initial Script
# Author: Kezie Iroha v1.02 Added Host Directory checks
# Author: Kezie Iroha v1.03 Added Audit Fix, DB/Dictionary/Fixed_Object stats, Auto Task schedule, and AWR schedule
# Author: Kezie Iroha v1.04 Removed Oracle SW Options SPATIAL/APEX, added DBA Users, add+deploy DBTOOLS (sqlt,sqlhc,TFA,oswatcher), added Listener Poisoning Fix, set minimum pool and cache sizes, set FRA size, added script log, added check /U01 meets EMS CRG standard
# Author: Kezie Iroha v1.05 Lock DBA accounts, they can be unlocked as sys - alter user <name> identified by <pass> account unlock;
# Author: Kezie Iroha v1.06 Added lime, modified fast_size, new input (DC/DB_Role required to deploy agent and set agent pass), new input syspass, added templates for 11.2,12.1,12.2
# Author: Kezie Iroha v1.061 Modified database memory calculation
# Author: Kezie Iroha v1.062 Added ORACLE_SID length and integer check
# Author: Kezie Iroha v1.063 Modified paths to have distinct db_unique_name
# Author: Kezie Iroha v1.064 added ram size memory allocation variations
# Author: Kezie Iroha v1.065 Modified ram size memory ratio in MB instead of GB to account for sizing gaps
# Author: Kezie Iroha v1.066 Added cleanup script to remove installed database cleanup.sh
# Author: Kezie Iroha v1.067 Removed Content Server BP params, Added Oracle 18c Software binary install and database build
# Author: Kezie Iroha v1.068 Added generic schema creation script Create_Schemas.sh
# Author: Kezie Iroha v1.0682 Added 19c database build, streams_pool now sets to 128M, (MOS 1314791.1, 2386566.1, 376022.1)
# Author: Kezie Iroha v1.0683 Added DBA Team Password Policy function, updated tools deploy for AHF and removed TFA
# Author: Kezie Iroha v1.0684 Removed DB deploy folder. Software is now staged by Pull_Software
# Author: Kezie Iroha v1.0685 Added Normal or Small build sizes, added exception to catch runaway failed build. Removed SYS and ORACLE_HOME password prompt. Ask for Version instead.
# Author: Kezie Iroha v1.0686 Added database autostart
# Author: Kezie Iroha v1.0687 removed EMLOC param
# Author: Kezie Iroha v1.0688 Added PSU Post Apply
# Author: Kezie Iroha v1.0689 removed lime user

unset ORACLE_SID
unset ORACLE_HOME
unset PATH
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin

export SRVROLE=`hostname -s | awk -F '-' '{print $3}'`
export VERSION=$1
export DB_SIZE=$2
export ORACLE_SID=$3
export dbown=oracle:oinstall
export DATE=`/bin/date '+%Y-%m-%d_%H:%M'`
export LC_ORACLE_SID=`echo ${ORACLE_SID} |tr '[A-Z]' '[a-z]'`
export SCRIPTDIR=/Export/staging/DBA_TOOLS/dba_scripts
export DBTOOLS=/Export/staging/DBA_TOOLS
export RAT_TMPDIR=/Export
export LOGFILE=/tmp/Database_Build_${DATE}.log
exec > >(tee -a $LOGFILE)

# Prompt for SYS password with default
read -sp "Enter SYS password (press Enter to use default 'ChangeMe'): " input_syspass
export SYSPASS=${input_syspass:-"ChangeMe"}
echo  # Ensures new line after password prompt

## set umask
umask 022

## check current os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

## Check parameters
if [ -z $VERSION ] || [ -z $DB_SIZE ] || [ -z $ORACLE_SID ] || [[ ! $VERSION =~ ^(11G|12CR1|12CR2|18C|19C)$ ]] || [[ ! $DB_SIZE =~ ^(NORMAL|SMALL)$ ]];
  then
    echo Usage: $0 "<11G|12CR1|12CR2|18C|19C> <NORMAL|SMALL> <ORACLE_SID>"
    echo ""
    echo "SID naming convention: https://confluence.kiroha.org/display/ED/EMS+Instance+Names"
    echo "ORACLE_SID should not begin with a number!"
    echo ""
    echo  "The minimum expected filesystem size for a Build Ops build is:
                /U01 50GB
                /U02 5GB (small build), 50GB (normal build)
                /U03 5GB (small build), 50GB (normal build)
                /U04 50GB
                /U05 80GB
                /U06 80GB (U06 archive dest excluded in small build)
                /Export 200GB
                /Fast_Recovery 50GB (small build), 180GB (normal build)"
    exit 1
fi

if [[ ${SRVROLE:0:1} == "p" ]];
    then ROLE="PROD"
elif [[ ${SRVROLE:0:1} =~ ^(a|b|d|l|m|q|r|s|t|x|y|z)$ ]];  
    then ROLE="DEV"
else
    echo "Could not determine server role"   
    exit 1 
fi 

echo "Server Role is $ROLE"
echo "++++++++++++++++++++"

# Set ORACLE_HOME
if [[ $VERSION == "11G" ]];
    then DB_HOME="/U01/app/oracle/product/11.2.0.4/db_1"
elif [[ $VERSION == "12CR1" ]];
    then DB_HOME="/U01/app/oracle/product/12.1.0.2/db_1" 
elif [[ $VERSION == "12CR2" ]];
    then DB_HOME="/U01/app/oracle/product/12.2.0.1/db_1"    
elif [[ $VERSION == "18C" ]];
    then DB_HOME="/U01/app/oracle/product/18.0.0/db_1"
elif [[ $VERSION == "19C" ]];
    then DB_HOME="/U01/app/oracle/product/19.0.0/db_1"
fi 

export ORACLE_HOME=$DB_HOME
export SW_VER=`echo $ORACLE_HOME | awk -F "/" '{print $6}'`;
export ORACLE_VER=$SW_VER

if [ `echo ${#ORACLE_SID}` -gt 8 ]; then
  echo "ORACLE_SID should not be longer than eight characters"
  exit 1 
fi

#if [ `echo $ORACLE_SID | awk '{print substr ($0,0,1)}'`  -ge 0 ]; then
#  echo "ORACLE_SID should not begin with a number"
#  exit 1
#fi

## Check oracle software is installed
if [ ! -x $ORACLE_HOME/bin/sqlplus ]; then
   echo "Could not find ORACLE_HOME! Please verify path to ORACLE_HOME"
   exit 1
fi

## Check /U02 Size
U02_CRG() {
echo "( `df -P /U02 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [ `U02_CRG` -lt 4 ] ;
then
echo "The /U02 directory requires at least 5GB. Please size according to Cloud EMS CRG specification"
exit 1
fi

## Check /U03 Size
U03_CRG() {
echo "( `df -P /U03 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [ `U03_CRG` -lt 4 ] ;
then
echo "The /U03 directory requires at least 5GB. Please size according to Cloud EMS CRG specification"
exit 1
fi

## Check /U04 Size
U04_CRG() {
echo "( `df -P /U04 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [ `U04_CRG` -lt 45 ] ;
then
echo "The /U04 directory requires at least 50GB. Please size according to Cloud EMS CRG specification"
exit 1
fi

## Check /U05 Size
U05_CRG() {
echo "( `df -P /U05 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [ `U05_CRG` -lt 30 ] ;
then
echo "The /U05 directory requires at least 35GB. Please size according to Cloud EMS CRG specification"
exit 1
fi

## Check /U06 Size
U06_CRG() {
echo "( `df -P /U06 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [[ $DB_SIZE == "NORMAL" && `U06_CRG` -lt 30 ]];
then
echo "The /U06 directory requires at least 35GB for a NORMAL build. Please size according to Cloud EMS CRG specification"
echo "If this is not a NORMAL build, then specify SMALL in your build syntax or refer to a DBA"
exit 1
fi

## Check /Fast_Recovery Size
FAST_REC() {
echo "( `df -P /Fast_Recovery | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
}

if [ `FAST_REC` -lt 50 ] ;
then
echo "The /Fast_Recovery directory does not have adequate space. This should be sized to at least the sum GB of: (U02 + U03 + U04 * 4 ) "
exit 1
fi

## Check directories are owned by oracle
if [[ $DB_SIZE == "NORMAL" && `stat -c %U /U01` != "oracle" && `stat -c %U /U02` != "oracle" && `stat -c %U /U03` != "oracle" && `stat -c %U /U04` != "oracle" && `stat -c %U /U05` != "oracle" && `stat -c %U /U06` != "oracle" && `stat -c %U /Export` != "oracle" && `stat -c %U /Fast_Recovery` != "oracle" ]];
   then
   echo "Required NORMAL build directory has incorrect ownership"
   echo "The owner of the following directories should be the oracle user:
                /U01
                /U02
                /U03
                /U04
                /U05
                /U06
                /Export
                /Fast_Recovery "
exit 1
elif [[ $DB_SIZE == "SMALL" && `stat -c %U /U01` != "oracle" && `stat -c %U /U02` != "oracle" && `stat -c %U /U03` != "oracle" && `stat -c %U /U04` != "oracle" && `stat -c %U /U05` != "oracle" && `stat -c %U /Export` != "oracle" && `stat -c %U /Fast_Recovery` != "oracle" ]];
   then
   echo "Required SMALL build directory has incorrect ownership"
   echo "The owner of the following directories should be the oracle user:
                /U01
                /U02
                /U03
                /U04
                /U05
                /Export
                /Fast_Recovery "
exit 1
fi

## Check required directories exist
if [[ $DB_SIZE == "NORMAL" && ! -d /U01 && ! -d /U02 && ! -d /U03 && ! -d /U04 && ! -d /U05 && ! -d /U06 && ! -d /Export && ! -d /Fast_Recovery ]];
   then
   echo "A required directory is missing"
   echo "Required directories for a NORMAL build are
        /U01
        /U02
        /U03
        /U04
        /U05
        /U06
        /Export
        /Fast_Recovery "
  exit 1
elif [[ $DB_SIZE == "SMALL" && ! -d /U01 && ! -d /U02 && ! -d /U03 && ! -d /U04 && ! -d /U05 && ! -d /U06 && ! -d /Export && ! -d /Fast_Recovery ]];
   then
   echo "A required directory is missing"
   echo "Required directories for a SMALL build are
        /U01
        /U02
        /U03
        /U04
        /U05
        /Export
        /Fast_Recovery "
  exit 1
fi

## create sub directories for normal database
if [[ $DB_SIZE == "NORMAL" ]];
   then
      echo Creating normal structures and permissions 
      mkdir -p /U01/${ORACLE_SID}/cntrl
      mkdir -p /U02/${ORACLE_SID}/cntrl
      mkdir -p /U03/${ORACLE_SID}/cntrl
      mkdir -p /U02/${ORACLE_SID}/redo
      mkdir -p /U03/${ORACLE_SID}/redo
      mkdir -p /U04/${ORACLE_SID}/oradata
      mkdir -p /U04/${ORACLE_SID}/changetracking
      mkdir -p /U05/${ORACLE_SID}/archivelog_dest_1
      mkdir -p /U06/${ORACLE_SID}/archivelog_dest_2
      mkdir -p /Export/${ORACLE_SID}/export
      mkdir -p /Export/staging/Oracle_Binary
      mkdir -p /Export/staging/DBA_TOOLS
      mkdir -p /Fast_Recovery/${ORACLE_SID}/CONTROLFILE
      chown ${dbown} -R /U01/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U02/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U03/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U02/${ORACLE_SID}/redo
      chown ${dbown} -R /U03/${ORACLE_SID}/redo
      chown ${dbown} -R /U04/${ORACLE_SID}/oradata
      chown ${dbown} -R /U04/${ORACLE_SID}/changetracking
      chown ${dbown} -R /U05/${ORACLE_SID}/archivelog_dest_1
      chown ${dbown} -R /U06/${ORACLE_SID}/archivelog_dest_2
      chown ${dbown} -R /Fast_Recovery/${ORACLE_SID}/CONTROLFILE
      chown ${dbown} -R /Export/${ORACLE_SID}/export 
elif [[ $DB_SIZE == "SMALL" ]];
   then
      echo Creating small directory structures and permissions
      mkdir -p /U01/${ORACLE_SID}/cntrl
      mkdir -p /U02/${ORACLE_SID}/cntrl
      mkdir -p /U03/${ORACLE_SID}/cntrl
      mkdir -p /U02/${ORACLE_SID}/redo
      mkdir -p /U03/${ORACLE_SID}/redo
      mkdir -p /U04/${ORACLE_SID}/oradata
      mkdir -p /U04/${ORACLE_SID}/changetracking
      mkdir -p /U05/${ORACLE_SID}/archivelog_dest_1
      mkdir -p /Export/${ORACLE_SID}/export
      mkdir -p /Export/staging/Oracle_Binary
      mkdir -p /Export/staging/DBA_TOOLS
      mkdir -p /Fast_Recovery/${ORACLE_SID}/CONTROLFILE
      chown ${dbown} -R /U01/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U02/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U03/${ORACLE_SID}/cntrl
      chown ${dbown} -R /U02/${ORACLE_SID}/redo
      chown ${dbown} -R /U03/${ORACLE_SID}/redo
      chown ${dbown} -R /U04/${ORACLE_SID}/oradata
      chown ${dbown} -R /U04/${ORACLE_SID}/changetracking
      chown ${dbown} -R /U05/${ORACLE_SID}/archivelog_dest_1
      chown ${dbown} -R /Fast_Recovery/${ORACLE_SID}/CONTROLFILE
      chown ${dbown} -R /Export/${ORACLE_SID}/export 
      chown ${dbown} -R /Export/staging/Oracle_Binary
fi

#Update bash profile
echo Backing up and recreating bash_profile
mv ${HOME}/.bash_profile ${HOME}/.bash_profile.${DATE}
cat /dev/null > ${HOME}/.bash_profile
cat <<EOF > ~/.bash_profile
# Generated by build script ${DATE}
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin
export PATH

# Oracle Settings
export ORACLE_VER=`echo $SW_VER`
TMP=/tmp; export TMP
TMPDIR=$TMP; export TMPDIR
RAT_TMPDIR=/Export; export RAT_TMPDIR
ORACLE_BASE=/U01/app/oracle; export ORACLE_BASE
ORACLE_HOME=/U01/app/oracle/product/$ORACLE_VER/db_1; export ORACLE_HOME
ORACLE_SID=${ORACLE_SID}; export ORACLE_SID
RAT_ORACLE_HOME=$ORACLE_HOME; export RAT_ORACLE_HOME
RAT_UPGRADE_LOC=/Export/staging; export RAT_UPGRADE_LOC
RAT_INV_LOC=/U01/app/oraInventory; export RAT_INV_LOC
PERL_HOME=$ORACLE_HOME/perl; export PERL_HOME
ORACLE_TERM=xterm; export ORACLE_TERM
SCRIPTDIR=/Export/staging/DBA_TOOLS; export SCRIPTDIR
DBTOOLS=/Export/staging/DBA_TOOLS/dba_scripts; export DBTOOLS
AGENT_HOME=/U01/app/oracle/product/Agent13c/agent_inst; export AGENT_HOME
TFA_HOME=/Export/staging/DBA_TOOLS/AHF/oracle.ahf/ahf; export TFA_HOME
PATH=$ORACLE_HOME/bin:$PERL_HOME/bin:$ORACLE_HOME/OPatch:$TFA_HOME/bin:$AGENT_HOME/bin:$PATH; export PATH

LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib; export LD_LIBRARY_PATH
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib; export CLASSPATH

umask 0022
alias b='cd /U01/app/oracle/diag/rdbms/${LC_ORACLE_SID}/${ORACLE_SID}/trace/'
alias agent13c='cd /U01/app/oracle/product/Agent13c/agent_inst'
alias dbtools='cd /Export/staging/DBA_TOOLS'
alias dbscripts='cd /Export/staging/DBA_TOOLS/dba_scripts'
alias tfa='cd /Export/staging/DBA_TOOLS/AHF/oracle.ahf/ahf/bin'
alias toolstatus='/Export/staging/DBA_TOOLS/AHF/oracle.ahf/ahf/bin/tfactl toolstatus'
alias orachk=' /Export/staging/DBA_TOOLS/AHF/oracle.ahf/orachk/orachk -a'

echo "Oracle verison is:" \${ORACLE_VER}
echo "Oracle Home is:" \${ORACLE_HOME}
echo "DBA Scripts Location:" \${SCRIPTDIR}
echo 
echo "TFA Bundle runs as oracle, commands:"
echo  "/Export/staging/DBA_TOOLS/AHF/oracle.ahf/ahf/bin/tfactl toolstatus"
echo  " /Export/staging/DBA_TOOLS/AHF/oracle.ahf/orachk/orachk -a"
echo "Type alias to display shortcuts"
# End of file
EOF

## Memory alloction
os_memG ()
{ echo "(`grep MemTotal /proc/meminfo | awk '{print $2}'` /1024 )" | bc
}

if [ `os_memG` -le `echo "(5 * 1024)" | bc` ]; then
os_alloc_percent=0.5
elif [ `os_memG` -le `echo "(7 * 1024)" | bc` ]; then
os_alloc_percent=0.6
elif [ `os_memG` -le `echo "(9 * 1024)" | bc` ]; then
os_alloc_percent=0.62
elif [ `os_memG` -le `echo "(13 * 1024)" | bc` ]; then
os_alloc_percent=0.67
elif [ `os_memG` -le `echo "(19 * 1024)" | bc` ]; then
os_alloc_percent=0.75
elif [ `os_memG` -le `echo "(23 * 1024)" | bc` ]; then
os_alloc_percent=0.81
elif [ `os_memG` -le `echo "(27 * 1024)" | bc` ]; then
os_alloc_percent=0.84
elif [ `os_memG` -le `echo "(35 * 1024)" | bc` ]; then
os_alloc_percent=0.87
elif [ `os_memG` -le `echo "(69 * 1024)" | bc` ]; then
os_alloc_percent=0.90
elif [ `os_memG` -gt `echo "(69 * 1024)" | bc` ]; then
os_alloc_percent=0.93
fi

os_alloc_percent2=`echo "($os_alloc_percent * 100)" | bc`

### Database Creation
## Create the database
echo
echo Logfile for this Installation is ${LOGFILE}
echo
echo  ORACLE_HOME is: $ORACLE_HOME
echo  Default SYS/SYSTEM Password for this installation is: ${SYSPASS}
echo "====================================================================="
echo

## vary build by version
if [[ $SW_VER == "11.2.0.4" && $DB_SIZE == "NORMAL" ]];
  then
    echo Creating NORMAL Size 11204 Build ..
    RESPONSE=EMS_11204_SI.rsp
    TEMPLATE=EMS_11204_SI_NORMAL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "11.2.0.4" && $DB_SIZE == "SMALL" ]];
  then
    echo Creating SMALL Size 11204 Build ..
    RESPONSE=EMS_11204_SI.rsp
    TEMPLATE=EMS_11204_SI_SMALL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "12.1.0.2" && $DB_SIZE == "NORMAL" ]];
  then
    echo Creating NORMAL Size 12102 Build ..
    RESPONSE=EMS_12102_SI.rsp
    TEMPLATE=EMS_12102_SI_NORMAL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "12.1.0.2" && $DB_SIZE == "SMALL" ]];
  then
    echo Creating SMALL Size 12102 Build ..
    RESPONSE=EMS_12102_SI.rsp
    TEMPLATE=EMS_12102_SI_SMALL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "12.2.0.1" && $DB_SIZE == "NORMAL" ]];
  then
    echo Creating NORMAL Size 12201 Build ..
    RESPONSE=EMS_12201_SI.rsp
    TEMPLATE=EMS_12201_SI_NORMAL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "12.2.0.1" && $DB_SIZE == "SMALL" ]];
  then
    echo Creating SMALL Size 12201 Build ..
    RESPONSE=EMS_12201_SI.rsp
    TEMPLATE=EMS_12201_SI_SMALL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "18.0.0" && $DB_SIZE == "NORMAL" ]];
  then
    echo Creating NORMAL Size 18C Build ..
    RESPONSE=EMS_18000_SI.rsp
    TEMPLATE=EMS_18000_SI_NORMAL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "18.0.0" && $DB_SIZE == "SMALL" ]];
  then
    echo Creating SMALL Size 18C Build ..
    RESPONSE=EMS_18000_SI.rsp
    TEMPLATE=EMS_18000_SI_SMALL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "19.0.0" && $DB_SIZE == "NORMAL" ]];
  then
    echo Creating NORMAL Size 19C Build ..
    RESPONSE=EMS_19000_SI.rsp
    TEMPLATE=EMS_19000_SI_NORMAL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
elif [[ $SW_VER == "19.0.0" && $DB_SIZE == "SMALL" ]];
  then
    echo Creating SMALL Size 19C Build ..
    RESPONSE=EMS_19000_SI.rsp
    TEMPLATE=EMS_19000_SI_SMALL.dbt
    echo TEMPLATE used is ${TEMPLATE}
    echo RESPONSE file is ${RESPONSE}
    echo Database will be allocated $os_alloc_percent2 % of Memory in this configuration
    ${ORACLE_HOME}/bin/dbca -silent -responseFile ./${RESPONSE} -createDatabase -templateName ./${TEMPLATE}  -gdbName ${ORACLE_SID} -sysPassword ${SYSPASS} -systemPassword ${SYSPASS}
fi

# Verify Database Build
if [[ `ps -ef | grep pmon | grep -v grep | wc -l` -lt 1 ]];
  then
    echo "Oracle Database Build Failed .."
    echo "Please review database log in /tmp"
    exit 1
fi

# Create Listener.ora
echo Backup existing Listener.ora
mv ${ORACLE_HOME}/network/admin/listener.ora ${ORACLE_HOME}/network/admin/listener.ora.${DATE}
echo Creating Listener.ora
cat <<EOF >/${ORACLE_HOME}/network/admin/listener.ora
# Generated by ems_dba_build ${DATE}
LISTENER =
  (ADDRESS_LIST =
        (ADDRESS= (PROTOCOL= TCP)(HOST=`hostname -f`)(Port= 1521)(QUEUESIZE=2048))
  )

SID_LIST_LISTENER =
   (SID_LIST=
        (SID_DESC=
          (SID_NAME=${ORACLE_SID})
          (ORACLE_HOME=${ORACLE_HOME})
         )
    )

ADR_BASE_LISTENER = /U01/app/oracle
VALID_NODE_CHECAuthor: Kezie IrohaNG_REGISTRATION_LISTENER=LOCAL

# End of file
EOF

# Create tnsnames.ora
echo Backup existing tnsnames.ora
mv ${ORACLE_HOME}/network/admin/tnsnames.ora ${ORACLE_HOME}/network/admin/tnsnames.ora.${DATE}
echo Creating tnsnames.ora
cat <<EOF >/${ORACLE_HOME}/network/admin/tnsnames.ora
# Generated by ems_dba_build ${DATE}
LISTENER=
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = `hostname -f`)(PORT = 1521))
    )
  )

${ORACLE_SID} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = `hostname -f`)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = ${ORACLE_SID})
    )
  )

# End of file
EOF

# Create sqlnet.ora
echo Backup existing sqlnet.ora
mv ${ORACLE_HOME}/network/admin/sqlnet.ora ${ORACLE_HOME}/network/admin/sqlnet.ora.${DATE}
echo Creating sqlnet.ora
cat <<EOF > ${ORACLE_HOME}/network/admin/sqlnet.ora
# Generated by ems_dba_build ${DATE}

TCP.NODELAY=yes
SQLNET.EXPIRE_TIME=10

# End of file
EOF

# Starting Up Listener
echo Starting the new oracle listener
${ORACLE_HOME}/bin/lsnrctl start LISTENER

# Verify Listener Poisoning Fix is set
echo ++++++++++++++++++++++++++++++++++++++++++++++++++
echo Verifying Listener Poisoning fix - VNCR
echo Verify that valid_node_checking_registration=LOCAL
echo ++++++++++++++++++++++++++++++++++++++++++++++++++
echo
echo
${ORACLE_HOME}/bin/lsnrctl show valid_node_checking_registration
echo
echo
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
Prompt Setting Local Listener
alter system set local_listener=LISTENER;
alter system register;
EOF

echo ++++++++++++++++++++++++++
echo Creating Database Profiles and Monitoring Users
echo ++++++++++++++++++++++++++
if [ $ROLE == "PROD" ]; then
snmp_pw=\"NotThePassword\$R0ck\"
elif [ $ROLE == "DEV" ] || [ $ROLE == "LAB" ]  ; then
snmp_pw=\"QANotThePassword\$R0ck\"
fi

${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
Prompt setting default dbsnmp pass ..
alter user dbsnmp identified by ${snmp_pw} account unlock;
EOF

echo Creating ot_ora_complexity_check and ot_verify_function procedures ..
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
@ot_ora_complexity_check.sql
@ot_verify_function.sql
EOF

${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
Prompt altering default profile ..
ALTER PROFILE default LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating service_account profile ..
CREATE PROFILE service_account LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time unlimited
 password_lock_time .0104
 password_reuse_max unlimited
 password_reuse_time unlimited
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating system_user profile ..
CREATE PROFILE system_user LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating normal_user profile ..
CREATE PROFILE normal_user LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt assign system users to profiles ..
GRANT EXECUTE ON ot_verify_function TO PUBLIC ;
Alter user system profile system_user;
Alter user sys profile system_user;
Alter user SYSMAN profile service_account;
Alter user DBSNMP profile service_account;
alter user MGMT_VIEW profile service_account;
EOF

echo +++++++++++++++++++++++
echo ++ Database Profiles ++
echo +++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
select distinct profile from dba_profiles;
EOF

#Create DBA Users
echo ++++++++++++++++++++++
echo Creating DBA Team Users
echo ++++++++++++++++++++++
for dbadmin in dba1 dba2 dba3
do $ORACLE_HOME/bin/sqlplus "/ as sysdba" <<EOF
CREATE USER ${dbadmin} PROFILE "DEFAULT" IDENTIFIED BY "NotThePassword$" DEFAULT TABLESPACE "USERS" TEMPORARY TABLESPACE "TEMP" PASSWORD EXPIRE ACCOUNT LOCK;
GRANT UNLIMITED TABLESPACE TO ${dbadmin};
GRANT "CONNECT" TO ${dbadmin};
GRANT "DBA" TO ${dbadmin};
GRANT "RESOURCE" TO ${dbadmin};
EOF
done
echo DBA Team users created

#Create APP Users
echo ++++++++++++++++++++++
echo Creating APPADMIN User
echo ++++++++++++++++++++++
$ORACLE_HOME/bin/sqlplus "/ as sysdba" <<EOF
CREATE USER APPADMIN PROFILE "DEFAULT" IDENTIFIED BY "${2:-'ChangeMe'}" DEFAULT TABLESPACE "USERS" TEMPORARY TABLESPACE "TEMP" PASSWORD EXPIRE;
GRANT CREATE USER TO APPADMIN;
GRANT CREATE TABLESPACE TO APPADMIN;
GRANT CREATE SESSION TO APPADMIN with admin option;        
GRANT CONNECT TO APPADMIN with admin option;
GRANT RESOURCE TO APPADMIN with admin option;    
GRANT CREATE ANY OUTLINE TO APPADMIN with admin option;
GRANT ALTER ANY OUTLINE TO APPADMIN with admin option;
GRANT DROP ANY OUTLINE TO APPADMIN with admin option;
GRANT CREATE MATERIALIZED VIEW TO APPADMIN with admin option;
GRANT CREATE PROCEDURE TO APPADMIN with admin option;
GRANT CREATE SEQUENCE TO APPADMIN with admin option;
GRANT CREATE TABLE TO APPADMIN with admin option;
GRANT CREATE TRIGGER TO APPADMIN with admin option;
GRANT CREATE TYPE TO APPADMIN with admin option;
GRANT CREATE VIEW TO APPADMIN with admin option;
GRANT CREATE CLUSTER TO APPADMIN with admin option;
GRANT CREATE OPERATOR TO APPADMIN with admin option;
GRANT CREATE INDEXTYPE TO APPADMIN with admin option;
GRANT SELECT ANY DICTIONARY TO APPADMIN with admin option;
GRANT SET CONTAINER TO APPADMIN with admin option;
GRANT UNLIMITED TABLESPACE TO APPADMIN with admin option;
GRANT EXECUTE ON sys.DBMS_SQL TO APPADMIN with grant option;
GRANT EXECUTE ON sys.DBMS_LOCK TO APPADMIN with grant option;
GRANT EXECUTE ON sys.DBMS_METADATA TO APPADMIN with grant option;
EOF
echo APPADMIN user created

#Set AUTO Task and AWR schedule
echo ++++++++++++++++++++++++++++++++++
echo Setting Auto Task and AWR Schedule
echo ++++++++++++++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
-- Enable DB Autotask Windows
Prompt Autotask windows
Rem
BEGIN
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => NULL);
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => NULL);
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => NULL);
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'THURSDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'THURSDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'THURSDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'FRIDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'FRIDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'FRIDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'SATURDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'SATURDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'SATURDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'SUNDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'SUNDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'SUNDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'MONDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'MONDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'MONDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'TUESDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'TUESDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'TUESDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto optimizer stats collection', operation => NULL, window_name => 'WEDNESDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'auto space advisor', operation => NULL, window_name => 'WEDNESDAY_WINDOW');
dbms_auto_task_admin.enable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'WEDNESDAY_WINDOW');
dbms_auto_task_admin.disable(client_name => 'auto space advisor', operation => NULL, window_name => 'NULL');
dbms_auto_task_admin.disable(client_name => 'sql tuning advisor', operation => NULL, window_name => 'NULL');
END;
/

-- Set AWR 60 day retention and 1hr snap interval
Prompt AWR schedule
Rem
begin DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(86400,60); end;
/
EOF

#Run Audit Fix
echo ++++++++++++++++++
echo Running Audit Fix
echo ++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
-- Run AUD Fix
set lines 100 pages 20
col table_name for a20
col segment_space_management for a30
select t.table_name,ts.segment_space_management from dba_tables t, dba_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$');

BEGIN
DBMS_AUDIT_MGMT.set_audit_trail_location(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD,--this moves table AUD$
audit_trail_location_value => 'SYSAUX');
END;
/

BEGIN
DBMS_AUDIT_MGMT.set_audit_trail_location(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD,--this moves table FGA_LOG$
audit_trail_location_value => 'SYSAUX');
END;
/

select t.table_name,ts.segment_space_management from dba_tables t, dba_tablespaces ts where ts.tablespace_name = t.tablespace_name and t.table_name in ('AUD$','FGA_LOG$');
EOF

# Gather DB Stats
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo Gathering Database, Dictionary and Fixed Object Stats, please wait ..
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
--Gather DB, Dictionary and Fixed Object stats
begin
dbms_stats.gather_database_stats(
cascade=> TRUE,
gather_sys=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 4,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_dictionary_stats(
cascade=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 4,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_fixed_objects_stats();
end;
/
EOF

# Set Additional DB Parameters
echo ++++++++++++++++++++++++++++++++
echo Setting Additional DB Parameters
echo ++++++++++++++++++++++++++++++++
FAST_SIZE ()
{ echo "( `df -P /Fast_Recovery | awk 'NR==2 {print $2}'` /1024/1024 )" | bc
}

#sga rounding /1
os_sga ()
{ echo "(`os_memG` * $os_alloc_percent) * .80 /1" | bc
}

#db cache rounding /1
os_dcz ()
 { echo "(`os_sga` * .35 ) /1" | bc
}

#shared pool rounding /1
os_spz ()
 { echo "(`os_sga` * .15 ) /1" | bc
}

if [ $SW_VER -ne 11 ]; then
    #pga >11g use one third, doubled for pga_limit. That is, 1/3 pga_aggregate_target, 2/3 pga_limit
    os_pgz ()
    { echo "(`os_memG` * $os_alloc_percent) * .20 * .333 /1" | bc
    }
else
    #pga 11g does not have pga_limit
    os_pgz ()
    { echo "(`os_memG` * $os_alloc_percent) * .20 /1" | bc
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

# Adjust memory pools
# Streams pool set to 150M, (MOS 1314791.1, 2386566.1, 376022.1)
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set db_recovery_file_dest_size
alter system set db_recovery_file_dest_size=`FAST_SIZE`G scope=spfile sid='*';

Prompt set java_pool_size
alter system set java_pool_size=32M scope=spfile sid='*';

Prompt set large_pool_size
alter system set large_pool_size=128M scope=spfile sid='*';

Prompt set streams_pool_size
alter system set streams_pool_size=128M scope=spfile sid='*';
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

echo Set DPDIR 
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set DPDIR 
create directory DPDIR as '/Export/${ORACLE_SID}/export';
EOF

echo "Enable block change tracking"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt set block change tracking
alter database enable block change tracking using file '/U04/${ORACLE_SID}/changetracking/bct_01.chg';
EOF

echo "Expire SYS/STSTEM and prompt to change post database creation"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt expiring default SYS/SYSTEM password
alter user sys password expire;
alter user system password expire;
EOF

# Restart the database
echo +++++++++++++++++++++++++++++++++++++++
echo Restarting the Database, please wait ..
echo +++++++++++++++++++++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
-- Restart the Database
conn / as sysdba
startup force;
EOF

# Create any other scripts
## Add Backup Script
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo Creating Backup scripts in /Export/staging/DBA_TOOLS/dba_scripts
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
mkdir -p /Export/staging/DBA_TOOLS/dba_scripts/
mkdir -p /Fast_Recovery/$ORACLE_SID/rman_snap_cntrl/

echo ++++++++++++++++++++++++++++++++
echo Creating RMAN FULL Backup script
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
backup as compressed backupset database format '/Fast_Recovery/${ORACLE_SID}/DB_comp_%d_%U_%t_%s' plus archivelog format '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%d_%U_%t_%s';
release channel ch01;
backup current controlfile format '/Fast_Recovery/${ORACLE_SID}/CFPRIM_comp_%d_%U_%t_%s';
backup current controlfile for standby format '/Fast_Recovery/${ORACLE_SID}/CFSTBY_comp_%d_%U_%t_%s';
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
backup check logical as compressed backupset incremental level 0 database tag 'LVL0_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL0_INCR_%d_%U_%t_%s';
backup check logical as compressed backupset archivelog all filesperset 32 not backed up delete input tag 'LVL0_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%d_%U_%t_%s';
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
backup check logical as compressed backupset cumulative incremental level 1 database tag 'LVL1_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL1_INCR_%d_%U_%t_%s';
backup check logical as compressed backupset archivelog all filesperset 32 not backed up delete input tag 'LVL1_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%d_%U_%t_%s';
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
crosscheck copy of database;
crosscheck archivelog all;
delete noprompt expired copy of database;
delete noprompt expired archivelog all;
delete noprompt obsolete;
allocate channel c1 type disk;
allocate channel c2 type disk;
backup check logical as compressed backupset incremental level 1 copies=1 for recover of copy with tag 'LVL0_MERGE_INCR' database FORMAT '/Fast_Recovery/${ORACLE_SID}/LVL0_MERGE_INCR_%d_%U_%t_%s';
recover copy of database with tag 'LVL0_MERGE_INCR' until time \"SYSDATE-3\" from tag 'LVL0_MERGE_INCR';
backup check logical as compressed backupset archivelog all not backed up 1 times delete input tag 'LVL0_MERGE_INCR' FORMAT '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%d_%U_%t_%s';
delete noprompt obsolete;
release channel c1;
release channel c2;
}" >> ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/daily_inc_updated_backup_$ORACLE_SID.rmn

echo ++++++++++++++++++++++++++++++++++++++
echo Creating RMAN Archivelog Backup script
echo ++++++++++++++++++++++++++++++++++++++
mv ${SCRIPTDIR}/arch_backup_$ORACLE_SID.sh ${SCRIPTDIR}/arch_backup_$ORACLE_SID.sh.${DATE}
echo "export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=$PATH:$ORACLE_HOME/bin
rman target / nocatalog @'${SCRIPTDIR}/archivelog_backup_compressed_$ORACLE_SID.rmn'
" >> ${SCRIPTDIR}/arch_backup_$ORACLE_SID.sh
chmod 755 ${SCRIPTDIR}/arch_backup_$ORACLE_SID.sh

echo Backup scripts if they pre-exist
mv ${SCRIPTDIR}/archivelog_backup_compressed_$ORACLE_SID.rmn ${SCRIPTDIR}/archivelog_backup_compressed_$ORACLE_SID.rmn.${DATE}
echo "spool log to '${SCRIPTDIR}/${ORACLE_SID}_archived_log_backup.log' APPEND;
run {
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all backed up 1 times to disk;
delete noprompt obsolete;
allocate channel ch01 type DISK;
backup as compressed backupset archivelog all format '/Fast_Recovery/${ORACLE_SID}/ARCH_comp_%d_%U_%t_%s' delete all input;
crosscheck backupset;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
delete noprompt archivelog all backed up 1 times to disk;
delete noprompt obsolete;
release channel ch01;
}" >> ${SCRIPTDIR}/archivelog_backup_compressed_$ORACLE_SID.rmn
chmod 755 ${SCRIPTDIR}/archivelog_backup_compressed_$ORACLE_SID.rmn
#Arch Backup script end

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
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/Fast_Recovery/${ORACLE_SID}/%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO BACKUPSET;
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/Fast_Recovery/${ORACLE_SID}/%U';
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

## Cleanup current dir
rm *.rmn

# Update oratab for auto start
echo +++++++++++++++++++++++++++++++++++++++
echo Updating oratab for database auto start
echo +++++++++++++++++++++++++++++++++++++++
cp -p /etc/oratab /tmp/oratab.{$DATE}
cp -p /etc/oratab /tmp/oratab.bak
sed -e 's/:N$/:Y/' /tmp/oratab.bak > /etc/oratab
rm -rf /tmp/oratab.bak

echo "================================================================="
echo "       Database Build Complete ... Commencing PSU Apply          "
echo "================================================================="
/bin/sleep 10

#######################################  Oracle PSU Post Patch Start  ################################################
oracle_patch_postInstall_12C ()
{ 
#=============================
# Oracle 12c Patch PostInstall
#=============================
echo +++++++++++++++++++++++++++++++++++++++
echo Starting in upgrade mode for PSU apply
echo +++++++++++++++++++++++++++++++++++++++
$ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup upgrade;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo ++++++++++++++++++++++++++++++++++++++
echo Running Post Patch SQL Install for 12c
echo ++++++++++++++++++++++++++++++++++++++
cd $ORACLE_HOME/OPatch
./datapatch -verbose

echo +++++++++++++++++++
echo Restarting database
echo +++++++++++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup open;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo +++++++++++
echo Recompiling
echo +++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
@?/rdbms/admin/utlrp;
@?/rdbms/admin/utlrp;
@?/rdbms/admin/utlrp;
EOF

echo +++++++++++++++++++++
echo Invalid object status
echo +++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt "Invalid DB Objects .."
select count(*) from dba_objects where status <> 'VALID';
Prompt "Invalid DB Registry .."
select count(*) from dba_registry where status ='INVALID';
EOF
}

oracle_patch_postInstall_11G ()
{ 
#=============================
# Oracle 11G Patch PostInstall
#=============================
echo ++++++++++++++++++++++++++++++++++++++
echo Starting in upgrade mode for PSU apply
echo ++++++++++++++++++++++++++++++++++++++
$ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup upgrade;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo +++++++++++++++++++++++++++
echo Starting 11G PSU SQL Apply
echo ++++++++++++++++++++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
@?/rdbms/admin/catbundle.sql psu apply
EOF

echo +++++++++++++++++++++++++++
echo Starting 11G JVM SQL Apply
echo ++++++++++++++++++++++++++++
PATCHGRP=`find /Export/staging/Oracle_Binary/Latest -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | awk -F '/' '{print $2}'`
SQPATCH=`find $ORACLE_HOME/sqlpatch -type d -printf '%P\n' | grep "$PATCHGRP"`
SQPATCHNUM=`ls $ORACLE_HOME/sqlpatch | grep "$PATCHGRP" | wc -l`

if [ $SQPATCHNUM -eq 0 ];
    then 
    echo "No SQL post patch identified in $ORACLE_HOME/sqlpatch"
    echo "Please verify that the patch JVM patch apply was successful and execute the post patch sql referenced in the post install notes"
    exit 1
elif [ $SQPATCHNUM -gt 1 ];
    then 
    echo "More than ONE SQL post patch identified in $ORACLE_HOME/sqlpatch for current PSU apply"
    echo "Please verify that the patch JVM patch apply was successful and execute the post patch sql referenced in the post install notes"
    exit 1
elif [[ $SQPATCHNUM -eq 1 && -f $ORACLE_HOME/sqlpatch/$SQPATCH/postinstall.sql ]];
    then
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    echo Executing JVM Post Install
    echo SQL Post apply patches found is: ${SQPATCHNUM}
    echo SQL Post apply patch is $ORACLE_HOME/sqlpatch/$SQPATCH
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    cd  $ORACLE_HOME/sqlpatch
    $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
    @$ORACLE_HOME/sqlpatch/$SQPATCH/postinstall.sql;
EOF
fi

echo +++++++++++++++++++
echo Restarting database
echo +++++++++++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup open;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo +++++++++++
echo Recompiling
echo +++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
@?/rdbms/admin/utlrp;
@?/rdbms/admin/utlrp;
@?/rdbms/admin/utlrp;
EOF

echo +++++++++++++++++++++
echo Invalid object status
echo +++++++++++++++++++++
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt "Invalid DB Objects .."
select count(*) from dba_objects where status <> 'VALID';
Prompt "Invalid DB Registry .."
select count(*) from dba_registry where status ='INVALID';
EOF

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Check the following log files in $ORACLE_HOME/cfgtoollogs/catbundle or $ORACLE_BASE/cfgtoollogs/catbundle for any errors:"
echo "catbundle_PSU_<database SID>_APPLY_<TIMESTAMP>.log"
echo "catbundle_PSU_<database SID>_GENERATE_<TIMESTAMP>.log"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

promote_targets ()
{ 
export MACHINE=`hostname -f`
export DC=`echo hostname -f | awk -F '.' '{print $5}'`
export AGT_VER=`/U01/app/oracle/product/Agent13c/agent_inst/bin/emctl status agent |grep "Agent Version" | awk -F ': ' '{print $2}'`
export AGENT_HOME=/U01/app/oracle/product/Agent13c/agent_$AGT_VER
export PATH=$AGENT_HOME/oracle_common/jdk/bin:/Export/staging/DBA_TOOLS/EMCLI:$PATH

if [ -z $AGT_VER ]; 
    then echo "EM13C Agent is not running, or installed"
    return 0
fi

if [ ! -d $AGENT_HOME/bin ];
    then echo "Cannot find EM13c Agent Home"
    return 0
fi	

if [[ "$MACHINE" =~ .*".eu".* ]];
        then SERVERLOC="EU"
elif [[ "$MACHINE" =~ .*".com".* ]];
        then SERVERLOC="NA"
else
        echo "EM13c targets will not be promoted for this target because host fqdn is not .com or .eu, could not determine deploy location"
        exit 1
fi

if [[ $ROLE == "PROD" ]]; then
    emcli_pw="NotThePassword"
elif [[ $ROLE == "DEV" ]]; then
    emcli_pw="ChangeMe"
fi

# Determine EM13c URL
if [ $SERVERLOC == 'EU' ] && [ $ROLE == 'DEV' ];
  then EMLOC=https://am3-d01.cloud.kiroha.org
elif [ $SERVERLOC == 'EU' ] && [ $ROLE == 'PROD' ];
  then EMLOC=https://am3-p01.cloud.kiroha.org
elif [ $SERVERLOC == 'NA' ] && [ $ROLE == 'DEV' ];
  then EMLOC=https://lit-d01.cloud.kiroha.org
elif [ $SERVERLOC == 'NA' ] && [ $ROLE == 'PROD' ];
  then EMLOC=https://lit-p01.cloud.kiroha.org
fi

echo ""
echo "Promoting database targets to $SERVERLOC $ROLE EM13c"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""

if [ -f /tmp/em_argfile.txt ]; then
rm /tmp/em_argfile.txt
fi

echo "
add_target -name=\"LISTENER_$MACHINE\" -type=\"oracle_listener\" -host=\"$MACHINE\" -properties=\"LsnrName:LISTENER;ListenerOraDir:$ORACLE_HOME/network/admin;Port:1521;OracleHome:$ORACLE_HOME;Machine:$MACHINE;\"
add_target -name=\"$ORACLE_SID\" -type=\"oracle_database\" -host=\"$MACHINE\" -credentials=\"UserName:dbsnmp;password:${snmp_pw};Role:Normal\" -properties=\"SID:$ORACLE_SID;Port:1521;OracleHome:$ORACLE_HOME;MachineName:$MACHINE;\"
add_target -name=\"${VERSION}HOME_$MACHINE\" -type=\"oracle_home\" -host=\"$MACHINE\" -properties=\"HOME_TYPE:O;INSTALL_LOCATION:$ORACLE_HOME;INVENTORY:/U01/app/oracle\"
" >> /tmp/em_argfile.txt

emcli login -username=sysman -password=${emcli_pw};
emcli sync;
emcli argfile /tmp/em_argfile.txt;
emcli logout  

echo "++++++++++++++++++++++++++++++++++"
echo "Database target promotion complete"
echo "++++++++++++++++++++++++++++++++++"
}

#====================================
#  Perform Patch Post Installation
#====================================
if [ $VERSION == "11G" ];
  then oracle_patch_postInstall_11G ;
else 
   oracle_patch_postInstall_12C ;
fi

echo
echo "==================================================================================="
echo "The Oracle Patch Set Update (PSU) Installation is complete. Log file is ${LOGFILE}"
echo "Review the install log to verify the installation of: Latest_PSU and Other_Patches."
echo
echo "The Following patches were applied from /Export/staging/Oracle_Binary/Latest_PSU :"
$ORACLE_HOME/OPatch/opatch lspatches
echo "==================================================================================="
echo
#========================
#  Promote EM13c targets
#========================
promote_targets;
echo


# Comments
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo                  Automated Build Complete 
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo
echo Logfile for this installation is ${LOGFILE}
echo --------------------------------------------------------------
echo
echo "The following settings are applied for 12c only: INMEMORY_FORCE=OFF, INMEMORY_QUERY=DISABLE"
echo "Additional DB Params:  https://jira.kiroha.org/browse/ECISDB-451"
echo
echo "NOTE 1:"
echo "Please Run an ORAchk assessment on this completed build:"
echo "----------------------------------------------------------------"
echo  /Export/staging/DBA_TOOLS/AHF/oracle.ahf/ahf/bin/tfactl toolstatus
echo   /Export/staging/DBA_TOOLS/AHF/oracle.ahf/orachk/orachk -a
echo
echo "NOTE 2:"
echo "If this database needs to be dropped, please Run the clean up script:  cleanup_database.sh"
echo "------------------------------------------------------------------------------------------"
echo
echo "NOTE 3: CREATE APP SCHEMAS"
echo "To create APP SCHEMAS please run the script: Create_Schemas.sh"
echo "--------------------------------------------------------------"
echo
echo "NOTE 4: DBA CHANGE SYS/SYSTEM PASSWORD"
echo "The default SYS/SYSTEM Password has been set to:" ${SYSPASS}
echo "--------------------------------------------------------------"
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo          PLEASE EXIT ORACLE SHELL AND LOG BACK IN
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo
echo Logfile for this installation is ${LOGFILE}
