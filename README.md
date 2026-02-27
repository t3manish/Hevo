Here is the complete `README.md` file, fully formatted for GitHub in Markdown. It incorporates all of your troubleshooting steps, the exact SQL queries you used, and perfectly aligns with the required structure from the assessment instructions.

You can copy everything below this line and paste it directly into your GitHub repository's `README.md` file.

---

# Hevo Data Pipeline Assessment I

**Candidate Name:** Manish Sairam Thota

**Hevo Account Team Name:** informatica.com_5 

**Pipeline ID:** 2409 

**Loom Video Link:** loom.com/share/46206e0aa4ef45ee81f6b64b55544465

> 
> **Security Notice:** In accordance with best practices and assessment guidelines, no hardcoded credentials, database passwords, or private RSA keys are published in this repository.
> 
> 

---

📁 Repository Contents 

* `README.md`: This documentation file.
* `postgres_ddl.sql`: DDL scripts for creating the local Postgres tables.
* `snowflake_transformations.sql`: SQL scripts used for ELT transformations in Snowflake.
* `snowflake_validation.sql`: SQL scripts used to validate the final data relationships.
* `CSV Files`: hevo-assessment-csv-main

---

1. Detailed Steps to Reproduce 

### Step 1: Local Source Setup (PostgreSQL via Docker)

To serve as the source database, I set up a local PostgreSQL 15 instance using Docker. Since Hevo requires Change Data Capture (CDC) via Logical Replication , I configured the database to output Write-Ahead Logs (WAL).

I used the following `docker-compose.yml` to spin up the database and enable logical replication:

```yaml
services:
  postgres:
    image: postgres:15
    container_name: hevo_postgres
    environment:
      POSTGRES_USER: hevo_user
      POSTGRES_DB: hevo_assessment
      TZ: "Asia/Kolkata"
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    command: 
      - "postgres"
      - "-c"
      - "wal_level=logical"
      - "-c"
      - "max_replication_slots=10"
      - "-c"
      - "max_wal_senders=10"
      - "-c"
      - "wal_sender_timeout=0" 

volumes:
  pgdata:

```

Step 2: Schema Creation & Data Loading 

I connected to the local Postgres database using DBeaver to create the schema and load the provided CSV files.

```sql
-- 1. Create the customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    address JSON
);

-- 2. Create the orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    status VARCHAR(50)
);

-- 3. Create the feedback table (Note: UNIQUE constraint removed for data ingestion)
CREATE TABLE feedback (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id), 
    feedback_comment TEXT,
    rating INTEGER
);

```

Step 3: Network Exposure & Replication Setup 

To allow Hevo to reach my local database, I used `ngrok` to create a secure TCP tunnel:

```bash
ngrok tcp 5432

```

Inside Postgres, I created the publication and replication slot required by Hevo to track incremental changes:

```sql
CREATE PUBLICATION hevo_pub FOR ALL TABLES;
SELECT pg_create_logical_replication_slot('hevo_slot', 'pgoutput');

```

### Step 4: Snowflake Destination & Security Configuration

I set up Snowflake as my destination warehouse using **Key-Pair Authentication**. I generated `.p8` (private) and `.pub` (public) RSA keys, provided the private key to Hevo, and attached the public key to my Snowflake user.

Snowflake's strict Role-Based Access Control (RBAC) required explicit permissions at both the Database and Schema levels. I executed the following script as `ACCOUNTADMIN` to grant the necessary privileges to the pipeline's service role (`HEVO_ROLE`):

```sql
USE ROLE ACCOUNTADMIN;

-- Database Access
GRANT USAGE, MODIFY ON DATABASE hevo_assessment TO ROLE HEVO_ROLE;

-- Schema Access
GRANT USAGE, MONITOR, CREATE TABLE, MODIFY ON SCHEMA hevo_assessment.public TO ROLE HEVO_ROLE;

-- Future-Proofing
GRANT USAGE, MONITOR, CREATE TABLE, MODIFY ON FUTURE SCHEMAS IN DATABASE hevo_assessment TO ROLE HEVO_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE hevo_assessment TO ROLE HEVO_ROLE;

```

Step 5: Hevo Pipeline Setup (ELT Approach) 

I configured a PostgreSQL to Snowflake pipeline using **Logical Replication**.

Hevo automatically routed my pipeline through its "Hevo Edge" architecture. Because Edge is designed purely for high-throughput data movement, it explicitly does not support in-flight Python transformations. Therefore, I adapted my strategy to an **ELT (Extract, Load, Transform)** approach, loading the raw data into Snowflake first and handling the transformations downstream.

Step 6: ELT Transformations in Snowflake 

Hevo successfully loaded the tables into a dynamically created schema named `PG_2_SNOWFLAKE_PUBLIC`.

Because the automated `HEVO_ROLE` created this schema, I used Snowflake's Role Hierarchy to inherit the pipeline's ownership rights so I could alter the tables to fulfill the assessment requirements.

