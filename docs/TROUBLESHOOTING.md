# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when running the ClickHouse + MySQL + OLake + Iceberg demo environment.

## 🚨 Common Issues and Solutions

### Container Startup Issues

#### Problem: Services fail to start
**Symptoms:**
```bash
$ docker-compose up -d
ERROR: Failed to start service 'clickhouse'
```

**Solutions:**
1. **Check Docker resources:**
   ```bash
   docker system df
   docker system prune -f  # Remove unused containers/images
   ```

2. **Verify port availability:**
   ```bash
   # Check if ports are already in use
   lsof -i :3306  # MySQL
   lsof -i :8123  # ClickHouse HTTP
   lsof -i :9000  # ClickHouse Native
   lsof -i :9090  # MinIO
   lsof -i :8000  # OLake
   ```

3. **Stop conflicting services:**
   ```bash
   # Stop local MySQL if running
   sudo systemctl stop mysql
   # Or on macOS
   brew services stop mysql
   ```

#### Problem: Out of memory errors
**Symptoms:**
```
ClickHouse container exits with code 137 (OOMKilled)
```

**Solutions:**
1. **Increase Docker memory limit** (Docker Desktop > Settings > Resources)
2. **Reduce ClickHouse memory usage:**
   ```xml
   <!-- In clickhouse-config/config.xml -->
   <max_server_memory_usage_to_ram_ratio>0.7</max_server_memory_usage_to_ram_ratio>
   ```

3. **Check system memory:**
   ```bash
   free -h  # Linux
   vm_stat  # macOS
   ```

### MySQL Connection Issues

#### Problem: ClickHouse cannot connect to MySQL
**Symptoms:**
```sql
Code: 1000. DB::Exception: MySQL connection failed: Can't connect to MySQL server
```

**Diagnosis:**
```bash
# Test MySQL connectivity
docker exec mysql-client mysql -h mysql -u clickhouse -pclickhouse_pass -e "SELECT 1"

# Check MySQL logs
docker-compose logs mysql | tail -50

# Verify MySQL is accepting connections
docker exec mysql-server mysqladmin ping
```

**Solutions:**
1. **Wait for MySQL initialization:**
   ```bash
   # MySQL needs time to initialize on first startup
   docker-compose logs mysql | grep "MySQL init process done"
   ```

2. **Check user permissions:**
   ```sql
   -- Connect to MySQL as root
   docker exec mysql-client mysql -h mysql -u root -proot_password

   -- Verify ClickHouse user exists
   SELECT User, Host FROM mysql.user WHERE User = 'clickhouse';

   -- Grant permissions if missing
   GRANT ALL PRIVILEGES ON demo_db.* TO 'clickhouse'@'%';
   FLUSH PRIVILEGES;
   ```

3. **Network connectivity test:**
   ```bash
   # Test network connection from ClickHouse container
   docker exec clickhouse-client ping mysql
   docker exec clickhouse-client telnet mysql 3306
   ```

#### Problem: MySQL binlog not working
**Symptoms:**
```sql
-- OLake cannot read binlog
SHOW BINARY LOGS;  -- Returns empty or error
```

**Solutions:**
1. **Verify binlog configuration:**
   ```sql
   SHOW VARIABLES LIKE 'log_bin';
   SHOW VARIABLES LIKE 'binlog_format';
   SHOW VARIABLES LIKE 'server_id';
   ```

2. **Check binlog files:**
   ```bash
   docker exec mysql-server ls -la /var/lib/mysql/mysql-bin.*
   ```

3. **Restart MySQL if needed:**
   ```bash
   docker-compose restart mysql
   ```

### ClickHouse Issues

#### Problem: Experimental Iceberg features not enabled
**Symptoms:**
```sql
Code: 36. DB::Exception: Setting allow_experimental_insert_into_iceberg is not enabled
```

**Solutions:**
1. **Enable in session:**
   ```sql
   SET allow_experimental_insert_into_iceberg = 1;
   ```

2. **Verify configuration:**
   ```bash
   # Check if setting is in config
   docker exec clickhouse-client grep -r "allow_experimental_insert_into_iceberg" /etc/clickhouse-server/
   ```

