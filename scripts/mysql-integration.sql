-- Create MySQL engine tables for real-time connectivity
CREATE TABLE mysql_users_test (
    id Int32,
    username String,
    email String,
    full_name String,
    age Nullable(Int32),
    country Nullable(String),
    status String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = MySQL('mysql:3306', 'demo_db', 'users', 'olake', 'olake_pass');

-- Test the connection
SELECT 'MySQL Integration Test:' as test, COUNT(*) as user_count FROM mysql_users_test;
