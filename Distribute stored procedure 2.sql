-- Distribute stored procedure on report server
-- Alan
-- 04/26/21

-- Distribute stored procedure to all RMO DBs on report server
-- *** Move comments to after the procedure name line ***

-- 1.  Changed to keep notes before PROCEDURE

-- Change these 2 variables to your Database and procedure to distribute
DECLARE @DB NVARCHAR(20) = 'RMONewYork'
DECLARE @SP NVARCHAR(50) = 'r_0000_CallFireByRoute'

-- This will grab the code of the stored procedure you define below
DECLARE @RawDefinition NVARCHAR(max) = OBJECT_DEFINITION (OBJECT_ID(N'[' +@DB+ N'].[dbo].[' +@SP+ ']'))
--SELECT PATINDEX('%PROCEDURE%', @RawDefinition)
DECLARE @sp_code NVARCHAR(max) = ' ' + Right(@RawDefinition, Len(@RawDefinition) -    PATINDEX('%PROCEDURE%', @RawDefinition) + 1)
--SELECT @sp_code
DECLARE @Notes NVARCHAR(max) = Substring(@RawDefinition, PATINDEX('%/**********%', @RawDefinition),  PATINDEX('%**********/%', @RawDefinition) - PATINDEX('%/**********%', @RawDefinition) + 11) + CHAR(13)+CHAR(10)
--SELECT @Notes

-- get a list of databases to install the stored procedure to (excludes @DB defined above)
--DROP TABLE #tbl_databases
SELECT [name]
INTO #tbl_databases
FROM sys.databases
WHERE [name] LIKE 'RMO%' and [name] <> @DB
select * from #tbl_databases

-- define some variables to use in the loop
DECLARE @sql NVARCHAR(MAX);
DECLARE @execute_sql NVARCHAR(MAX);
DECLARE @database_name NVARCHAR(500);
declare @cmd varchar(8000);

-- iterate through each database
WHILE EXISTS (SELECT * FROM #tbl_databases)
BEGIN

    -- get this iteration's database
    SELECT TOP 1
        @database_name = [name]
    FROM #tbl_databases

    -- determine whether stored procedure should be created or altered
    IF OBJECT_ID(QUOTENAME(@database_name) + '.[dbo].' + QUOTENAME(@SP)) IS NULL
        SET @sql = @notes + 'CREATE' + @sp_code;
    ELSE
        SET @sql = @notes + 'ALTER' + @sp_code;

    -- define some dynamic sql to execute against the appropriate database
    SET @execute_sql = 'EXEC ' + QUOTENAME(@database_name) + '.[dbo].[sp_executesql] @sql';

    -- execute the code to create/alter the procedure
    EXEC [dbo].[sp_executesql] @execute_sql, N'@sql NVARCHAR(MAX)', @sql;

	-- grant public permissions
	set @cmd = '
       USE '+ @database_name + '
       GRANT EXECUTE ON OBJECT::'+ @SP +' TO PUBLIC'
	exec (@cmd)

    -- delete this database so the loop will process the next one
    DELETE FROM #tbl_databases
    WHERE   [name] = @database_name

END

-- clean up :)
DROP TABLE #tbl_databases
