# Data Lakehouse Architecture Documentation

## Overview

This document explains the architecture of the ClickHouse + MySQL + OLake + Iceberg data lakehouse demonstration environment. The setup showcases modern data engineering patterns with real-time CDC, schema evolution, and cross-system analytics.

## System Architecture

### High-Level Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Sources  │    │ Processing Layer │    │  Storage Layer  │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   MySQL   │──┼────┼─→│ ClickHouse│──┼────┼─→│   MinIO   │  │
│  │ Database  │  │    │  │  Server   │  │    │  │S3 Storage │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                 │    │        │       │    │                 │
│                 │    │  ┌───────────┐  │    │                 │
│                 │    │  │   OLake   │──┼────┼─────────────────┤
│                 │    │  │ Platform  │  │    │                 │
│                 │    │  └───────────┘  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │ Analytics Layer │
                       │                 │
                       │ ┌─────────────┐ │
                       │ │Time Travel  │ │
                       │ │ Queries     │ │
                       │ └─────────────┘ │
                       │ ┌─────────────┐ │
                       │ │Cross-DB     │ │
                       │ │Analytics    │ │
                       │ └─────────────┘ │
                       │ ┌─────────────┐ │
                       │ │Schema       │ │
                       │ │Evolution    │ │
                       │ └─────────────┘ │
                       └─────────────────┘
```

### Data Flow Patterns

#### Pattern 1: Direct MySQL → ClickHouse Integration
```
MySQL Tables → ClickHouse MySQL Engine → Real-time Analytics
```
- **Use Case**: Real-time operational analytics
- **Latency**: Near real-time (seconds)
- **Data Freshness**: Always current
- **Query Performance**: Good for OLTP-style queries

#### Pattern 2: MySQL → OLake → Iceberg → ClickHouse
```
MySQL (CDC) → OLake ETL → Iceberg Tables → ClickHouse Analytics
```
- **Use Case**: Historical analytics, data lake queries
- **Latency**: Batch processing (minutes to hours)
- **Data Freshness**: Depends on ETL schedule
- **Query Performance**: Optimized for OLAP workloads

#### Pattern 3: Hybrid Cross-Database Analytics
```
MySQL (Real-time) + Iceberg (Historical) → Combined Analytics
```
- **Use Case**: Complete customer 360, trending analysis
- **Benefits**: Best of both worlds - current + historical
- **Complexity**: Higher query complexity, JOIN optimization needed

## Component Deep Dive

### MySQL Database Layer

#### Configuration Highlights
```sql
-- Binary logging for CDC
--log-bin=mysql-bin
--server-id=1
--binlog-format=ROW
--gtid-mode=ON
--enforce-gtid-consistency=ON
```

#### Schema Design
- **Normalized Structure**: Traditional OLTP design
- **Referential Integrity**: Foreign key constraints
- **Indexing Strategy**: Optimized for transactional workloads
- **Change Tracking**: Timestamp-based with `updated_at` columns

#### Data Patterns
```
users (demographic data)
├── orders (transaction data)
│   └── products (catalog data)
└── user_sessions (behavioral data)
```

### ClickHouse Processing Layer

#### Engine Configuration
```xml
<profiles>
    <default>
        <allow_experimental_insert_into_iceberg>1</allow_experimental_insert_into_iceberg>
        <use_iceberg_partition_pruning>1</use_iceberg_partition_pruning>
        <use_iceberg_metadata_files_cache>1</use_iceberg_metadata_files_cache>
    </default>
</profiles>
```

#### Table Engine Strategy

**MySQL Engine Tables**
```sql
CREATE TABLE mysql_users (...)
ENGINE = MySQL('mysql:3306', 'demo_db', 'users', 'clickhouse', 'clickhouse_pass');
```
- **Purpose**: Real-time data access
- **Performance**: Direct MySQL query performance
- **Use Cases**: Operational dashboards, real-time alerts

**IcebergS3 Engine Tables**
```sql
CREATE TABLE iceberg_users (...)
ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/users/', 'minioadmin', 'minioadmin123')
PARTITION BY toYYYYMM(created_at);
```
- **Purpose**: Analytical data storage
- **Performance**: Optimized for aggregations, time-series analysis
- **Use Cases**: Historical reporting, trend analysis, ML features

#### Named Collections
```xml
<named_collections>
    <minio_s3>
        <url>http://minio:9000/</url>
        <access_key_id>minioadmin</access_key_id>
        <secret_access_key>minioadmin123</secret_access_key>
    </minio_s3>
