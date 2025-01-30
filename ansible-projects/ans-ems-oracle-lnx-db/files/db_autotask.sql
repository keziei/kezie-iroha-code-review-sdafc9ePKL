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