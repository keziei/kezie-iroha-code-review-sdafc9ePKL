#!/bin/bash
# Kezie Iroha, EMS_DBA
# Pull and Deploy software for Build Ops Customer configuration

export VERSION=""
export SRVROLE=`hostname -s | awk -F '-' '{print $3}'`
export SWLOC=/Export/staging/Oracle_Binary
export NADEV_EM13C=https://lit-d01.cloud.kiroha.org
export NAPROD_EM13C=https://lit-p01.cloud.kiroha.org
export EUDEV_EM13C=https://am3-d01.cloud.kiroha.org
export EUPROD_EM13C=https://am3-p01.cloud.kiroha.org
export OTPROXY=https://artifactory.kiroha.org:443/artifactory/cloud-ops-dba-local
export AM3HTTP_PROXY=http://am3-artifactory.kiroha.org:8081/artifactory/cloud-ops-dba-local
export AM3HTTPS_PROXY=https://am3-artifactory.kiroha.org/artifactory/cloud-ops-dba-local
export WO3HTTP_PROXY=http://wo3-artifactory.kiroha.org:8081/artifactory/cloud-ops-dba-local
export LITHTTP_PROXY=http://lit-artifactory.kiroha.org:8081/artifactory/cloud-ops-dba-local
export LITHTTPS_PROXY=https://lit-artifactory.kiroha.org:8443/artifactory/cloud-ops-dba-local
export EMCLI_DIR=/Export/staging/DBA_TOOLS/EMCLI/
export PSUSWDIR=$SWLOC/Latest
export OPATCHDIR=$SWLOC
export TOOLSDIR=/Export/staging/DBA_TOOLS
export DATE=`/bin/date '+%Y-%m-%d_%H-%M'`
export MACHINE=`hostname -f`
export LOGFILE=/tmp/Pull_and_Deploy_Software_${DATE}.log
exec > >(tee -a $LOGFILE)
export CUR_DIR=`readlink -f .`
export OSV=`cat /etc/redhat-release`
export RAT_TMPDIR=/Export
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/U01/app/oracle/product/Agent13c/agent_inst/bin:/U01/app/oracle/product/Agent12c/agent_inst/bin

## check os user is root
WHOAMI=`whoami`
if [ $WHOAMI != "root" ]; then
    echo $0: Should run as the root user
    exit 1
fi

# Format scripts
echo "Formating scripts ............."
BASEDIR=$(dirname "$0")
echo "$BASEDIR"
dos2unix adjust_sga.sh
dos2unix check_memory.sh
dos2unix cleanup_database.sh
dos2unix Create_Schemas.sh
dos2unix deploy_agent_gold_image.sh
dos2unix deploy_emcli_api.sh
dos2unix deploy_oms_patch.sh
dos2unix Existing_DB_PSU_Apply.sh
dos2unix Existing_DB_PSU_Rollback.sh
dos2unix gather_missing_stats.sh
dos2unix hugepage_settings.sh
dos2unix Modify_RMAN_with_Inc_Updated_Backup.sh
dos2unix Modify_RMAN_with_L0L1_Backup.sh
dos2unix Pull_and_Deploy_Software.sh
dos2unix STD_Database_Build.sh
dos2unix UTF8_Database_Build.sh
dos2unix $BASEDIR/EMS_*.dbt
dos2unix $BASEDIR/EMS_*.rsp
chmod 755 adjust_sga.sh
chmod 755 check_memory.sh
chmod 755 cleanup_database.sh
chmod 755 Create_Schemas.sh
chmod 755 deploy_agent_gold_image.sh
chmod 755 deploy_emcli_api.sh
chmod 755 deploy_oms_patch.sh
chmod 755 Existing_DB_PSU_Apply.sh
chmod 755 Existing_DB_PSU_Rollback.sh
chmod 755 gather_missing_stats.sh
chmod 755 hugepage_settings.sh
chmod 755 Modify_RMAN_with_Inc_Updated_Backup.sh
chmod 755 Modify_RMAN_with_L0L1_Backup.sh
chmod 755 Pull_and_Deploy_Software.sh
chmod 755 STD_Database_Build.sh
chmod 755 UTF8_Database_Build.sh
chown oracle:oinstall adjust_sga.sh
chown oracle:oinstall check_memory.sh
chown oracle:oinstall cleanup_database.sh
chown oracle:oinstall Create_Schemas.sh
chown oracle:oinstall deploy_agent_gold_image.sh
chown oracle:oinstall deploy_emcli_api.sh
chown oracle:oinstall deploy_oms_patch.sh
chown oracle:oinstall Existing_DB_PSU_Apply.sh
chown oracle:oinstall Existing_DB_PSU_Rollback.sh
chown oracle:oinstall gather_missing_stats.sh
chown oracle:oinstall hugepage_settings.sh
chown oracle:oinstall Modify_RMAN_with_Inc_Updated_Backup.sh
chown oracle:oinstall Modify_RMAN_with_L0L1_Backup.sh
chown oracle:oinstall Pull_and_Deploy_Software.sh
chown oracle:oinstall STD_Database_Build.sh
chown oracle:oinstall UTF8_Database_Build.sh
chown oracle:oinstall ocm.rsp EMS*.rsp dbora_em13c otora *.sql EMS*.dbt
echo "Formatting scripts complete .."
echo "++++++++++++++++++++++++++++++++++++++++"
echo ""