</named_collections>
```

### MinIO Storage Layer

#### Bucket Organization
```
iceberg-warehouse/
├── users/
│   ├── metadata/
│   │   ├── v1.metadata.json
│   │   ├── v2.metadata.json
│   │   └── snap-*.avro
│   └── data/
│       ├── created_at_month=2024-01/
│       │   ├── country=USA/
│       │   └── country=Canada/
│       └── created_at_month=2024-02/
├── products/
├── orders/
└── user_sessions/
```

#### Performance Optimizations
- **Partition Strategy**: Time-based + categorical
- **File Format**: Parquet with Snappy compression
- **Metadata Caching**: Enabled for faster query planning
- **Concurrent Access**: Multiple readers/writers supported

### OLake Orchestration Layer

#### Pipeline Configuration
```json
{
  "source": "mysql-demo-source",
  "destination": "iceberg-s3-destination", 
  "schedule": "*/5 * * * *",
  "parallelism": 4,
  "batch_size": 10000
}
```

#### CDC Implementation
- **Binlog Reading**: Real-time change capture
- **GTID Support**: Reliable replication positioning
- **Schema Inference**: Automatic column detection
- **Conflict Resolution**: Last-write-wins strategy

## Query Patterns and Performance

### Real-Time Operational Queries

**Pattern**: Direct MySQL engine access
```sql
-- Real-time user activity
SELECT 
    username, 
    last_activity,
    is_active 
FROM mysql_user_sessions 
WHERE last_activity >= now() - INTERVAL 1 HOUR;
```

**Performance Characteristics**:
- Latency: < 100ms
- Throughput: Limited by MySQL performance
- Scalability: Single MySQL instance bottleneck

### Historical Analytical Queries

**Pattern**: Iceberg table aggregations
```sql
-- Monthly sales trends
SELECT 
    toYYYYMM(order_date) as month,
    SUM(total_amount) as revenue,
    COUNT(DISTINCT user_id) as customers
FROM iceberg_orders 
WHERE order_date >= '2023-01-01'
GROUP BY month
ORDER BY month;
```

**Performance Characteristics**:
- Latency: 1-10 seconds
- Throughput: High parallel processing
- Scalability: Horizontal scaling via partitioning

### Cross-Database Hybrid Queries

**Pattern**: JOIN between MySQL and Iceberg
```sql
-- Customer lifetime value with recent activity
WITH recent_orders AS (
    SELECT user_id, COUNT(*) as recent_count
    FROM mysql_orders
    WHERE order_date >= now() - INTERVAL 30 DAY
    GROUP BY user_id
),
lifetime_stats AS (
    SELECT user_id, SUM(total_amount) as lifetime_value
    FROM iceberg_orders
    GROUP BY user_id
)
SELECT 
    u.username,
    r.recent_count,
    l.lifetime_value
FROM mysql_users u
LEFT JOIN recent_orders r ON u.id = r.user_id
LEFT JOIN lifetime_stats l ON u.id = l.user_id;
```

**Performance Considerations**:
- **Join Strategy**: Stream MySQL, hash Iceberg aggregates
- **Data Movement**: Minimize cross-engine data transfer
- **Caching**: Leverage ClickHouse query cache for repeated patterns

## Schema Evolution Capabilities

### Automatic Schema Detection
```sql
-- OLake detects new columns automatically
ALTER TABLE mysql_users ADD COLUMN phone_number VARCHAR(20);

-- Next sync will include new column in Iceberg
```

### Manual Schema Evolution
```sql
-- Add column to existing Iceberg table
ALTER TABLE iceberg_users ADD COLUMN phone_number Nullable(String);

-- Update existing records
ALTER TABLE iceberg_users 
UPDATE phone_number = '555-0000' 
WHERE id <= 10;
```

### Compatibility Matrix
| Operation | MySQL → ClickHouse | ClickHouse → Iceberg | Iceberg Compatibility |
|-----------|-------------------|---------------------|----------------------|
| Add Column | ✅ Automatic | ✅ Manual + Auto | ✅ Forward compatible |
| Drop Column | ⚠️ Manual sync | ✅ Supported | ✅ Backward compatible |
| Rename Column | ⚠️ Manual mapping | ❌ Not supported | ⚠️ Version dependent |
| Change Type | ⚠️ Data dependent | ⚠️ Limited support | ⚠️ Rules apply |

## Time Travel Implementation

### Snapshot Management
```sql
-- Query specific snapshot
SELECT * FROM iceberg_orders 
SETTINGS iceberg_snapshot_id = 8744736658442914487;

