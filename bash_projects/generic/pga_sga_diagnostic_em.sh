#!/bin/bash
## Author: Kezie Iroha PGA / SGA Diagnostic
# Generate diagnostic report of PGA analysis

export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/bin:/usr/bin:/sbin:/home/oracle/.local/bin:/home/oracle/bin
export v_sid=`grep -v '^\(Agent\|agent\|#\|*\|$\)' /etc/oratab | awk -F ':' '{print $1}'`
export DATE=`/bin/date '+%%Y-%%m-%%d_%%H:%%M'`

. oraenv << EOF
${v_sid}
EOF

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

# Generate Diagnostic Report
${ORACLE_HOME}/bin/sqlplus -s "/ as sysdba" <<EOF
set markup html on echo off feedback off verify off
spool /tmp/pga_sga_diagnostic_${ORACLE_SID}.html

-- Target 
prompt Database Name / Machine 
select instance_name, host_name from v\$instance;

--Locate the top PGA user
/*
prompt
set feedback off
set lines 75
set pages 999
set serveroutput on
declare a1 number;
            a2 number;
            a3 varchar2(30);
            a4 varchar2(30);
            a5 number;
            a6 number;
            a7 number;
            a8 number;
            blankline varchar2(70);
cursor code is select pid, spid, substr(username,1,20) "USER" , substr(program,1,30) "Program",
PGA_USED_MEM, PGA_ALLOC_MEM, PGA_FREEABLE_MEM, PGA_MAX_MEM
from v\$process where pga_alloc_mem=
(select max(pga_alloc_mem) from v\$process
where program not like '%%LGWR%%');
begin
  blankline:=chr(13);
  open code;
  fetch code into a1, a2, a3, a4, a5, a6, a7, a8;
    
  dbms_output.put_line(blankline);
  dbms_output.put_line('               Top PGA User (bytes)');
  dbms_output.put_line(blankline);

  dbms_output.put_line('PID:   '||a1||'     '||'SPID:   '||a2);
  dbms_output.put_line('User Info:          '||a3);
  dbms_output.put_line('Program:            '||a4);
  dbms_output.put_line('PGA Used:           '||a5);
  dbms_output.put_line('PGA Allocated:      '||a6);
  dbms_output.put_line('PGA Freeable:       '||a7);
  dbms_output.put_line('Maximum PGA:        '||a8);
end;
/  
*/

prompt
prompt  OS Physical Memory / Swap Stats
set lines 1000
col stat_name for a30
select stat_name, round((value/1024/1024/1024),2) SIZE_GB
from v\$osstat where stat_name like '%%_BYTES'
/

prompt
prompt  SGA Target
set lines 1000
col name for a50
select 'SGA Target' Name, round(sum(bytes/1024/1024/1024)) TOTAL, 'GB' unit from v\$sgainfo where name='Maximum SGA Size'
/
prompt
prompt  PGA Statistics
col name for a50
select name, round(sum(value/1024/1024/1024)) Total, 'GB' unit from v\$pgastat where unit = 'bytes' group by name, unit
union
select name, value, unit from v\$pgastat where (unit is null or unit != 'bytes')
/
prompt
prompt
prompt  PGA Target Advice
set lines 1000
select 
round((PGA_TARGET_FOR_ESTIMATE/1024/1024/1024),2) PGA_TARGET_FOR_ESTIMATE_GB, 
PGA_TARGET_FACTOR,
ADVICE_STATUS,
round((BYTES_PROCESSED/1024/1024/1024)) GB_PROCESSED,  
ESTD_TIME ESTD_TIME_SECONDS, 
round((ESTD_EXTRA_BYTES_RW/1024/1024/1024)) ESTD_EXTRA_GB_RW, 
ESTD_PGA_CACHE_HIT_PERCENTAGE, 
ESTD_OVERALLOC_COUNT   
from v\$pga_target_advice
/

prompt
prompt  SGA Target Advice
select 
round((SGA_SIZE/1024)) SGA_SIZE_GB,
SGA_SIZE_FACTOR,
ESTD_DB_TIME ESTD_DB_TIME_SECONDS,
ESTD_DB_TIME_FACTOR,
round((ESTD_PHYSICAL_READS/1024/1024/1024)) ESTD_PHYSICAL_READS_GB, 
round((ESTD_BUFFER_CACHE_SIZE/1024),1) ESTD_BUFFER_CACHE_SIZE_GB,
round((ESTD_SHARED_POOL_SIZE/1024),1) ESTD_SHARED_POOL_SIZE_GB 
from v\$sga_target_advice
/

set lines 132
set pages 999
col name format a40 head "Name"
col value format 999,999,999 head "Total"
col unit format a10 head "Units"
col pga_size format a25 head "PGA Size"
col optimal_executions format 999,999,999,999 head "Optimal"
col onepass_executions format 999,999,999,999 head "One-Pass"
col multipasses_executions format 999,999,999,999 head "Multi-Pass"
col optimal_count format 999,999,999,999 head "Optimal Count"
col optimal_perc format 999 head "Optimal|PCT"
col onepass_count format 999,999,999,999 head "One-Pass Count"
col onepass_perc format 999 head "One|PCT"
col multipass_count format 999,999,999,999 head "Multi-Pass Count"
col multipass_perc format 999 head "Multi|PCT"
col sid format 999,999 Head "SID"
col operation format a30 head "Operation"
col esize format 999,999,999 head "Expected Size"
col mem format 999,999,999 head "Actual Mem"
col "MAX MEM" format 999,999,999 head "Maximum Mem"
col pass format 999,999 head "Passes"
col tsize format 999,999,999,999,999 head "Temporary|Segment Size"

