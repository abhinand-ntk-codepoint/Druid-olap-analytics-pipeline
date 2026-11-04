-- Roll No: 2025AG05637 | DM4ML Lab Assignment
-- Step 4 — OLAP vs OLTP demonstration on datasource "dm4ml_2025AG05637".
-- Run each statement in the Druid web console (Query tab) and screenshot the response,
-- or run:  python3 run_queries.py   (saves Druid's exact responses to results/oltp_*.txt).

-- T0. Row count BEFORE the attempts (baseline)
SELECT COUNT(*) AS stored_rows, SUM(line_count) AS order_lines, ROUND(SUM(sales), 2) AS total_sales
FROM "dm4ml_2025AG05637";

-- T1. Row-level DELETE (OLTP-style)
DELETE FROM "dm4ml_2025AG05637"
WHERE category = 'Furniture' AND market = 'Canada';

-- T2. Row-level UPDATE (OLTP-style)
UPDATE "dm4ml_2025AG05637"
SET sales = sales * 1.10
WHERE category = 'Technology' AND __time >= TIMESTAMP '2014-01-01 00:00:00';

-- T3. Row count AFTER the attempts — expected to be identical to T0 (no effect on data)
SELECT COUNT(*) AS stored_rows, SUM(line_count) AS order_lines, ROUND(SUM(sales), 2) AS total_sales
FROM "dm4ml_2025AG05637";
