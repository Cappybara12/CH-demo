#!/bin/bash

# ClickHouse + MySQL + OLake + Iceberg Demo Setup Script
# This script sets up and tests the complete data lakehouse environment

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local check_command=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    print_status "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if eval $check_command > /dev/null 2>&1; then
            print_success "$service_name is ready!"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts: $service_name not ready yet, waiting..."
        sleep 10
        ((attempt++))
    done
    
    print_error "$service_name failed to start within expected time"
    return 1
}

# Function to check if Docker is running
check_docker() {
    print_section "CHECKING DOCKER ENVIRONMENT"
    
    if ! docker --version > /dev/null 2>&1; then
        print_error "Docker is not installed or not running"
        exit 1
    fi
    
    if ! docker-compose --version > /dev/null 2>&1; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_success "Docker and Docker Compose are available"
}

# Function to start services
start_services() {
    print_section "STARTING SERVICES"
    
    print_status "Stopping any existing containers..."
    docker-compose down -v || true
    
    print_status "Starting all services..."
    docker-compose up -d
    
    print_status "Waiting for services to initialize..."
    sleep 30
}

# Function to check service health
check_services() {
    print_section "CHECKING SERVICE HEALTH"
    
    # Check MySQL
    wait_for_service "MySQL" "docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password -e 'SELECT 1'" 20
    
    # Check MinIO
    wait_for_service "MinIO" "curl -f http://localhost:9090/minio/health/live" 15
    
    # Check ClickHouse
    wait_for_service "ClickHouse" "docker exec clickhouse-client clickhouse-client --host clickhouse --query 'SELECT 1'" 20
    
    # Check PostgreSQL (for OLake)
    wait_for_service "PostgreSQL" "docker exec postgres-olake pg_isready -U olake_user -d olake" 15
}

