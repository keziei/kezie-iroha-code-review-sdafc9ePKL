--Gather DB, Dictionary and Fixed Object stats
begin
dbms_stats.gather_database_stats(
cascade=> TRUE,
gather_sys=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 4,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_dictionary_stats(
cascade=> TRUE,
estimate_percent=> DBMS_STATS.AUTO_SAMPLE_SIZE,
degree=> 4,
no_invalidate=> FALSE,
granularity=> 'AUTO',
method_opt=> 'FOR ALL COLUMNS SIZE AUTO',
options=> 'GATHER');

dbms_stats.gather_fixed_objects_stats();
end;
/

  

