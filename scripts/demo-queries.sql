-- ClickHouse + MySQL + Iceberg Demo Queries
-- This script demonstrates the complete data lakehouse integration

-- ========================================
-- PART 1: BASIC CONNECTIVITY TESTING
-- ========================================

-- Test ClickHouse connectivity
SELECT 'ClickHouse Server Info' as test_section;
SELECT version() as clickhouse_version, now() as current_time;

-- Check experimental features are enabled
SELECT 'Experimental Features Check' as test_section;
SELECT name, value FROM system.settings 
WHERE name LIKE '%iceberg%' OR name LIKE '%experimental%'
ORDER BY name;

-- ========================================
-- PART 2: MYSQL INTEGRATION SETUP
-- ========================================

-- Create MySQL engine table to read from MySQL directly
SELECT 'Creating MySQL Engine Tables' as test_section;

-- Users table from MySQL
CREATE OR REPLACE TABLE mysql_users (
    id Int32,
    username String,
    email String,
    full_name Nullable(String),
    created_at DateTime,
    updated_at DateTime,
    status Enum8('active' = 1, 'inactive' = 2, 'premium' = 3, 'banned' = 4),
    age Nullable(Int32),
    country String
)
ENGINE = MySQL('mysql:3306', 'demo_db', 'users', 'clickhouse', 'clickhouse_pass');

-- Products table from MySQL
CREATE OR REPLACE TABLE mysql_products (
    id Int32,
    product_name String,
    category Nullable(String),
    price Decimal(10,2),
    stock_quantity Int32,
    created_at DateTime,
    updated_at DateTime,
    is_active Bool
)
ENGINE = MySQL('mysql:3306', 'demo_db', 'products', 'clickhouse', 'clickhouse_pass');

-- Orders table from MySQL
CREATE OR REPLACE TABLE mysql_orders (
    id Int32,
    user_id Int32,
    product_id Int32,
    quantity Int32,
    unit_price Decimal(10,2),
    total_amount Decimal(12,2),
    order_date DateTime,
    status Enum8('pending' = 1, 'confirmed' = 2, 'shipped' = 3, 'delivered' = 4, 'cancelled' = 5),
    shipping_address Nullable(String),
    notes Nullable(String)
)
ENGINE = MySQL('mysql:3306', 'demo_db', 'orders', 'clickhouse', 'clickhouse_pass');

-- User sessions table from MySQL
CREATE OR REPLACE TABLE mysql_user_sessions (
    id Int32,
    user_id Int32,
    session_token String,
    ip_address Nullable(String),
    user_agent Nullable(String),
    login_time DateTime,
    last_activity DateTime,
    is_active Bool
)
ENGINE = MySQL('mysql:3306', 'demo_db', 'user_sessions', 'clickhouse', 'clickhouse_pass');

-- Test MySQL connectivity
SELECT 'MySQL Connectivity Test' as test_section;
SELECT 'mysql_users' as table_name, count() as row_count FROM mysql_users
UNION ALL
SELECT 'mysql_products' as table_name, count() as row_count FROM mysql_products
UNION ALL
SELECT 'mysql_orders' as table_name, count() as row_count FROM mysql_orders
UNION ALL
SELECT 'mysql_user_sessions' as table_name, count() as row_count FROM mysql_user_sessions;

-- ========================================
-- PART 3: ICEBERG TABLES CREATION
-- ========================================

-- Enable experimental Iceberg settings for this session
SET allow_experimental_insert_into_iceberg = 1;
SET use_iceberg_partition_pruning = 1;
SET use_iceberg_metadata_files_cache = 1;

SELECT 'Creating Iceberg Tables' as test_section;

-- Create Iceberg users table
CREATE OR REPLACE TABLE iceberg_users (
    id Int32,
    username String,
    email String,
    full_name Nullable(String),
    created_at DateTime,
    updated_at DateTime,
    status String,
    age Nullable(Int32),
    country String,
    ingestion_time DateTime DEFAULT now()
)
ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/users/', 'minioadmin', 'minioadmin123')
PARTITION BY toYYYYMM(created_at);

-- Create Iceberg products table
CREATE OR REPLACE TABLE iceberg_products (
    id Int32,
    product_name String,
    category Nullable(String),
    price Decimal(10,2),
    stock_quantity Int32,
    created_at DateTime,
    updated_at DateTime,
    is_active Bool,
    ingestion_time DateTime DEFAULT now()
)
ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/products/', 'minioadmin', 'minioadmin123')
PARTITION BY category;

-- Create Iceberg orders table with partitioning
CREATE OR REPLACE TABLE iceberg_orders (
    id Int32,
    user_id Int32,
    product_id Int32,
    quantity Int32,
    unit_price Decimal(10,2),
    total_amount Decimal(12,2),
    order_date DateTime,
    status String,
    shipping_address Nullable(String),
    notes Nullable(String),
    ingestion_time DateTime DEFAULT now()
)
ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/orders/', 'minioadmin', 'minioadmin123')
PARTITION BY (toYYYYMM(order_date), status);

