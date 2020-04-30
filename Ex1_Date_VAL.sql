create or replace FUNCTION DATE_VALIDATOR(D1 VARCHAR2, FRMT VARCHAR2) RETURN VARCHAR2

AS /*If you want to return date, write RETURNS DATE instead of VARCHAR*/

sqlText VARCHAR2(2000);
sqlText1 VARCHAR2(2000);
CONVERTED_DATE VARCHAR2(2000);
CONVERTED_DATE1 VARCHAR2(2000);

BEGIN

	--RAISE NOTICE 'DATE PASSED WHILE CALLING THIS FUNCTION IS %', D1;
	--RAISE NOTICE 'DATE FORMAT WHILE CALLING THIS FUNCTION IS %', FRMT;

	IF FRMT = 'YYYYMMDD' THEN

	    sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;
        
	ELSIF FRMT = 'MM/DD/YYYY' THEN 

	sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;

	--RAISE NOTICE 'Value of sqlText1 is %', sqlText1;

	ELSIF FRMT = 'YYYY-MM-DD' THEN 

	sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;

	--RAISE NOTICE 'Value of sqlText1 is %', sqlText1;

	ELSIF FRMT = 'YYYY' THEN 

	sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;

	--RAISE NOTICE 'Value of sqlText1 is %', sqlText1;

	ELSIF FRMT = 'DDMONYYYY' THEN 

	sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;

	--RAISE NOTICE 'Value of sqlText1 is %', sqlText1;
    
    ELSIF FRMT = 'MM/DD/YYYY HH:MM:SS AM/PM' THEN
    
    sqlText1:= 'SELECT TO_CHAR ( TO_DATE (' || D1 || ',''yyyy-MM-dd'')' || ',' || '''' || FRMT || '''' || ') ' ||' FROM DUAL' ;

	ELSE DBMS_OUTPUT.PUT_LINE( 'INVALID DATE FORMAT PASSED AS INPUT');

	END IF;

    EXECUTE IMMEDIATE sqlText1 INTO CONVERTED_DATE1;
    
    --CONVERTED_DATE1 := sqlText;

	--RAISE NOTICE 'Converted Date1 from sqltext1 is %', CONVERTED_DATE1; 

	RETURN CONVERTED_DATE1;

	EXCEPTION
		WHEN OTHERS THEN
		--DBMS_OUTPUT.PUT_LINE( 'THIS NOTICE IS FROM WITHIN AN EXCEPTION');
		RETURN null; --TO_DATE('19000101','yyyyMMdd'); 
		/*Returned 'null' as a string because in SP DQ Date_Format check utility, target table has 'null' instead of database NULL */

END;