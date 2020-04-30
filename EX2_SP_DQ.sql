create or replace PROCEDURE SP_Utility_DQ_Test 

AS

/* Declare all required variables and updated list of columns for list */

ScenarioCount int; SOURCE_CNT int; TARGET_CNT int; FINAL_STATUS nvarchar2(50); STATUS_DESCRIPTION nvarchar2(500); DQ_REMARKS nvarchar2(500);
id INT := 1; i INT := 1; s INT := 1; COL_COUNT INT; COLUMN_NAME nvarchar2(50); sqlText varchar2(4000); VAR nvarchar2(50); PlanName nvarchar2(4000);
FileNM nvarchar2(4000); DQCheck nvarchar2(4000); DQFormat nvarchar2(4000); SourceColumns nvarchar2(4000) := NULL; SourceTable nvarchar2(4000) := NULL;
TargetTable nvarchar2(4000) := NULL; TargetColumns nvarchar2(4000) := NULL; TestScenarioDetails nvarchar2(4000); Dateformatvalue nvarchar2(4000);
SRCTableName varchar2(4000); TRGTableName nvarchar2(4000); SourceColumnsReplaced nvarchar2(4000) := NULL; TargetColumnsReplaced nvarchar2(4000) := NULL;
CNTsqlText INT; V_COUNT INT;

BEGIN
--SET NOCOUNT ON; 

/* DROP Output Result table before start of testing */

EXECUTE IMMEDIATE 'TRUNCATE TABLE SYSTEM.SP_Utility_DQ_OUTPUT';

/*-------------------------------Create Tables---------------------------------------------------------- */

sqlText := 'CREATE TABLE TESTSCENARIO (
            row_num INT NOT NULL,
            PlanName NVARCHAR2(400) NOT NULL, 
            FileNM NVARCHAR2(2000) NOT NULL,
            ExecuteTest NVARCHAR2(2000) NOT NULL,
            SourceTable NVARCHAR2(2000) NOT NULL,
            DQCheck NVARCHAR2(2000) NOT NULL,
            DQFormat NVARCHAR2(2000),
            SourceColumns NVARCHAR2(2000),
            TargetTable NVARCHAR2(2000),
            TargetColumns NVARCHAR2(2000)
            )';
EXECUTE IMMEDIATE sqlText;

sqlText:= 'Create Table TempCount
(
    CNT INT NOT NULL
)';
EXECUTE IMMEDIATE sqlText;

sqlText := 'Create Table Column_Table(
            id INT NOT NULL,
            value VARCHAR(4000) NOT NULL 
            )';
EXECUTE IMMEDIATE sqlText;

/*------------------------------------End of Creating Tables-----------------------------------------------  */

/* ----------------------------- Start of reading Scenario File--------------------------------------------  */

/* Read Information FROM Test Scenario document */

