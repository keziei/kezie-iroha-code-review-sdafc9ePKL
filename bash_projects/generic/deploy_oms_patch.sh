#!/bin/bash
# Kezie Iroha, EMS_DBA
# Download and deploy Oracle Cloud Control OMS Patch (Oracle Management Service patches)
# This patch is mandatory before an em13c target agent can be patched

export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin
export ORACLE_HOME=$1
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$ORACLE_HOME/OMSPatcher:$PATH
export SWLOC=/Export/staging/Oracle_Binary/EM13C
export EM13C_AGENT=/U01/app/oracle/product/Agent13c/agent_inst
export OTPROXY=https://artifactory.kiroha.org/artifactory/cloud-ops-dba-local
export AM3HTTP_PROXY=http://am3-artifactory-cloud.net:8081/artifactory/cloud-ops-dba-local
export AM3HTTPS_PROXY=https://am3-artifactory-cloud.net/artifactory/cloud-ops-dba-local
export WO3HTTP_PROXY=http://wo3-artifactory-cloud.net:8081/artifactory/cloud-ops-dba-local
export LITHTTP_PROXY=http://lit-artifactory-cloud.net:8081/artifactory/cloud-ops-dba-local
export LITHTTPS_PROXY=https://lit-artifactory-cloud.net:8443/artifactory/cloud-ops-dba-local
export DATE=`/bin/date '+%Y%m%d_T%H%M'`
export MACHINE=`hostname -f`
export CUR_DIR=`readlink -f .`
export LOGFILE=/tmp/deploy_oms_patch_${DATE}.log
exec > >(tee -a $LOGFILE)

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

## check parameter is set for database name
if [ -z $ORACLE_HOME ];
  then
    echo Usage: $0 "<ORACLE_HOME>"
    echo "Specify Path to EM13c Middleware Home, example: /U01/app/oracle/product/EM13.4"
    echo "The weblogic server runs from this home: ps -ef | grep wlserver"
    echo ""
    exit 1
fi

# Check middleware home
if [ ! -d $ORACLE_HOME/wlserver/server ]; then
   echo "Could not find ORACLE_HOME! Please verify path to ORACLE_HOME"
   exit 1
fi

# Check Middleware weblogic server
if [ `ps -ef | grep -v grep | grep -c wlserver` -eq 0 ]; then
   echo "The specified middleware home is inactive!"
   echo "Please verify that the EM OMS is running as follows: ORACLE_HOME/emctl status oms -details -sysman_pwd <sysman password>"
   exit 1
fi

# Test Artifactory Proxy
echo "Performing Proxy Test ..."
WO3_HTTP_response () {
wget --quiet --server-response --timeout=60 --tries=1 $WO3HTTP_PROXY
echo $?
}

AM3_HTTPS_response () {
wget --quiet --server-response --timeout=60 --tries=1 $AM3HTTPS_PROXY
echo $?
}

AM3_HTTP_response () {
wget --quiet --server-response --timeout=60 --tries=1 $AM3HTTP_PROXY
echo $?
}

LIT_HTTPS_response () {
wget --quiet --server-response --timeout=60 --tries=1 $LITHTTPS_PROXY
echo $?
}

LIT_HTTP_response () {
wget --quiet --server-response --timeout=60 --tries=1 $LITHTTP_PROXY
echo $?
}

OT_response () {
wget --quiet --server-response --timeout=60 --tries=1 $OTPROXY
echo $?
}

# Select Artifactory Proxy
if [ `AM3_HTTPS_response` -eq 0 ];
    then PROXY=$AM3HTTPS_PROXY
	echo $AM3HTTPS_PROXY will be used
	echo "Proxy Test Complete .."
	echo "+++++++++++++++++++++++++++++++++++++"
elif [ `AM3_HTTP_response` -eq 0 ];
    then PROXY=$AM3HTTP_PROXY
	echo $AM3HTTP_PROXY will be used
	echo "Proxy Test Complete .."
	echo "+++++++++++++++++++++++++++++++++++++"    
#elif [ `WO3_HTTP_response` -eq 0 ];
#    then PROXY=$WO3HTTP_PROXY
#    echo $WO3HTTP_PROXY will be used
#	echo "Proxy Test Complete .."
#	echo "+++++++++++++++++++++++++++++++++++++"
elif [ `LIT_HTTPS_response` -eq 0 ];
    then PROXY=$LITHTTPS_PROXY
    echo $LITHTTPS_PROXY will be used
elif [ `LIT_HTTP_response` -eq 0 ];
    then PROXY=$LITHTTP_PROXY
    echo $LITHTTP_PROXY will be used   
