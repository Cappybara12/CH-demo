SELECT 'CROSS-DATABASE ANALYTICS DEMONSTRATION' as title;

-- Real-time data from MySQL
SELECT 'Real-time MySQL Data (Live):' as source;
SELECT 
    status,
    COUNT(*) as user_count,
    groupArray(username) as users
FROM mysql_users_test 
GROUP BY status
ORDER BY user_count DESC;

-- Historical data from Iceberg  
SELECT 'Historical Iceberg Data (Data Lake):' as source;
SELECT 
    country,
    COUNT(*) as user_count,
    ROUND(AVG(total_spent), 2) as avg_spent,
    SUM(order_count) as total_orders
FROM iceberg_blog_demo
GROUP BY country
ORDER BY avg_spent DESC;

-- Data source comparison
SELECT 'DATA SOURCE COMPARISON:' as analysis_type;
SELECT 
    'MySQL (Real-time)' as source,
    COUNT(*) as total_users
FROM mysql_users_test
UNION ALL
SELECT 
    'Iceberg (Data Lake)' as source,
    COUNT(*) as total_users  
FROM iceberg_blog_demo;
