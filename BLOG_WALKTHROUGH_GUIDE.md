# Blog Walkthrough Guide - Code File Insertion Points

This guide tells you exactly where to insert code files in your blog walkthrough and what commands to run with expected outputs.

## Step 1: Project Setup

### 1.1 Create Project Directory
**Command to run:**
```bash
mkdir clickhouse-lakehouse
cd clickhouse-lakehouse
```

**Expected Output:**
```
(No output - directory created successfully)
```

**Screenshot Needed:** Terminal showing directory creation

### 1.2 Create Directory Structure
**Command to run:**
```bash
mkdir -p {mysql-init,clickhouse-config,olake-config,scripts,docs}
```

**Expected Output:**
```
(No output - directories created successfully)
```

**INSERT CODE FILE HERE:** Create `docker-compose.yml` in the root directory
**File Content:** Use the docker-compose.yml file from your project

**INSERT CODE FILE HERE:** Create `mysql-init/01-setup.sql`
**File Content:** Use the 01-setup.sql file from your mysql-init directory

**INSERT CODE FILE HERE:** Create `mysql-init/02-permissions.sql`
**File Content:** Use the 02-permissions.sql file from your mysql-init directory

**Screenshot Needed:** MySQL initialization scripts created

## Step 2: ClickHouse Configuration

**INSERT CODE FILE HERE:** Create `clickhouse-config/config.xml`
**File Content:** Use the config.xml file from your clickhouse-config directory

**INSERT CODE FILE HERE:** Create `clickhouse-config/users.xml`
**File Content:** Use the users.xml file from your clickhouse-config directory

**Screenshot Needed:** ClickHouse configuration files

## Step 3: Start Infrastructure

### 3.1 Launch All Services
**Command to run:**
```bash
docker-compose up -d
```

**Expected Output:**
```
[+] Running 8/8
 ✔ Network clickhouse_lakehouse-net  Created                                                           0.0s 
 ✔ Container minio-server            Healthy                                                          31.3s 
 ✔ Container postgres-olake          Started                                                           0.9s 
 ✔ Container mysql-server            Healthy                                                          31.3s 
 ✔ Container mysql-client            Started                                                          31.4s 
 ✔ Container clickhouse-server       Healthy                                                          62.0s 
 ✔ Container minio-client            Started                                                          31.4s 
 ✔ Container clickhouse-client       Started                                                          62.3s 
```

**Screenshot Needed:** Docker compose startup output

### 3.2 Verify All Services
**Command to run:**
```bash
docker-compose ps
```

**Expected Output:**
```
NAME                IMAGE                                 COMMAND                  SERVICE             CREATED       STATUS                   PORTS

clickhouse-client   clickhouse/clickhouse-server:latest   "/entrypoint.sh tail…"   clickhouse-client   2 hours ago   Up About an hour             8123/tcp, 9000/tcp, 9009/tcp

clickhouse-server   clickhouse/clickhouse-server:latest   "/entrypoint.sh"         clickhouse          2 hours ago   Up About an hour (healthy)   0.0.0.0:8123->8123/tcp, [::]:8123->8123/tcp, 0.0.0.0:19000->9000/tcp, [::]:19000->9000/tcp, 0.0.0.0:19004->9004/tcp, [::]:19004->9004/tcp

minio-server        minio/minio:latest                    "/usr/bin/docker-ent…"   minio               2 hours ago   Up 2 hours (healthy)         0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:9090->9000/tcp, [::]:9090->9000/tcp

mysql-client        mysql:8.0                             "docker-entrypoint.s…"   mysql-client        2 hours ago   Up 2 hours                   3306/tcp, 33060/tcp

mysql-server        mysql:8.0                             "docker-entrypoint.s…"   mysql               2 hours ago   Up 2 hours (healthy)         0.0.0.0:3307->3306/tcp, [::]:3307->3306/tcp

postgres-olake      postgres:15                           "docker-entrypoint.s…"   postgres            2 hours ago   Up 2 hours (healthy)         0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
```

