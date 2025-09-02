# Feature Documentation

This document details all the features demonstrated in the ClickHouse + MySQL + OLake + Iceberg data lakehouse environment, including their implementation, benefits, and use cases.

## 🎯 Core Features Overview

### 1. Experimental Iceberg Write Support in ClickHouse

#### Description
ClickHouse 24.7+ introduces experimental support for writing to Apache Iceberg tables using the `IcebergS3` engine. This enables ClickHouse to act as both a reader and writer for data lake storage.

#### Implementation
```sql
-- Enable experimental feature
SET allow_experimental_insert_into_iceberg = 1;

-- Create Iceberg table
CREATE TABLE iceberg_users (
    id Int32,
    username String,
    email String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/users/', 'minioadmin', 'minioadmin123')
PARTITION BY toYYYYMM(created_at);

-- Insert data
INSERT INTO iceberg_users SELECT * FROM mysql_users;

-- Update data (experimental)
ALTER TABLE iceberg_users UPDATE email = 'new@email.com' WHERE id = 1;

-- Add columns
ALTER TABLE iceberg_users ADD COLUMN last_login DateTime;
```

#### Key Capabilities
- **Table Creation**: Create new Iceberg tables with custom schemas
- **Data Insertion**: Bulk and streaming inserts
- **Schema Evolution**: Add columns dynamically
- **Updates**: Modify existing records (experimental)
- **Partitioning**: Time-based and categorical partitioning

#### Benefits
- **Unified Analytics**: Single system for operational and analytical workloads
- **Data Lake Integration**: Direct access to object storage
- **Cost Efficiency**: Store cold data in cheaper object storage
- **Scalability**: Horizontal scaling through partitioning

#### Limitations
- **Experimental Status**: Not yet production-ready
- **Limited Operations**: Some SQL operations not yet supported
- **Performance**: Updates slower than native ClickHouse tables

### 2. Real-time Change Data Capture (CDC)

#### Description
Capture changes from MySQL using binary log replication and stream them to Iceberg tables via OLake platform for near real-time data lake updates.

#### Implementation
```yaml
# MySQL Configuration (docker-compose.yml)
command: >
  --log-bin=mysql-bin
  --server-id=1
  --binlog-format=ROW
  --gtid-mode=ON
  --enforce-gtid-consistency=ON
```

```json
// OLake Source Configuration
{
  "replication": {
    "method": "binlog",
    "server_id": 100,
    "initial_sync": true,
    "gtid_enabled": true
  }
}
```

#### Data Flow
```
MySQL Changes → Binary Log → OLake CDC → Iceberg Tables → ClickHouse Analytics
```

#### Benefits
- **Real-time Sync**: Changes appear in data lake within minutes
- **Automatic Schema Sync**: New columns automatically detected
- **Fault Tolerance**: GTID-based replication ensures consistency
- **Scalability**: Parallel processing of change streams

#### Use Cases
- **Real-time Dashboards**: Live metrics from operational data
- **Event-driven Architecture**: Trigger actions based on data changes
- **Data Lake Freshness**: Keep analytical data current
- **Audit Trails**: Track all database changes

### 3. Cross-Database Analytics

#### Description
Query data across MySQL (operational) and Iceberg (analytical) systems in a single SQL statement, enabling hybrid analytical workloads.

#### Implementation
```sql
-- Cross-database customer analysis
WITH 
real_time_orders AS (
    -- Real-time data from MySQL
    SELECT user_id, COUNT(*) as recent_orders, SUM(total_amount) as recent_spend
    FROM mysql_orders
    WHERE order_date >= now() - INTERVAL 30 DAY
    GROUP BY user_id
),
historical_analysis AS (
    -- Historical data from Iceberg
    SELECT user_id, COUNT(*) as total_orders, SUM(total_amount) as lifetime_spend
    FROM iceberg_orders
    GROUP BY user_id
)
SELECT 
    u.username,
    COALESCE(r.recent_orders, 0) as orders_last_30_days,
    h.total_orders as total_orders_ever,
    h.lifetime_spend as lifetime_value,
    CASE 
        WHEN h.lifetime_spend > 2000 THEN 'VIP'
        WHEN h.lifetime_spend > 1000 THEN 'Premium'
        ELSE 'Standard'
    END as customer_segment
FROM mysql_users u
LEFT JOIN real_time_orders r ON u.id = r.user_id
LEFT JOIN historical_analysis h ON u.id = h.user_id
ORDER BY h.lifetime_spend DESC;
```

#### Query Patterns
- **Fresh + Historical**: Combine current operational data with historical trends
- **Operational Dashboards**: Real-time metrics with historical context
- **Customer 360**: Complete customer view across all touchpoints
- **Trend Analysis**: Compare current performance to historical baselines

