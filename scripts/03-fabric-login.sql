-- 03-fabric-login.sql
-- master データベースで実行
USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'fabric_login')
BEGIN
    CREATE LOGIN [fabric_login] WITH PASSWORD = N'F@bric_Strong_Pwd_2026';
    PRINT 'fabric_login created.';
END
ELSE
BEGIN
    PRINT 'fabric_login already exists.';
END
GO
