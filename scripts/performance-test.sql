SELECT 'PERFORMANCE COMPARISON: MySQL vs Iceberg' as title;

-- MySQL query performance test
SELECT 'MySQL Engine Query:' as query_type, now() as start_time;
SELECT 'User count by status (MySQL):' as info;
SELECT status, COUNT(*) as user_count 
FROM mysql_users_test 
GROUP BY status 
ORDER BY user_count DESC;

-- Iceberg query performance test  
SELECT 'Iceberg Engine Query:' as query_type, now() as start_time;
SELECT 'User analytics (Iceberg):' as info;
SELECT 
    country,
    COUNT(*) as users,
    ROUND(AVG(total_spent), 2) as avg_spent,
    SUM(order_count) as total_orders
FROM iceberg_blog_demo
GROUP BY country
ORDER BY avg_spent DESC;