#### Performance Optimizations
- **Materialized Views**: Pre-compute common aggregations
- **Query Cache**: Cache results for repeated patterns
- **Pushdown**: Execute filters close to data storage
- **Parallel Processing**: Leverage ClickHouse's columnar processing

### 4. Schema Evolution

#### Description
Modify table schemas without data loss or downtime, supporting business requirement changes over time.

#### Iceberg Schema Evolution
```sql
-- Add new column
ALTER TABLE iceberg_users ADD COLUMN phone_number Nullable(String);

-- Column is immediately available
SELECT username, email, phone_number FROM iceberg_users LIMIT 5;

-- Update existing records
ALTER TABLE iceberg_users UPDATE phone_number = '555-0000' WHERE id <= 10;

-- Add column with default value
ALTER TABLE iceberg_users ADD COLUMN subscription_tier String DEFAULT 'basic';
```

#### MySQL → ClickHouse Evolution
```sql
-- Add column to MySQL
ALTER TABLE users ADD COLUMN loyalty_points INT DEFAULT 0;

-- ClickHouse MySQL engine automatically sees new column
SELECT username, loyalty_points FROM mysql_users LIMIT 5;

-- Update Iceberg schema to match
ALTER TABLE iceberg_users ADD COLUMN loyalty_points Nullable(Int32);
```

#### Supported Operations
| Operation | MySQL | ClickHouse MySQL Engine | ClickHouse Iceberg |
|-----------|-------|------------------------|-------------------|
| Add Column | ✅ | ✅ Auto-detect | ✅ Manual |
| Drop Column | ✅ | ✅ | ✅ |
| Rename Column | ✅ | ⚠️ Manual sync | ❌ Not supported |
| Change Type | ✅ | ⚠️ Compatibility rules | ⚠️ Limited |
| Add Constraint | ✅ | ❌ | ❌ |

#### Best Practices
- **Additive Changes**: Prefer adding columns over modifying existing ones
- **Nullable Columns**: New columns should be nullable or have defaults
- **Testing**: Validate schema changes in staging environment
- **Documentation**: Track schema changes in version control

### 5. Time Travel Queries

#### Description
Query historical states of data using Iceberg's snapshot mechanism, enabling point-in-time analysis and data recovery.

#### Implementation
```sql
-- Query data at specific timestamp
SELECT * FROM iceberg_orders 
SETTINGS iceberg_timestamp_ms = 1693456800000  -- Unix timestamp in milliseconds
WHERE user_id = 123;

-- Query specific snapshot
SELECT * FROM iceberg_orders 
SETTINGS iceberg_snapshot_id = 8744736658442914487
WHERE order_date >= '2024-01-01';

-- Compare data across time periods
WITH 
current_data AS (
    SELECT status, COUNT(*) as current_count 
    FROM iceberg_orders 
    GROUP BY status
),
historical_data AS (
    SELECT status, COUNT(*) as historical_count 
    FROM iceberg_orders 
    SETTINGS iceberg_timestamp_ms = 1693456800000
    GROUP BY status
)
SELECT 
    c.status,
    c.current_count,
    h.historical_count,
    c.current_count - h.historical_count as change
FROM current_data c
FULL OUTER JOIN historical_data h ON c.status = h.status;
```

#### Use Cases
- **Data Recovery**: Restore accidentally deleted or corrupted data
- **Audit Compliance**: Prove data state at specific points in time
- **Trend Analysis**: Compare metrics across different time periods
- **Debugging**: Investigate when data issues were introduced
- **A/B Testing**: Analyze performance before/after changes

#### Snapshot Management
```sql
-- View available snapshots
SELECT * FROM system.iceberg_snapshots WHERE table = 'iceberg_orders';

-- Snapshot retention configuration
-- Automatically expires snapshots older than 5 days
-- Keeps minimum 5 snapshots regardless of age
```

### 6. Intelligent Partitioning

#### Description
Optimize query performance through strategic data partitioning based on query patterns and data characteristics.

#### Partitioning Strategies

**Time-based Partitioning:**
```sql
-- Monthly partitions for time-series analysis
CREATE TABLE iceberg_orders (...)
ENGINE = IcebergS3(...)
PARTITION BY toYYYYMM(order_date);

-- Daily partitions for high-volume data
CREATE TABLE iceberg_user_sessions (...)
ENGINE = IcebergS3(...)
PARTITION BY toYYYYMMDD(login_time);
```

