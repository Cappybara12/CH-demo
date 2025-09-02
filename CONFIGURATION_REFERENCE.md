# Configuration Reference Guide

## Quick Command Reference

### Start Environment
```bash
docker-compose up -d
```

### Check Status
```bash
docker-compose ps
```

### Access Points
- **ClickHouse Web**: http://localhost:8123
- **MinIO Console**: http://localhost:9091 (minioadmin/minioadmin123)
- **MySQL**: localhost:3307 (demo_user/demo_password)

### Essential Test Commands

#### Verify MySQL Data
```bash
docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "SELECT COUNT(*) FROM users"
```

#### Test ClickHouse
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "SELECT version()"
```

#### Cross-Database Query
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "
SELECT 'MySQL' as source, COUNT(*) FROM mysql_users_test
UNION ALL 
SELECT 'Iceberg' as source, COUNT(*) FROM iceberg_blog_demo"
```

#### OLake Test
```bash
docker exec olake-worker bash -c "cd /tmp/olake/drivers/mysql && ./olake-mysql check --config source.json"
```

## File Structure Created
```
clickhouse-lakehouse/
├── docker-compose.yml
├── mysql-init/
│   ├── 01-setup.sql
│   └── 02-permissions.sql
├── clickhouse-config/
│   ├── config.xml
│   └── users.xml
├── olake-config/
├── scripts/
└── BLOG_POST_COMPLETE_WALKTHROUGH.md
```

## Key Configuration Points

### MySQL CDC Setup
- Binary logging: ENABLED
- Format: ROW
- GTID: ON
- Server ID: 1

### ClickHouse Experimental Features
- allow_experimental_insert_into_iceberg: 1
- use_iceberg_partition_pruning: 1
- use_iceberg_metadata_files_cache: 1

### OLake Configuration
- Source: MySQL with proper CDC user
- Destination: Iceberg with JDBC catalog
- Transport: PostgreSQL metadata store

## Data Verification Commands

### MySQL Verification
```sql
-- Check CDC configuration
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';

-- Check data
SELECT 
  'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL  
SELECT 'Orders', COUNT(*) FROM orders;
```

### ClickHouse Verification
```sql
-- Check experimental settings
SELECT name, value FROM system.settings 
WHERE name LIKE '%iceberg%' AND value != '0';

-- Test integrations
SELECT COUNT(*) FROM mysql_users_test;
SELECT COUNT(*) FROM iceberg_blog_demo;
```

## Common Issues and Solutions

### Port Conflicts
If ports 3307, 8123, 9000, 9091, or 5432 are in use:
1. Update docker-compose.yml port mappings
2. Use `docker-compose down && docker-compose up -d`

### ClickHouse Connection Issues
```bash
# Check if ClickHouse is responding
curl http://localhost:8123/ping

# Check logs
docker logs clickhouse-server
```

### MySQL Connection Issues
```bash
# Test connection
docker exec mysql-client mysql -h mysql -u root -proot_password -e "SELECT 1"

# Check logs
docker logs mysql-server
```

### OLake Issues
```bash
# Check if binary exists
docker exec olake-worker ls -la /tmp/olake/drivers/mysql/olake-mysql

# Test connection
docker exec olake-worker bash -c "cd /tmp/olake/drivers/mysql && ./olake-mysql check --config source.json"
```

## Performance Monitoring

### Resource Usage
```bash
docker stats --no-stream
```

### Query Performance
```sql
-- In ClickHouse
SELECT 
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) as data_read,
    substring(query, 1, 50) as query_preview
FROM system.query_log 
WHERE event_time >= now() - INTERVAL 60 SECOND
ORDER BY event_time DESC
LIMIT 5;
```

## Cleanup

### Stop Services
```bash
docker-compose down
```

### Remove All Data
```bash
docker-compose down -v
docker stop olake-worker && docker rm olake-worker
```

### Remove Images (Optional)
```bash
docker rmi $(docker images -q)
```