3. **Check current settings:**
   ```sql
   SELECT name, value FROM system.settings 
   WHERE name LIKE '%iceberg%' 
   ORDER BY name;
   ```

#### Problem: Iceberg table creation fails
**Symptoms:**
```sql
Code: 519. DB::Exception: Cannot create Iceberg table: S3 connection failed
```

**Diagnosis:**
```sql
-- Test S3 connectivity
SELECT * FROM s3('http://minio:9000/iceberg-warehouse/test.csv', 'minioadmin', 'minioadmin123', 'CSV', 'col1 String');
```

**Solutions:**
1. **Verify MinIO is running:**
   ```bash
   curl -f http://localhost:9090/minio/health/live
   docker-compose logs minio
   ```

2. **Check bucket exists:**
   ```bash
   docker exec minio-client mc ls myminio/iceberg-warehouse
   
   # Create if missing
   docker exec minio-client mc mb myminio/iceberg-warehouse
   ```

3. **Test S3 configuration:**
   ```sql
   -- Verify named collection
   SELECT * FROM system.named_collections WHERE name = 'minio_s3';
   ```

#### Problem: Query performance issues
**Symptoms:**
- Slow queries on Iceberg tables
- High memory usage
- Query timeouts

**Diagnosis:**
```sql
-- Check query log
SELECT 
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage,
    substring(query, 1, 200) as query_preview
FROM system.query_log 
WHERE type = 'QueryFinish'
ORDER BY event_time DESC 
LIMIT 10;

-- Check running queries
SELECT 
    query_id,
    user,
    query_duration_ms,
    memory_usage,
    substring(query, 1, 100) as query_preview
FROM system.processes;
```

**Solutions:**
1. **Enable partition pruning:**
   ```sql
   SET use_iceberg_partition_pruning = 1;
   ```

2. **Optimize queries:**
   ```sql
   -- Use partition columns in WHERE clause
   SELECT * FROM iceberg_orders 
   WHERE toYYYYMM(order_date) = 202401  -- Good
   
   -- Avoid
   SELECT * FROM iceberg_orders 
   WHERE order_date >= '2024-01-01'     -- Scans all partitions
   ```

3. **Increase memory limits:**
   ```sql
   SET max_memory_usage = 20000000000;  -- 20GB
   SET max_threads = 16;
   ```

### MinIO Storage Issues

#### Problem: MinIO service not accessible
**Symptoms:**
```bash
curl: (7) Failed to connect to localhost port 9090: Connection refused
```

**Solutions:**
1. **Check MinIO container:**
   ```bash
   docker-compose logs minio
   docker exec minio-server mc admin info local
   ```

2. **Verify port mapping:**
   ```bash
   docker-compose ps minio
   # Should show 0.0.0.0:9090->9000/tcp
   ```

3. **Test internal connectivity:**
   ```bash
   docker exec minio-client mc ls myminio/
   ```

#### Problem: Permission denied errors
**Symptoms:**
```
AccessDenied: Access Denied
```

**Solutions:**
1. **Check bucket policies:**
   ```bash
   docker exec minio-client mc policy get myminio/iceberg-warehouse
   
   # Set public policy if needed
   docker exec minio-client mc policy set public myminio/iceberg-warehouse
   ```

2. **Verify credentials:**
   ```bash
   # Test with MinIO client
   docker exec minio-client mc ls myminio/ --debug
   ```

### OLake Platform Issues

#### Problem: OLake UI not accessible
**Symptoms:**
```
Connection refused on http://localhost:8000
```

**Solutions:**
1. **Check OLake container:**
   ```bash
   docker-compose logs olake
   docker-compose ps olake
   ```

2. **Verify PostgreSQL backend:**
   ```bash
   docker exec postgres-olake pg_isready -U olake_user -d olake
   ```

3. **Check application logs:**
   ```bash
   docker-compose logs olake | grep -i error
   ```

#### Problem: Cannot create MySQL source connection
**Symptoms:**
- Connection test fails in OLake UI
- MySQL credentials rejected

**Solutions:**
1. **Verify OLake user in MySQL:**
   ```sql
   -- Connect to MySQL
   SELECT User, Host FROM mysql.user WHERE User = 'olake';
   
   -- Check permissions
   SHOW GRANTS FOR 'olake'@'%';
   ```