# Function to verify MySQL data
verify_mysql_data() {
    print_section "VERIFYING MYSQL DATA"
    
    print_status "Checking MySQL tables and data..."
    
    # Check if tables exist and have data
    local tables=("users" "products" "orders" "user_sessions")
    
    for table in "${tables[@]}"; do
        local count=$(docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -se "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
        if [ "$count" -gt 0 ]; then
            print_success "Table '$table' has $count records"
        else
            print_warning "Table '$table' has no data or doesn't exist"
        fi
    done
    
    # Show sample data
    print_status "Sample users data:"
    docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "SELECT id, username, email, status, country FROM users LIMIT 5"
    
    print_status "Sample orders data:"
    docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "SELECT id, user_id, product_id, quantity, total_amount, status FROM orders LIMIT 5"
}

# Function to verify MinIO setup
verify_minio_setup() {
    print_section "VERIFYING MINIO SETUP"
    
    print_status "Checking MinIO buckets..."
    
    # Check if buckets exist
    if docker exec minio-client mc ls myminio/iceberg-warehouse > /dev/null 2>&1; then
        print_success "iceberg-warehouse bucket exists"
    else
        print_warning "iceberg-warehouse bucket not found, creating..."
        docker exec minio-client mc mb myminio/iceberg-warehouse
    fi
    
    if docker exec minio-client mc ls myminio/olake-data > /dev/null 2>&1; then
        print_success "olake-data bucket exists"
    else
        print_warning "olake-data bucket not found, creating..."
        docker exec minio-client mc mb myminio/olake-data
    fi
    
    print_status "MinIO console available at: http://localhost:9091"
    print_status "Credentials: minioadmin / minioadmin123"
}

# Function to test ClickHouse connectivity
test_clickhouse_connectivity() {
    print_section "TESTING CLICKHOUSE CONNECTIVITY"
    
    print_status "Testing ClickHouse basic connectivity..."
    docker exec clickhouse-client clickhouse-client --host clickhouse --query "SELECT 'ClickHouse is working!'"
    
    print_status "Checking experimental Iceberg features..."
    docker exec clickhouse-client clickhouse-client --host clickhouse --query "SELECT name, value FROM system.settings WHERE name LIKE '%iceberg%' ORDER BY name"
    
    print_status "Testing MySQL engine connectivity..."
    docker exec clickhouse-client clickhouse-client --host clickhouse --query "
    CREATE OR REPLACE TABLE test_mysql_connection (
        id Int32,
        username String
    ) ENGINE = MySQL('mysql:3306', 'demo_db', 'users', 'clickhouse', 'clickhouse_pass');
    
    SELECT 'MySQL connectivity test:', count() FROM test_mysql_connection;
    DROP TABLE test_mysql_connection;
    "
}

# Function to run demo queries
run_demo_queries() {
    print_section "RUNNING DEMO QUERIES"
    
    print_status "Executing demo SQL script..."
    
    # Copy demo script to ClickHouse client container and execute
    docker cp /Users/akshay/clickhouse/scripts/demo-queries.sql clickhouse-client:/tmp/demo-queries.sql
    
    print_status "Starting demo execution (this may take a few minutes)..."
    docker exec clickhouse-client clickhouse-client --host clickhouse --multiquery < /tmp/demo-queries.sql
    
    print_success "Demo queries completed successfully!"
}

# Function to show service URLs and credentials
show_service_info() {
    print_section "SERVICE INFORMATION"
    
    echo -e "${GREEN}🚀 All services are running! Here's how to access them:${NC}\n"
    
    echo -e "${BLUE}ClickHouse:${NC}"
    echo -e "  HTTP Interface: http://localhost:8123"
    echo -e "  Native Client: docker exec -it clickhouse-client clickhouse-client --host clickhouse"
    echo -e "  MySQL Protocol: mysql -h localhost -P 9004 -u default"
    echo -e ""
    
    echo -e "${BLUE}MySQL:${NC}"
    echo -e "  Connection: mysql -h localhost -P 3306 -u demo_user -pdemo_password demo_db"
    echo -e "  Docker exec: docker exec -it mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db"
    echo -e ""
    
    echo -e "${BLUE}MinIO S3:${NC}"
    echo -e "  Console: http://localhost:9091"
    echo -e "  API: http://localhost:9090"
    echo -e "  Credentials: minioadmin / minioadmin123"
    echo -e ""
    
    echo -e "${BLUE}OLake:${NC}"
    echo -e "  UI: http://localhost:8000"
    echo -e "  Credentials: admin / password"
    echo -e ""
    
    echo -e "${BLUE}PostgreSQL (OLake metadata):${NC}"
    echo -e "  Connection: postgresql://olake_user:olake_password@localhost:5432/olake"
    echo -e ""
    
    echo -e "${GREEN}📚 Quick Commands:${NC}"
    echo -e "  View logs: docker-compose logs -f [service-name]"
    echo -e "  Stop all: docker-compose down"
    echo -e "  Restart: docker-compose restart [service-name]"
    echo -e "  Full cleanup: docker-compose down -v"
    echo -e ""
    
    echo -e "${GREEN}🔧 Test Commands:${NC}"
    echo -e "  Run demo again: docker exec clickhouse-client clickhouse-client --host clickhouse --multiquery < /tmp/demo-queries.sql"
    echo -e "  Check MySQL data: docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db"
    echo -e "  Check ClickHouse: docker exec clickhouse-client clickhouse-client --host clickhouse"
    echo -e ""
}

# Function to run health checks
run_health_checks() {
    print_section "RUNNING HEALTH CHECKS"
    
    # Check all containers are running
    print_status "Checking container status..."
    docker-compose ps
    
    # Check individual service health
    local services=("mysql" "clickhouse" "minio" "postgres")
    
    for service in "${services[@]}"; do
        if docker-compose ps | grep -q "$service.*Up"; then
            print_success "$service container is running"
        else
            print_error "$service container is not running properly"
        fi
    done
}

# Function to create test data for CDC
create_test_data() {
    print_section "CREATING TEST DATA FOR CDC"
    
    print_status "Adding test records to MySQL for CDC testing..."
    
    docker exec mysql-client mysql -h mysql -u demo_user -pdemo_password demo_db -e "
    INSERT INTO users (username, email, full_name, age, country, status) VALUES 
    ('test_user_1', 'test1@example.com', 'Test User 1', 25, 'USA', 'active'),
    ('test_user_2', 'test2@example.com', 'Test User 2', 30, 'Canada', 'premium');
    
    INSERT INTO products (product_name, category, price, stock_quantity) VALUES
    ('Test Product A', 'Testing', 99.99, 100),
    ('Test Product B', 'Testing', 199.99, 50);
    
    INSERT INTO orders (user_id, product_id, quantity, unit_price, status) VALUES
    ((SELECT id FROM users WHERE username = 'test_user_1'), (SELECT id FROM products WHERE product_name = 'Test Product A'), 2, 99.99, 'pending'),
    ((SELECT id FROM users WHERE username = 'test_user_2'), (SELECT id FROM products WHERE product_name = 'Test Product B'), 1, 199.99, 'confirmed');
    "
    
    print_success "Test data created for CDC validation"
}

# Main execution function
main() {
    print_section "CLICKHOUSE + MYSQL + OLAKE + ICEBERG DEMO SETUP"
    
    # Check prerequisites
    check_docker
    
    # Start services
    start_services
    
    # Check service health
    check_services
    
    # Verify setups
    verify_mysql_data
    verify_minio_setup
    
    # Test connectivity
    test_clickhouse_connectivity
    
    # Run demo queries
    run_demo_queries
    
    # Create additional test data
    create_test_data
    
    # Final health checks
    run_health_checks
    
    # Show service information
    show_service_info
    
    print_section "SETUP COMPLETED SUCCESSFULLY"
    print_success "Your ClickHouse + MySQL + OLake + Iceberg demo environment is ready!"
    print_status "Check the demo-queries.sql output above for detailed test results."
    print_status "You can now experiment with the data lakehouse architecture."
}

# Script options
case "${1:-setup}" in
    "setup"|"")
        main
        ;;
    "health")
        check_services
        run_health_checks
        ;;
    "demo")
        run_demo_queries
        ;;
    "info")
        show_service_info
        ;;
    "clean")
        print_status "Cleaning up environment..."
        docker-compose down -v
        docker system prune -f
        print_success "Environment cleaned up"
        ;;
    *)
        echo "Usage: $0 [setup|health|demo|info|clean]"
        echo "  setup  - Full environment setup (default)"
        echo "  health - Run health checks"
        echo "  demo   - Run demo queries only"
        echo "  info   - Show service information"
        echo "  clean  - Clean up environment"
        exit 1
        ;;
esac
