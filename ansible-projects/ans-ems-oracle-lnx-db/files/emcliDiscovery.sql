set verify off
set termout off
set term off
set heading off
set feedback off
set echo off
set linesize 1000
set pagesize 0
spool /tmp/emcliDiscovery.txt
--DiscoverCluster--
select 
'add_target -name="' || ManagementEntityEO.ENTITY_NAME 
|| '" -type="cluster" -host="' ||ManagementEntityEO.HOST_NAME 
|| '" -monitor_mode="1" -properties="OracleHome:' ||
(SELECT PROPERTY_VALUE FROM SYSMAN.MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%HOME' AND UPPER(PROPERTY_NAME)!='MW_HOME' OR PROPERTY_NAME ='INSTALL_LOCATION') AND ROWNUM = 1) 
|| ';eonsPort:' || 
(SELECT PROPERTY_VALUE FROM SYSMAN.MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE 'EONSPORT%')) 
|| ';scanName:' || 
(SELECT PROPERTY_VALUE FROM SYSMAN.MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE 'SCANNAME%')) 
|| ';scanPort:' || 
(SELECT PROPERTY_VALUE FROM SYSMAN.MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE 'SCANPORT%'))
|| '" -instances="'||
/*(select listagg(sub.entity_name,':host;') within group (order by sub.entity_name) FROM GC_MANAGEABLE_ENTITIES sub
where sub.ENTITY_TYPE='host' and sub.entity_name like ManagementEntityEO.ENTITY_NAME||'%')*/
(select listagg(d.entity_name,':host;') within group (order by d.entity_name) FROM GC_MANAGEABLE_ENTITIES sub, mgmt_assoc_instances a, em_manageable_entities d
where
a.source_me_guid = HEXTORAW(sub.entity_guid)
and sub.entity_guid= a.SOURCE_ME_GUID
AND a.dest_me_guid = d.entity_guid
AND d.manage_status != 1
and d.ENTITY_TYPE='host'
and a.ASSOC_TYPE = 'cluster_contains'
and sub.entity_name like '%'||ManagementEntityEO.ENTITY_NAME||'%')
||':host"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='cluster'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT 1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.HOST_NAME ='machine1';
--Discover database instance--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="oracle_database" -host="' ||
ManagementEntityEO.HOST_NAME || '" -credentials="UserName:dbsnmp;password:mypassword;Role:Normal" -properties="SID:' ||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%SID')) || ';Port:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = 
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%PORT')) || ';OracleHome:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%HOME' AND UPPER(PROPERTY_NAME)!='MW_HOME' OR PROPERTY_NAME ='INSTALL_LOCATION') AND ROWNUM = 1) ||
';MachineName:' || ManagementEntityEO.HOST_NAME || ';"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='oracle_database'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT  1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.HOST_NAME ='machine1';
--Discover second instance--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="oracle_database" -host="' ||
ManagementEntityEO.HOST_NAME || '" -credentials="UserName:dbsnmp;password:mypassword;Role:Normal" -properties="SID:' ||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%SID')) || ';Port:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%PORT')) || ';OracleHome:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%HOME' AND UPPER(PROPERTY_NAME)!='MW_HOME' OR PROPERTY_NAME ='INSTALL_LOCATION') AND ROWNUM = 1) ||
';MachineName:' || ManagementEntityEO.HOST_NAME || ';"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='oracle_database'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT  1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.HOST_NAME ='machine2';
--Discover rac database--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="rac_database" -host="' ||
ManagementEntityEO.HOST_NAME || 
'" -monitor_mode="1" -properties="ServiceName:'||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%SERVICENAME%')) ||';ClusterName:'||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%CLUSTERNAME%')) ||'" -instances="'||
(select listagg(sub.entity_name,':oracle_database;') within group (order by sub.entity_name) FROM GC_MANAGEABLE_ENTITIES sub
where sub.ENTITY_TYPE='oracle_database' and sub.entity_name like ManagementEntityEO.ENTITY_NAME||'%')||':oracle_database"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='rac_database'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT 1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
and ManagementEntityEO.HOST_NAME='machine1';
--Discover ASM instance--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="osm_instance" -host="' ||
ManagementEntityEO.HOST_NAME || '" -credentials="UserName:asmsnmp;password:mypassword;Role:sysdba" -properties="SID:' ||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%SID')) || ';Port:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%PORT')) || ';OracleHome:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%HOME' AND UPPER(PROPERTY_NAME)!='MW_HOME' OR PROPERTY_NAME ='INSTALL_LOCATION') AND ROWNUM = 1) ||
';MachineName:' || ManagementEntityEO.HOST_NAME || ';"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='osm_instance'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT 1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.HOST_NAME ='machine1';
--discover second asm instance--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="osm_instance" -host="' ||
ManagementEntityEO.HOST_NAME || '" -credentials="UserName:asmsnmp;password:mypassword;Role:sysdba" -properties="SID:' ||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%SID')) || ';Port:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%PORT')) || ';OracleHome:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE '%HOME' AND UPPER(PROPERTY_NAME)!='MW_HOME' OR PROPERTY_NAME ='INSTALL_LOCATION') AND ROWNUM = 1) ||
';MachineName:' || ManagementEntityEO.HOST_NAME || ';"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='osm_instance'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT 1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.HOST_NAME ='machine2';
--discover asm cluster--
select 'add_target -name="' || ManagementEntityEO.ENTITY_NAME || '" -type="osm_cluster" -host="' ||
ManagementEntityEO.HOST_NAME || '" -monitor_mode="1" -properties="ServiceName:'||
(SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID = ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE 'SERVICE%')) || ';ClusterName:' || (SELECT PROPERTY_VALUE FROM MGMT_TARGET_PROPERTIES WHERE TARGET_GUID =
ManagementEntityEO.ENTITY_GUID AND
(UPPER(PROPERTY_NAME) LIKE 'CLUSTER%')) ||'" -instances="'||(select listagg(d.entity_name,':osm_instance;') within group (order by d.entity_name) FROM GC_MANAGEABLE_ENTITIES sub, mgmt_assoc_instances a, em_manageable_entities d
WHERE a.dest_me_guid = HEXTORAW(sub.ENTITY_GUID)
AND a.source_me_guid = d.entity_guid
--and d.entity_guid = sub.entity_guid
and a.ASSOC_TYPE='cluster_member'
and sub.entity_name like '%'||ManagementEntityEO.ENTITY_NAME||'%')
||':osm_instance" -credentials="UserName:asmsnmp;password:mypassword;Role:sysdba"'
FROM GC_MANAGEABLE_ENTITIES ManagementEntityEO,MGMT_TARGET_TYPES ManagementEntityTypeEO
WHERE ManagementEntityEO.PROMOTE_STATUS=1
AND ManagementEntityEO.MANAGE_STATUS=1
AND ManagementEntityEO.ENTITY_TYPE!= 'host'
AND ManagementEntityEO.ENTITY_TYPE='osm_cluster'
AND ManagementEntityEO.ENTITY_TYPE= ManagementEntityTypeEO.TARGET_TYPE
AND (NOT EXISTS(SELECT 1 FROM
mgmt_type_properties mtp WHERE mtp.target_type= ManagementEntityEO.entity_type AND mtp.property_name ='DISCOVERY_FWK_OPTOUT'AND
mtp.property_value='1'))
AND ManagementEntityEO.entity_name =
(select ENTITY_NAME from em_manageable_entities where ENTITY_TYPE='osm_cluster'and MANAGE_STATUS=1 and PROMOTE_STATUS=1 and host_name='machine1');
spool off
