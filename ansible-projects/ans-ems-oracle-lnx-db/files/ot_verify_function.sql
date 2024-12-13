CREATE OR REPLACE FUNCTION ot_verify_function
(username varchar2,
 password varchar2,
 old_password varchar2)
RETURN boolean IS
   differ integer;
   db_name varchar2(40);
   i integer;
--   reverse_user dbms_id;
--   canon_username dbms_id := username;
BEGIN
   -- Bug 22369990: Dbms_Utility may not be available at this point, so switch
   -- to dynamic SQL to execute canonicalize procedure.
--   IF (substr(username,1,1) = '"') THEN
--     execute immediate 'begin dbms_utility.canonicalize(:p1,  :p2, 128); end;'
--                        using IN username, OUT canon_username;
--   END IF;
   IF NOT ot_ora_complexity_check(password, chars => 10, letter => 1, digit => 1,
                               special => 1) THEN
      RETURN(FALSE);
   END IF;

   -- Check if the password contains the username
--   IF regexp_instr(password, canon_username, 1, 1, 0, 'i') > 0 THEN
--     raise_application_error(-20002, 'Password contains the username');
--   END IF;

   -- Check if the password contains the username reversed
--   FOR i in REVERSE 1..length(canon_username) LOOP
--     reverse_user := reverse_user || substr(canon_username, i, 1);
--   END LOOP;
--   IF regexp_instr(password, reverse_user, 1, 1, 0, 'i') > 0 THEN
--     raise_application_error(-20003, 'Password contains the username ' ||
--                                     'reversed');
--   END IF;

   -- Check if the password contains the server name
   select name into db_name from sys.v$database;
   IF regexp_instr(password, db_name, 1, 1, 0, 'i') > 0 THEN
      raise_application_error(-20004, 'Password contains the server name');
   END IF;

   -- Check if the password contains 'oracle'
   IF regexp_instr(password, 'oracle', 1, 1, 0, 'i') > 0 THEN
        raise_application_error(-20006, 'Password too simple');
   END IF;

   RETURN(TRUE);
END;
/

GRANT EXECUTE ON ot_verify_function TO PUBLIC ;