2. **Test connection manually:**
   ```bash
   docker exec mysql-client mysql -h mysql -u olake -polake_pass demo_db -e "SELECT 1"
   ```

3. **Check network connectivity:**
   ```bash
   docker exec olake-platform ping mysql
   ```

### Performance Issues

#### Problem: High CPU usage
**Symptoms:**
- System becomes unresponsive
- Docker containers using excessive CPU

**Diagnosis:**
```bash
# Monitor container resource usage
docker stats

# Check ClickHouse queries
docker exec clickhouse-client clickhouse-client --host clickhouse --query "
SELECT query, elapsed, memory_usage 
FROM system.processes 
WHERE elapsed > 5"
```

**Solutions:**
1. **Limit resource usage:**
   ```yaml
   # In docker-compose.yml
   services:
     clickhouse:
       deploy:
         resources:
           limits:
             cpus: '4.0'
             memory: 8G
   ```

2. **Optimize queries:**
   ```sql
   -- Kill long-running queries
   KILL QUERY WHERE query_id = 'query-id-here';
   
   -- Set execution limits
   SET max_execution_time = 300;  -- 5 minutes
   ```

#### Problem: High memory usage
**Symptoms:**
- System swap usage increases
- OOM killer terminates containers

**Solutions:**
1. **Monitor memory usage:**
   ```bash
   # Check Docker memory usage
   docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
   
   # Check system memory
   free -h
   ```

2. **Tune ClickHouse memory:**
   ```xml
   <!-- clickhouse-config/config.xml -->
   <max_server_memory_usage>6000000000</max_server_memory_usage>  <!-- 6GB -->
   <max_server_memory_usage_to_ram_ratio>0.75</max_server_memory_usage_to_ram_ratio>
   ```

3. **Optimize queries:**
   ```sql
   SET max_memory_usage = 4000000000;  -- 4GB per query
   SET max_bytes_before_external_group_by = 2000000000;  -- Use disk for large GROUP BY
   ```

### Data Consistency Issues

#### Problem: Data missing in Iceberg tables
**Symptoms:**
- Row counts don't match between MySQL and Iceberg
- Recent data not appearing

**Diagnosis:**
```sql
-- Compare row counts
SELECT 'MySQL' as source, COUNT(*) as count FROM mysql_users
UNION ALL
SELECT 'Iceberg' as source, COUNT(*) as count FROM iceberg_users;

-- Check ingestion timestamps
SELECT 
    MIN(ingestion_time) as first_ingestion,
    MAX(ingestion_time) as last_ingestion,
    COUNT(*) as total_rows
FROM iceberg_users;
```

**Solutions:**
1. **Check OLake sync status:**
   ```bash
   # Review OLake logs for sync errors
   docker-compose logs olake | grep -i sync
   ```

2. **Manual data refresh:**
   ```sql
   -- Re-insert data if needed
   INSERT INTO iceberg_users 
   SELECT *, now() as ingestion_time 
   FROM mysql_users 
   WHERE id NOT IN (SELECT id FROM iceberg_users);
   ```

3. **Verify CDC configuration:**
   ```sql
   -- Check binlog position
   SHOW MASTER STATUS;
   SHOW BINARY LOGS;
   ```

### Network Connectivity Issues

#### Problem: Container-to-container communication fails
**Symptoms:**
```
Name or service not known: mysql
Could not connect to host: clickhouse
```

**Diagnosis:**
```bash
# Check Docker network
docker network ls
docker network inspect clickhouse_lakehouse-net

# Test connectivity between containers
docker exec clickhouse-client ping mysql
docker exec mysql-client ping clickhouse
```

**Solutions:**
1. **Recreate network:**
   ```bash
   docker-compose down
   docker network prune
   docker-compose up -d
   ```

2. **Use IP addresses instead of hostnames:**
   ```bash
   # Get container IPs
   docker inspect mysql-server | grep IPAddress
   docker inspect clickhouse-server | grep IPAddress
   ```

## 🔧 Diagnostic Commands