**Screenshot Needed:** Service status verification

## Step 4: Verify MySQL Data and CDC Setup

### 4.1 Check MySQL Data
**Command to run:**
```bash
docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "
SELECT 'Total Users:' as metric, COUNT(*) as count FROM users
UNION ALL SELECT 'Total Products:', COUNT(*) FROM products  
UNION ALL SELECT 'Total Orders:', COUNT(*) FROM orders
UNION ALL SELECT 'Total Sessions:', COUNT(*) FROM user_sessions;"
```

**Expected Output:**
```
mysql: [Warning] Using a password on the command line interface can be insecure.
header
=== DEMO DATABASE OVERVIEW ===
table_info
Users Table:
id      username        email   status  country
1       john_doe        john.doe@example.com    premium USA
2       jane_smith      jane.smith@example.com  premium Canada
3       bob_wilson      bob.wilson@example.com  active  UK
4       alice_brown     alice.brown@example.com active  Australia
5       charlie_davis   charlie.davis@example.com       inactive        Germany
table_info
Products Table:
id      product_name    category        price   stock_quantity
1       MacBook Pro 16" Electronics     2499.99 50
2       iPhone 15 Pro   Electronics     999.99  200
3       Samsung Galaxy S24      Electronics     899.99  150
4       Dell XPS 13     Electronics     1299.99 75
5       iPad Air        Electronics     599.99  100
summary
Data Summary:
table_name      total_records
Users   11
Products        16
Orders  15
User Sessions   9
```

**Screenshot Needed:** MySQL data verification

### 4.2 Verify CDC Configuration
**Command to run:**
```bash
docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'gtid_mode';"
```

**Expected Output:**
```
mysql: [Warning] Using a password on the command line interface can be insecure.
header
=== MYSQL CDC CONFIGURATION VERIFICATION ===
section
Binary Logging Status:
Variable_name   Value
log_bin ON
section
Binlog Format:
Variable_name   Value
binlog_format   ROW
section
GTID Mode:
Variable_name   Value
gtid_mode       ON
section
Server ID:
Variable_name   Value
server_id       1
section
Row Image:
Variable_name   Value
binlog_row_image        FULL
```

**Screenshot Needed:** CDC configuration verification

## Step 5: Configure ClickHouse Integration

### 5.1 Test ClickHouse Connectivity
**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "SELECT 'ClickHouse Version:' as info, version() as version, now() as current_time"
```

**Expected Output:**
```
=== CLICKHOUSE INTEGRATION TEST ===
System Info:
25.8.1.5101     2025-08-31 20:47:12
```

**Screenshot Needed:** ClickHouse connectivity test

### 5.2 Create MySQL Engine Tables
**INSERT CODE FILE HERE:** Create `scripts/mysql-integration.sql`
**File Content:** Use the mysql-integration.sql file from your scripts directory

**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "$(cat scripts/mysql-integration.sql)"
```

**Expected Output:**
```
MySQL Engine Test:
11
Sample MySQL Data via ClickHouse:
1       john_doe        john.doe@example.com    premium
2       jane_smith      jane.smith@example.com  premium
3       bob_wilson      bob.wilson@example.com  active
```

**Screenshot Needed:** MySQL engine table creation and test

### 5.3 Create Iceberg Tables
**INSERT CODE FILE HERE:** Create `scripts/iceberg-setup.sql`
**File Content:** Use the iceberg-setup.sql file from your scripts directory

**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "$(cat scripts/iceberg-setup.sql)"
```

**Expected Output:**
```
Iceberg Table Test:
8
Sample Iceberg Data:
1       john_doe        premium 299.99
2       jane_smith      premium 599.98
3       bob_wilson      active  899.97
```

**Screenshot Needed:** Iceberg table creation and data insertion

## Step 6: Set Up OLake CDC Pipeline

### 6.1 Create OLake Container
**Command to run:**
```bash
docker run -d \
  --name olake-worker \
  --network clickhouse_lakehouse-net \
  -v $(pwd)/olake-config:/app/config \
  -v $(pwd)/scripts:/app/scripts \
  -w /app \
  python:3.11-slim \
  tail -f /dev/null

