-- Enable experimental Iceberg features
SET allow_experimental_insert_into_iceberg = 1;

-- Drop table if exists (for clean runs)
DROP TABLE IF EXISTS iceberg_blog_demo;

-- Create Iceberg table
CREATE TABLE iceberg_blog_demo (
    id Int32,
    username String,
    email String,
    country String,
    order_count Int32,
    total_spent Float64,
    demo_timestamp DateTime DEFAULT now()
) ENGINE = IcebergS3('http://minio:9000/iceberg-warehouse/blog-demo-new/', 'minioadmin', 'minioadmin123');

-- Insert data from MySQL into Iceberg
INSERT INTO iceberg_blog_demo (id, username, email, country, order_count, total_spent)
SELECT 
    id,
    username,
    email,
    status as country,
    id * 2 as order_count,
    id * 299.99 as total_spent
FROM mysql_users_test 
LIMIT 8;

-- Verify Iceberg data
SELECT 'Iceberg Table Created:' as status, COUNT(*) as records FROM iceberg_blog_demo;
