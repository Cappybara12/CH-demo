-- MySQL Database Setup for ClickHouse + OLake + Iceberg Demo
-- This script creates sample tables and data for testing the integration

-- Create the demo database if it doesn't exist
CREATE DATABASE IF NOT EXISTS demo_db;
USE demo_db;

-- Create users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status ENUM('active', 'inactive', 'premium', 'banned') DEFAULT 'active',
    age INT,
    country VARCHAR(50) DEFAULT 'USA',
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Create products table
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_category (category),
    INDEX idx_price (price)
);

-- Create orders table
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    shipping_address TEXT,
    notes TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id),
    INDEX idx_order_date (order_date),
    INDEX idx_status (status)
);

-- Create user_sessions table for CDC testing
CREATE TABLE user_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_session_token (session_token),
    INDEX idx_last_activity (last_activity)
);

-- Insert sample users
INSERT INTO users (username, email, full_name, age, country, status) VALUES
('john_doe', 'john.doe@example.com', 'John Doe', 28, 'USA', 'active'),
('jane_smith', 'jane.smith@example.com', 'Jane Smith', 32, 'Canada', 'premium'),
('bob_wilson', 'bob.wilson@example.com', 'Bob Wilson', 45, 'UK', 'active'),
('alice_brown', 'alice.brown@example.com', 'Alice Brown', 29, 'Australia', 'active'),
('charlie_davis', 'charlie.davis@example.com', 'Charlie Davis', 35, 'Germany', 'inactive'),
('diana_miller', 'diana.miller@example.com', 'Diana Miller', 41, 'France', 'premium'),
('frank_garcia', 'frank.garcia@example.com', 'Frank Garcia', 26, 'Spain', 'active'),
('grace_lee', 'grace.lee@example.com', 'Grace Lee', 33, 'South Korea', 'active'),
('henry_taylor', 'henry.taylor@example.com', 'Henry Taylor', 39, 'USA', 'active'),
('ivy_anderson', 'ivy.anderson@example.com', 'Ivy Anderson', 27, 'Canada', 'premium');

-- Insert sample products
INSERT INTO products (product_name, category, price, stock_quantity, is_active) VALUES
('MacBook Pro 16"', 'Electronics', 2499.99, 50, TRUE),
('iPhone 15 Pro', 'Electronics', 999.99, 200, TRUE),
('Samsung Galaxy S24', 'Electronics', 899.99, 150, TRUE),
('Dell XPS 13', 'Electronics', 1299.99, 75, TRUE),
('iPad Air', 'Electronics', 599.99, 100, TRUE),
('AirPods Pro', 'Electronics', 249.99, 300, TRUE),
('Sony WH-1000XM5', 'Electronics', 399.99, 80, TRUE),
('Mechanical Keyboard', 'Accessories', 129.99, 120, TRUE),
('Wireless Mouse', 'Accessories', 79.99, 200, TRUE),
('USB-C Hub', 'Accessories', 49.99, 150, TRUE),
('Portable Monitor', 'Electronics', 299.99, 60, TRUE),
('Webcam HD', 'Electronics', 89.99, 100, TRUE),
('Bluetooth Speaker', 'Electronics', 159.99, 90, TRUE),
('Gaming Chair', 'Furniture', 299.99, 40, TRUE),
('Standing Desk', 'Furniture', 499.99, 25, TRUE);

