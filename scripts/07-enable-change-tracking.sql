-- 07-enable-change-tracking.sql
-- AdventureWorksLT2022 で実行
-- Azure Functions SQL Trigger は Change Tracking を使用します。
-- CDC (Fabric ミラーリング用) とは独立した機能であり、共存可能です。
USE [AdventureWorksLT2022];
GO

-- DB レベルで Change Tracking を有効化
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
BEGIN
    ALTER DATABASE [AdventureWorksLT2022]
        SET CHANGE_TRACKING = ON
        (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
    PRINT 'Change Tracking enabled on database.';
END
ELSE
    PRINT 'Change Tracking already enabled on database.';
GO

-- SalesLT スキーマの全テーブルで Change Tracking を有効化
DECLARE @schema sysname = N'SalesLT';
DECLARE @table  sysname;
DECLARE @sql    nvarchar(500);

DECLARE table_cursor CURSOR FOR
    SELECT t.name
    FROM sys.tables t
    WHERE t.schema_id = SCHEMA_ID(@schema)
      AND NOT EXISTS (
        SELECT 1 FROM sys.change_tracking_tables ct
        WHERE ct.object_id = t.object_id);

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @sql = N'ALTER TABLE ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table)
                 + N' ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON)';
        EXEC sp_executesql @sql;
        PRINT N'Change Tracking enabled: ' + @schema + N'.' + @table;
    END TRY
    BEGIN CATCH
        PRINT N'Change Tracking skipped: ' + @schema + N'.' + @table + N' (' + ERROR_MESSAGE() + N')';
    END CATCH

    FETCH NEXT FROM table_cursor INTO @table;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

-- dbo.ErrorLog にも Change Tracking を有効化
IF EXISTS (SELECT 1 FROM sys.tables t WHERE t.name = 'ErrorLog' AND t.schema_id = SCHEMA_ID('dbo'))
   AND NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables ct
                   WHERE ct.object_id = OBJECT_ID('dbo.ErrorLog'))
BEGIN
    ALTER TABLE [dbo].[ErrorLog] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
    PRINT 'Change Tracking enabled: dbo.ErrorLog';
END
GO

-- 検証
SELECT DB_NAME() AS DatabaseName,
       is_cdc_enabled,
       CASE WHEN EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
            THEN 1 ELSE 0 END AS is_change_tracking_enabled
FROM sys.databases WHERE name = N'AdventureWorksLT2022';

SELECT OBJECT_SCHEMA_NAME(object_id) AS [Schema],
       OBJECT_NAME(object_id) AS [Table],
       min_valid_version, begin_version
FROM sys.change_tracking_tables;
GO
