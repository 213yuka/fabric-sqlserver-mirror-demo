-- 05-enable-cdc.sql
-- AdventureWorksLT2022 で実行
-- 注意: SQL Server Agent が起動している必要があります（Docker では MSSQL_AGENT_ENABLED=true）
USE [AdventureWorksLT2022];
GO

-- DB レベルで CDC を有効化
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'AdventureWorksLT2022' AND is_cdc_enabled = 1)
BEGIN
    EXEC sys.sp_cdc_enable_db;
    PRINT 'CDC enabled on database.';
END
GO

-- SalesLT スキーマの全テーブルで CDC を有効化
DECLARE @schema sysname = N'SalesLT';
DECLARE @table  sysname;

DECLARE table_cursor CURSOR FOR
    SELECT t.name
    FROM sys.tables t
    WHERE t.schema_id = SCHEMA_ID(@schema)
      AND NOT EXISTS (
        SELECT 1 FROM cdc.change_tables ct
        WHERE ct.source_object_id = t.object_id);

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- Fabric ミラーリング要件: @supports_net_changes = 1 必須 (主キーが必要)
        EXEC sys.sp_cdc_enable_table
            @source_schema = @schema,
            @source_name   = @table,
            @role_name     = NULL,
            @supports_net_changes = 1;
        PRINT N'CDC enabled (net_changes=1): ' + @schema + N'.' + @table;
    END TRY
    BEGIN CATCH
        PRINT N'CDC skipped: ' + @schema + N'.' + @table + N' (' + ERROR_MESSAGE() + N')';
    END CATCH

    FETCH NEXT FROM table_cursor INTO @table;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

-- 検証
SELECT name, is_cdc_enabled FROM sys.databases WHERE name = N'AdventureWorksLT2022';
SELECT capture_instance, source_schema = OBJECT_SCHEMA_NAME(source_object_id),
       source_table  = OBJECT_NAME(source_object_id), start_lsn, create_date
FROM cdc.change_tables;
GO