usage ()
{	echo ""
	echo "Usage:"
	echo $0 "-v <11G|12CR1|12CR2|18C|19C> -M <Main pull and deploy>"
	echo ""
	echo "Alternative partial runs of this script:"  
	echo $0 "-v <11G|12CR1|12CR2|18C|19C> -B <Binary pull only> | -D <Deploy RDBMS & PSU Software only> | -P <PSU install only, pre DB build> | -E <EM Client install only> | -A <Agent install only>"
	echo ""
    echo "Specify 11G for 11.2.0.4"
    echo "Specify 12CR1 for 12.1.0.2"
    echo "Specify 12CR2 for 12.2.0.1"
    echo "Specify 18C for 12.2.0.2"
    echo "Specify 19C for 12.2.0.3"
    echo ""
}	

var_check ()
{
## check parameter is set for database name
if [ -z $VERSION ] || [[ ! $VERSION =~ ^(11G|12CR1|12CR2|18C|19C)$ ]];
  then
    echo "Usage: $0 -h <displays help>"
    exit 1
fi

if [[ -z $RHEL_VERSION && "$OSV" =~ .*"8.".* || "$OSV" =~ .*"8".* ]];
    then RHEL_VERSION=8
fi

if [[ $VERSION =~ ^(11G|12CR1|12CR2|18C)$ && $RHEL_VERSION == 8 ]];
    then
    echo "Oracle Versions lower than 19C are not supported on RHEL8"
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

# Response
rm -rf /tmp/${VERSION}.rsp 
cat <<EOF > /tmp/${VERSION}.rsp 
`if [[ $VERSION == '19C' ]]; then
echo oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
elif [[ $VERSION == '18C' ]]; then
echo oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0
elif [[ $VERSION == '12CR2' ]]; then
echo oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
elif [[ $VERSION == '12CR1' ]]; then
echo oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.1.0
elif [[ $VERSION == '11G' ]]; then
echo oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
fi`
`if [[ $VERSION =~ ^(11G|12CR1)$ ]]; then
echo oracle.install.db.DBA_GROUP=oinstall
else
echo oracle.install.db.OSDBA_GROUP=oinstall
fi`
`if [[ $VERSION == '12CR1' ]]; then
echo "oracle.install.db.BACKUPDBA_GROUP=oinstall
oracle.install.db.DGDBA_GROUP=oinstall
oracle.install.db.KMDBA_GROUP=oinstall"
elif [[ $VERSION =~ ^(12CR2|18C|19C)$ ]]; then
echo "oracle.install.db.OSBACKUPDBA_GROUP=oinstall
oracle.install.db.OSDGDBA_GROUP=oinstall
oracle.install.db.OSKMDBA_GROUP=oinstall"
fi`
`if [[ $VERSION =~ ^(12CR2|18C|19C)$ ]]; then
echo oracle.install.db.OSRACDBA_GROUP=oinstall
fi`
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=`hostname -f`
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/U01/app/oraInventory
ORACLE_HOME=$ORACLE_HOME
ORACLE_BASE=/U01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OPER_GROUP=oinstall
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SAuthor: Kezie IrohaP_UPDATES
EOF
chown oracle:oinstall /tmp/${VERSION}.rsp 
chmod 644 /tmp/${VERSION}.rsp 
}

em13c_loc () 
{
# Determine EM13c location
if [[ "$MACHINE" =~ .*".eu".* ]];
		then SERVERLOC="EU"
elif [[ "$MACHINE" =~ .*".com".* ]];
		then SERVERLOC="NA"
else
		echo "EM13c will not be deployed for this target because host fqdn is not .com or .eu, could not determine deploy location"
		echo ""
fi
export EMLOC=$SERVERLOC	
}

fs_check () 
{
	## Check /U01 Size meets EMS CRG specification
	U01_CRG() {
	echo "( `df -P /U01 | awk 'NR==2 {print $4}'`/1024/1024 )" | bc
	}

	if [ `U01_CRG` -lt 10 ] ;
	then
	echo "The /U01 directory has less than 10GB available. Please size according to Cloud EMS CRG specification"
	exit 1
	fi

	## Check directories are owned by oracle
	if [ `stat -c %U /U01` != "oracle" ] ;
	then
			echo "Required directory has incorrect ownership"
			echo "The owner of the following directories should be the oracle user:  /U01 "
			echo "setting ownership to oracle for database filesystem"   
			chown oracle:oinstall /U01
			chown oracle:oinstall /U02
			chown oracle:oinstall /U03
			chown oracle:oinstall /U04
			chown oracle:oinstall /U05
			chown oracle:oinstall /U06
			chown oracle:oinstall /Fast_Recovery
			chown oracle:oinstall /Export
	fi
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
	#	then PROXY=$WO3HTTP_PROXY
	#	echo ""
	#	echo $WO3HTTP_PROXY will be used
	#	echo "Proxy Test Complete .."
	#	echo "+++++++++++++++++++++++++++++++++++++"
	elif [ `LIT_HTTPS_response` -eq 0 ];
		then PROXY=$LITHTTPS_PROXY
		echo ""
		echo $LITHTTPS_PROXY will be used
	elif [ `LIT_HTTP_response` -eq 0 ];
		then PROXY=$LITHTTP_PROXY
		echo ""
		echo $LITHTTP_PROXY will be used    
	elif [ `OT_response` -eq 0 ];
		then PROXY=$OTPROXY
		echo ""
		echo $OTPROXY will be used    		
	else
		echo Could not connect to Artifactory PROXY
		echo "Please resolve proxy problem with sysadmin or perform a manual pull"
		echo "Manual Pull commands:"
		echo "wget -nc --timeout=900 --read-timeout=300 --tries=3 <Artifactory_Proxy_URL>/Oracle_Binary_DB/<rdbms_binary_version>"
		echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Binary_PSU/RHEL/<rdbms_binary_version>/Latest"
        echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Binary_OPatch/RHEL/<rdbms_binary_version>"
		echo "wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Tools/"
		exit 1
	fi
}

