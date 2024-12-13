#!/bin/bash
# Kezie Iroha, EMS_DBA
# Rollback patches
# Version updates:
# Author: Kezie Iroha v1.0 Initial Version

export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin
export SWLOC=/Export/staging/Oracle_Binary
export TOOLSDIR=/Export/staging/DBA_TOOLS
export EM13C_AGENT=/U01/app/oracle/product/Agent13c/agent_inst
export OTPROXY=https://artifactory.kiroha.org/artifactory/cloud-ops-dba-local
export AM3HTTP_PROXY=http://am3.kiroha.eu:8081/artifactory/cloud-ops-dba-local
export AM3HTTPS_PROXY=https://am3.kiroha.eu/artifactory/cloud-ops-dba-local
export WO3HTTP_PROXY=http://wo3.kiroha.eu:8081/artifactory/cloud-ops-dba-local
export LITHTTP_PROXY=http://kiroha.net:8081/artifactory/cloud-ops-dba-local
export LITHTTPS_PROXY=https://kiroha.net:8443/artifactory/cloud-ops-dba-local
export DATE=`/bin/date '+%Y%m%d_T%H%M'`
export MACHINE=`hostname -f`
export CUR_DIR=`readlink -f .`
export ORACLE_SID=""
export VERSION=""
export PATCH_AGE=""
export RAT_TMPDIR=/Export
export LOGFILE=/tmp/Existing_DB_PSU_Rollback_${DATE}.log
exec > >(tee -a $LOGFILE)

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

echo "Formating scripts ............."
BASEDIR=$(dirname "$0")
echo "$BASEDIR"
dos2unix Existing_DB_PSU_Apply.sh
dos2unix Existing_DB_PSU_Rollback.sh
chmod 755 Existing_DB_PSU_Apply.sh
chmod 755 Existing_DB_PSU_Rollback.sh
chown oracle:oinstall Existing_DB_PSU_Apply.sh
chown oracle:oinstall Existing_DB_PSU_Rollback.sh
echo "Formatting scripts complete .."
echo "++++++++++++++++++++++++++++++++++++++++"
echo ""

var_check ()
{
#======================
# Define Patch Activity
#======================
case $action in
NXfetch)
    if [ -z $ORACLE_SID ] || [ -z $VERSION ] || [ -z $PATCH_AGE ] || [[ ! $VERSION =~ ^(11G|12CR1|12CR2|18C|19C)$ ]];
    then
        echo Usage: $0 "-h <displays help>"
        exit 1
    else 
        echo "N-X PSU Program"
        echo "+++++++++++++++"
    fi

    NXvar='^[0-9]+$'
    if ! [[ $PATCH_AGE =~ $NXvar ]]; then
        echo "please enter a number for N-X <-n> argument"
        exit 1
    fi 

    if [[ $PATCH_AGE == 0 ]]; then
        PSU_FETCH='Latest'
    elif [[ $PATCH_AGE != 0 ]]; then
        PSU_FETCH="N-$PATCH_AGE"
    fi 
    ;;
Archivedfetch)
    if [ -z $ORACLE_SID ] || [ -z $VERSION ] || [ -z $ARCHIVE_PSU_FILE ] || [[ ! $VERSION =~ ^(11G|12CR1|12CR2|18C|19C)$ ]];
    then
        echo Usage: $0 "-h <displays help>"
        exit 1
    else 
        echo "Random Archived PSU Program"
        echo "+++++++++++++++++++++++++++"
    fi

    PSU_FETCH='PSU_Archive'
    ;;
esac

#================
# Set Oracle Env
#================
. oraenv <<EOF
$ORACLE_SID
EOF

## Check oracle software is installed
if [ ! -x $ORACLE_HOME/bin/sqlplus ]; then
   echo "Could not find ORACLE_HOME! Please verify the specified ORACLE_VERSION and ORACLE_SID"
   exit 1
fi

