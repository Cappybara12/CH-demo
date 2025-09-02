-- Additional Test Data Generation for ClickHouse + MySQL + Iceberg Demo
-- This script creates more comprehensive test data for various scenarios

USE demo_db;

-- ========================================
-- SCENARIO 1: E-COMMERCE SIMULATION DATA
-- ========================================

-- Add more diverse users for better analytics
INSERT INTO users (username, email, full_name, age, country, status) VALUES 
-- Premium customers from different regions
('sarah_jones', 'sarah.jones@example.com', 'Sarah Jones', 34, 'UK', 'premium'),
('michael_chen', 'michael.chen@example.com', 'Michael Chen', 28, 'Singapore', 'premium'),
('emma_mueller', 'emma.mueller@example.com', 'Emma Mueller', 31, 'Germany', 'premium'),
('james_smith', 'james.smith@example.com', 'James Smith', 42, 'Australia', 'premium'),

-- Active customers for geographic diversity
('maria_garcia', 'maria.garcia@example.com', 'Maria Garcia', 26, 'Mexico', 'active'),
('pierre_martin', 'pierre.martin@example.com', 'Pierre Martin', 38, 'France', 'active'),
('akiko_tanaka', 'akiko.tanaka@example.com', 'Akiko Tanaka', 29, 'Japan', 'active'),
('raj_patel', 'raj.patel@example.com', 'Raj Patel', 33, 'India', 'active'),
('lars_olsen', 'lars.olsen@example.com', 'Lars Olsen', 45, 'Norway', 'active'),
('ana_silva', 'ana.silva@example.com', 'Ana Silva', 27, 'Brazil', 'active'),

-- Some inactive users for churn analysis
('inactive_user1', 'inactive1@example.com', 'Former Customer 1', 35, 'USA', 'inactive'),
('inactive_user2', 'inactive2@example.com', 'Former Customer 2', 29, 'Canada', 'inactive'),
('banned_user1', 'banned1@example.com', 'Banned Customer 1', 25, 'UK', 'banned');

-- Add more diverse products across categories
INSERT INTO products (product_name, category, price, stock_quantity, is_active) VALUES 
-- Software & Digital
('Adobe Creative Suite', 'Software', 599.99, 1000, TRUE),
('Microsoft Office 365', 'Software', 149.99, 1000, TRUE),
('Antivirus Premium', 'Software', 79.99, 1000, TRUE),

-- Gaming
('Gaming Laptop RTX 4080', 'Gaming', 2299.99, 25, TRUE),
('PlayStation 5', 'Gaming', 499.99, 15, TRUE),
('Xbox Series X', 'Gaming', 499.99, 20, TRUE),
('Nintendo Switch OLED', 'Gaming', 349.99, 40, TRUE),
('Gaming Mouse RGB', 'Gaming', 89.99, 150, TRUE),
('Mechanical Gaming Keyboard', 'Gaming', 159.99, 100, TRUE),

-- Home & Kitchen
('Smart Coffee Maker', 'Home', 299.99, 60, TRUE),
('Robot Vacuum', 'Home', 399.99, 35, TRUE),
('Air Fryer XL', 'Home', 159.99, 80, TRUE),
('Smart Thermostat', 'Home', 249.99, 45, TRUE),

-- Books & Education
('Data Science Handbook', 'Books', 49.99, 200, TRUE),
('Machine Learning Course', 'Education', 199.99, 1000, TRUE),
('Python Programming Guide', 'Books', 39.99, 150, TRUE),

-- Health & Fitness
('Fitness Tracker Pro', 'Health', 199.99, 120, TRUE),
('Smart Scale', 'Health', 89.99, 90, TRUE),
('Yoga Mat Premium', 'Health', 79.99, 200, TRUE),

-- Discontinued products for historical analysis
('Old iPhone Model', 'Electronics', 299.99, 0, FALSE),
('Legacy Laptop', 'Electronics', 599.99, 0, FALSE);

-- ========================================
-- SCENARIO 2: TIME-SERIES ORDER DATA
-- ========================================

-- Generate orders across different time periods for trend analysis
-- Recent orders (last 30 days)
INSERT INTO orders (user_id, product_id, quantity, unit_price, status, order_date, shipping_address) VALUES 
-- High-value orders
((SELECT id FROM users WHERE username = 'sarah_jones'), (SELECT id FROM products WHERE product_name = 'Gaming Laptop RTX 4080'), 1, 2299.99, 'delivered', NOW() - INTERVAL 5 DAY, '10 Downing Street, London, UK'),
((SELECT id FROM users WHERE username = 'michael_chen'), (SELECT id FROM products WHERE product_name = 'MacBook Pro 16"'), 1, 2499.99, 'shipped', NOW() - INTERVAL 3 DAY, '1 Marina Bay, Singapore 018989'),

