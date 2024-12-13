#!/bin/bash
# Kezie Iroha, EMS_DBA
# Download and deploy patches
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
export LITHTTP_PROXY=http://lit.kiroha.net:8081/artifactory/cloud-ops-dba-local
export LITHTTPS_PROXY=https://lit.kiroha.net:8443/artifactory/cloud-ops-dba-local
export DATE=`/bin/date '+%Y%m%d_T%H%M'`
export BLKOUT_DATE=`/bin/date '+%Y%m%d'`
export MACHINE=`hostname -f`
export CUR_DIR=`readlink -f .`
export ORACLE_SID=""
export VERSION=""
export PATCH_AGE=""
export RAT_TMPDIR=/Export
export LOGFILE=/tmp/Existing_DB_PSU_Apply_${DATE}.log
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
    echo "Usage: Pull and Apply N-X PSU, or a file from PSU_Archive"
    echo $0 "-s <ORACLE_SID> -v <11G|12CR1|12CR2|18C|19C> [-n <0|1|2> OR -f <archived_psu_file.zip>] -M <Main install -> pull & deploy>"
    echo $0 "-s <ORACLE_SID> -v <11G|12CR1|12CR2|18C|19C> [-n <0|1|2> OR -f <archived_psu_file.zip>] -P <Pull Patch updates only>"
    echo $0 "-s <ORACLE_SID> -v <11G|12CR1|12CR2|18C|19C> [-n <0|1|2> OR -f <archived_psu_file.zip>] -C <Perform a Pre-Deploy PSU Conflict Check>"
    echo $0 "-s <ORACLE_SID> -v <11G|12CR1|12CR2|18C|19C> [-n <0|1|2> OR -f <archived_psu_file.zip>] -D <Deploy Patch updates only>"
    echo ""
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Arg -n <patch_age NUMBER> OR -f <archived_psu.zip FILENAME> "
    echo "Specify <-n 0> to pull Latest PSU"
    echo "Specify <-n 1|2|3|..99> to pull N-1, N-2, N-3 PSU etc"
    echo ""
    echo "Specify <-f some_old_psu.zip> to pull and apply an archived psu"
    echo ""
    echo "New patches staged in Artifactory take 24hrs to sync to the EMS Cloud Artifactory proxy"
    echo "Pulls PSU artifactory structure to: $SWLOC/Latest|N-X|PSU_Archive>"
    echo "Pulls Tools software to: $SWLOC"
    echo "Patch Artifactory procedure:  https://confluence.kiroha.org/display/ED/Oracle+Artifactory+Patch+Staging"
    echo "Patch Procedure: https://confluence.kiroha.org/display/ED/Oracle+Patch+Procedure"    
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
}

proxy_check ()
{
    # Test Artifactory Proxy
    echo "Performing Proxy Test ..."
    WO3_HTTP_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $WO3HTTP_PROXY
    echo $?
    }

    AM3_HTTPS_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $AM3HTTPS_PROXY
    echo $?
    }

    AM3_HTTP_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $AM3HTTP_PROXY
    echo $?
    }

    LIT_HTTPS_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $LITHTTPS_PROXY
    echo $?
    }

    LIT_HTTP_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $LITHTTP_PROXY
    echo $?
    }

    OT_response () {
    wget --quiet --server-response --timeout=30 --tries=1 $OTPROXY
    echo $?
    }

    # Select Artifactory Proxy
    if [ `AM3_HTTPS_response` -eq 0 ];
            then PROXY=$AM3HTTPS_PROXY
            echo ""
            echo $AM3HTTPS_PROXY will be used
            echo "Proxy Test Complete .."
            echo "+++++++++++++++++++++++++++++++++++++"
    elif [ `AM3_HTTP_response` -eq 0 ];
            then PROXY=$AM3HTTP_PROXY
            echo ""
            echo $AM3HTTP_PROXY will be used
            echo "Proxy Test Complete .."
            echo "+++++++++++++++++++++++++++++++++++++"
    #elif [ `WO3_HTTP_response` -eq 0 ];
    #        then PROXY=$WO3HTTP_PROXY
    #        echo ""
    #        echo $WO3HTTP_PROXY will be used
    #        echo "Proxy Test Complete .."
    #        echo "+++++++++++++++++++++++++++++++++++++"
    elif [ `LIT_HTTPS_response` -eq 0 ];
            then PROXY=$LITHTTPS_PROXY
            echo ""
            echo $LITHTTPS_PROXY will be used
    elif [ `LIT_HTTP_response` -eq 0 ];
            then PROXY=$LITHTTP_PROXY
            echo ""
            echo $LITHTTP_PROXY will be used
    else
            echo Could not connect to Artifactory PROXY
            echo "Please resolve proxy problem with sysadmin or perform a manual pull"
            echo "Manual Pull commands:"
            echo "wget -nc --timeout=900 --read-timeout=300 --tries=3 <Artifactory_Proxy_URL>/Oracle_Binary_DB/<rdbms_binary_version>"
            echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Binary_OPatch/RHEL/<rdbms_binary_version>/"
            echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Binary_PSU/RHEL/<rdbms_binary_version>/"
            echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Tools/"
            exit 1
    fi
}