**Categorical Partitioning:**
```sql
-- Geographic partitioning
CREATE TABLE iceberg_users (...)
ENGINE = IcebergS3(...)
PARTITION BY country;

-- Status-based partitioning
CREATE TABLE iceberg_orders (...)
ENGINE = IcebergS3(...)
PARTITION BY (toYYYYMM(order_date), status);
```

#### Partition Pruning Benefits
```sql
-- Efficient query - only scans January 2024 partition
SELECT COUNT(*) FROM iceberg_orders 
WHERE toYYYYMM(order_date) = 202401;

-- Inefficient query - scans all partitions
SELECT COUNT(*) FROM iceberg_orders 
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01';
```

#### Performance Impact
| Query Type | Partitions Scanned | Performance Gain |
|------------|-------------------|------------------|
| Single month | 1/24 (4%) | 20-100x faster |
| Quarter | 3/24 (12%) | 5-20x faster |
| Year | 12/24 (50%) | 2-5x faster |
| All time | 24/24 (100%) | Baseline |

#### Partition Management
- **Automatic Creation**: New partitions created as data arrives
- **Pruning Statistics**: Monitor which partitions are accessed
- **Compaction**: Merge small files within partitions
- **Lifecycle Management**: Archive or delete old partitions

### 7. Advanced Storage Optimization

#### Description
Leverage modern storage formats and compression techniques for optimal query performance and storage efficiency.

#### File Format Configuration
```json
{
  "format": {
    "file_format": "parquet",
    "compression": "snappy",
    "row_group_size": 134217728,  // 128MB
    "page_size": 1048576,         // 1MB
    "dictionary_enabled": true
  }
}
```

#### Iceberg Table Properties
```sql
CREATE TABLE iceberg_optimized (...)
ENGINE = IcebergS3(...)
SETTINGS 
  'format-version' = '2',
  'write.target-file-size-bytes' = '536870912',  -- 512MB files
  'write.parquet.compression-codec' = 'snappy',
  'write.metadata.compression-codec' = 'gzip';
```

#### Storage Benefits
- **Compression**: 70-90% reduction in storage size
- **Columnar Format**: Efficient for analytical queries
- **Predicate Pushdown**: Skip reading irrelevant data
- **Statistics**: Min/max values for efficient filtering

#### Performance Metrics
| Feature | Benefit | Typical Improvement |
|---------|---------|-------------------|
| Snappy Compression | Storage reduction | 70-80% |
| Parquet Format | Query speed | 3-10x |
| Dictionary Encoding | String compression | 80-95% |
| Column Pruning | I/O reduction | 50-90% |

### 8. Monitoring and Observability

#### Description
Comprehensive monitoring of query performance, data freshness, and system health across all components.

#### ClickHouse Query Monitoring
```sql
-- Real-time query monitoring
SELECT 
    user,
    query_id,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage,
    substring(query, 1, 100) as query_preview
FROM system.processes
WHERE query_duration_ms > 1000;

-- Historical query performance
SELECT 
    toStartOfHour(event_time) as hour,
    COUNT() as queries,
    AVG(query_duration_ms) as avg_duration,
    quantile(0.95)(query_duration_ms) as p95_duration,
    SUM(read_rows) as total_rows_read
FROM system.query_log
WHERE event_time >= now() - INTERVAL 24 HOUR
GROUP BY hour
ORDER BY hour DESC;
```

#### Storage Monitoring
```sql
-- Table size and growth tracking
SELECT 
    database,
    table,
    formatReadableSize(total_bytes) as size,
    total_rows,
    round(total_bytes / total_rows, 2) as bytes_per_row
FROM system.tables
WHERE engine LIKE '%Iceberg%'
ORDER BY total_bytes DESC;

-- Partition distribution
SELECT 
    partition,
    COUNT() as parts,
    formatReadableSize(SUM(bytes_on_disk)) as size,
    SUM(rows) as rows
FROM system.parts
WHERE table = 'iceberg_orders'
GROUP BY partition
ORDER BY partition DESC;
```

#### Data Freshness Monitoring
```sql
-- Check CDC lag
SELECT 
    table,
    MAX(ingestion_time) as last_update,
    now() - MAX(ingestion_time) as lag_seconds
FROM (
    SELECT 'users' as table, MAX(ingestion_time) as ingestion_time FROM iceberg_users
    UNION ALL
    SELECT 'orders' as table, MAX(ingestion_time) as ingestion_time FROM iceberg_orders
) t
GROUP BY table;
```

#### Alert Thresholds
- **Query Performance**: P95 latency > 10 seconds
- **Data Freshness**: CDC lag > 5 minutes
- **Storage Growth**: >20% increase day-over-day
- **Error Rate**: >1% failed queries