-- Medium-value orders
((SELECT id FROM users WHERE username = 'emma_mueller'), (SELECT id FROM products WHERE product_name = 'PlayStation 5'), 1, 499.99, 'delivered', NOW() - INTERVAL 7 DAY, 'Alexanderplatz 1, Berlin, Germany'),
((SELECT id FROM users WHERE username = 'james_smith'), (SELECT id FROM products WHERE product_name = 'Adobe Creative Suite'), 1, 599.99, 'confirmed', NOW() - INTERVAL 2 DAY, '1 Sydney Harbour Bridge, Sydney, Australia'),

-- Bulk orders
((SELECT id FROM users WHERE username = 'raj_patel'), (SELECT id FROM products WHERE product_name = 'AirPods Pro'), 5, 249.99, 'pending', NOW() - INTERVAL 1 DAY, 'Gateway of India, Mumbai, India'),
((SELECT id FROM users WHERE username = 'maria_garcia'), (SELECT id FROM products WHERE product_name = 'Wireless Mouse'), 10, 79.99, 'confirmed', NOW() - INTERVAL 4 DAY, 'Zócalo, Mexico City, Mexico'),

-- Software purchases
((SELECT id FROM users WHERE username = 'pierre_martin'), (SELECT id FROM products WHERE product_name = 'Machine Learning Course'), 1, 199.99, 'delivered', NOW() - INTERVAL 6 DAY, 'Champs-Élysées, Paris, France'),
((SELECT id FROM users WHERE username = 'akiko_tanaka'), (SELECT id FROM products WHERE product_name = 'Microsoft Office 365'), 1, 149.99, 'delivered', NOW() - INTERVAL 8 DAY, 'Shibuya Crossing, Tokyo, Japan');

-- Historical orders (2-6 months ago) for trend analysis
INSERT INTO orders (user_id, product_id, quantity, unit_price, status, order_date, shipping_address) VALUES 
-- Q4 2023 holiday season simulation
((SELECT id FROM users WHERE username = 'john_doe'), (SELECT id FROM products WHERE product_name = 'iPhone 15 Pro'), 1, 999.99, 'delivered', '2023-12-15 10:30:00', '123 Main St, New York, NY 10001'),
((SELECT id FROM users WHERE username = 'jane_smith'), (SELECT id FROM products WHERE product_name = 'Nintendo Switch OLED'), 2, 349.99, 'delivered', '2023-12-20 14:20:00', '456 Oak Ave, Toronto, ON M5V 3A8'),
((SELECT id FROM users WHERE username = 'bob_wilson'), (SELECT id FROM products WHERE product_name = 'Smart Coffee Maker'), 1, 299.99, 'delivered', '2023-11-25 09:15:00', '789 Pine Rd, London, UK SW1A 1AA'),

-- Q3 2023 back-to-school season
((SELECT id FROM users WHERE username = 'alice_brown'), (SELECT id FROM products WHERE product_name = 'Dell XPS 13'), 1, 1299.99, 'delivered', '2023-09-10 16:45:00', '321 Elm St, Sydney, NSW 2000'),
((SELECT id FROM users WHERE username = 'diana_miller'), (SELECT id FROM products WHERE product_name = 'Data Science Handbook'), 3, 49.99, 'delivered', '2023-08-20 11:30:00', '987 Cedar Ln, Paris, France 75001'),

-- Some cancelled orders for analysis
((SELECT id FROM users WHERE username = 'charlie_davis'), (SELECT id FROM products WHERE product_name = 'Gaming Laptop RTX 4080'), 1, 2299.99, 'cancelled', '2023-10-15 13:20:00', '654 Maple Dr, Berlin, Germany 10115'),
((SELECT id FROM users WHERE username = 'lars_olsen'), (SELECT id FROM products WHERE product_name = 'Xbox Series X'), 1, 499.99, 'cancelled', '2023-11-05 15:10:00', 'Royal Palace, Oslo, Norway');

-- ========================================
-- SCENARIO 3: USER SESSION DATA FOR CDC
-- ========================================