#=============
# Generic VAR
#=============
PSUSWDIR=$SWLOC/$PSU_FETCH
OPATCHDIR=$SWLOC
}

usage ()
{   echo ""
    echo "Usage:"
    echo $0 "-s <ORACLE_SID> -v <11G|12CR1|12CR2|18C|19C> [-n <0|1|2> OR -f <archived_psu_file.zip>] -M <Main Rollback>"
    echo ""
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Arg -n <patch_age NUMBER> OR -f <archived_psu.zip FILENAME> "
    echo "Specify <-n 0> to rollback Latest PSU"
    echo "Specify <-n 1|2|3|..99> to rollback N-1, N-2, N-3 PSU etc"
    echo ""
    echo "Specify <-f some_old_psu.zip> to rollback psu for that archived psu"
    echo
    echo "Patch Artifactory procedure:  https://confluence.kiroha.org/display/ED/Oracle+Artifactory+Patch+Staging"
    echo "Patch procedure: https://confluence.kiroha.org/display/ED/Oracle+Patch+Procedure"    
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo  
}

oracle_patch_stage ()
{
#========================
# Oracle Patch Stage
#========================
if [ -f $PSUSWDIR/*.zip ]; then
    cd $PSUSWDIR
    for x in $PSUSWDIR/*.zip; do unzip -qq -o $x; done;
fi

if [ -f ${SWLOC}/Other_Patches/*.zip ]; then
    cd ${SWLOC}/Other_Patches
    for x in ${SWLOC}/Other_Patches/*.zip; do unzip -qq -o $x; done;
fi
}

oracle_patch_rollback () 
{
oracle_patch_stage ;

#======================
# Oracle Patch Rollback
#======================    
echo
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Shutting down EM_Agent, database and listener"
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Stopping Agent"
echo "+++++++++++++"
$EM13C_AGENT/bin/emctl stop agent
echo
echo "Stopping Listener"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/lsnrctl stop
echo
echo "Stopping database"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
startup force;
EOF

$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
EOF

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Rolling back $PSU_FETCH PSU for $VERSION ... "
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo
cd $PSUSWDIR
# Commence Patch Rollback
if [ $VERSION == "11G" ];
then
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    PATCHID=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | awk -F '/' '{print $2}'`
    for patch in ${PATCHID}
    #do cd $PSUSWDIR/$patch; $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME -ocmrf $CUR_DIR/ocm.rsp
    do $ORACLE_HOME/OPatch/opatch rollback -id $patch -local -silent -OH $ORACLE_HOME
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Rollback complete"
else
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    PATCHID=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | awk -F '/' '{print $2}'`
    for patch in ${PATCHID}
    #do cd $PSUSWDIR/$patch; $ORACLE_HOME/OPatch/opatch rollback -id $patch -local -silent -OH $ORACLE_HOME 
    do $ORACLE_HOME/OPatch/opatch rollback -id $patch -local -silent -OH $ORACLE_HOME 
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Rollback complete"
fi

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Starting EM_Agent, database and listener"
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Starting Agent"
echo "+++++++++++++"
$EM13C_AGENT/bin/emctl start agent
echo
echo "Starting Listener"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/lsnrctl start
echo
echo "Starting database"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
startup open;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF
}

oracle_patch_postRollback_11G ()
{ 
#========================
# Oracle Patch PostInstall
#========================
echo +++++++++++++++++++++++++++++
echo Starting 11G PSU SQL Rollback
echo ++++++++++++++++++++++++++++++
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
@?/rdbms/admin/catbundle_PSU_${ORACLE_SID}_ROLLBACK.sql
EOF

echo +++++++++++++++++++++++++++++
echo Starting 11G JVM SQL Rollback
echo +++++++++++++++++++++++++++++
PATCHGRP=`find $PSUSWDIR -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | awk -F '/' '{print $2}'`
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
elif [[ $SQPATCHNUM -eq 1 && -f $ORACLE_HOME/sqlpatch/$SQPATCH/postdeinstall.sql ]];
    then
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    echo Executing JVM Post De-Install
    echo SQL Post apply patches found is: ${SQPATCHNUM}
    echo SQL Post apply patch is $ORACLE_HOME/sqlpatch/$SQPATCH
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++
    cd  $ORACLE_HOME/sqlpatch
    $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
    @$ORACLE_HOME/sqlpatch/$SQPATCH/postinstall.sql;
EOF
fi

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

oracle_patch_postRollback_12C ()
{ 
#=============================
# Oracle 12c Patch PostRollback
#=============================
echo +++++++++++++++++++++++++
echo Starting in upgrade mode
echo +++++++++++++++++++++++++
$ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup upgrade;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo +++++++++++++++++++++++++++++++++++++++++++++
echo Running Post Patch SQL Rollback for $VERSION
echo +++++++++++++++++++++++++++++++++++++++++++++
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

main_rollback ()
{ 
var_check;    
#==========================
# 1. Oracle Patch Rollback
#==========================
oracle_patch_rollback ;

#====================================
# 2. Perform Patch Post Rollback
#====================================
if [ $VERSION == "11G" ];
    #then oracle_patch_postRollback_11G ;
    then echo "The 11g Rollback process has a few bugs which would require manual intervention. Please refer to the patch rollback README and implement a rollback manually."
else oracle_patch_postRollback_12C ;
fi

# End Install
echo "==================================================================================="
echo "The Oracle Patch Set Update (PSU) Installation is complete. Log file is ${LOGFILE}"
echo "Review the install log to verify the installation of: $PSU_FETCH and Other_Patches."
echo
echo "The Following patches are applied:"
$ORACLE_HOME/OPatch/opatch lspatches
echo
echo "==================================================================================="
}

while getopts ":Mhs:v:n:f:" opt; do
    case $opt in
        M )
            main_rollback;
            exit 0
            ;;    
        h )
            usage;
            exit 0
            ;;    
        s ) 
            export ORACLE_SID=$OPTARG
            ;;
        v )     
            export VERSION=$OPTARG
            # Artifactory Software
            if [ $VERSION == "11G" ];
                    then AFSWVER="11204"
            elif [ $VERSION == "12CR1" ];
                    then AFSWVER="12102"
            elif [ $VERSION == "12CR2" ];
                    then AFSWVER="12201"
            elif [ $VERSION == "18C" ];
                    then AFSWVER="18C"
            elif [ $VERSION == "19C" ];
                    then AFSWVER="19C"
            else
                echo Unknown Oracle version specified!
                exit 1
            fi

            #OPatch Binary
            if [ $VERSION == "11G" ];
                    then OPATCH_BIN="p6880880_112000_Linux-x86-64.zip"
            elif [ $VERSION == "12CR1" ];
                    then OPATCH_BIN="p6880880_121010_Linux-x86-64.zip"
            elif [ $VERSION == "12CR2" ];
                    then OPATCH_BIN="p6880880_122010_Linux-x86-64.zip"
            elif [ $VERSION == "18C" ];
                    then OPATCH_BIN="p6880880_180000_Linux-x86-64.zip"
            elif [ $VERSION == "19C" ];
                    then OPATCH_BIN="p6880880_190000_Linux-x86-64.zip"
            else
                echo Unknown Oracle version specified!
                exit 1
            fi
            ;;
        n )
            action=NXfetch
            export PATCH_AGE=$OPTARG
            ;;    
        f )
            action=Archivedfetch
            export ARCHIVE_PSU_FILE=$OPTARG
            ;;              
        \? )
            echo "Invalid Option $OPTARG" 1>&2
            exit 1
            #echo "No option specified, performing default installation"
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if ((OPTIND == 1)) || (($# == 0))
        then
    echo "No options or positional arguments specified"
        echo "Usage: $0 -h <displays help>"
fi

## End Script