-- Query at timestamp
SELECT * FROM iceberg_orders 
SETTINGS iceberg_timestamp_ms = 1693456800000;
```

### Retention Policies
```json
{
  "history.expire.max-snapshot-age-ms": "432000000",
  "history.expire.min-snapshots-to-keep": "5"
}
```

### Use Cases
- **Audit Trails**: Track data changes over time
- **Error Recovery**: Rollback to known good state
- **Analytics**: Compare metrics across time periods
- **Debugging**: Investigate data quality issues

## Partitioning Strategy

### Users Table
```sql
PARTITION BY (toYYYYMM(created_at), country)
```
- **Time Partition**: Monthly buckets for time-based queries
- **Geographic Partition**: Country-based for regional analysis
- **Pruning Benefit**: Skip irrelevant partitions in queries

### Orders Table  
```sql
PARTITION BY (toYYYYMM(order_date), status)
```
- **Time Partition**: Monthly buckets for reporting
- **Status Partition**: Operational status grouping
- **Analytics Benefit**: Fast status-based aggregations

### Performance Impact
| Query Type | Partition Pruning | Performance Gain |
|------------|------------------|------------------|
| Time range | ✅ Month-based | 10-100x faster |
| Geographic | ✅ Country-based | 5-50x faster |
| Status filter | ✅ Status-based | 3-20x faster |
| Full scan | ❌ No pruning | Baseline |

## Monitoring and Observability

### ClickHouse Metrics
```sql
-- Query performance monitoring
SELECT 
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log 
WHERE query LIKE '%iceberg%'
ORDER BY event_time DESC;
```

### Storage Metrics
```sql
-- Table size and partition information
SELECT 
    database,
    table,
    partition,
    rows,
    bytes_on_disk
FROM system.parts
WHERE table LIKE 'iceberg_%';
```

### OLake Pipeline Metrics
- **Sync Latency**: Time from MySQL change to Iceberg availability
- **Throughput**: Records per second processed
- **Error Rate**: Failed sync attempts percentage
- **Data Freshness**: Age of most recent synchronized data

## Security Considerations

### Network Security
- **Internal Network**: All services in isolated Docker network
- **Access Control**: Service-specific user accounts
- **Encryption**: TLS for external connections (production)

### Data Security
- **User Isolation**: Separate MySQL users for different access patterns
- **Permission Granularity**: Table-level access controls
- **Audit Logging**: Query logs for compliance

### Operational Security
- **Secret Management**: Environment variables for credentials
- **Resource Limits**: Memory and CPU constraints
- **Health Monitoring**: Service availability checks

## Scaling Considerations

### Horizontal Scaling
- **ClickHouse Cluster**: Multiple nodes for query distribution
- **MySQL Read Replicas**: Scale read workloads
- **MinIO Cluster**: Distributed object storage
- **OLake Workers**: Parallel CDC processing

### Vertical Scaling
- **Memory**: Increase for larger analytical workloads
- **CPU**: More cores for parallel query processing
- **Storage**: NVMe for better I/O performance
- **Network**: Higher bandwidth for data movement

### Performance Bottlenecks
1. **MySQL Binlog**: CDC throughput limitation
2. **Network I/O**: Data transfer between components
3. **MinIO Storage**: Object storage latency
4. **ClickHouse Memory**: Large JOIN operations

## Best Practices

### Query Optimization
- **Partition Pruning**: Always include partition columns in WHERE clauses
- **Projection Pushdown**: Select only necessary columns
- **Aggregation Strategy**: Use materialized views for repeated calculations
- **JOIN Order**: Stream smaller tables, hash larger ones

### Data Management
- **Compaction**: Regular small file consolidation
- **Retention**: Implement data lifecycle policies
- **Backup**: Regular snapshots of critical data
- **Testing**: Validate schema changes in staging

### Operational Excellence
- **Monitoring**: Comprehensive metrics and alerting
- **Documentation**: Keep schema and process documentation current
- **Version Control**: Track configuration changes
- **Disaster Recovery**: Test backup and restore procedures

This architecture provides a solid foundation for modern data lakehouse implementations, combining the benefits of real-time operational analytics with scalable historical data processing.
