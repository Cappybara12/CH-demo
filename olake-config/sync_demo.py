#!/usr/bin/env python3
import mysql.connector
import json
import time
from datetime import datetime

def sync_mysql_to_iceberg():
    print("🚀 Starting MySQL to Iceberg sync simulation...")
    
    # Connect to MySQL
    conn = mysql.connector.connect(
        host='mysql', port=3306, user='olake', 
        password='olake_pass', database='demo_db'
    )
    cursor = conn.cursor()
    
    # Get data from each table
    tables = ['users', 'products', 'orders', 'user_sessions']
    
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"📊 Would sync {count} records from {table}")
        
        # Simulate processing time
        time.sleep(0.5)
        
        print(f"✅ Completed sync for {table}")
    
    cursor.close()
    conn.close()
    print("🎉 Sync simulation completed!")

if __name__ == "__main__":
    sync_mysql_to_iceberg()