-- Create Iceberg user sessions table
CREATE OR REPLACE TABLE iceberg_user_sessions (
    id Int32,
    user_id Int32,
    session_token String,
    ip_address Nullable(String),
    user_agent Nullable(String),
    login_time DateTime,
    last_activity DateTime,
    is_active Bool,
    ingestion_time DateTime DEFAULT now()
)
ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/user_sessions/', 'minioadmin', 'minioadmin123')
PARTITION BY toYYYYMM(login_time);

-- ========================================
-- PART 4: DATA MIGRATION TO ICEBERG
-- ========================================

SELECT 'Migrating Data to Iceberg Tables' as test_section;

-- Migrate users data
INSERT INTO iceberg_users (id, username, email, full_name, created_at, updated_at, status, age, country)
SELECT 
    id, 
    username, 
    email, 
    full_name, 
    created_at, 
    updated_at, 
    CAST(status AS String) as status, 
    age, 
    country
FROM mysql_users;

-- Migrate products data
INSERT INTO iceberg_products (id, product_name, category, price, stock_quantity, created_at, updated_at, is_active)
SELECT 
    id, 
    product_name, 
    category, 
    price, 
    stock_quantity, 
    created_at, 
    updated_at, 
    is_active
FROM mysql_products;

-- Migrate orders data
INSERT INTO iceberg_orders (id, user_id, product_id, quantity, unit_price, total_amount, order_date, status, shipping_address, notes)
SELECT 
    id, 
    user_id, 
    product_id, 
    quantity, 
    unit_price, 
    total_amount, 
    order_date, 
    CAST(status AS String) as status, 
    shipping_address, 
    notes
FROM mysql_orders;

-- Migrate user sessions data
INSERT INTO iceberg_user_sessions (id, user_id, session_token, ip_address, user_agent, login_time, last_activity, is_active)
SELECT 
    id, 
    user_id, 
    session_token, 
    ip_address, 
    user_agent, 
    login_time, 
    last_activity, 
    is_active
FROM mysql_user_sessions;

-- Verify data migration
SELECT 'Data Migration Verification' as test_section;
SELECT 'iceberg_users' as table_name, count() as row_count FROM iceberg_users
UNION ALL
SELECT 'iceberg_products' as table_name, count() as row_count FROM iceberg_products
UNION ALL
SELECT 'iceberg_orders' as table_name, count() as row_count FROM iceberg_orders
UNION ALL
SELECT 'iceberg_user_sessions' as table_name, count() as row_count FROM iceberg_user_sessions;

-- ========================================
-- PART 5: SCHEMA EVOLUTION TESTING
-- ========================================

SELECT 'Testing Schema Evolution' as test_section;

-- Add new columns to Iceberg tables
ALTER TABLE iceberg_users ADD COLUMN last_login Nullable(DateTime);
ALTER TABLE iceberg_products ADD COLUMN promotion_active Bool DEFAULT false;
ALTER TABLE iceberg_orders ADD COLUMN tracking_number Nullable(String);

-- Update some records to test schema evolution
ALTER TABLE iceberg_users UPDATE last_login = now() WHERE id <= 5;
ALTER TABLE iceberg_products UPDATE promotion_active = true WHERE category = 'Electronics' AND price > 500;
ALTER TABLE iceberg_orders UPDATE tracking_number = 'TRK' || toString(id) || '_' || toString(rand()) WHERE status = 'shipped';

-- Verify schema evolution
SELECT 'Schema Evolution Verification' as test_section;
DESCRIBE iceberg_users;
DESCRIBE iceberg_products;
DESCRIBE iceberg_orders;

-- ========================================
-- PART 6: ADVANCED ANALYTICS QUERIES
-- ========================================

SELECT 'Advanced Analytics Queries' as test_section;

-- Cross-database analytics: Real-time MySQL + Historical Iceberg
SELECT 'Customer Lifetime Value Analysis' as analysis_type;
WITH 
real_time_orders AS (
    SELECT 
        user_id,
        COUNT(*) as recent_orders,
        SUM(total_amount) as recent_spend
    FROM mysql_orders
    WHERE order_date >= now() - INTERVAL 30 DAY
    GROUP BY user_id
),
historical_analysis AS (
    SELECT 
        user_id,
        COUNT(*) as total_orders,
        SUM(total_amount) as lifetime_spend,
        MIN(order_date) as first_order,
        MAX(order_date) as last_order
    FROM iceberg_orders
    GROUP BY user_id
),
user_segments AS (
    SELECT 
        u.id,
        u.username,
        u.status,
        u.country,
        COALESCE(r.recent_orders, 0) as orders_last_30_days,
        COALESCE(r.recent_spend, 0) as spend_last_30_days,
        h.total_orders,
        h.lifetime_spend,
        h.first_order,
        h.last_order,
        CASE 
            WHEN h.lifetime_spend > 2000 THEN 'VIP'
            WHEN h.lifetime_spend > 1000 THEN 'Premium'
            WHEN h.lifetime_spend > 500 THEN 'Standard'
            ELSE 'New'
        END as customer_segment
    FROM iceberg_users u
    LEFT JOIN real_time_orders r ON u.id = r.user_id
    LEFT JOIN historical_analysis h ON u.id = h.user_id
)
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    AVG(lifetime_spend) as avg_lifetime_spend,
    AVG(orders_last_30_days) as avg_recent_orders,
    SUM(spend_last_30_days) as total_recent_revenue
