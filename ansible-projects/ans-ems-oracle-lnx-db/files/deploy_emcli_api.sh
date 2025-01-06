#!/bin/bash
# Deploy EM13c API and promote targets
# KIroha - EMS DBA

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
export SWLOC=/Export/staging/Oracle_Binary
export NADEV_EM13C=https://lit-d01.cloud.kiroha.com
export NAPROD_EM13C=https://lit-p01.cloud.kiroha.com
export EUDEV_EM13C=https://am3-d01.cloud.kiroha.eu
export EUPROD_EM13C=https://am3-p01.cloud.kiroha.eu
export DATE=`/bin/date '+%Y-%m-%d_%H-%M'`
export MACHINE=`hostname -f`
export DC=`echo hostname -f | awk -F '.' '{print $5}'`
export AGT_VER=`/U01/app/oracle/product/Agent13c/agent_inst/bin/emctl status agent |grep "Agent Version" | awk -F ': ' '{print $2}'`
export ROLE=`hostname -s | awk -F '-' '{print $3}'`
export AGENT_HOME=/U01/app/oracle/product/Agent13c/agent_$AGT_VER
export JAVA_HOME=$AGENT_HOME/oracle_common/jdk
export EMCLI_DIR=/Export/staging/DBA_TOOLS/EMCLI/
export PATH=$AGENT_HOME/oracle_common/jdk/bin:$JAVA_HOME/bin:$EMCLI_DIR:$AGENT_HOME/bin:$PATH
export LOGFILE=/tmp/Deploy_EM13c_API_${DATE}.log
exec > >(tee -a $LOGFILE)

. oraenv << EOF1
${v_sid}
EOF1

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

if [ ${ROLE:0:1} == "p" ];
    then ROLE="PROD"
else ROLE="DEV"
fi 

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

emcli_13c_install () 
{	NADEV_EM13C_response () {
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
		emcli_pw="NotThePassword"
	elif [[ $ROLE == "DEV" ]]; then
		emcli_pw="QANotThePassword"
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
		wget --quiet --no-check-certificate $NADEV_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		$JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		$EMCLI_DIR/emcli setup -url=$NADEV_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		$EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		$EMCLI_DIR/emcli sync
		$EMCLI_DIR/emcli logout 
    elif [[ $ROLE == "PROD" && $EMLOC == "NA" && `NAPROD_EM13C_response` -eq 0 ]]; 
    then 
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		wget --quiet --no-check-certificate $NAPROD_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		$JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		$EMCLI_DIR/emcli setup -url=$NAPROD_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		$EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		$EMCLI_DIR/emcli sync
		$EMCLI_DIR/emcli logout 
    elif [[ $ROLE == "DEV" && $EMLOC == "EU" && `EUDEV_EM13C_response` -eq 0 ]];  
    then
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		wget --quiet --no-check-certificate $EUDEV_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		$JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		$EMCLI_DIR/emcli setup -url=$EUDEV_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		$EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		$EMCLI_DIR/emcli sync
		$EMCLI_DIR/emcli logout  	
    elif [[ $ROLE == "PROD" && $EMLOC == "EU" && `EUPROD_EM13C_response` -eq 0 ]];  
    then 
        echo "Deploying EMCLI"
        cd $EMCLI_DIR/
		wget --quiet --no-check-certificate $EUPROD_EM13C:4903/em/public_lib_download/emcli/kit/emcliadvancedkit.jar
		$JAVA_HOME/bin/java -jar emcliadvancedkit.jar -install_dir=$EMCLI_DIR/
		$EMCLI_DIR/emcli setup -url=$EUPROD_EM13C:4903/em -username=sysman -password=${emcli_pw} -dir=$EMCLI_DIR -trustall
		$EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw}
		$EMCLI_DIR/emcli sync
		$EMCLI_DIR/emcli logout  
    else 
    echo "Could not connect to EM13c to deploy EMCLI .." 
    fi
}

promote_targets ()
{ 
if [ -z $AGT_VER ]; 
    then echo "EM13C Agent is not running, or installed"
    return 0
fi

if [ ! -d $AGENT_HOME/bin ];
    then echo "Cannot find EM13c Agent Home"
    return 0
fi	

# Determine Server location
echo "Determining EM13c location ..."
if [[ "$MACHINE" =~ .*".eu".* ]];
        then SERVERLOC="EU"
        echo EM13C targets will be promoted to $SERVERLOC
elif [[ "$MACHINE" =~ .*".com".* ]];
        then SERVERLOC="NA"
        echo EM13C targets will be promoted to $SERVERLOC
else
        echo "EM13c targets will not be promoted for this target because host fqdn is not .com or .eu, could not determine deploy location"
        exit 1
fi

if [[ $ROLE == "PROD" ]]; then
    emcli_pw="NotThePassword"
elif [[ $ROLE == "DEV" ]]; then
    emcli_pw="QANotThePassword"
fi

if [ $ROLE == "PROD" ]; then
snmp_pw=\"NotThePassword"
elif [ $ROLE == "DEV" ] || [ $ROLE == "LAB" ]  ; then
snmp_pw=\"QANotThePassword"
fi

# Determine EM13c URL
if [ $SERVERLOC == 'EU' ] && [ $ROLE == 'DEV' ];
  then EMLOC=https://am3-d01.cloud.kiroha.eu
elif [ $SERVERLOC == 'EU' ] && [ $ROLE == 'PROD' ];
  then EMLOC=https://am3-p01.cloud.kiroha.eu
elif [ $SERVERLOC == 'NA' ] && [ $ROLE == 'DEV' ];
  then EMLOC=https://lit-d01.cloud.kiroha.com
elif [ $SERVERLOC == 'NA' ] && [ $ROLE == 'PROD' ];
  then EMLOC=https://lit-p01.cloud.kiroha.com
fi

echo "+++++++++++++++++++++++++++"
echo "Promoting database targets"
echo "+++++++++++++++++++++++++++"
rm /tmp/em_argfile.txt
echo "
add_target -name=\"LISTENER_$MACHINE\" -type=\"oracle_listener\" -host=\"$MACHINE\" -properties=\"LsnrName:LISTENER;ListenerOraDir:$ORACLE_HOME/network/admin;Port:1521;OracleHome:$ORACLE_HOME;Machine:$MACHINE;\"
add_target -name=\"$ORACLE_SID\" -type=\"oracle_database\" -host=\"$MACHINE\" -credentials=\"UserName:dbsnmp;password:${snmp_pw};Role:Normal\" -properties=\"SID:$ORACLE_SID;Port:1521;OracleHome:$ORACLE_HOME;MachineName:$MACHINE;\"
add_target -name=\"${VERSION}HOME_$MACHINE\" -type=\"oracle_home\" -host=\"$MACHINE\" -properties=\"HOME_TYPE:O;INSTALL_LOCATION:$ORACLE_HOME;INVENTORY:/U01/app/oracle\"
" >> /tmp/em_argfile.txt

$EMCLI_DIR/emcli login -username=sysman -password=${emcli_pw};
$EMCLI_DIR/emcli sync;
$EMCLI_DIR/emcli argfile /tmp/em_argfile.txt;
$EMCLI_DIR/emcli logout  

echo "++++++++++++++++++++++++++++++++++"
echo "Database target promotion complete"
echo "++++++++++++++++++++++++++++++++++"
}

# ===========================
# Configure EM13c Client API
# ==========================
emcli_13c_install;

# ======================
# Promote EM13c Targets
# ======================
promote_targets;