else
    echo Could not connect to Artifactory PROXY
    echo "Please resolve proxy problem with sysadmin or perform a manual pull"
    echo "Manual Pull commands:"
    echo "wget -e robots=off -r --no-parent -nH --cut-dirs=3 --proxy=off -N --read-timeout=300 --tries=3 -N <Artifactory_Proxy_URL>/Oracle_Binary_PSU/EM13C/"
    exit 1
fi

# Test Large Oracle Binaries
test_OPATCH () {
if [ ! -f $SWLOC/p28186730_*_Generic.zip ]; then
  echo "Patch file p28186730_*_Generic.zip does not exist in $SWLOC"
  echo "Please update the OMS OPatch in Artifactory location: Oracle_Binary_PSU/EM13C/OPatch"
  exit 1
else  
unzip -qq -t $SWLOC/p28186730_*_Generic.zip
echo $?
fi
}

cnt_OPATCH () {
ls $SWLOC/OPatch/p28186730_*_Generic.zip | wc -l
}

test_OMSPATCH () {
if [ ! -f $SWLOC/OMSPatcher/p19999993_*_Generic.zip ]; then
  echo "Patch file p19999993_*_Generic.zip does not exist in $SWLOC/OMSPatcher"
  echo "Please update the OMS OPatch in Artifactory location: Oracle_Binary_PSU/EM13C/OMSPatcher"
  exit 1
else  
unzip -qq -t $SWLOC/OMSPatcher/p19999993_*_Generic.zip
echo $?
fi
}

cnt_OMSPATCH () {
ls $SWLOC/OMSPatcher/p19999993_*_Generic.zip | wc -l
}

