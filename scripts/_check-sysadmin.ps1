$q = "SET NOCOUNT ON; SELECT 'IsSysadmin=' + CAST(IS_SRVROLEMEMBER('sysadmin','fabric_login') AS VARCHAR) + '; Ver=' + CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR);"
sqlcmd -S localhost -U fabric_login -P 'F@bric_Strong_Pwd_2026' -C -h-1 -W -Q $q
