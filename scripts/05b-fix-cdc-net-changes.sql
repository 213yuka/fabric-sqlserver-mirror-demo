-- 05b-fix-cdc-net-changes.sql
-- 既に @supports_net_changes = 0 で CDC を有効化したテーブルを
-- いったん無効化 → @supports_net_changes = 1 で再有効化する
-- (Fabric ミラーリングは net changes 必須)
USE [AdventureWorksLT2022];
GO

PRINT N'=== 現在の CDC キャプチャ インスタンス ===';
SELECT capture_instance,
       source_schema = OBJECT_SCHEMA_NAME(source_object_id),
       source_table  = OBJECT_NAME(source_object_id),
       supports_net_changes
FROM cdc.change_tables;
GO

DECLARE @schema sysname, @table sysname, @capture sysname;

DECLARE cdc_cursor CURSOR FOR
    SELECT OBJECT_SCHEMA_NAME(ct.source_object_id),
           OBJECT_NAME(ct.source_object_id),
           ct.capture_instance
    FROM cdc.change_tables ct
    WHERE ct.supports_net_changes = 0;

OPEN cdc_cursor;
FETCH NEXT FROM cdc_cursor INTO @schema, @table, @capture;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- いったん無効化
        EXEC sys.sp_cdc_disable_table
            @source_schema   = @schema,
            @source_name     = @table,
            @capture_instance = @capture;
        PRINT N'Disabled  : ' + @schema + N'.' + @table + N' (' + @capture + N')';

        -- net_changes = 1 で再有効化
        EXEC sys.sp_cdc_enable_table
            @source_schema = @schema,
            @source_name   = @table,
            @role_name     = NULL,
            @supports_net_changes = 1;
        PRINT N'Re-enabled: ' + @schema + N'.' + @table + N' (net_changes=1)';
    END TRY
    BEGIN CATCH
        PRINT N'!! ERROR  : ' + @schema + N'.' + @table + N' -> ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM cdc_cursor INTO @schema, @table, @capture;
END

CLOSE cdc_cursor;
DEALLOCATE cdc_cursor;
GO

PRINT N'=== 再有効化後の CDC キャプチャ インスタンス ===';
SELECT capture_instance,
       source_schema = OBJECT_SCHEMA_NAME(source_object_id),
       source_table  = OBJECT_NAME(source_object_id),
       supports_net_changes
FROM cdc.change_tables
ORDER BY source_schema, source_table;
GO

-- net_changes=1 にできなかったテーブル (= PK が無い等) を一覧
PRINT N'=== net_changes=1 \u3067\u306a\u3044 \u3082\u306e\u304c\u6b8b\u3063\u3066\u3044\u305f\u3089 PK \u3092\u898b\u76f4\u3057 ===';
SELECT capture_instance,
       source_schema = OBJECT_SCHEMA_NAME(source_object_id),
       source_table  = OBJECT_NAME(source_object_id),
       supports_net_changes
FROM cdc.change_tables
WHERE supports_net_changes = 0;
GO
