-- MySQL User Permissions Setup for ClickHouse and OLake Integration
-- This script creates necessary users and permissions for integrations

-- Create ClickHouse integration user
CREATE USER IF NOT EXISTS 'clickhouse'@'%' IDENTIFIED BY 'clickhouse_pass';

-- Grant necessary privileges for ClickHouse to read MySQL data
GRANT SELECT ON demo_db.* TO 'clickhouse'@'%';
GRANT SHOW DATABASES ON *.* TO 'clickhouse'@'%';
GRANT SHOW VIEW ON demo_db.* TO 'clickhouse'@'%';

-- Grant privileges for potential future write operations
GRANT INSERT, UPDATE, DELETE ON demo_db.* TO 'clickhouse'@'%';

-- Create OLake integration user for CDC
CREATE USER IF NOT EXISTS 'olake'@'%' IDENTIFIED BY 'olake_pass';

-- Grant necessary privileges for OLake CDC operations
GRANT SELECT ON demo_db.* TO 'olake'@'%';
GRANT SHOW DATABASES ON *.* TO 'olake'@'%';
GRANT SHOW VIEW ON demo_db.* TO 'olake'@'%';

-- Grant replication privileges for CDC
GRANT REPLICATION SLAVE ON *.* TO 'olake'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'olake'@'%';

-- Grant privileges to read binary logs
GRANT SELECT ON mysql.* TO 'olake'@'%';

-- Create a monitoring user for health checks
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor_pass';
GRANT PROCESS ON *.* TO 'monitor'@'%';
GRANT SELECT ON performance_schema.* TO 'monitor'@'%';
GRANT SELECT ON information_schema.* TO 'monitor'@'%';

-- Create demo user for manual testing
CREATE USER IF NOT EXISTS 'demo_user'@'%' IDENTIFIED BY 'demo_password';
GRANT ALL PRIVILEGES ON demo_db.* TO 'demo_user'@'%';

-- Flush privileges to ensure all changes take effect
FLUSH PRIVILEGES;

-- Display created users
SELECT 'User Permissions Summary' as info;

SELECT 'clickhouse user created for ClickHouse MySQL engine' as status;
SELECT 'olake user created for CDC operations' as status;
SELECT 'monitor user created for health checks' as status;
SELECT 'demo_user created for manual testing' as status;

-- Verify binary log configuration
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'server_id';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'gtid_mode';

-- Show current binary log files
SHOW BINARY LOGS;

-- Display replication status (should show master status)
SHOW MASTER STATUS;