```sql
-- 1. Inherit Ownership Rights
USE ROLE ACCOUNTADMIN;
GRANT ROLE HEVO_ROLE TO ROLE ACCOUNTADMIN;
USE DATABASE hevo_assessment;
USE SCHEMA PG_2_SNOWFLAKE_PUBLIC;

-- ==========================================
-- TRANSFORMATION 1: Orders -> Event Table 
-- ==========================================
CREATE OR REPLACE TABLE order_events AS
SELECT 
    *, 
    'order_' || status AS event_type
FROM orders;

-- ==========================================
-- TRANSFORMATION 2: Customers -> Username 
-- ==========================================
ALTER TABLE customers ADD COLUMN username VARCHAR;

UPDATE customers 
SET username = SPLIT_PART(email, '@', 1);

```

---

2. Assumptions Made 

1. 
**Status Field Data Type:** I defined the `status` field in the `orders` table as a standard `VARCHAR(50)` rather than a strict Postgres `ENUM`. This approach is more flexible for ELT pipelines, as it prevents pipeline failures if new, unexpected status types are introduced by the source application in the future.


2. 
**Handling of Duplicate Constraints:** The provided ER diagram indicated a one-to-one relationship between orders and feedback (implying a `UNIQUE` constraint on `feedback.order_id`). However, the provided `feedback.csv` file contained duplicate `order_id`s. I assumed the priority was successful data ingestion, so I actively removed the `UNIQUE` constraint from the source Postgres table to allow the pipeline to flow. Deduplication would be handled downstream in the data warehouse.



---

3. How Postgres was Connected to Hevo 

PostgreSQL was connected to Hevo using **Logical Replication** over a secure TCP tunnel.

1. **Network:** I utilized `ngrok` to expose the local Docker container port (`5432`) to the public internet, providing Hevo with the generated ngrok TCP URL and port.
2. **CDC Mechanism:** I configured the `wal_level` in `docker-compose.yml` to `logical`, created a publication for all tables, and generated a logical replication slot (`pgoutput`). This allowed Hevo to continuously read the Write-Ahead Logs (WAL) and incrementally sync inserts, updates, and deletes to Snowflake.

---

4. Choices Made for Transformations 

**Strategy: ELT over ETL**
During pipeline setup, Hevo routed my connection through its "Hevo Edge" architecture. Because Edge focuses on high-performance data replication, it does not currently support in-flight Python code blocks.

I made the active architectural choice to pivot to **ELT (Extract, Load, Transform)**.

1. I used Hevo Edge to perfectly replicate the raw data into Snowflake.


2. I executed SQL-based transformations directly inside Snowflake.
This is a modern data engineering best practice, as it leverages the infinite compute power of the cloud data warehouse to perform transformations (`SPLIT_PART` for strings, and `CREATE TABLE AS SELECT` for event generation) rather than bottlenecking the ingestion pipeline.

---

5. Issues Encountered & Workarounds 

* **Issue 1: Docker Configuration Format.** My Docker compose file was initially saved as `.txt` instead of `.yml` (`no configuration file provided: not found`).
* *Workaround:* Renamed the file extension to `.yml` to allow Docker to parse it correctly.


* **Issue 2: Local Postgres Timezone Errors.** When connecting to Docker via DBeaver, I encountered a fatal error (`invalid value for parameter "TimeZone": "Asia/Calcutta"`).
* *Workaround:* I bypassed the Docker environment limitations by forcing the timezone configuration directly in the local client via the `dbeaver.ini` file (`-Duser.timezone=Asia/Kolkata`).


* **Issue 3: Snowflake RBAC Loop.** Snowflake rejected the Hevo connection despite assigning Key-Pair credentials, citing missing `MODIFY` privileges.
* *Workaround:* I researched Snowflake's hierarchical security model and wrote a comprehensive script to explicitly grant `MODIFY` permissions at the Warehouse, Database, Schema, and *Future Schema* levels.


* **Issue 4: Table Ownership Blocks.** After Hevo loaded the data, my `ACCOUNTADMIN` role was blocked from altering the `customers` table to add the derived `username` column because the `HEVO_ROLE` owned the table.
* *Workaround:* I utilized Snowflake's Role Hierarchy by executing `GRANT ROLE HEVO_ROLE TO ROLE ACCOUNTADMIN;`, effectively allowing my user to inherit the necessary table-alteration privileges from the pipeline service account.



---

6. Data Validation 

To prove the pipeline successfully ingested the data and maintained the relational integrity shown in the ER diagram, I ran the following query in Snowflake to join the raw tables:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE hevo_assessment;
USE SCHEMA PG_2_SNOWFLAKE_PUBLIC;

[cite_start]-- Validation Check: Verify columns and relationships [cite: 248]
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
LIMIT 10;


```

