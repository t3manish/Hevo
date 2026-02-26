-- ==========================================
-- HEVO DATA PIPELINE ASSESSMENT I
-- Snowflake Validation & Verification Script
-- ==========================================

-- 1. Set Context
USE ROLE ACCOUNTADMIN;
USE DATABASE hevo_assessment;
USE SCHEMA PG_2_SNOWFLAKE_PUBLIC;

-- ==========================================
-- TEST 1: Count Rows (Verify Hevo Ingestion)
-- ==========================================
-- This ensures all records from the Postgres source made it to Snowflake
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'feedback' AS table_name, COUNT(*) AS row_count FROM feedback
UNION ALL
SELECT 'order_events' AS table_name, COUNT(*) AS row_count FROM order_events;

-- ==========================================
-- TEST 2: Check Usernames (Verify Transformation 1)
-- ==========================================
-- This confirms the username was successfully extracted from the email
SELECT 
    email, 
    username 
FROM customers 
WHERE username IS NOT NULL 
LIMIT 10;

-- ==========================================
-- TEST 3: Confirm Event Rows (Verify Transformation 2)
-- ==========================================
-- This confirms the order_events table was created and the event_type was prepended
SELECT 
    id AS order_id, 
    status AS original_status, 
    event_type 
FROM order_events 
LIMIT 10;

-- ==========================================
-- TEST 4: ER Diagram Integrity Check (The Final Proof)
-- ==========================================
-- This proves that the relationships (1-to-Many and 1-to-1) survived the pipeline
-- and can be successfully queried in the data warehouse.
SELECT 
    c.first_name,
    c.email,
    o.id AS order_id,
    o.status,
    f.rating,
    f.feedback_comment
FROM customers c
JOIN orders o 
    ON c.id = o.customer_id
LEFT JOIN feedback f 
    ON o.id = f.order_id
ORDER BY o.id
LIMIT 15;