patch_check ()
{   # Test Oracle Patches
    var_check;
    echo ""
    echo "Performing patch checksum tests .."
    echo ""

    # Tests
    test_OPATCH () {
    unzip -qq -t $OPATCHDIR/$OPATCH_BIN
    echo $?
    }

    test_PSU_FETCH () {
    if [ -f $PSUSWDIR/*.zip ]; then
    unzip -qq -t $PSUSWDIR/*.zip
    fi
    echo $?
    }

    test_Other_Patches () {
    if [ -f $SWLOC/Other_Patches/*.zip ]; then
    for x in `ls $SWLOC/Other_Patches/*.zip`; do unzip -qq -t $x; echo $?; done;
    fi
    }

    cnt_PSU () {
    ls $PSUSWDIR/*.zip | wc -l
    }

    # test opatch
    if [[ `test_OPATCH` != 0 ]];
            then
            echo "OPatch binary has a checksum error, Please retry download or place a valid OPatch binary in $OPATCHDIR/$OPATCH_BIN"
            echo "To perform a manual test, execute unzip -qq -t file.zip"
            exit 1
    fi

        # test latest psu
    if [[ `test_PSU_FETCH` != 0 ]];
        then
        echo "The ${VERSION} patch file in $PSUSWDIR has a checksum error. Please remove and re-download the software"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    fi

    # check psu count
    if [[ `cnt_PSU` != 1 ]];
        then
        echo "Only one PSU file is expected in $PSUSWDIR"
        echo "If the artifactory source is correct, but duplicate files are pulled, then this indicates that old files are still cached. Contact cloud-ops"
        exit 1
    fi
    
    echo ""
    echo "Patch software check complete.."
    echo ""
}

patch_conflict () 
{
#======================
# OPatch Conflict Check
#======================
echo
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Performing OPatch Conflict Check for $VERSION $PSU_FETCH PSU ... "
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
cd $PSUSWDIR/
#PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
PATCHDIR=`find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n'`
cd $PATCHDIR/ 
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -ph ./ > /tmp/conflict.out
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -ph ./
if [[ `grep -c failed /tmp/conflict.out` != 0 && `grep -c Conflict /tmp/conflict.out` != 0 ]]; 
then
    echo "Review Patch Conflict Error"
    exit 1
else echo "PSU Patch Conflict Check Complete"
fi   
}

oracle_patch_stage ()
{
var_check;    
#===================
# Oracle Patch Stage
#===================
# OPatch Software
# Patch Location Check
if [ -d $PSUSWDIR ];
    then 
    cd $PSUSWDIR
else     
    echo "Patch folder $PSUSWDIR does not exist"
    echo "Please verify that the N-X patch location exists in the artifactory proxy cache, and the software pull was successful"
    echo ""
    exit 1
fi 

if [ ! -d $ORACLE_HOME ];
then
    echo "ORACLE_HOME not found! : $ORACLE_HOME"
    exit 1
fi

if [ -f $PSUSWDIR/*.zip ]; then
    cd $PSUSWDIR
    for x in $PSUSWDIR/*.zip; do unzip -qq -o $x; done;
fi

if [ -f ${SWLOC}/Other_Patches/*.zip ]; then
    cd ${SWLOC}/Other_Patches
    for x in ${SWLOC}/Other_Patches/*.zip; do unzip -qq -o $x; done;
fi

# Stage OPatch
if [[ -f $OPATCHDIR/$OPATCH_BIN ]];
    then
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Updating OPatch from $OPATCHDIR/$OPATCH_BIN"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    /bin/sleep 15
    mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_$DATE
    unzip -qq $OPATCHDIR/$OPATCH_BIN -d $ORACLE_HOME/
    echo "OPatch binary updated .."
    else
    echo "OPatch binary not found: $OPATCHDIR/$OPATCH_BIN"
exit 1
fi
}

pull_oracle_binary ()
{
#======================
# Start Software Pull
#======================
var_check;
proxy_check;

echo
echo "+++++++++++++++++++++++++++++++"
echo "Performing PSU software pull.. "
echo "+++++++++++++++++++++++++++++++"

# Oracle binary directory
echo "Removing existing patch binary"
rm -rf ${SWLOC}/Latest
rm -rf ${SWLOC}/N*
rm -rf ${SWLOC}/PSU_ARCHIVE
rm -rf ${SWLOC}/$PSU_FETCH
rm -rf ${SWLOC}/Other_Patches
rm -rf ${SWLOC}/*.zip

echo "Creating software location"
mkdir -p ${SWLOC}
chown oracle:oinstall -R $SWLOC
chmod 755 -R $SWLOC

if [ ! -d $SWLOC ]; then
   echo "$SWLOC does not exist and could not be created"
   exit 1
fi

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Pulling $PSU_FETCH $VERSION ($AFSWVER) Tools, OPatch, Other_Patch software from $PROXY"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

cd $SWLOC
wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_OPatch/RHEL/$AFSWVER/
wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/$PSU_FETCH/
wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/Other_Patches/
wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Tools/

#=========================
# Verify patches post-pull
#=========================
patch_check;
}

refresh_tools_software ()
{
var_check;
#========================
# Refresh Tools Software
#========================
echo ""
echo "++++++++++++++++++++++++++++++"
echo "Starting Oracle Tools Refresh "
echo "++++++++++++++++++++++++++++++"

    if [ -f $SWLOC/AHF*.zip ] && [ -f $SWLOC/p21769913*.zip ] && [ -f $SWLOC/sqlhc*.zip ];
        then
            echo "++++++++++++++++++++++++++++++++++++++++++++++++"
            echo "Staging DBA Tools in $TOOLSDIR"
            echo "++++++++++++++++++++++++++++++++++++++++++++++++"
            /bin/sleep 5

            echo
            echo "Removing existing Tool Installations"
            echo "+++++++++++++++++++++++++++++++++++"
            # uninstall tools
            if [ -f $TOOLSDIR/AHF/oracle.ahf/bin/tfactl ];
            then
                $TOOLSDIR/AHF/oracle.ahf/bin/tfactl uninstall -local -silent
            elif [ -f /Export/TFA/tfa/bin/tfactl ];
            then
                /Export/TFA/tfa/bin/tfactl uninstall -local -silent
            else
            echo "Could not detect an existing TFA Installation for removal"
            fi

            echo
            echo "Staging new Tool Binaries"
            echo "+++++++++++++++++++++++++"
            #stage tools
            rm -rf $TOOLSDIR/AHF
            rm -rf $TOOLSDIR/TFA
            rm -rf $TOOLSDIR/RDA
            rm -rf $TOOLSDIR/SQLHC
            mkdir -p $TOOLSDIR/
            unzip -qq $SWLOC/AHF*.zip -d $TOOLSDIR/AHF/
            unzip -qq $SWLOC/p21769913*.zip -d $TOOLSDIR/RDA/
            unzip -qq $SWLOC/sqlhc*.zip -d $TOOLSDIR/SQLHC/
            echo "RDA, AHF, SQLHC staged .."
            echo ""
        else
            echo "DBA Tools binaries do not exist in: $SWLOC, please verify that the software pull was successful"
    fi

    # Perform AHF Installation
    if [[ ! -f $TOOLSDIR/AHF/oracle.ahf/ahf/bin/tfactl ]];
        then
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo "installing AHF bundle as oracle (See Doc ID 2550798.1 for list of bundled tools which include ORAchk)"
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        /bin/sleep 15
        $TOOLSDIR/AHF/ahf_setup -ahf_loc $TOOLSDIR/AHF
        #nohup $TOOLSDIR/AHF/oracle.ahf/ahf/bin/tfactl toolstatus &
        else
        echo AHF is already installed .......
    fi
}

oracle_patch_postInstall_12C ()
{
#=============================
# Oracle 12c Patch PostInstall
#=============================
echo
echo +++++++++++++++++++++++++
echo Starting in upgrade mode
echo +++++++++++++++++++++++++
#$ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
startup upgrade;
select instance_name, status, database_role, open_mode from v\$database, v\$instance;
EOF

echo +++++++++++++++++++++++++++++++++++++++++++
echo Running Post Patch SQL Install for $VERSION
echo +++++++++++++++++++++++++++++++++++++++++++
cd $ORACLE_HOME/OPatch
./datapatch -verbose

echo
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
#========================
# Oracle Patch PostInstall
#========================
echo
echo +++++++++++++++++++++++++
echo Starting in upgrade mode
echo +++++++++++++++++++++++++
#$ORACLE_HOME/bin/lsnrctl start
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

echo
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

oracle_postpatch ()
{
var_check;
if [ $VERSION == "11G" ];
  then oracle_patch_postInstall_11G ;
else oracle_patch_postInstall_12C ;
fi

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo " NOTE: "
echo " If the cookbook was run prior to this patching, and memory allocation was changed, then please run the adjust_sga.sh script"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""

# End Install
echo "==================================================================================="
echo "The Oracle Patch Set Update (PSU) Installation is complete. Log file is ${LOGFILE}"
echo "Review the install log to verify the installation of: $PSU_FETCH Patches."
echo
echo "The Following patches are applied:"
$ORACLE_HOME/OPatch/opatch lspatches
echo
echo "==================================================================================="
}

oracle_patch_install () {
#======================
# Start Software Stage
#======================
#echo
#echo "Performing PSU check and stage for $VERSION "
#echo "++++++++++++++++++++++++++++++++++++++++++++"
#oracle_patch_stage ;   

#====================
# Start Patch Install
#====================
echo
echo "Starting Patch installation for $VERSION "
echo "+++++++++++++++++++++++++++++++++++++++++"

echo
echo "Creating EM13C Blackout"
echo "+++++++++++++++++++++++"
$EM13C_AGENT/bin/emctl start blackout Blackout_`hostname -s`_${BLKOUT_DATE} -nodeLevel -patching -timeout 1 -d 7

echo
echo "EM13C Blackout Status"
echo "+++++++++++++++++++++"
$EM13C_AGENT/bin/emctl status blackout Blackout_`hostname -s`_${BLKOUT_DATE}

# Update oratab for auto start
echo ""
echo "Updating oratab for database auto start"
echo "+++++++++++++++++++++++++++++++++++++++"
cp -p /etc/oratab /tmp/oratab.{$DATE}
cp -p /etc/oratab /tmp/oratab.bak
sed -e 's/:N$/:Y/' /tmp/oratab.bak > /etc/oratab
rm -rf /tmp/oratab.bak

# Install Patch
echo
echo "Clean DB Restart"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
startup force;
EOF

echo
echo "Invalid object status"
echo "+++++++++++++++++++++"
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
Prompt "Invalid DB Objects .."
select count(*) from dba_objects where status <> 'VALID';
Prompt "Invalid DB Registry .."
select count(*) from dba_registry where status ='INVALID';
EOF

echo
echo "Creating flashback restore point"
echo "+++++++++++++++++++++++++++++++++"
echo
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" << EOF
create restore point pre_dbpatch_${DATE} guarantee flashback database;

set lines 1000 pages 20
col name for a20
col time for a50
SELECT NAME, SCN, TIME, DATABASE_INCARNATION#,
GUARANTEE_FLASHBACK_DATABASE, STORAGE_SIZE
FROM V\$RESTORE_POINT
WHERE GUARANTEE_FLASHBACK_DATABASE='YES';
EOF

echo
echo "Stopping Agent"
echo "+++++++++++++"
$EM13C_AGENT/bin/emctl stop agent

echo
echo "Stopping Listener"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/lsnrctl stop

echo
echo "Stopping Database"
echo "+++++++++++++++++"
$ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF
shutdown immediate;
EOF

echo
echo "+++++++++++++++++++++++++++++++++++++++++++"
echo "Installing $PSU_FETCH PSU for $VERSION ... "
echo "+++++++++++++++++++++++++++++++++++++++++++"
echo
cd $PSUSWDIR
if [ $VERSION == "11G" ];
then
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $PSUSWDIR/$patch; $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME -ocmrf $CUR_DIR/ocm.rsp
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
else
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $PSUSWDIR/$patch; $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
fi

#echo "++++++++++++++++++++++"
#echo "Applying Other Patches"
#echo "++++++++++++++++++++++"

echo
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
EOF


# "++++++++++++++++++++++++"
# "Post Patch Installation"
# "++++++++++++++++++++++++"
oracle_postpatch;

echo
echo "Ending EM13c Blackout"
echo "+++++++++++++++++++++"
$EM13C_AGENT/bin/emctl stop blackout Blackout_`hostname -s`_${BLKOUT_DATE}
}

main_installation ()
{
#==================================
# 1 - Perform Oracle Software Pull
#==================================
pull_oracle_binary ;

#================================
# 2 - Perform PSU Conflict Check
#================================
oracle_patch_stage ;
patch_conflict ;

#===============================
# 3 - Perform Patch Installation
#===============================
oracle_patch_install ;

#============================
# 4 - Refresh Tools Software
#============================
refresh_tools_software ;
}

while getopts ":MPCDhs:v:n:f:" opt; do
    case $opt in
        M )
            main_installation;
            exit 0
            ;;
        P )
            pull_oracle_binary;
            exit 0
            ;;
        C )
            oracle_patch_stage;
            patch_conflict;
            exit 0
            ;;             
        D )
            refresh_tools_software;
            oracle_patch_stage;
            oracle_patch_install;
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
