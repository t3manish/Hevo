-- ==========================================
-- HEVO DATA PIPELINE ASSESSMENT I
-- ELT Transformations in Snowflake
-- ==========================================

-- 1. Inherit Ownership Rights
-- (Required because the automated HEVO_ROLE created the schema and tables)
USE ROLE ACCOUNTADMIN;
GRANT ROLE HEVO_ROLE TO ROLE ACCOUNTADMIN;

-- 2. Set Context
USE DATABASE hevo_assessment;
USE SCHEMA PG_2_SNOWFLAKE_PUBLIC;

-- ==========================================
-- TRANSFORMATION 1: Orders -> Event Table
-- Requirement: Based on the status field, create a new table where each row represents an event.
-- ==========================================
CREATE OR REPLACE TABLE order_events AS
SELECT 
    *, 
    'order_' || status AS event_type
FROM orders;

-- ==========================================
-- TRANSFORMATION 2: Customers -> Username
-- Requirement: Add a derived field username to the customers data, extracted from the email address.
-- ==========================================
-- Add the new column
ALTER TABLE customers ADD COLUMN username VARCHAR;

-- Populate the column by extracting text before the '@'
UPDATE customers 
SET username = SPLIT_PART(email, '@', 1);

-- ==========================================
-- VERIFY TRANSFORMATIONS
-- ==========================================
SELECT * FROM order_events LIMIT 5;
SELECT email, username FROM customers LIMIT 5;