-- Generate diverse session data for real-time analytics
INSERT INTO user_sessions (user_id, session_token, ip_address, user_agent, login_time, last_activity, is_active) VALUES 
-- Recent active sessions
((SELECT id FROM users WHERE username = 'sarah_jones'), 'sess_sarah_1693456800', '192.168.1.200', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36', NOW() - INTERVAL 2 HOUR, NOW() - INTERVAL 30 MINUTE, TRUE),
((SELECT id FROM users WHERE username = 'michael_chen'), 'sess_michael_1693456801', '10.0.0.150', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0', NOW() - INTERVAL 1 HOUR, NOW() - INTERVAL 15 MINUTE, TRUE),
((SELECT id FROM users WHERE username = 'emma_mueller'), 'sess_emma_1693456802', '172.16.0.100', 'Mozilla/5.0 (X11; Linux x86_64) Firefox/121.0', NOW() - INTERVAL 3 HOUR, NOW() - INTERVAL 45 MINUTE, TRUE),

-- Mobile sessions
((SELECT id FROM users WHERE username = 'maria_garcia'), 'sess_maria_mobile_1693456803', '192.168.2.50', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)', NOW() - INTERVAL 30 MINUTE, NOW() - INTERVAL 5 MINUTE, TRUE),
((SELECT id FROM users WHERE username = 'raj_patel'), 'sess_raj_android_1693456804', '10.1.1.75', 'Mozilla/5.0 (Android 14; Mobile; rv:120.0)', NOW() - INTERVAL 45 MINUTE, NOW() - INTERVAL 10 MINUTE, TRUE),

-- Ended sessions
((SELECT id FROM users WHERE username = 'pierre_martin'), 'sess_pierre_ended_1693456805', '192.168.3.25', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15', NOW() - INTERVAL 4 HOUR, NOW() - INTERVAL 2 HOUR, FALSE),
((SELECT id FROM users WHERE username = 'akiko_tanaka'), 'sess_akiko_ended_1693456806', '172.20.1.80', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.0.0', NOW() - INTERVAL 6 HOUR, NOW() - INTERVAL 3 HOUR, FALSE),

-- Admin/staff sessions
((SELECT id FROM users WHERE username = 'james_smith'), 'sess_admin_james_1693456807', '192.168.100.10', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0.0.0 AdminPanel/1.0', NOW() - INTERVAL 1 HOUR, NOW() - INTERVAL 5 MINUTE, TRUE);

-- ========================================
-- SCENARIO 4: PRODUCT UPDATES FOR SCHEMA EVOLUTION
-- ========================================

-- Update some product information to test CDC
UPDATE products SET 
    stock_quantity = stock_quantity - 1,
    updated_at = NOW()
WHERE id IN (
    SELECT id FROM (
        SELECT id FROM products WHERE stock_quantity > 0 ORDER BY RAND() LIMIT 5
    ) as temp
);

-- Update user statuses
UPDATE users SET 
    status = 'premium',
    updated_at = NOW()
WHERE username IN ('lars_olsen', 'ana_silva') AND status = 'active';

-- Mark some orders as shipped/delivered
UPDATE orders SET 
    status = 'shipped',
    notes = 'Expedited shipping applied'
WHERE status = 'confirmed' AND order_date >= NOW() - INTERVAL 7 DAY;

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Show data summary
SELECT 'Extended Data Summary' as info;

SELECT 'Total Users:' as metric, COUNT(*) as count, 
       GROUP_CONCAT(DISTINCT status) as statuses,
       GROUP_CONCAT(DISTINCT country ORDER BY country) as countries
FROM users;

SELECT 'Total Products:' as metric, COUNT(*) as count,
       GROUP_CONCAT(DISTINCT category ORDER BY category) as categories,
       SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_products
FROM products;

SELECT 'Total Orders:' as metric, COUNT(*) as count,
       GROUP_CONCAT(DISTINCT status ORDER BY status) as order_statuses,
       SUM(total_amount) as total_revenue
FROM orders;

SELECT 'Total Sessions:' as metric, COUNT(*) as count,
       SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_sessions,
       COUNT(DISTINCT user_id) as unique_users_with_sessions
FROM user_sessions;

-- Show recent activity for CDC validation
SELECT 'Recent Orders (Last 7 days):' as activity_type;
SELECT 
    o.id,
    u.username,
    p.product_name,
    o.quantity,
    o.total_amount,
    o.status,
    o.order_date
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN products p ON o.product_id = p.id
WHERE o.order_date >= NOW() - INTERVAL 7 DAY
ORDER BY o.order_date DESC;

SELECT 'Active Sessions:' as activity_type;
SELECT 
    s.id,
    u.username,
    s.ip_address,
    s.login_time,
    s.last_activity,
    TIMESTAMPDIFF(MINUTE, s.login_time, s.last_activity) as session_duration_minutes
FROM user_sessions s
JOIN users u ON s.user_id = u.id
WHERE s.is_active = TRUE
ORDER BY s.last_activity DESC;

-- Geographic distribution
SELECT 'Geographic Distribution:' as analysis_type;
SELECT 
    country,
    COUNT(DISTINCT u.id) as users,
    COUNT(o.id) as orders,
    COALESCE(SUM(o.total_amount), 0) as revenue
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY country
ORDER BY revenue DESC;

SELECT 'Test Data Generation Completed!' as status;