-- Insert sample orders
INSERT INTO orders (user_id, product_id, quantity, unit_price, status, shipping_address, notes) VALUES
(1, 1, 1, 2499.99, 'delivered', '123 Main St, New York, NY 10001', 'Rush delivery requested'),
(1, 6, 2, 249.99, 'delivered', '123 Main St, New York, NY 10001', NULL),
(2, 2, 1, 999.99, 'shipped', '456 Oak Ave, Toronto, ON M5V 3A8', 'Gift wrap requested'),
(2, 8, 1, 129.99, 'delivered', '456 Oak Ave, Toronto, ON M5V 3A8', NULL),
(3, 3, 1, 899.99, 'confirmed', '789 Pine Rd, London, UK SW1A 1AA', NULL),
(4, 4, 1, 1299.99, 'pending', '321 Elm St, Sydney, NSW 2000', 'Business purchase'),
(5, 5, 1, 599.99, 'cancelled', '654 Maple Dr, Berlin, Germany 10115', 'Customer changed mind'),
(6, 7, 1, 399.99, 'delivered', '987 Cedar Ln, Paris, France 75001', NULL),
(7, 9, 2, 79.99, 'shipped', '147 Birch Ave, Madrid, Spain 28001', NULL),
(8, 10, 3, 49.99, 'delivered', '258 Spruce St, Seoul, South Korea 04524', 'Bulk order'),
(9, 11, 1, 299.99, 'confirmed', '369 Willow Way, Los Angeles, CA 90210', NULL),
(10, 12, 2, 89.99, 'pending', '741 Aspen Rd, Vancouver, BC V6B 1A1', 'Corporate order'),
(1, 13, 1, 159.99, 'delivered', '123 Main St, New York, NY 10001', NULL),
(3, 14, 1, 299.99, 'shipped', '789 Pine Rd, London, UK SW1A 1AA', 'Assembly required'),
(6, 15, 1, 499.99, 'confirmed', '987 Cedar Ln, Paris, France 75001', 'White color preferred');

-- Insert sample user sessions
INSERT INTO user_sessions (user_id, session_token, ip_address, user_agent, is_active) VALUES
(1, CONCAT('sess_john_', UNIX_TIMESTAMP()), '192.168.1.100', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', TRUE),
(2, CONCAT('sess_jane_', UNIX_TIMESTAMP()), '192.168.1.101', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', TRUE),
(3, CONCAT('sess_bob_', UNIX_TIMESTAMP()), '192.168.1.102', 'Mozilla/5.0 (X11; Linux x86_64)', FALSE),
(4, CONCAT('sess_alice_', UNIX_TIMESTAMP()), '192.168.1.103', 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)', TRUE),
(6, CONCAT('sess_diana_', UNIX_TIMESTAMP()), '192.168.1.105', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', TRUE),
(7, CONCAT('sess_frank_', UNIX_TIMESTAMP()), '192.168.1.106', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', TRUE),
(8, CONCAT('sess_grace_', UNIX_TIMESTAMP()), '192.168.1.107', 'Mozilla/5.0 (Android 13; Mobile)', TRUE),
(9, CONCAT('sess_henry_', UNIX_TIMESTAMP()), '192.168.1.108', 'Mozilla/5.0 (iPad; CPU OS 16_0)', FALSE),
(10, CONCAT('sess_ivy_', UNIX_TIMESTAMP()), '192.168.1.109', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', TRUE);

-- Create some indexes for better performance
CREATE INDEX idx_orders_date_status ON orders(order_date, status);
CREATE INDEX idx_users_country_status ON users(country, status);
CREATE INDEX idx_products_category_active ON products(category, is_active);

-- Display summary of created data
SELECT 'Data Summary' as info;
SELECT 'Users created:' as metric, COUNT(*) as count FROM users;
SELECT 'Products created:' as metric, COUNT(*) as count FROM products;
SELECT 'Orders created:' as metric, COUNT(*) as count FROM orders;
SELECT 'User sessions created:' as metric, COUNT(*) as count FROM user_sessions;

-- Show sample data
SELECT 'Sample Users:' as info;
SELECT id, username, email, status, country FROM users LIMIT 5;

SELECT 'Sample Orders with Details:' as info;
SELECT 
    o.id,
    u.username,
    p.product_name,
    o.quantity,
    o.unit_price,
    o.total_amount,
    o.status,
    o.order_date
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN products p ON o.product_id = p.id
LIMIT 10;