sqlText:='INSERT INTO TestScenario  
SELECT RANK() OVER ( ORDER BY PlanName, FileNM ,SourceTable, DQcheck, DQFormat DESC) as row_num, 
PlanName, FileNM ,ExecuteTest, SourceTable, DQcheck, DQFormat, SourceColumns, TargetTable, TargetColumns
FROM SYSTEM.SP_UTILITY_DQ_TESTSCENARIO WHERE ExecuteTest = ''Y''';

EXECUTE IMMEDIATE sqlText;

EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM TestScenario' INTO ScenarioCount;

/* Store Information for each row */

WHILE (s <= ScenarioCount)

LOOP

/* Extract Test scenario information */

	EXECUTE IMMEDIATE 'SELECT PlanName  FROM testscenario WHERE row_num = :i ' INTO PlanName USING s; 
    EXECUTE IMMEDIATE 'SELECT FileNM  FROM testscenario WHERE row_num = :i ' INTO FileNM USING s;
    EXECUTE IMMEDIATE 'SELECT DQCheck  FROM testscenario WHERE row_num = :i ' INTO DQCheck USING s;
    EXECUTE IMMEDIATE 'SELECT DQFormat  FROM testscenario WHERE row_num = :i ' INTO DQFormat USING s;
    EXECUTE IMMEDIATE 'SELECT SourceTable  FROM testscenario WHERE row_num = :i ' INTO SourceTable USING s;
    EXECUTE IMMEDIATE 'SELECT SourceColumns  FROM testscenario WHERE row_num = :i ' INTO SourceColumns USING s;
    EXECUTE IMMEDIATE 'SELECT TargetTable  FROM testscenario WHERE row_num = :i ' INTO TargetTable USING s;
    EXECUTE IMMEDIATE 'SELECT TargetColumns  FROM testscenario WHERE row_num = :i ' INTO TargetColumns USING s;

/*-------------------------------Starting DQ Scenarios------------------------------------------------------- */

/* ----------------------------- Start of NULL column scenario-----------------------------------------------  */
IF DQCheck = 'Null' THEN

	/* Store Column Count in COL_COUNT variable  */

	EXECUTE IMMEDIATE 'DELETE FROM column_table';

	sqlText := 'INSERT INTO column_table  
	SELECT ROW_NUMBER() OVER(ORDER BY value DESC) AS ID, 
    VALUE FROM (select distinct regexp_substr(SourceColumns,''[^,]+'', 1, level) as VALUE FROM 
    testscenario where DQCHECK = ''Null'' connect by regexp_substr(SourceColumns, ''[^,]+'', 1, level) is not null)';

    EXECUTE IMMEDIATE sqlText;

    EXECUTE IMMEDIATE 'SELECT count (ID) FROM column_table' INTO COL_COUNT;


	/* Start of While Loop which adds a row per COLUMN in output Table  */

	i := 1;    -- resetting the counter variable

	WHILE i <= COL_COUNT
		LOOP

			EXECUTE IMMEDIATE 'SELECT value  FROM column_table WHERE ID = :i ' INTO COLUMN_NAME USING i ;

			/*  ----  SQL for Source Table ----  */
			EXECUTE IMMEDIATE 'DELETE FROM TempCount';              -- Clear the TempCount table 
			SRCTableName := NULL;               					-- Clear the temp variable

			/* Drop output table IF already existing */

            SRCTableName := 'SRC_NULL_'|| COLUMN_NAME;

			SELECT COUNT(1) INTO V_COUNT   FROM USER_tables WHERE table_name = UPPER(SRCTableName);
			IF V_COUNT > 0 THEN
			sqlText := ' DROP TABLE '||SRCTableName;
			EXECUTE IMMEDIATE sqlText; 
			END IF;

			sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT *  FROM ' ||SourceTable || '  WHERE ' || COLUMN_NAME || ' is NULL';

            EXECUTE IMMEDIATE  sqlText;

			/* SQL to count the mismatched records */            

            sqlText := u' SELECT count (*) ' ||'FROM '||SRCTableName||'';

            EXECUTE IMMEDIATE sqlText INTO SOURCE_CNT;

			/*  ----  SQL for Target Table ----  */

			EXECUTE IMMEDIATE 'DELETE FROM TempCount';                 -- Clear the TempCount table 
			TRGTableName := NULL;               -- Clear the temp variable

			/* Drop output table IF already existing */

			TRGTableName := 'TGT_NULL_'|| COLUMN_NAME ;

			SELECT COUNT(1) INTO V_COUNT   FROM USER_tables WHERE table_name = UPPER(TRGTableName);
			IF V_COUNT > 0 THEN
			sqlText := ' DROP TABLE '||TRGTableName;
			EXECUTE IMMEDIATE sqlText; 
			END IF;

            sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT *  FROM ' ||TargetTable || 
            '  WHERE ' || COLUMN_NAME || ' is null and DQ_STATUS = ''Invalid''';

			EXECUTE IMMEDIATE  sqlText;

			/* SQL to count the mismatched records */

           -- sqlText := 'SELECT Count(*) INTO' || sqlText || 'FROM' || TRGTableName ;  

            sqlText := u' SELECT count (*) ' ||'FROM '||TRGTableName||'';

			EXECUTE IMMEDIATE sqlText INTO TARGET_CNT ;

			EXECUTE IMMEDIATE 'DELETE FROM TempCount';

			/* Compare source and target counts and update the status accordingly */

			IF SOURCE_CNT <> TARGET_CNT THEN
				FINAL_STATUS := 'FAILED';
			ELSE 
				FINAL_STATUS := 'PASSED';
			END IF;

			/* Status Description*/

			IF SOURCE_CNT > 0 and TARGET_CNT = 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT = 0 THEN 
				STATUS_DESCRIPTION := 'Table '''||TRGTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT > 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' and Table '''||TRGTableName||''' will show mismatched records';
			ELSE
				STATUS_DESCRIPTION := 'Source and target table are a complete match';
			END IF;

			/* Decommented code
            IF FINAL_STATUS = 'FAILED'
				SET STATUS_DESCRIPTION = 'Count MISMATCH between source and target files for records with DQ_STATUS as INVALID'
            ELSE 
				SET STATUS_DESCRIPTION = 'Count MATCH for Source and target files for records with DQ_STATUS as INVALID'
                    */

			/* DQ_REMARK Description*/

			IF SOURCE_CNT > 0 THEN
			DQ_REMARKS := 'The value of ' || COLUMN_NAME || ' is missing ';
			ELSE 
				DQ_REMARKS := NULL;
			END IF;

			TestScenarioDetails :=  DQCheck || coalesce('-' || DQFormat, '');

			/* Write results INTO output table */

			INSERT INTO SYSTEM.SP_Utility_DQ_OUTPUT (
				HEALTHPLAN,
				TABLENAME ,
				COLUMNNAME ,
				TEST_SCENARIO ,
				SOURCE_COUNT ,
				TARGET_COUNT ,
				STATUS,
				STATUS_DESC,
				DQ_REMARKS	
				)
				VALUES ( PlanName , FileNM, COLUMN_NAME , TestScenarioDetails, SOURCE_CNT , TARGET_CNT, FINAL_STATUS, STATUS_DESCRIPTION , DQ_REMARKS );

			i := i + 1;

	END LOOP;     -- end of While Loop for 'Null check' ####check error for end loop######

END IF;    -- end of IF for 'Null check'
/* ----------------------------- End of NULL column scenario-------------------------------------------------  */


/* ----------------------------- Start of Duplicate Record Count Check scenario------------------------------  */
IF DQCheck = 'Duplicate' 
THEN

	/*  ----  SQL for Source Table ----  */

	EXECUTE IMMEDIATE 'DELETE FROM TempCount' ;             -- Clear the TempCount table 
	SRCTableName := NULL;                  					-- Clear the temp variable

	/* Drop output table IF already existing */

	SRCTableName := 'SRC_DUPLICATE_CHECK';

    SELECT COUNT(1) INTO V_COUNT   FROM USER_tables WHERE table_name = UPPER(SRCTableName);
    IF V_COUNT > 0 THEN
	sqlText := ' DROP TABLE '||SRCTableName;
	EXECUTE IMMEDIATE sqlText; 
    END IF;

	sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT ' || SourceColumns || ' , count(*) as CNT FROM ' || SourceTable || 
    ' Group by ' || SourceColumns || ' Having Count (*) > 1';

	EXECUTE IMMEDIATE sqlText;

	/* SQL to count the mismatched records */

	sqlText := u' SELECT count (*) ' ||'FROM '||SRCTableName||'';

    EXECUTE IMMEDIATE sqlText INTO SOURCE_CNT;

	/*  ----  SQL for Target Table ----  */

	EXECUTE IMMEDIATE 'DELETE FROM TempCount';              -- Clear the TempCount table 
	TRGTableName := NULL ;                 					-- Clear the temp variable

	/* Drop output table IF already existing */

	TRGTableName := 'TGT_DUPLICATE_CHECK';

    SELECT COUNT(1) INTO V_COUNT   FROM USER_tables WHERE table_name = UPPER(SRCTableName);
    IF V_COUNT > 0 THEN
	sqlText := ' DROP TABLE '||TRGTableName;
	EXECUTE IMMEDIATE sqlText; 
    END IF;

	sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT ' || TargetColumns || ' , count(*) as CNT FROM '|| TargetTable || 
               ' Group by ' || TargetColumns || ' Having Count (*) > 1';
	EXECUTE IMMEDIATE sqlText;

	/* SQL to count the mismatched records */

	sqlText := ' SELECT count (*) ' ||'FROM '||TRGTableName||'';

    EXECUTE IMMEDIATE sqlText INTO TARGET_CNT ;

	EXECUTE IMMEDIATE 'DELETE FROM TempCount';

	/* Compare source and target counts and update the status accordingly */

	IF SOURCE_CNT > 0 or TARGET_CNT > 0 THEN
		FINAL_STATUS := 'FAILED';
	ELSE 
		FINAL_STATUS := 'PASSED';
	END IF;

	/* Status Description*/

	IF SOURCE_CNT > 0 and TARGET_CNT = 0 THEN
        STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' will show duplicate records';
	ELSIF TARGET_CNT > 0 and SOURCE_CNT = 0 THEN
		STATUS_DESCRIPTION := 'Table '''||TRGTableName||''' will show duplicate records';
	ELSIF TARGET_CNT > 0 and SOURCE_CNT > 0 THEN 
		STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' and Table '''||TRGTableName||''' will show duplicate records';
	ELSE
		STATUS_DESCRIPTION := 'Source and target table do not have duplicate records';
	END IF;

	/* DQ_REMARK Description*/

	IF TARGET_CNT > 0 or SOURCE_CNT > 0 THEN
		DQ_REMARKS := 'The ' || TargetColumns || ' do not create unique record in table';
	ELSE 
		DQ_REMARKS := NULL;
	END IF;

	TestScenarioDetails :=  DQCheck || coalesce('-' || DQFormat, '');

	/* Write results INTO output table */

	INSERT INTO SP_Utility_DQ_OUTPUT (
		HEALTHPLAN,
		TABLENAME ,
		COLUMNNAME ,
		TEST_SCENARIO ,
		SOURCE_COUNT ,
		TARGET_COUNT ,
		STATUS,
		STATUS_DESC,
		DQ_REMARKS	
		)
		VALUES ( PlanName , FileNM, COLUMN_NAME , TestScenarioDetails, SOURCE_CNT , TARGET_CNT, FINAL_STATUS, STATUS_DESCRIPTION , DQ_REMARKS );


END IF;    -- end of IF for 'Duplicate check'
/* ----------------------------- End of Duplicate Record Count Check scenario--------------------------------  */

/* ----------------------------- Start of Date format (YYYYMMDD) scenario------------------------------------  */
/* Store Column Count in COL_COUNT variable  */
IF DQCheck = 'DateFormat' 
THEN

	EXECUTE IMMEDIATE 'DELETE FROM column_table';

	---****Check for this error***---
    sqlText := 'INSERT INTO column_table  
	SELECT ROW_NUMBER() OVER(ORDER BY value DESC) AS ID, 
    VALUE FROM (select distinct regexp_substr(SourceColumns,''[^,]+'', 1, level) as VALUE FROM 
    testscenario  where DQCHECK = ''DateFormat'' connect by regexp_substr(SourceColumns, ''[^,]+'', 1, level) is not null) ';

    EXECUTE IMMEDIATE sqlText;

	EXECUTE IMMEDIATE 'SELECT count (ID) FROM column_table' INTO COL_COUNT;

	/* Start of While Loop which adds a row per COLUMN in output Table  */

	i := 1;    -- resetting the counter variable

	WHILE i <= COL_COUNT
		LOOP
            COLUMN_NAME := null;
            EXECUTE IMMEDIATE 'SELECT value FROM column_table WHERE ID = :i ' INTO COLUMN_NAME USING i ;

			/*  ----  SQL for Source Table ----  */

			EXECUTE IMMEDIATE 'DELETE FROM TempCount';              -- Clear the TempCount table 
			SRCTableName := NULL;               					-- Clear the temp variable

			/* Drop output table IF already existing */

			SRCTableName := 'SRC_DATE_'||COLUMN_NAME;

			SELECT COUNT(1) INTO V_COUNT FROM USER_tables WHERE table_name = UPPER(SRCTableName);

            IF V_COUNT > 0 THEN
			sqlText := 'DROP TABLE '||SRCTableName;
			EXECUTE IMMEDIATE sqlText; 
            END IF;

			/*  Condition to check IF date format is YYYYMMDD  */

            IF DQFormat = 'YYYYMMDD'
			THEN
				sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYYMMDD'' ) as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
				WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;						


            /*  Condition to check IF date format is MM/DD/YYYY  */
			elsIF DQFormat = 'MM/DD/YYYY'
			THEN
				sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''MM/DD/YYYY'' ) as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;


			/*  Condition to check IF date format is YYYY-MM-DD  */
			ELSIF DQFormat = 'YYYY-MM-DD'
			THEN
				sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYY-MM-DD'' ) as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;


			/*  Condition to check IF date format is YYYY  */
			ELSIF DQFormat = 'YYYY' 
			THEN
				sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYY'' ) as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;



			/*  Condition to check IF date format is DDMONYYYY */
			ELSIF DQFormat = 'DDMONYYYY'
			THEN
				 sqlText:= 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                 || COLUMN_NAME ||', ''DDMONYYYY'') as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
                 WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;

            /*  Condition to check IF date format is MM/DD/YYYY HH:MM:SS AM/PM */
            ELSIF DQFormat = 'MM/DD/YYYY HH:MM:SS AM/PM'
            THEN
                sqlText:= 'CREATE TABLE ' || SRCTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                 || COLUMN_NAME ||', ''MM/DD/YYYY HH:MM:SS AM/PM'') as converted_column,'||SourceTable|| '.* FROM '|| SourceTable || ' ) A 
                 WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;
            END IF;

			EXECUTE IMMEDIATE sqlText;

			/* SQL to count the mismatched records */

			sqlText := u' SELECT count (*) ' ||'FROM '||SRCTableName||'';

            EXECUTE IMMEDIATE sqlText INTO SOURCE_CNT;

			/*  ----  SQL for Target Table ----  */

			EXECUTE IMMEDIATE 'DELETE FROM TempCount';                  -- Clear the TempCount table 
			TRGTableName := NULL;              							-- Clear the temp variable

			/* Drop output table IF already existing */

			TRGTableName := 'TGT_DATE_'||COLUMN_NAME;

            SELECT COUNT(1) INTO V_COUNT   FROM USER_tables WHERE table_name = UPPER(TRGTableName);
            IF V_COUNT > 0 then
			sqlText := 'DROP TABLE '||TRGTableName;
			EXECUTE IMMEDIATE sqlText; 
            END IF;

			/*  Condition to check IF date format is YYYYMMDD  */

			IF DQFormat = 'YYYYMMDD'
			THEN

				sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYYMMDD'' ) as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;	

			/*  Condition to check IF date format is MM/DD/YYYY  */

			ELSIF DQFormat = 'MM/DD/YYYY'
			THEN
				sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''MM/DD/YYYY'' ) as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;


			/*  Condition to check IF date format is YYYY-MM-DD  */

			ELSIF DQFormat = 'YYYY-MM-DD'
			THEN
				sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYY-MM-DD'' ) as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;


			/*  Condition to check IF date format is YYYY  */

			ELSIF DQFormat = 'YYYY' 
			THEN
				sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''YYYY'') as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;


			/*  Condition to check IF date format is DDMONYYYY  */

			ELSIF DQFormat = 'DDMONYYYY'  
			THEN
				sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''DDMONYYYY'' ) as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;

            /*  Condition to check IF date format is DDMONYYYY  */

            ELSIF DQFormat = 'MM/DD/YYYY HH:MM:SS AM/PM'
            THEN
                sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT * FROM ( Select DATE_VALIDATOR ( '
                || COLUMN_NAME ||', ''MM/DD/YYYY HH:MM:SS AM/PM'' ) as converted_column,'||TargetTable|| '.* FROM '|| TargetTable || ' ) A 
                WHERE COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' ||  COLUMN_NAME;
            END IF;

			EXECUTE IMMEDIATE sqlText;

			/* SQL to count the mismatched records */

			sqlText := u' SELECT count (*) ' ||'FROM '||TRGTableName||'';

            EXECUTE IMMEDIATE sqlText INTO TARGET_CNT;


            /*EXECUTE IMMEDIATE 'DELETE FROM TempCount';  
            EXECUTE IMMEDIATE ' SELECT CNTsqlText FROM DUAL' INTO TempCount ;
			EXECUTE IMMEDIATE 'SELECT CNT  FROM TempCount' INTO TARGET_CNT;
			EXECUTE IMMEDIATE 'DELETE FROM TempCount'; */


			/* Compare source and target counts and update the status accordingly */

			IF SOURCE_CNT <> TARGET_CNT THEN
				FINAL_STATUS := 'FAILED';
			ELSE 
				FINAL_STATUS := 'PASSED';
			END IF;

			/* Status Description*/

            IF SOURCE_CNT > 0 and TARGET_CNT = 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT = 0 THEN
				STATUS_DESCRIPTION := 'Table '''||TRGTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT > 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' and Table '''||TRGTableName||''' will show mismatched records';
			ELSE
				STATUS_DESCRIPTION := 'Source and target table are a complete match';
			END IF;

			/* DQ_REMARK Description*/

			IF SOURCE_CNT > 0 THEN
				DQ_REMARKS := 'The value of ' || COLUMN_NAME || ' is in the format other than expected '''||DQFormat||''' format ';
			ELSE 
				DQ_REMARKS := NULL;
			END IF;

			TestScenarioDetails :=  DQCheck || coalesce('-' || DQFormat, '');

			/* Write results INTO output table */

			INSERT INTO SP_Utility_DQ_OUTPUT (
				HEALTHPLAN,
				TABLENAME ,
				COLUMNNAME ,
				TEST_SCENARIO ,
				SOURCE_COUNT ,
				TARGET_COUNT ,
				STATUS,
				STATUS_DESC,
				DQ_REMARKS	
				)
				VALUES ( PlanName , FileNM, COLUMN_NAME , TestScenarioDetails, SOURCE_CNT , TARGET_CNT, FINAL_STATUS, STATUS_DESCRIPTION , DQ_REMARKS );

			i := i + 1;

		END LOOP;     -- end of While Loop for 'DateFormat'

END IF;     -- end of IF for 'DateFormat'
/* ----------------------------- End of Date format (YYYYMMDD) scenario--------------------------------------  */

/* ----------------------------- Start of Integer Format check column scenario-------------------------------  */
IF DQCheck = 'IntegerFormatCheck' THEN

	/* Store Column Count in COL_COUNT variable  */

	EXECUTE IMMEDIATE 'DELETE FROM column_table';

	sqlText := 'INSERT INTO column_table  
	SELECT ROW_NUMBER() OVER(ORDER BY value DESC) AS ID, 
    VALUE FROM (select distinct regexp_substr(SourceColumns,''[^,]+'', 1, level) as VALUE FROM 
    testscenario where DQCHECK = ''IntegerFormatCheck'' connect by regexp_substr(SourceColumns, ''[^,]+'', 1, level) is not null)';

    EXECUTE IMMEDIATE sqlText;

    EXECUTE IMMEDIATE 'SELECT count (ID) FROM column_table' INTO COL_COUNT;

    i := 1;    -- resetting the counter variable

	WHILE i <= COL_COUNT
		LOOP

			EXECUTE IMMEDIATE 'SELECT value  FROM column_table WHERE ID = :i ' INTO COLUMN_NAME USING i ;

			/*  ----  SQL for Source Table ----  */
			EXECUTE IMMEDIATE 'DELETE FROM TempCount';              -- Clear the TempCount table 
			SRCTableName := NULL;               					-- Clear the temp variable

			/* Drop output table IF already existing */

            SRCTableName := 'SRC_IFC_'||COLUMN_NAME;

            SELECT COUNT(1) INTO V_COUNT FROM USER_tables WHERE table_name = UPPER(SRCTableName);

            IF V_COUNT > 0 THEN
			sqlText := ' DROP TABLE '||SRCTableName;
			EXECUTE IMMEDIATE sqlText; 
            END IF;

            sqlText := 'CREATE TABLE ' || SRCTableName|| ' AS SELECT *  FROM ' ||SourceTable || '  WHERE REGEXP_LIKE (RTRIM ( ' ||COLUMN_NAME ||' ) , ''[^0-9]'')';

            EXECUTE IMMEDIATE  sqlText;

            sqlText := u' SELECT count (*) ' ||'FROM '||SRCTableName||'';

            EXECUTE IMMEDIATE sqlText INTO SOURCE_CNT;

            /*  ----  SQL for Target Table ----  */

			EXECUTE IMMEDIATE 'DELETE FROM TempCount';                -- Clear the TempCount table 
			TRGTableName := NULL;               -- Clear the temp variable

			/* Drop output table IF already existing */

			TRGTableName := 'TGT_IFC_'|| COLUMN_NAME ;

			SELECT COUNT(1) INTO V_COUNT FROM USER_tables WHERE table_name = UPPER(TRGTableName);

            IF V_COUNT > 0 THEN
			sqlText := ' DROP TABLE '||TRGTableName;
			EXECUTE IMMEDIATE sqlText; 
            END IF;

            --sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT *  FROM ' ||TargetTable || 
            --'  WHERE REGEXP_LIKE (RTRIM ( ' ||COLUMN_NAME ||' ) , ''[^0-9]'') and DQ_STATUS = ''Invalid'' ';
            sqlText := 'CREATE TABLE ' || TRGTableName|| ' AS SELECT *  FROM ' ||TargetTable || '  
            WHERE REGEXP_LIKE (RTRIM ( ' ||COLUMN_NAME ||' ) , ''[^0-9]'') and DQ_STATUS = ''Invalid'' ';
			EXECUTE IMMEDIATE  sqlText;

            /* SQL to count the mismatched records */

            sqlText := u' SELECT count (*) ' ||'FROM '||TRGTableName||'';

			EXECUTE IMMEDIATE  sqlText INTO CNTsqlText;

			EXECUTE IMMEDIATE sqlText INTO TARGET_CNT;

			--DELETE FROM TempCount;

            /* Compare source and target counts and update the status accordingly */

			IF SOURCE_CNT <> TARGET_CNT THEN
				FINAL_STATUS := 'FAILED';
			ELSE 
				FINAL_STATUS := 'PASSED';
			END IF;

			/* Status Description*/
                    /* Decommented code
                    IF FINAL_STATUS = 'FAILED'
                    SET STATUS_DESCRIPTION = 'Count MISMATCH between source and target files for records with DQ_STATUS as INVALID'
                    ELSE 
                    SET STATUS_DESCRIPTION = 'Count MATCH for Source and target files for records with DQ_STATUS as INVALID'
                    */
			IF SOURCE_CNT > 0 and TARGET_CNT = 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT = 0 THEN 
				STATUS_DESCRIPTION := 'Table '''||TRGTableName||''' will show mismatched records';
			ELSIF TARGET_CNT > 0 and SOURCE_CNT > 0 THEN
				STATUS_DESCRIPTION := 'Table '''||SRCTableName||''' and Table '''||TRGTableName||''' will show mismatched records';
			ELSE
				STATUS_DESCRIPTION := 'Source and target table are a complete match';
			END IF;

			/* DQ_REMARK Description*/

			IF SOURCE_CNT > 0 THEN
			DQ_REMARKS := 'The value of ' || COLUMN_NAME || ' is missing ';
			ELSE 
				DQ_REMARKS := NULL;
			END IF;

			TestScenarioDetails :=  DQCheck || coalesce('-' || DQFormat, '');

			/* Write results INTO output table */

			INSERT INTO SYSTEM.SP_Utility_DQ_OUTPUT (
				HEALTHPLAN,
				TABLENAME ,
				COLUMNNAME ,
				TEST_SCENARIO ,
				SOURCE_COUNT ,
				TARGET_COUNT ,
				STATUS,
				STATUS_DESC,
				DQ_REMARKS	
				)
				VALUES ( PlanName , FileNM, COLUMN_NAME , TestScenarioDetails, SOURCE_CNT , TARGET_CNT, FINAL_STATUS, STATUS_DESCRIPTION , DQ_REMARKS );


            i := i + 1;

        END LOOP;

    END IF;
/* -------------------------------- END of Integer Format check column scenario -------------------------------  */    
    s := s + 1;

END LOOP;

sqlText:= 'SELECT * FROM SYSTEM.SP_Utility_DQ_OUTPUT';
EXECUTE IMMEDIATE sqlText;
--open prc for sqlText;

EXECUTE IMMEDIATE ' DROP TABLE TESTSCENARIO';
EXECUTE IMMEDIATE ' DROP TABLE TempCount';
EXECUTE IMMEDIATE ' DROP TABLE column_table';

END;