### 9. Multi-Engine Data Access

#### Description
Access the same data through different engines optimized for specific workloads and access patterns.

#### Engine Comparison
| Engine | Use Case | Performance | Freshness | Scalability |
|--------|----------|-------------|-----------|-------------|
| MySQL Direct | OLTP queries | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| ClickHouse MySQL | Real-time analytics | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| ClickHouse Iceberg | Historical analytics | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

#### Access Patterns
```sql
-- OLTP: Find specific user
SELECT * FROM mysql_users WHERE username = 'john_doe';

-- Real-time Analytics: Current active users
SELECT country, COUNT(*) FROM mysql_users WHERE status = 'active' GROUP BY country;

-- Historical Analytics: User growth trends
SELECT 
    toYYYYMM(created_at) as month,
    COUNT(*) as new_users,
    SUM(COUNT(*)) OVER (ORDER BY month) as cumulative_users
FROM iceberg_users
GROUP BY month
ORDER BY month;
```

### 10. Disaster Recovery and Data Protection

#### Description
Built-in data protection through versioning, snapshots, and backup capabilities.

#### Snapshot-based Recovery
```sql
-- Create manual snapshot
ALTER TABLE iceberg_orders CREATE SNAPSHOT;

-- Restore from snapshot
CREATE TABLE iceberg_orders_restored AS
SELECT * FROM iceberg_orders 
SETTINGS iceberg_snapshot_id = 1234567890;
```

#### Backup Strategies
- **Incremental Backups**: Only backup changed data
- **Cross-Region Replication**: Copy data to multiple regions
- **Version Control**: Git-like versioning for schema changes
- **Point-in-Time Recovery**: Restore to any historical state

## 🚀 Advanced Use Cases

### Real-time Recommendation Engine
```sql
-- User behavior analysis for recommendations
WITH user_preferences AS (
    SELECT 
        user_id,
        groupArray(product_id) as purchased_products,
        groupArray(category) as preferred_categories
    FROM iceberg_orders o
    JOIN iceberg_products p ON o.product_id = p.id
    WHERE order_date >= now() - INTERVAL 90 DAY
    GROUP BY user_id
),
trending_products AS (
    SELECT product_id, COUNT(*) as popularity
    FROM mysql_orders
    WHERE order_date >= now() - INTERVAL 7 DAY
    GROUP BY product_id
    ORDER BY popularity DESC
    LIMIT 100
)
SELECT 
    u.username,
    p.preferred_categories,
    t.product_id as recommended_product
FROM mysql_users u
JOIN user_preferences p ON u.id = p.user_id
CROSS JOIN trending_products t
WHERE NOT hasAny(p.purchased_products, [t.product_id])
LIMIT 10;
```

### Fraud Detection Pipeline
```sql
-- Real-time fraud detection
WITH suspicious_activity AS (
    SELECT 
        user_id,
        COUNT(*) as order_count,
        SUM(total_amount) as total_spent,
        COUNT(DISTINCT shipping_address) as address_count
    FROM mysql_orders
    WHERE order_date >= now() - INTERVAL 1 HOUR
    GROUP BY user_id
    HAVING order_count > 5 OR total_spent > 5000 OR address_count > 3
)
SELECT 
    u.username,
    u.email,
    s.order_count,
    s.total_spent,
    s.address_count,
    'HIGH_RISK' as risk_level
FROM suspicious_activity s
JOIN mysql_users u ON s.user_id = u.id;
```

### Customer Lifecycle Analytics
```sql
-- Customer journey analysis
WITH customer_lifecycle AS (
    SELECT 
        user_id,
        MIN(order_date) as first_order,
        MAX(order_date) as last_order,
        COUNT(*) as total_orders,
        SUM(total_amount) as lifetime_value,
        dateDiff('day', MIN(order_date), MAX(order_date)) as customer_lifespan_days
    FROM iceberg_orders
    GROUP BY user_id
)
SELECT 
    CASE 
        WHEN customer_lifespan_days = 0 THEN 'One-time'
        WHEN customer_lifespan_days <= 30 THEN 'New'
        WHEN customer_lifespan_days <= 365 THEN 'Regular'
        ELSE 'Loyal'
    END as customer_segment,
    COUNT(*) as customer_count,
    AVG(lifetime_value) as avg_lifetime_value,
    AVG(total_orders) as avg_orders_per_customer
FROM customer_lifecycle
GROUP BY customer_segment
ORDER BY avg_lifetime_value DESC;
```

This comprehensive feature set demonstrates the power of modern data lakehouse architecture, combining the best of operational databases, analytical engines, and data lake storage in a unified platform.