# Install OLake dependencies
docker exec olake-worker bash -c "
  apt-get update && apt-get install -y git curl build-essential golang-go
  git clone https://github.com/datazip-inc/olake.git /tmp/olake
  echo 'OLake source code downloaded'
"
```

**Screenshot Needed:** OLake container setup

### 6.2 Build OLake MySQL Driver
**Command to run:**
```bash
docker exec olake-worker bash -c "
  cd /tmp/olake/drivers/mysql
  go build -o olake-mysql main.go
  chmod +x olake-mysql
  ls -la olake-mysql
  echo 'OLake MySQL driver built successfully'
"
```

**Expected Output:**
```
=== OLAKE STATUS ===
OLake Binary Info:
-rwxr-xr-x 1 root root 58757997 Aug 31 19:58 olake-mysql
OLake MySQL driver built successfully
```

**Screenshot Needed:** OLake driver compilation

### 6.3 Create OLake Configuration Files
**INSERT CODE FILE HERE:** Create `olake-config/source.json`
**File Content:** Use the source.json file from your olake-config directory

**INSERT CODE FILE HERE:** Create `olake-config/destination.json`
**File Content:** Use the destination.json file from your olake-config directory

**Command to run:**
```bash
docker exec olake-worker bash -c "
cd /tmp/olake/drivers/mysql
cp /app/config/source.json .
cp /app/config/destination.json .
"
```

**Screenshot Needed:** OLake configuration files

### 6.4 Test OLake Connectivity
**Command to run:**
```bash
docker exec olake-worker bash -c "
  cd /tmp/olake/drivers/mysql
  ./olake-mysql check --config source.json
"
```

**Expected Output:**
```
Connection Test Output:
2025-08-31T20:47:22Z INFO System has 7GB RAM, setting iceberg writer batch size to 104857600 bytes
2025-08-31T20:47:22Z INFO Found CDC Configuration
2025-08-31T20:47:22Z WARN binlog_row_metadata is not set to FULL
2025-08-31T20:47:22Z WARN CDC is not supported
2025-08-31T20:47:22Z INFO {"connectionStatus":{"status":"SUCCEEDED"},"type":"CONNECTION_STATUS"}
```

**Screenshot Needed:** OLake MySQL connection test

### 6.5 Discover Tables
**Command to run:**
```bash
docker exec olake-worker bash -c "
  cd /tmp/olake/drivers/mysql
  ./olake-mysql discover --config source.json > streams.json
  echo 'Tables discovered:'
  grep -o '\"name\":\"[^\"]*\"' streams.json | head -5
"
```

**Expected Output:**
```
Table Discovery Output:
2025-08-31T20:47:22Z INFO System has 7GB RAM, setting iceberg writer batch size to 104857600 bytes
2025-08-31T20:47:22Z INFO Found CDC Configuration
2025-08-31T20:47:22Z WARN binlog_row_metadata is not set to FULL
2025-08-31T20:47:22Z WARN CDC is not supported
2025-08-31T20:47:22Z INFO Starting discover for MySQL database demo_db
2025-08-31T20:47:22Z INFO producing type schema for stream [demo_db.products]
2025-08-31T20:47:22Z INFO producing type schema for stream [demo_db.user_sessions]
2025-08-31T20:47:22Z INFO producing type schema for stream [demo_db.users]
2025-08-31T20:47:22Z INFO producing type schema for stream [demo_db.orders]

Tables discovered:
"name":"products"
"name":"users"
"name":"orders"
"name":"user_sessions"
```

**Screenshot Needed:** OLake table discovery

## Step 7: Demonstrate Cross-Database Analytics

### 7.1 Real-time MySQL vs Historical Iceberg Queries
**INSERT CODE FILE HERE:** Create `scripts/cross-database-analytics.sql`
**File Content:** Use the cross-database-analytics.sql file from your scripts directory

**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "$(cat scripts/cross-database-analytics.sql)"
```