Prompt
Prompt Review workarea buckets to see how efficient memory is utilized
Prompt  Ideal to see OPTIMAL EXECUTIONS vs. ONE-PASS and Multi-PASS
select case when low_optimal_size < 1024*1024 
then to_char(low_optimal_size/1024,'999999') || 'kb <= PGA < ' || 
(HIGH_OPTIMAL_SIZE+1)/1024|| 'kb' 
else to_char(low_optimal_size/1024/1024,'999999') || 'mb <= PGA < ' || 
(high_optimal_size+1)/1024/1024|| 'mb' 
end pga_size, 
optimal_executions, 
onepass_executions, 
multipasses_executions 
from v\$sql_workarea_histogram where total_executions <> 0 
order by low_optimal_size
/

Prompt
Prompt Review workarea buckets as percentages overall
Prompt      this script assuming 64K optimal size 
SELECT optimal_count, round(optimal_count*100/total, 2) optimal_perc,
       onepass_count, round(onepass_count*100/total, 2) onepass_perc,
       multipass_count, round(multipass_count*100/total, 2) multipass_perc
FROM
       (SELECT decode(sum(total_executions), 0, 1, sum(total_executions)) total,
               sum(OPTIMAL_EXECUTIONS) optimal_count,
               sum(ONEPASS_EXECUTIONS) onepass_count,
               sum(MULTIPASSES_EXECUTIONS) multipass_count
        FROM   v\$sql_workarea_histogram
        WHERE  low_optimal_size > 64*1024)
/

Prompt
Prompt   Review current activity in Work Areas
SELECT to_number(decode(SID, 65535, NULL, SID)) sid,
       operation_type OPERATION,trunc(EXPECTED_SIZE/1024) ESIZE,
       trunc(ACTUAL_MEM_USED/1024) MEM, trunc(MAX_MEM_USED/1024) "MAX MEM",
       NUMBER_PASSES PASS, trunc(TEMPSEG_SIZE/1024) TSIZE
FROM v\$SQL_WORKAREA_ACTIVE
ORDER BY 1,2
/

prompt
prompt List Largest process.
prompt Do Not eliminate all background process because certain background processes do need to be monitored at times 
select pid,spid,substr(username,1,20) "USER" ,program,PGA_USED_MEM,PGA_ALLOC_MEM,PGA_FREEABLE_MEM,PGA_MAX_MEM
from v\$process
where pga_alloc_mem=(select max(pga_alloc_mem) from v\$process
where program not like '%%LGWR%%');

prompt
prompt Summation of pga based on v\$process
prompt allocated includes free PGA memory not yet released to the operating system by the server process
select sum(pga_alloc_mem)/1024/1024 as "Mbytes allocated", sum(PGA_USED_MEM)/1024/1024 as "Mbytes used" from v\$process;

prompt
prompt Summation of pga memory based on v\$sesstat
select sum(value)/1024/1024 as Mbytes from v\$sesstat s, v\$statname n
where
n.STATISTIC# = s.STATISTIC# and
n.name = 'session pga memory';

prompt
prompt List all processes including pga size from v\$process
prompt Outer join will show if any defunct processes exist without associated session.
set lines 1000 pages 500
column spid heading 'OSpid' format a8
column pid heading 'Orapid' format 999999
column sid heading 'Sess id' format 99999
column 'serial#' heading 'Serial#' format 999999
column status heading 'Status' format a8
column pga_alloc_mem heading 'PGA alloc' format 99,999,999,999
column pga_used_mem heading 'PGA used' format 99,999,999,999
column username heading 'oracleuser' format a12
column osuser heading 'OS user' format a12
column program heading 'Program' format a50
SELECT
p.spid,
p.pid,
s.sid,
s.serial#,
s.status,
p.pga_alloc_mem,
p.PGA_USED_MEM,
s.username,
s.osuser,
s.program
FROM
v\$process p,
v\$session s
WHERE s.paddr ( + ) = p.addr
and p.BACKGROUND is null /* Remove if need to monitor background processes */
Order by p.pga_alloc_mem desc;

prompt
prompt Summation of pga and sga gives a value of total memory usage by oracle instance
prompt look at total memory used by instance SGA and PGA
select sum(bytes)/1024/1024 as Mbytes from
(select value as bytes from v\$sga
union all
select value as bytes from
v\$sesstat s,
v\$statname n
where
n.STATISTIC# = s.STATISTIC# and
n.name = 'session pga memory'
)
/

prompt
prompt PGA usage for all processes related to instance from v\$sesstat.
prompt Trends of individual processes growing in size
prompt v\$sesstat pga/uga memory size
select p.spid, s.sid, substr(n.name,1,25) memory, s.value as Bytes from v\$sesstat s, v\$statname n, v\$process p, v\$session vs
where s.statistic# = n.statistic#
/* this query currently looks at both uga and pga, if only one of these is desired modify the like clause to pga or uga */
and n.name like '%%ga memory%%'
and s.sid=vs.sid
and vs.paddr=p.addr
/* --remove comment delimiters to view only certain sizes, i.e. over 10Mbytes
and s.value > 10000000 */
order by s.value desc
/

set markup html on echo on feedback on verify on
spool off
EOF

#Mail report
#mailx -s "PGA Diagnostic Report - {ORACLE_SID} `hostname`" -a /tmp/pga_sga_diagnostic_${ORACLE_SID}.html
uuencode /tmp/pga_sga_diagnostic_${ORACLE_SID}.html pga_sga_diagnostic_${ORACLE_SID}.html | mailx -s "PGA Diagnostic for ${ORACLE_SID}" kiroha@kiroha.org < /dev/null