Prompt altering default profile ..
ALTER PROFILE default LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating service_account profile ..
CREATE PROFILE service_account LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time unlimited
 password_lock_time .0104
 password_reuse_max unlimited
 password_reuse_time unlimited
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating system_user profile ..
CREATE PROFILE system_user LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt Creating normal_user profile ..
CREATE PROFILE normal_user LIMIT
 failed_login_attempts 6
 password_grace_time 7
 password_life_time 90
 password_lock_time .0104
 password_reuse_max 5
 password_reuse_time 400
PASSWORD_VERIFY_FUNCTION ot_verify_function
/
Prompt assign system users to profiles ..
GRANT EXECUTE ON ot_verify_function TO PUBLIC ;
Alter user system profile system_user;
Alter user sys profile system_user;
Alter user SYSMAN profile service_account;
Alter user DBSNMP profile service_account;
alter user MGMT_VIEW profile service_account;