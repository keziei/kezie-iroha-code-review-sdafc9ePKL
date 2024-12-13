#!/bin/bash
# kiroha - DBA Team
# Deploy EM13c Gold Image
# Deploy will select current gold image version under the parent image "EM_GOLD_AGENT"
# https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadv/installing-oracle-management-agent-silent-mode.html#GUID-10D4B8D1-DBF8-40E5-A864-8D273A4E4623

export ROLE=$1
export EMLOC=$2
export TMP=/Export/tmp
export SWLOCDIR=/Export/staging/Oracle_Binary
mkdir -p /Export/tmp /Export/staging/Oracle_Binary

## check os user is root
WHOAMI=`whoami`
if [ $WHOAMI != "root" ]; then
    echo $0: Should run as the root user
    exit 1
fi

if [ -z $ROLE ] | [ -z $EMLOC ] ; then
    echo Usage: $0 "<DEV|PROD> <AM3|LIT> "
    exit 1
fi

## Check required directories exist
if [ -d /U01/app/oracle/product/Agent13c ];
then
    echo "Agent13c Installation Directory already exists ......."
    echo "If required, you may run the deploy_agent.sh script to re-initiate an agent install, after decommissioning and then removing the existing agent installation"
    exit 1
fi


## Deploy Agent
if [ $ROLE == "DEV" ] && [ $EMLOC == "LIT" ]; 
  then 
    cd $SWLOCDIR
    curl "https://lit-d01.cloud.kiroha.org:4903/em/install/getAgentImage" --insecure -o AgentPull.sh

    chown oracle:oinstall AgentPull.sh
    chmod +x AgentPull.sh
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showPlatforms
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showGoldImageVersions 
    sudo -u oracle $SWLOCDIR/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=QANotThePassword \
    IMAGE_NAME=EM_GOLD_AGENT \
    PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=QANotThePassword \
    AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
    ORACLE_HOSTNAME=`hostname -f`
elif [ $ROLE == "PROD" ] && [ $EMLOC == "LIT" ]; 
  then 
    cd $SWLOCDIR
    curl "https://lit-p01.cloud.kiroha.org:4903/em/install/getAgentImage" --insecure -o AgentPull.sh

    chown oracle:oinstall AgentPull.sh
    chmod +x AgentPull.sh
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showPlatforms
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showGoldImageVersions 
    sudo -u oracle $SWLOCDIR/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=NotThePassword \
    IMAGE_NAME=EM_GOLD_AGENT \
    PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=NotThePassword \
    AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
    ORACLE_HOSTNAME=`hostname -f`
elif [ $ROLE == "DEV" ] && [ $EMLOC == "AM3" ]; 
  then 
    cd $SWLOCDIR
    curl "https://am3-d01.cloud.kiroha.org:4903/em/install/getAgentImage" --insecure -o AgentPull.sh

    chown oracle:oinstall AgentPull.sh
    chmod +x AgentPull.sh
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showPlatforms
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showGoldImageVersions 
    sudo -u oracle $SWLOCDIR/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=QANotThePassword \
    IMAGE_NAME=EM_GOLD_AGENT \
    PLATFORM="Linux x86-64" AGENT_REGISTRATION_PASSWORD=QANotThePassword \
    AGENT_BASE_DIR=/U01/app/oracle/product/Agent13c \
    ORACLE_HOSTNAME=`hostname -f`
elif [ $ROLE == "PROD" ] && [ $EMLOC == "AM3" ]; 
  then 
    cd $SWLOCDIR
    curl "https://am3-p01.cloud.kiroha.org:4903/em/install/getAgentImage" --insecure -o AgentPull.sh

    chown oracle:oinstall AgentPull.sh
    chmod +x AgentPull.sh
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showPlatforms
    sudo -u oracle $SWLOCDIR/AgentPull.sh -showGoldImageVersions 
    sudo -u oracle $SWLOCDIR/AgentPull.sh LOGIN_USER=sysman LOGIN_PASSWORD=NotThePassword \
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