# Test Oracle Patches
patch_check ()
{ 	var_check;
	echo ""
	echo "Performing patch checksum tests .."
	echo ""

	# Test Patches
	test_OPATCH () {
	unzip -qq -t $OPATCHDIR/$OPATCH_BIN
	echo $?
	}

	test_Latest_PSU () { 
	if [ -f $PSUSWDIR/*.zip ]; then
	unzip -qq -t $PSUSWDIR/*.zip  
	fi
	echo $?
	}

	test_RHEL8_PSU () { 
	if [ -f ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip ]; then
	unzip -qq -t ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip
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

	# check psu count
	if [ `cnt_PSU` != 1 ];
		then
			echo "Only one PSU file is expected in $PSUSWDIR"
			exit 1
	fi

	# test opatch
	if [ `test_OPATCH` != 0 ];
		then 
		echo "OPatch binary has a checksum error, Please retry download or place a valid OPatch binary in $OPATCHDIR"
		echo "To perform a manual test, execute unzip -qq -t file.zip"
		exit 1
	fi 

	# test latest psu
	if [ `test_Latest_PSU` != 0 ];
		then
			echo "The ${VERSION} patch in $PSUSWDIR has a checksum error. Please remove and re-download the software"
			echo "To perform a manual test, execute unzip -qq -t file.zip"
			exit 1
	fi	

    # test RHEL8 psu
	if [[ $RHEL_VERSION = 8 && `test_RHEL8_PSU` != 0 ]];
		then
			echo "The ${VERSION} patch ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip has a checksum error. Please remove and re-download the software"
			echo "To perform a manual test, execute unzip -qq -t file.zip"
			exit 1
	fi	
}

# Test Large Oracle Binaries
binary_check ()
{ 	var_check;

	echo ""
	echo "Performing oracle binary checksum tests .."
	echo ""

	test_11G_a () { 
	unzip -qq -t ${SWLOC}/p13390677_112040_Linux-x86-64_1of7.zip
	echo $?
	}

	test_11G_b () { 
	unzip -qq -t ${SWLOC}/p13390677_112040_Linux-x86-64_2of7.zip
	echo $?
	}

	test_12CR1_a () { 
	unzip -qq -t ${SWLOC}/linuxamd64_12102_database_1of2.zip
	echo $?
	}

	test_12CR1_b () { 
	unzip -qq -t ${SWLOC}/linuxamd64_12102_database_2of2.zip
	echo $?
	}

	test_12CR2 () { 
	unzip -qq -t ${SWLOC}/linuxx64_12201_database.zip
	echo $?
	}

	test_18C () { 
	unzip -qq -t ${SWLOC}/LINUX.X64_180000_db_home.zip
	echo $?
	}

	test_19C () { 
	unzip -qq -t ${SWLOC}/LINUX.X64_193000_db_home.zip
	echo $?
	}

    # test oracle binary
    if [[ $VERSION == "11G" && `test_11G_a` != 0 && `test_11G_a` != 0 ]];
        then
        echo "11G binary has a checksum error, please retry download"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    elif [[ $VERSION == "12CR1" && `test_12CR1_a` != 0 && `test_12CR1_b` != 0 ]];
        then
        echo "12CR1 binary has a checksum error, please retry download"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    elif [[ $VERSION == "12CR2" && `test_12CR2` != 0 ]];
        then
        echo "12CR2 binary has a checksum error, please retry download"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    elif [[ $VERSION == "18C" && `test_18C` != 0 ]];
        then
        echo "18C binary has a checksum error, please retry download"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    elif [[ $VERSION == "19C" && `test_19C` != 0 ]];
        then
        echo "19C binary has a checksum error, please retry download"
        echo "To perform a manual test, execute unzip -qq -t file.zip"
        exit 1
    fi	
}

stage_tools_software ()
{
#======================
# Stage Tools Software
#======================
if [ -f ${SWLOC}/AHF*.zip ] && [ -f ${SWLOC}/p21769913*.zip ] && [ -f ${SWLOC}/sqlhc*.zip ];
	then 
		echo "++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "Staging DBA Tools in $TOOLSDIR"
		echo "++++++++++++++++++++++++++++++++++++++++++++++++"
		/bin/sleep 15
		mkdir -p $TOOLSDIR
		mkdir -p /Export/staging/DBA_TOOLS/autoupgrade                                                                     
		cp /Export/staging/Oracle_Binary/autoupgrade.jar /Export/staging/DBA_TOOLS/autoupgrade/
		chown oracle:oinstall -R /Export/staging 
		#chmod 755 -R /Export/staging 
		sudo -u oracle unzip -qq -o ${SWLOC}/AHF*.zip -d $TOOLSDIR/AHF/
		sudo -u oracle unzip -qq -o ${SWLOC}/p21769913*.zip -d $TOOLSDIR/RDA/
		sudo -u oracle unzip -qq -o ${SWLOC}/sqlhc*.zip -d $TOOLSDIR/SQLHC/
		echo "RDA, AHF, SQLHC staged .."
	else 
		echo "DBA Tools binaries do not exist in: ${SWLOC}, please verify that the tools software pull was successful"
fi
}

stage_patch_software ()
{
#=====================
# Stage Patch Software
#=====================
if [ -f $PSUSWDIR/*.zip ]; then
	chown oracle:oinstall -R $PSUSWDIR
	cd $PSUSWDIR
	for x in $PSUSWDIR/*.zip; do sudo -u oracle unzip -qq -o $x; done;
fi 

if [ -f ${SWLOC}/Other_Patches/*.zip ]; then
	chown oracle:oinstall -R $PSUSWDIR
	cd ${SWLOC}/Other_Patches
	for x in ${SWLOC}/Other_Patches/*.zip; do sudo -u oracle unzip -qq -o $x; done;
fi

if [[ $VERSION == "11G" ]]; then
	if [[ ! -f ${SWLOC}/PSU_Archive/p19121551_112040_Linux-x86-64.zip ]]; then
		echo "Mandatory PSU for 11G not found: ${SWLOC}/PSU_Archive/p19121551_112040_Linux-x86-64.zip"	
		exit 1
	else 	
		chown oracle:oinstall -R ${SWLOC}/PSU_Archive
		cd ${SWLOC}/PSU_Archive
		sudo -u oracle unzip -qq -o ${SWLOC}/PSU_Archive/p19121551_112040_Linux-x86-64.zip
	fi
fi	

if [ -f ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip ]; then
	chown oracle:oinstall -R ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip
	cd ${SWLOC}/RHEL8_RDBMS_DNC
	sudo -u oracle unzip -qq -o ${SWLOC}/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip
fi

echo "Patch software staged .."
}

oracle_patch_install () 
{
var_check;	
patch_check;
#===============================
# Stage Patch and Tool Software
#===============================
stage_patch_software;

if [ $VERSION == "11G" ]; then
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo " Installing p19121551_112040_Linux-x86-64.zip PSU for 11G ... "
echo " 11g PSU pre-requisite for subsequent JVM apply Doc ID 1933203.1"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
	cd $SWLOC/PSU_Archive
    PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    #PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $SWLOC/PSU_Archive/$patch; sudo -u oracle $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME -ocmrf $CUR_DIR/ocm.rsp -invPtrLoc '/etc/oraInst.loc'
        if [ $? != 0 ]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
echo "++++++++++++++++++++++++++++++++++++++++"
echo "Installing Latest PSU for 11G ... "
echo "+++++++++++++++++++++++++++++++++++++++"
echo
	cd $PSUSWDIR
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $PSUSWDIR/$patch; sudo -u oracle $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME -ocmrf $CUR_DIR/ocm.rsp
        if [ $? != 0 ]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
else
echo "++++++++++++++++++++++++++++++++++++++++"
echo "Installing Latest PSU for $VERSION ... "
echo "+++++++++++++++++++++++++++++++++++++++"
echo
	cd $PSUSWDIR
    #PATCHDIR=`ls -d */ | awk -F '/' '{print $1}'`
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $PSUSWDIR/$patch; sudo -u oracle $ORACLE_HOME/OPatch/opatch apply -local -silent -OH $ORACLE_HOME 
        if [ $? != 0 ]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
fi

#echo "++++++++++++++++++++++"
#echo "Applying Other Patches"
#echo "++++++++++++++++++++++"
}

emcli_13c_install () 
{	var_check;
	em13c_loc;
    export AGT_VER=`sudo -u oracle /U01/app/oracle/product/Agent13c/agent_inst/bin/emctl status agent |grep "Agent Version" | awk -F ': ' '{print $2}'`
    export AGENT_HOME=/U01/app/oracle/product/Agent13c/agent_$AGT_VER
    export JAVA_HOME=$AGENT_HOME/oracle_common/jdk
    export PATH=$JAVA_HOME/bin:$EMCLI_DIR:$AGENT_HOME/bin:$PATH

	# Test EMCLI stage
	NADEV_EM13C_response () {
	wget --quiet --server-response --timeout=30 --tries=1 --no-check-certificate $NADEV_EM13C:4903
	echo $?
	}

	NAPROD_EM13C_response () {
	wget --quiet --server-response --timeout=30 --tries=1 --no-check-certificate $NAPROD_EM13C:4903
	echo $?
	}

	EUDEV_EM13C_response () {
	wget --quiet --server-response --timeout=30 --tries=1 --no-check-certificate $EUDEV_EM13C:4903
	echo $?
	}

	EUPROD_EM13C_response () {
	wget --quiet --server-response --timeout=30 --tries=1 --no-check-certificate $EUPROD_EM13C:4903
	echo $?
	}

	echo ""
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "Deploying EM13c Client API for a $ROLE $EMLOC configuration ... "
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

	if [ -z $AGT_VER ]; 
		then echo "EM13C Agent is not running, or installed"
		return 0
	fi

	if [ ! -d $AGENT_HOME/bin ];
		then echo "Cannot find EM13c Agent Home"
		return 0
	fi		

	if [[ $ROLE == "PROD" ]]; then
		emcli_pw="ChangeMe"
	elif [[ $ROLE == "DEV" ]]; then
		emcli_pw="ChangeMe"
	fi

    ## Create EMCLI Directory
	rm -rf $EMCLI_DIR/
    mkdir -p $EMCLI_DIR/
    chown oracle:oinstall $EMCLI_DIR
    chmod 755 $EMCLI_DIR

    ## Deploy EMCLI API
    if [[ $ROLE == "DEV" && $EMLOC == "NA" && `NADEV_EM13C_response` -eq 0 ]]; 
    then 
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		sudo -E -u oracle wget --quiet --no-check-certificate $NADEV_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		sudo -E -u oracle $JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		sudo -E -u oracle $EMCLI_DIR/emcli setup -url=$NADEV_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		sudo -E -u oracle $EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		sudo -E -u oracle $EMCLI_DIR/emcli sync
		sudo -E -u oracle $EMCLI_DIR/emcli logout 
    elif [[ $ROLE == "PROD" && $EMLOC == "NA" && `NAPROD_EM13C_response` -eq 0 ]]; 
    then 
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		sudo -E -u oracle wget --quiet --no-check-certificate $NAPROD_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		sudo -E -u oracle $JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		sudo -E -u oracle $EMCLI_DIR/emcli setup -url=$NAPROD_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		sudo -E -u oracle $EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		sudo -E -u oracle $EMCLI_DIR/emcli sync
		sudo -E -u oracle $EMCLI_DIR/emcli logout 
    elif [[ $ROLE == "DEV" && $EMLOC == "EU" && `EUDEV_EM13C_response` -eq 0 ]];  
    then
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		sudo -E -u oracle wget --quiet --no-check-certificate $EUDEV_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		sudo -E -u oracle $JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		sudo -E -u oracle $EMCLI_DIR/emcli setup -url=$EUDEV_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		sudo -E -u oracle $EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		sudo -E -u oracle $EMCLI_DIR/emcli sync
		sudo -E -u oracle $EMCLI_DIR/emcli logout  	
    elif [[ $ROLE == "PROD" && $EMLOC == "EU" && `EUPROD_EM13C_response` -eq 0 ]];  
    then 
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		sudo -E -u oracle wget --quiet --no-check-certificate $EUPROD_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		sudo -E -u oracle $JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		sudo -E -u oracle $EMCLI_DIR/emcli setup -url=$EUPROD_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		sudo -E -u oracle $EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		sudo -E -u oracle $EMCLI_DIR/emcli sync
		sudo -E -u oracle $EMCLI_DIR/emcli logout  
    else 
    echo "Could not connect to EM13c to deploy EMCLI .." 
    fi
}

agent13c_install () 
{	var_check;
	em13c_loc;

	if [[ $ROLE =~ ^(DEV|PROD)$ ]] ;
	then
		echo ""
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "Deploying EM13c Agent for a $ROLE $EMLOC configuration ... "
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

		# Check required directories exist
		if [ -d /U01/app/oracle/product/Agent13c ];
		then
		echo "Agent13c Installation Directory already exists ......."
		echo "If required, you may run the deploy_agent.sh script to re-initiate an agent install, after removing the existing agent installation"
		echo ""
		return 1
		fi

		## Deploy Agent
		if [ $ROLE == "DEV" ] && [ $EMLOC == "NA" ]; 
		then 
			echo "Deploying EM13c Agent"
			cd /tmp
			curl "$NADEV_EM13C:4903/em/install/getAgentImage" --insecure -o AgentPull.sh
			chown oracle:oinstall AgentPull.sh
			chmod +x AgentPull.sh
			sudo -u oracle /tmp/AgentPull.sh -showPlatforms
			sudo -u oracle /tmp/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=ChangeMe \
			IMAGE_NAME=EM_GOLD_AGENT \
			PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=ChangeMe \
			AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
			ORACLE_HOSTNAME=`hostname -f`
		elif [ $ROLE == "PROD" ] && [ $EMLOC == "NA" ]; 
		then 
			echo "Deploying EM13c Agent"
			cd /tmp
			curl "$NAPROD_EM13C:4903/em/install/getAgentImage" --insecure -o AgentPull.sh
			chown oracle:oinstall AgentPull.sh
			chmod +x AgentPull.sh
			sudo -u oracle /tmp/AgentPull.sh -showPlatforms
			sudo -u oracle /tmp/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=NotThePassword \
			IMAGE_NAME=EM_GOLD_AGENT \
			PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=NotThePassword \
			AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
			ORACLE_HOSTNAME=`hostname -f`
		elif [ $ROLE == "DEV" ] && [ $EMLOC == "EU" ]; 
		then
			echo "Deploying EM13c Agent"
			cd /tmp
			curl "$EUDEV_EM13C:4903/em/install/getAgentImage" --insecure -o AgentPull.sh
			chown oracle:oinstall AgentPull.sh
			chmod +x AgentPull.sh
			sudo -u oracle /tmp/AgentPull.sh -showPlatforms
			sudo -u oracle /tmp/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=ChangeMe \
			IMAGE_NAME=EM_GOLD_AGENT \
			PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=ChangeMe \
			AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
			ORACLE_HOSTNAME=`hostname -f`
		elif [ $ROLE == "PROD" ] && [ $EMLOC == "EU" ]; 
		then 
			echo "Deploying EM13c Agent"
			cd /tmp
			curl "$EUPROD_EM13C:4903/em/install/getAgentImage" --insecure -o AgentPull.sh
			chown oracle:oinstall AgentPull.sh
			chmod +x AgentPull.sh
			sudo -u oracle /tmp/AgentPull.sh -showPlatforms
			sudo -u oracle /tmp/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=NotThePassword \
			IMAGE_NAME=EM_GOLD_AGENT \
			PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=NotThePassword \
			AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
			ORACLE_HOSTNAME=`hostname -f`
		fi

		## Root script
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo running EM13c Agent root script
		echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		export AGT_VER=`sudo -u oracle /U01/app/oracle/product/Agent13c/agent_inst/bin/emctl status agent |grep "Agent Version" | awk -F ': ' '{print $2}'`
		echo "Agent Version is: $AGT_VER"
		export ORACLE_HOME=/U01/app/oracle/product/Agent13c/agent_$AGT_VER
		echo "AGENT Home is: $ORACLE_HOME"
		$ORACLE_HOME/root.sh
	else 
	echo "EM13c Agent Install not performed for LAB environment"
	return 1
	fi
}

pull_oracle_binary ()
{
	var_check;
	fs_check; 
	proxy_check;

	echo ""
	echo "+++++++++++++++++++++++++++++++"
	echo "Performing software pull ......"
	echo "+++++++++++++++++++++++++++++++"
	echo ""
	#======================
	# Start Software Pull
	#======================
	# Oracle binary directory
	echo "Creating software location"
	mkdir -p ${SWLOC}
	mkdir -p $TOOLSDIR
	chown oracle:oinstall -R /Export/staging 
	#chmod 755 -R /Export/staging 

	echo "Removing existing Patches"
    rm -rf $SWLOC/*
	rm -rf $PSUSWDIR

	# Pull Software
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo
    echo Pulling $VERSION Database/PSU/OPatch/DBA_Tools software from $PROXY
    echo
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    cd ${SWLOC}
    wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_OPatch/RHEL/$AFSWVER/
    wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/Latest/
    wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/Other_Patches/
    wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Tools/

    if [[ $VERSION =~ ^(11G|12CR1)$ ]]; then
        wget -nc --timeout=900 --read-timeout=300 --tries=3 $PROXY/Oracle_Binary_DB/$SW_BIN1
        wget -nc --timeout=900 --read-timeout=300 --tries=3 $PROXY/Oracle_Binary_DB/$SW_BIN2
    else
        wget -nc --timeout=900 --read-timeout=300 --tries=3 $PROXY/Oracle_Binary_DB/$SW_BIN
    fi

    if [[ $VERSION == "11G" ]]; then
    	wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/PSU_Archive/p19121551_112040_Linux-x86-64.zip
    fi

    if [[ $VERSION == "19C" && $RHEL_VERSION == 8 ]]; then
        wget -e robots=off -r --no-parent -nH --cut-dirs=5 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/RHEL/$AFSWVER/RHEL8_RDBMS_DNC/p32126828_190000_Linux-x86-64.zip
    fi

	# Binary Check
	binary_check;
	patch_check;
}

ora_check ()  
{
# Oracle Pre-Req
echo "Performing Oracle Pre-Req check"
echo "+++++++++++++++++++++++++++++++"
echo
if [ -z $IGNORE_PREREQ ]; then 
    IGNORE_PREREQ=1 
fi    

if [[ $VERSION == "19C" && $RHEL_VERSION == 8 ]]; then    
	export CV_ASSUME_DISTID=OL7
	sudo -Eu oracle $ORACLE_HOME/runInstaller -executePrereqs -silent -responseFile /tmp/${VERSION}.rsp 
	RC=$?
elif [[ $VERSION =~ ^(18C|19C)$ && $RHEL_VERSION != 8 ]]; then    
	sudo -Eu oracle $ORACLE_HOME/runInstaller -executePrereqs -silent -responseFile /tmp/${VERSION}.rsp 
	RC=$?
elif [[ $VERSION =~ ^(11G|12CR1|12CR2)$ && $RHEL_VERSION != 8 ]]; then    
    sudo -Eu oracle $SWLOC/database/runInstaller -executePrereqs -silent -waitforcompletion -responseFile /tmp/${VERSION}.rsp 
	RC=$?
fi   
   
if [ $RC != 0 ] && [ $IGNORE_PREREQ = 1 ]; then
	echo
    echo "Oracle Pre-Requisite Check Failed, please review the log: /U01/app/oraInventory/logs/"
	echo
    echo "You can Ignore the PreReq failure by setting IGNORE_PREREQ=0 and running the script again"
    echo "export IGNORE_PREREQ=0"
	echo
    exit 1
else echo "Oracle Pre-Requisite checks complete"
fi
}

deploy_software ()
{
#========================
# Oracle Software Install
#========================	
var_check;	

	ee_software_install ()
	{  	
    # Check Oracle Home
    if [[ -d $ORACLE_HOME ]];
        then
            echo "Install location already exists: $ORACLE_HOME"
            echo "skipping Oracle $VERSION software install"
            echo ""
            exit 1
    fi

    # Stage Binary
    if [[ $VERSION =~ ^(11G|12CR1)$ ]];
        then
        echo Staging $VERSION Binary .. 
        echo "+++++++++++++++++++++++++"
        echo
        sudo -u oracle mkdir -p $ORACLE_HOME
        sudo -u oracle unzip -qq -o ${SWLOC}/$SW_BIN1 -d ${SWLOC}/
        sudo -u oracle unzip -qq -o ${SWLOC}/$SW_BIN2 -d ${SWLOC}/ 
    elif [[ $VERSION =~ ^(12CR2)$ ]];
        then
        echo Staging $VERSION Binary .. 
        echo "+++++++++++++++++++++++++"
        echo        
        sudo -u oracle mkdir -p $ORACLE_HOME
        sudo -u oracle unzip -qq -o ${SWLOC}/$SW_BIN -d ${SWLOC}/
    elif [[ $VERSION =~ ^(18C|19C)$ ]];
        then
        echo Staging $VERSION RDBMS Binary and OPatch .. 
        echo "++++++++++++++++++++++++++++++++++++++++++"
        echo        
        sudo -u oracle mkdir -p $ORACLE_HOME
        sudo -u oracle unzip -qq -o ${SWLOC}/$SW_BIN -d $ORACLE_HOME
        sudo -u oracle mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_$DATE
	    sudo -u oracle unzip -qq $OPATCHDIR/$OPATCH_BIN -d $ORACLE_HOME/
    fi

	# Oracle Pre-requisite
	ora_check;

    # Install Software
    if [[ $VERSION =~ ^(11G|12CR1|12CR2)$ && $RHEL_VERSION != 8 ]];
        then
            echo
            echo "Proceeding with $VERSION installation"
            echo "The Logfile for this installation is ${LOGFILE}"
            echo "+++++++++++++++++++++++++++++++++++++++++++++++"
            echo
            sudo -u oracle ${SWLOC}/database/runInstaller -silent -showProgress -waitforcompletion -responseFile /tmp/${VERSION}.rsp    
    elif [[ $VERSION =~ ^(18C|19C)$ && $RHEL_VERSION != 8 ]];
        then
            echo
            echo "Proceeding with $VERSION installation"
            echo "The Logfile for this installation is ${LOGFILE}"
            echo "+++++++++++++++++++++++++++++++++++++++++++++++"
            echo                
            sudo -u oracle $ORACLE_HOME/runInstaller -silent -force -responseFile /tmp/${VERSION}.rsp 
    elif [[ $VERSION == "19C" && $RHEL_VERSION == 8 ]];
        then
            echo
            echo "Proceeding with $VERSION installation for RHEL 8"
            echo "The Logfile for this installation is ${LOGFILE}"
            echo "+++++++++++++++++++++++++++++++++++++++++++++++"
            echo                
            export CV_ASSUME_DISTID=OL7
            sudo -Eu oracle $ORACLE_HOME/runInstaller -applyRU $SWLOC/RHEL8_RDBMS_DNC/32126828/32218454 -applyOneOffs $SWLOC/RHEL8_RDBMS_DNC/32126828/32067171 -silent -force -responseFile /tmp/${VERSION}.rsp                      
    fi

    # Run Root scripts
    if [[ $VERSION =~ ^(11G|12CR1|12CR2)$ && -f $ORACLE_HOME/root.sh ]];
        then 
        echo 
        echo " Running $VERSION Root scripts as $WHOAMI ... "
        echo "++++++++++++++++++++++++++++++++++++++++++++++"
		echo
        /U01/app/oraInventory/orainstRoot.sh
        $ORACLE_HOME/root.sh              
    elif [[ $VERSION =~ ^(18C|19C)$ && -f $ORACLE_HOME/root.sh ]];
        then 
        echo 
        echo " Running $VERSION Root scripts as $WHOAMI ... "
        echo "++++++++++++++++++++++++++++++++++++++++++++++"
		echo
		/U01/app/oraInventory/orainstRoot.sh
        $ORACLE_HOME/root.sh
    else
        echo "Root script not found in $ORACLE_HOME/"
        echo "Please verify install was successful and run root script manually"
        exit 1
    fi

    # Perform OPatch Install
    if [[ $VERSION =~ ^(11G|12CR1|12CR2)$ ]];
        then
        echo 
        echo "Updating OPatch from $OPATCHDIR/$OPATCH_BIN"
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo
        sudo -u oracle mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_$DATE
        sudo -u oracle unzip -qq $OPATCHDIR/$OPATCH_BIN -d $ORACLE_HOME/
        echo "OPatch binary updated .." 
    fi

    # Perform AHF Installation
    if [[ ! -f $TOOLSDIR/AHF/oracle.ahf/ahf/bin/tfactl ]];
        then
        echo 
        echo "installing AHF bundle as oracle (See Doc ID 2550798.1 for list of bundled tools which include ORAchk)"
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo
        sudo -u oracle $TOOLSDIR/AHF/ahf_setup -ahf_loc $TOOLSDIR/AHF
        #sudo -u oracle nohup $TOOLSDIR/AHF/oracle.ahf/ahf/bin/tfactl toolstatus &
        else
        echo AHF is already installed ....... 
    fi
	}
#===============================
# Stage Patch and Tool Software
#===============================
stage_tools_software;
stage_patch_software;

#=========================
# Install Oracle Software
#=========================
echo ""
echo "=================================================="
echo "Starting Software installation for $VERSION"
echo "The Logfile for this installation is ${LOGFILE}"
echo "=================================================="
# Check filesystem and binaries
fs_check;
binary_check;

# Install Software
ee_software_install;

#===============================
# Install Patch & Tools Update
#===============================
## Deploy Oracle Patch and Agent Software
echo "==================================================================="
echo "Deploying $VERSION PSU, EM13c Agent, and EM13c API client software"
echo "The Logfile for this installation is ${LOGFILE}"
echo "===================================================================="
	oracle_patch_install;
	agent13c_install;
	emcli_13c_install;
	
echo "==============================================================================================================================="
echo "The software installation is complete. Log file is ${LOGFILE}"
echo "Review the install log to verify the installation of: Oracle Binary, Oracle OPatch, AHF-TFA, RDA, SQLHC, EMCLI and EM13c agent."
echo "==============================================================================================================================="
}

main_installation ()
{
	#==================================
	# 1 - Perform Oracle Software Pull
	#==================================
	pull_oracle_binary ;

	#===============================================================
	# 2 - Perform Oracle Software, OPatch and DBA Tool Installation
	#===============================================================
	deploy_software ;

	# End Install
}

while getopts ":hv:MBDPEA" opt; do
    case $opt in 
        h )  
            usage;
            exit 0
            ;;
		v )	export VERSION=$OPTARG
			if [ $VERSION == "11G" ];
				then 
                    AFSWVER="11204"
                    OPATCH_BIN="p6880880_112000_Linux-x86-64.zip"
                    SW_BIN1="p13390677_112040_Linux-x86-64_1of7.zip"
                    SW_BIN2="p13390677_112040_Linux-x86-64_2of7.zip"
                    ORACLE_HOME=/U01/app/oracle/product/11.2.0.4/db_1
			elif [ $VERSION == "12CR1" ];
				then 
                    AFSWVER="12102"
                    OPATCH_BIN="p6880880_121010_Linux-x86-64.zip"
                    SW_BIN1="linuxamd64_12102_database_1of2.zip"
                    SW_BIN2="linuxamd64_12102_database_2of2.zip"
                    ORACLE_HOME=/U01/app/oracle/product/12.1.0.2/db_1
			elif [ $VERSION == "12CR2" ];
				then 
                    AFSWVER="12201"
                    OPATCH_BIN="p6880880_122010_Linux-x86-64.zip"
                    SW_BIN="linuxx64_12201_database.zip"
                    ORACLE_HOME=/U01/app/oracle/product/12.2.0.1/db_1
			elif [ $VERSION == "18C" ];
				then 
                    AFSWVER="18C"
                    OPATCH_BIN="p6880880_180000_Linux-x86-64.zip"
                    SW_BIN="LINUX.X64_180000_db_home.zip"
                    ORACLE_HOME=/U01/app/oracle/product/18.0.0/db_1
			elif [ $VERSION == "19C" ];
				then 
                    AFSWVER="19C"
                    OPATCH_BIN="p6880880_190000_Linux-x86-64.zip"
                    SW_BIN="LINUX.X64_193000_db_home.zip"
                    ORACLE_HOME=/U01/app/oracle/product/19.0.0/db_1
			else 
				echo Unknown Oracle version specified! 
				exit 1
			fi
			;;
		M )
            main_installation;
            exit 0
            ;;		
        B ) 
            pull_oracle_binary;
            exit 0
            ;;
        D ) 
            deploy_software;
            exit 0
            ;;
        P )
            oracle_patch_install;     
            exit 0
            ;;
        E )  
            emcli_13c_install;
            exit 0
            ;;
        A )
            agent13c_install;
            exit 0
            ;;   
        \? ) 
            echo "Invalid Option $OPTARG" 1>&2
            exit 1
            #echo "No option specified, performing default installation"
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            ;;   			    
    esac
done    
#shift $((OPTIND - 1))

if ((OPTIND == 1)) || (($# == 0))
	then
    echo "No options or positional arguments specified"
	echo "Usage: $0 -h <displays help>"
fi
shift $((OPTIND - 1))

## End Script
