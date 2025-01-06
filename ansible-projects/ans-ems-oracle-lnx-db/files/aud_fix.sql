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