test_OMSBIN () {
if [ ! -f $SWLOC/OMS/*.zip ]; then
  echo "The OMS Release Update patch does not exist in $SWLOC/OMS"
  echo "Please update the OMS RU/PSU in Artifactory location: Oracle_Binary_PSU/EM13C"
  exit 1
else  
unzip -qq -t $SWLOC/OMS/*.zip
echo $?
fi
}

cnt_OMSBIN () {
ls $SWLOC/OMS/*.zip | wc -l
}

# Check Weblogic property file
getDC () { echo `hostname | awk -F '-' '{print $1}'`
}

getRole () { echo `hostname | awk -F '-' '{print $3}'`
}

create_weblogic_key ()
# create property file
# https://updates.oracle.com/Orion/Services/download?type=readme&aru=23947946#GUID-013C4D6E-D84F-4277-9554-AA77E6F32EBC
{
echo "Weblogic username is: weblogic"    
echo "Please enter the keepass password for the weblogic user if prompted"    
if [ ! -f /U01/app/oracle/wlskey/properties ]; then
mkdir -p /U01/app/oracle/wlskey
$ORACLE_HOME/OMSPatcher/wlskeys/createkeys.sh –oh $ORACLE_HOME -location /U01/app/oracle/wlskey
fi

if [ `getDC` == "am3" ] && [ `getRole` == "d01" ]; then
echo "AdminServerURL=t3s://am3-d01.cloud.kiroha.org:7102
AdminConfigFile=/U01/app/oracle/wlskey/config
AdminKeyFile=/U01/app/oracle/wlskey/key" >> /U01/app/oracle/wlskey/properties
elif [ `getDC` == "am3" ] && [ `getRole` == "p01" ]; then
echo "AdminServerURL=t3s://am3-p01.cloud.kiroha.org:7102
AdminConfigFile=/U01/app/oracle/wlskey/config
AdminKeyFile=/U01/app/oracle/wlskey/key" >> /U01/app/oracle/wlskey/properties
elif [ `getDC` == "lit" ] && [ `getRole` == "d01" ]; then
echo "AdminServerURL=t3s://lit-d01.cloud.kiroha.org:7102
AdminConfigFile=/U01/app/oracle/wlskey/config
AdminKeyFile=/U01/app/oracle/wlskey/key" >> /U01/app/oracle/wlskey/properties
elif [ `getDC` == "lit" ] && [ `getRole` == "p01" ]; then
echo "AdminServerURL=t3s://lit-p01.cloud.kiroha.org:7102
AdminConfigFile=/U01/app/oracle/wlskey/config
AdminKeyFile=/U01/app/oracle/wlskey/key" >> /U01/app/oracle/wlskey/properties
fi
}

# software pull
pull_oracle_patches ()
{
#======================
# Start Software Pull
#======================
# Oracle binary directory
echo "Removing existing EM13c patch binary"
rm -rf ${SWLOC}

echo "Creating software location"
mkdir -p ${SWLOC}
chown oracle:oinstall -R /Export/staging/Oracle_Binary/EM13C
chmod 755 -R /Export/staging/Oracle_Binary/EM13C

if [ ! -d $SWLOC ]; then
   echo "/Export/staging/Oracle_Binary/EM13C does not exist and could not be created"
   exit 1
fi

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Pulling EM!3C OMS patches from $PROXY"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
cd /Export/staging/Oracle_Binary
wget -e robots=off -r --no-parent -nH --cut-dirs=3 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_OPatch/EM13C/
wget -e robots=off -r --no-parent -nH --cut-dirs=3 --proxy=off -N --read-timeout=300 --tries=3 -N $PROXY/Oracle_Binary_PSU/EM13C/

  if [ `cnt_OPATCH` != 1 ];
    then
      echo "Only one EM13c OPatch file is expected in ${SWLOC}/OPatch"
      echo "Please verify that there are no duplicate files in Artifactory location: cloud_ops_dba_local/Oracle_Binary_PSU/EM13C/OPatch"
      exit 1
  fi

  if [[ `test_OMSPATCH` -gt 0 ]];
    then 
    echo "OMSPatcher RU binary is invalid!, Please retry download or place a valid OMSPatcher RU binary in $SWLOC/OMSPatcher"
    exit 1
  fi 

  if [ `cnt_OMSPATCH` != 1 ];
    then
      echo "Only one PSU file is expected in ${SWLOC}/OMSPatcher"
      echo "Please verify that there are no duplicate files in Artifactory location: cloud_ops_dba_local/Oracle_Binary_PSU/EM13C/OMSPatcher"
      exit 1
  fi

  if [[ `test_OMSBIN` -gt 0 ]];
    then 
    echo "OMS PSU binary is invalid!, Please retry download or place a valid OMS PSU binary in $SWLOC/OMS"
    exit 1
  fi 

  if [ `cnt_OMSBIN` != 1 ];
    then
      echo "Only one PSU file is expected in ${SWLOC}/OMS"
      echo "Please verify that there are no duplicate files in Artifactory location: cloud_ops_dba_local/Oracle_Binary_PSU/EM13C/OMS"
      exit 1
  fi
}

#========================
# Oracle Patch Install
#========================
# OMSPatcher Software
oracle_omspatcher_install ()
{   
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Updating OMSPatcher from $SWLOC/OMSPatcher"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
which omspatcher
mv $ORACLE_HOME/OMSPatcher $ORACLE_HOME/OMSPatcher_$DATE
mv $ORACLE_HOME/PatchSearch.xml $ORACLE_HOME/PatchSearch.xml_$DATE
rm /U01/app/oracle/product/EM13.4/readme.txt
unzip -qq $SWLOC/OMSPatcher/p19999993_*.zip -d $ORACLE_HOME/

echo "OMSPatcher Update complete"
echo ""
$ORACLE_HOME/OMSPatcher/omspatcher version
$ORACLE_HOME/OMSPatcher/omspatcher lspatches
}

# OMS OPatch Software  
oracle_opatch_install ()
{   
echo "+++++++++++++++++++++++++++++++++++++++"
echo "Updating OPatch from $SWLOC/OPatch"
echo "+++++++++++++++++++++++++++++++++++++++"
echo ""

which opatch
unzip -qq $SWLOC/OPatch/p28186730_*_Generic.zip -d $SWLOC/OPatch/p28186730

$ORACLE_HOME/bin/emctl stop oms -all
$ORACLE_HOME/oracle_common/jdk/bin/java -jar $SWLOC/OPatch/p28186730/6880880/opatch_generic.jar -silent ORACLE_HOME=$ORACLE_HOME
$ORACLE_HOME/bin/emctl start oms
}

# OMS OPatch Software stage
oracle_omspatch_install ()
{   
echo "+++++++++++++++++++++++++++++++++++++++"
echo "Applying OMS Patch from $SWLOC/OMS"
echo "+++++++++++++++++++++++++++++++++++++++"
echo ""
    # stage OMS PSU
    unzip -qq $SWLOC/OMS/p32198287_*_Generic.zip -d $SWLOC/OMS/p32198287

    # stop oms
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"    
    echo "Shutting down EM13c Oracle Management Service (OMS) .."
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++"     
    $ORACLE_HOME/bin/emctl stop oms 

    # apply oms patch
    echo ""
    echo "+++++++++++++++++++++++++++"    
    echo "Performing Patch Analyze .."
    echo "+++++++++++++++++++++++++++"
    cd $SWLOC/OMS
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $SWLOC/OMS/$patch; $ORACLE_HOME/OMSPatcher/omspatcher apply -silent -analyze -property_file /U01/app/oracle/wlskey/properties
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply Analyze complete"

    echo ""
    echo "+++++++++++++++++++++++++++"    
    echo "Performing Patch Apply .."
    echo "+++++++++++++++++++++++++++"    
    cd $SWLOC/OMS
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $SWLOC/OMS/$patch; $ORACLE_HOME/OMSPatcher/omspatcher apply -silent -property_file /U01/app/oracle/wlskey/properties
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "PSU Apply complete"
    echo ""

    # start oms
    echo "+++++++++++++++++"    
    echo "Restarting OMS .."
    echo "+++++++++++++++++"     
    $ORACLE_HOME/bin/emctl start oms 

    # emcli sync
    echo ""
    echo "+++++++++++++++++++++++++"    
    echo "Performing EMCLI sync .."
    echo "+++++++++++++++++++++++++"       
    if [ `getRole` == "d01" ]; then
        $ORACLE_HOME/bin/emcli login -username=sysman -password=QANotThePassword 
        $ORACLE_HOME/bin/emcli sync
    elif [ `getRole` == "p01" ]; then
        $ORACLE_HOME/bin/emcli login -username=sysman -password=NotThePassword 
        $ORACLE_HOME/bin/emcli sync
    fi        
}

oracle_agent_patch ()
{   
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "Applying Central Agent Patch from $SWLOC/Agent"
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo ""

export AGT_VER=`/U01/app/oracle/product/Agent13c/agent_inst/bin/emctl status agent |grep "Agent Version" | awk -F ': ' '{print $2}'`
echo "Agent Version is: $AGT_VER"
export ORACLE_HOME=/U01/app/oracle/product/Agent13c/agent_$AGT_VER
echo "AGENT Home is: $ORACLE_HOME"
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH
export SWLOC=/Export/staging/Oracle_Binary/EM13C

    # stage Agent Patch
    cd $SWLOC/Agent/
    rm -rf $SWLOC/Agent/p32198303
    unzip -qq $SWLOC/Agent/p32198303_*_Generic.zip -d $SWLOC/Agent/p32198303

    # stop agent
    echo "++++++++++++++++++++++++++++++++"    
    echo "Shutting down EM13c OMS Agent .."
    echo "++++++++++++++++++++++++++++++++"     
    $ORACLE_HOME/bin/emctl stop agent 

    # apply agent patch
    echo ""
    echo "+++++++++++++++++++++++++++"    
    echo "Performing Patch Apply .."
    echo "+++++++++++++++++++++++++++"    
    cd $SWLOC/Agent
    PATCHDIR=`find . -mindepth 2 -maxdepth 2 -type d -printf '%P\n'`
    for patch in ${PATCHDIR}
    do cd $SWLOC/Agent/$patch; $ORACLE_HOME/OPatch/opatch napply -silent 
        if [[ `echo $?` != 0 ]]; then
            break
            echo "Review Patch Error"
        fi
    done
    echo "Agent Patch Apply complete"
    echo ""

    # start agent
    echo "+++++++++++++++++++++++++++"    
    echo "Starting EM13c OMS Agent .."
    echo "+++++++++++++++++++++++++++"     
    $ORACLE_HOME/bin/emctl start agent 

}

#==================================
# 1 - Perform Oracle Software Pull
#==================================
echo ""
echo "+++++++++++++++++++++++++++++++"
echo "Performing PSU software pull.. "
echo "+++++++++++++++++++++++++++++++"
pull_oracle_patches ;

#=================================
# 2 - Perform OMS Patcher Install
#=================================
echo ""
echo "+++++++++++++++++++++++++++++++++"
echo "Performing OMS Patcher Install.. "
echo "+++++++++++++++++++++++++++++++++"
oracle_omspatcher_install ;

#===============================
# 3 - Perform OMS Patch Install
#===============================
echo ""
echo "+++++++++++++++++++++++++++++++"
echo "Performing OMS Patch Install.. "
echo "+++++++++++++++++++++++++++++++"
oracle_opatch_install ;

#===============================
# 4 - Perform OMS Patch Install
#===============================
echo ""
echo "+++++++++++++++++++++++++++++++"
echo "Performing OMS Patch Install.. "
echo "+++++++++++++++++++++++++++++++"
create_weblogic_key ;
oracle_omspatch_install ;

#=====================================
# 5 - Perform OMS Central Agent Patch
#=====================================
echo ""
echo "+++++++++++++++++++++++++++++++++++++"
echo "Performing OMS Central Agent Patch.. "
echo "+++++++++++++++++++++++++++++++++++++"
oracle_agent_patch ;