**Expected Output:**
```
=== CROSS-DATABASE ANALYTICS DEMO ===
Real-time MySQL Data:
active  6       ['bob_wilson','alice_brown','frank_garcia','grace_lee','henry_taylor','olake_test_user']
premium 4       ['john_doe','jane_smith','diana_miller','ivy_anderson']
inactive        1       ['charlie_davis']
Iceberg Data Lake Analytics:
active  4       1649.95 44
inactive        1       1499.95 10
premium 3       899.97  18
Data Source Comparison:
Iceberg (Data Lake)     8
MySQL (Real-time)       11
```

**Screenshot Needed:** Cross-database analytics results

## Step 8: Access Web Interfaces

### 8.1 ClickHouse Web Interface
**URL:** http://localhost:8123

**INSERT CODE FILE HERE:** Create `scripts/web-interface-demo.sql`
**File Content:** Use the web-interface-demo.sql file from your scripts directory

**Screenshot Needed:** ClickHouse web interface with query results

### 8.2 MinIO Console
**URL:** http://localhost:9091
**Login:** minioadmin / minioadmin123

**Screenshot Needed:** MinIO console showing Iceberg files

## Step 9: Performance Testing and Monitoring

### 9.1 Performance Comparison
**INSERT CODE FILE HERE:** Create `scripts/performance-test.sql`
**File Content:** Use the performance-test.sql file from your scripts directory

**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "$(cat scripts/performance-test.sql)"
```

**Screenshot Needed:** Performance comparison results

### 9.2 System Monitoring
**Command to run:**
```bash
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

**Screenshot Needed:** System resource monitoring

## Step 10: Advanced Features and Schema Evolution

### 10.1 Add New Data (Simulating CDC)
**Command to run:**
```bash
docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "
INSERT INTO users (username, email, full_name, age, country, status) 
VALUES ('olake_test_user', 'olake@test.com', 'OLake Test User', 30, 'TestLand', 'active');

SELECT 'New user added:' as info;
SELECT id, username, email, country FROM users WHERE username = 'olake_test_user';
"
```

**Screenshot Needed:** New data insertion

### 10.2 Real-time Query Update
**Command to run:**
```bash
docker exec clickhouse-client clickhouse-client --host clickhouse --query "
SELECT 'Updated user count from MySQL:' as info, COUNT(*) as total_users FROM mysql_users_test;
"
```

**Expected Output:**
```
Updated user count from MySQL:     12
```

**Screenshot Needed:** Real-time data reflection

## Step 11: Troubleshooting and Common Issues

### 11.1 Check Service Health
**Command to run:**
```bash
docker-compose ps
```

### 11.2 View Service Logs
**Commands to run:**
```bash
docker logs clickhouse-server
docker logs mysql-server
docker logs minio-server
docker exec olake-worker ls -la /tmp/olake/drivers/mysql/logs/
```

### 11.3 Performance Monitoring
**Commands to run:**
```bash
docker stats --no-stream

# Check ClickHouse query performance
docker exec clickhouse-client clickhouse-client --host clickhouse --query "
SELECT query_duration_ms, read_rows, query 
FROM system.query_log 
WHERE event_time >= now() - INTERVAL 60 SECOND 
ORDER BY event_time DESC LIMIT 5"
```

## Step 12: Cleanup and Resource Management

### 12.1 Stop All Services
**Command to run:**
```bash
docker-compose down
```

### 12.2 Remove Volumes (Optional)
**Command to run:**
```bash
docker-compose down -v
```

### 12.3 Remove OLake Container
**Command to run:**
```bash
docker rm -f olake-worker
```

## Summary

This guide provides the exact flow for your blog walkthrough with:
- Clear insertion points for code files
- Commands to run with expected outputs
- Screenshot requirements
- Proper sequencing of steps

The walkthrough demonstrates a complete modern data lakehouse implementation using ClickHouse + MySQL + OLake + Iceberg integration.
