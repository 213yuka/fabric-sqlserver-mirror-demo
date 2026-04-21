-- 04-fabric-user.sql
-- AdventureWorksLT2022 データベースで実行
USE [AdventureWorksLT2022];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'fabric_user')
BEGIN
    CREATE USER [fabric_user] FOR LOGIN [fabric_login];
    PRINT 'fabric_user created.';
END
GO

-- SQL Server 2016-2022 のミラーリングは db_owner 相当の権限を要求
ALTER ROLE db_owner ADD MEMBER [fabric_user];
GO

PRINT 'fabric_user has been added to db_owner.';
