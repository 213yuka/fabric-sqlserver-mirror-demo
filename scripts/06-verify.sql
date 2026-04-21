-- 06-verify.sql
-- すべての準備が完了しているかを確認するクエリ
USE [AdventureWorksLT2022];
GO

PRINT '== ログイン =='
SELECT name, type_desc, is_disabled
FROM sys.server_principals
WHERE name = N'fabric_login';

PRINT '== ユーザー =='
SELECT name, type_desc
FROM sys.database_principals
WHERE name = N'fabric_user';

PRINT '== ロール =='
SELECT r.name AS role_name, m.name AS member_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name = N'fabric_user';

PRINT '== CDC データベース =='
SELECT name, is_cdc_enabled FROM sys.databases WHERE name = DB_NAME();

PRINT '== CDC テーブル =='
SELECT capture_instance,
       source_schema = OBJECT_SCHEMA_NAME(source_object_id),
       source_table  = OBJECT_NAME(source_object_id)
FROM cdc.change_tables
ORDER BY source_table;

PRINT '== SQL Server Agent (CDC は Agent 必須) =='
SELECT
    servicename,
    status_desc,
    last_startup_time
FROM sys.dm_server_services
WHERE servicename LIKE N'%Agent%';