FROM user_segments
GROUP BY customer_segment
ORDER BY avg_lifetime_spend DESC;

-- Product performance analysis
SELECT 'Product Performance Analysis' as analysis_type;
SELECT 
    p.category,
    p.product_name,
    COUNT(o.id) as total_orders,
    SUM(o.quantity) as total_quantity_sold,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    COUNT(DISTINCT o.user_id) as unique_customers
FROM iceberg_products p
LEFT JOIN iceberg_orders o ON p.id = o.product_id
GROUP BY p.category, p.product_name, p.id
HAVING total_orders > 0
ORDER BY total_revenue DESC
LIMIT 10;

-- Geographic sales analysis
SELECT 'Geographic Sales Analysis' as analysis_type;
SELECT 
    u.country,
    COUNT(DISTINCT u.id) as total_customers,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    COUNT(DISTINCT o.product_id) as unique_products_bought
FROM iceberg_users u
LEFT JOIN iceberg_orders o ON u.id = o.user_id
GROUP BY u.country
HAVING total_orders > 0
ORDER BY total_revenue DESC;

-- Time-based order trends
SELECT 'Time-based Order Trends' as analysis_type;
SELECT 
    toYYYYMM(order_date) as order_month,
    status,
    COUNT(*) as order_count,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT user_id) as unique_customers
FROM iceberg_orders
GROUP BY toYYYYMM(order_date), status
ORDER BY order_month DESC, status;

-- Session analysis with real-time data
SELECT 'User Session Analysis' as analysis_type;
SELECT 
    DATE(s.login_time) as login_date,
    COUNT(*) as total_sessions,
    COUNT(DISTINCT s.user_id) as unique_users,
    AVG(CASE WHEN s.is_active THEN dateDiff('minute', s.login_time, s.last_activity) END) as avg_session_duration_minutes,
    COUNT(CASE WHEN s.is_active THEN 1 END) as active_sessions
FROM iceberg_user_sessions s
GROUP BY DATE(s.login_time)
ORDER BY login_date DESC;

-- ========================================
-- PART 7: PERFORMANCE TESTING
-- ========================================

SELECT 'Performance Comparison Tests' as test_section;

-- Test query performance on MySQL vs Iceberg
SELECT 'MySQL Query Performance Test' as test_type, now() as start_time;
SELECT COUNT(*), AVG(total_amount), MAX(order_date) FROM mysql_orders WHERE status = 'delivered';
SELECT 'MySQL Query Completed' as test_type, now() as end_time;

SELECT 'Iceberg Query Performance Test' as test_type, now() as start_time;
SELECT COUNT(*), AVG(total_amount), MAX(order_date) FROM iceberg_orders WHERE status = 'delivered';
SELECT 'Iceberg Query Completed' as test_type, now() as end_time;

-- Test partition pruning effectiveness
SELECT 'Partition Pruning Test' as test_type;
SELECT 
    toYYYYMM(order_date) as partition_month,
    status,
    COUNT(*) as record_count
FROM iceberg_orders 
WHERE order_date >= '2024-01-01' AND status IN ('delivered', 'shipped')
GROUP BY toYYYYMM(order_date), status
ORDER BY partition_month, status;

-- ========================================
-- PART 8: MONITORING AND METADATA
-- ========================================

SELECT 'System Monitoring Information' as test_section;

-- Check Iceberg table metadata
SELECT 'Iceberg Table Information' as info_type;
SELECT 
    database,
    table,
    engine,
    total_rows,
    total_bytes
FROM system.tables 
WHERE engine LIKE '%Iceberg%'
ORDER BY database, table;

-- Check MySQL engine tables
SELECT 'MySQL Engine Table Information' as info_type;
SELECT 
    database,
    table,
    engine,
    total_rows,
    total_bytes
FROM system.tables 
WHERE engine = 'MySQL'
ORDER BY database, table;

-- Query performance statistics
SELECT 'Recent Query Performance' as info_type;
SELECT 
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage,
    substring(query, 1, 100) as query_preview
FROM system.query_log 
WHERE query LIKE '%iceberg_%' OR query LIKE '%mysql_%'
ORDER BY event_time DESC
LIMIT 10;

SELECT 'Demo Completed Successfully!' as final_message, now() as completion_time;
