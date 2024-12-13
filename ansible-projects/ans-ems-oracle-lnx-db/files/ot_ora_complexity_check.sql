create or replace function ot_ora_complexity_check
(password varchar2,
 chars integer := null,
 letter integer := null,
 upper integer := null,
 lower integer := null,
 digit integer := null,
 special integer := null)
return boolean is
   digit_array varchar2(10) := '0123456789';
   alpha_array varchar2(26) := 'abcdefghijklmnopqrstuvwxyz';
   cnt_letter integer := 0;
   cnt_upper integer := 0;
   cnt_lower integer := 0;
   cnt_digit integer := 0;
   cnt_special integer := 0;
   delimiter boolean := false;
   len integer := nvl (length(password), 0);
   i integer ;
   ch char(1);
begin
   -- Check that the password length does not exceed 2 * (max DB pwd len)
   -- The maximum length of any DB User password is 128 bytes.
   -- This limit improves the performance of the Edit Distance calculation
   -- between old and new passwords.
   if len > 256 then
      raise_application_error(-20020, 'Password length more than 256 characters'
);
   end if;

   -- Classify each character in the password.
   for i in 1..len loop
      ch := substr(password, i, 1);
      if ch = '"' then
         delimiter := true;
      elsif instr(digit_array, ch) > 0 then
         cnt_digit := cnt_digit + 1;
      elsif instr(alpha_array, nls_lower(ch)) > 0 then
         cnt_letter := cnt_letter + 1;
         if ch = nls_lower(ch) then
            cnt_lower := cnt_lower + 1;
         else
            cnt_upper := cnt_upper + 1;
         end if;
      else
         cnt_special := cnt_special + 1;
      end if;
   end loop;

   if delimiter = true then
      raise_application_error(-20012, 'password must NOT contain a '
                               || 'double-quotation mark which is '
                               || 'reserved as a password delimiter');
   end if;
   if chars is not null and len < chars then
      raise_application_error(-20001, 'Password length less than ' ||
                              chars);
   end if;

   if letter is not null and cnt_letter < letter then
      raise_application_error(-20022, 'Password must contain at least ' ||
                                      letter || ' letter(s)');
   end if;
   if upper is not null and cnt_upper < upper then
      raise_application_error(-20023, 'Password must contain at least ' ||
                                      upper || ' uppercase character(s)');
   end if;
   if lower is not null and cnt_lower < lower then
      raise_application_error(-20024, 'Password must contain at least ' ||
                                      lower || ' lowercase character(s)');
   end if;
   if digit is not null and cnt_digit < digit then
      raise_application_error(-20025, 'Password must contain at least ' ||
                                      digit || ' digit(s)');
   end if;
   if special is not null and cnt_special < special then
      raise_application_error(-20026, 'Password must contain at least ' ||
                                      special || ' special character(s)');
   end if;

   return(true);
end;
/