### Health Check Script
```bash
#!/bin/bash
# Save as health-check.sh

echo "=== Docker Compose Status ==="
docker-compose ps

echo -e "\n=== Container Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo -e "\n=== MySQL Health ==="
docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password -e "SELECT 'MySQL OK' as status, NOW() as timestamp"

echo -e "\n=== ClickHouse Health ==="
docker exec clickhouse-client clickhouse-client --host clickhouse --query "SELECT 'ClickHouse OK' as status, now() as timestamp"

echo -e "\n=== MinIO Health ==="
curl -f http://localhost:9090/minio/health/live && echo "MinIO OK" || echo "MinIO Failed"

echo -e "\n=== Iceberg Tables ==="
docker exec clickhouse-client clickhouse-client --host clickhouse --query "
SELECT database, table, engine, total_rows 
FROM system.tables 
WHERE engine LIKE '%Iceberg%'"
```

### Log Analysis
```bash
# View all service logs
docker-compose logs --tail=50

# Follow specific service logs
docker-compose logs -f clickhouse
docker-compose logs -f mysql
docker-compose logs -f olake

# Search for errors
docker-compose logs | grep -i error
docker-compose logs | grep -i exception
docker-compose logs | grep -i failed
```

### Performance Monitoring
```sql
-- ClickHouse query performance
SELECT 
    toStartOfMinute(event_time) as minute,
    COUNT() as queries,
    AVG(query_duration_ms) as avg_duration_ms,
    MAX(memory_usage) as max_memory_bytes
FROM system.query_log 
WHERE event_time >= now() - INTERVAL 1 HOUR
GROUP BY minute
ORDER BY minute DESC;

-- Top slow queries
SELECT 
    query_duration_ms,
    read_rows,
    memory_usage,
    substring(query, 1, 200) as query_preview
FROM system.query_log 
WHERE type = 'QueryFinish' 
  AND event_time >= now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC
LIMIT 10;
```

## 🆘 Recovery Procedures

### Complete Environment Reset
```bash
# Stop all services and remove volumes
docker-compose down -v

# Remove all Docker resources (careful!)
docker system prune -a

# Start fresh
docker-compose up -d
```

### Partial Recovery

**Reset MySQL data only:**
```bash
docker-compose stop mysql
docker volume rm clickhouse_mysql-data
docker-compose up -d mysql
```

**Reset ClickHouse data only:**
```bash
docker-compose stop clickhouse
docker volume rm clickhouse_clickhouse-data
docker-compose up -d clickhouse
```

**Reset MinIO data only:**
```bash
docker-compose stop minio
docker volume rm clickhouse_minio-data
docker-compose up -d minio
# Recreate buckets
docker exec minio-client mc mb myminio/iceberg-warehouse
```

### Backup and Restore

**Backup procedure:**
```bash
# Export Docker volumes
docker run --rm -v clickhouse_mysql-data:/data -v $(pwd):/backup alpine tar czf /backup/mysql-backup.tar.gz -C /data .
docker run --rm -v clickhouse_clickhouse-data:/data -v $(pwd):/backup alpine tar czf /backup/clickhouse-backup.tar.gz -C /data .
```

**Restore procedure:**
```bash
# Restore Docker volumes
docker volume create clickhouse_mysql-data
docker run --rm -v clickhouse_mysql-data:/data -v $(pwd):/backup alpine tar xzf /backup/mysql-backup.tar.gz -C /data
```

## 📞 Getting Help

### Useful Resources
- **ClickHouse Documentation**: https://clickhouse.com/docs/
- **MySQL Documentation**: https://dev.mysql.com/doc/
- **Docker Compose Documentation**: https://docs.docker.com/compose/
- **Apache Iceberg Documentation**: https://iceberg.apache.org/docs/

### Creating Bug Reports
When reporting issues, include:

1. **Environment information:**
   ```bash
   docker --version
   docker-compose --version
   uname -a  # System information
   ```

2. **Service status:**
   ```bash
   docker-compose ps
   docker-compose logs --tail=100
   ```

3. **Error messages:**
   ```bash
   docker-compose logs | grep -i error
   ```

4. **Steps to reproduce**
5. **Expected vs. actual behavior**

This troubleshooting guide should help you resolve most common issues. If you encounter problems not covered here, check the service logs first, then consult the official documentation for the specific component.
