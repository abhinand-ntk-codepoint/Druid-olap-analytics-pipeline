-- Roll No: 2025AG05637 | DM4ML Lab Assignment
-- =====================================================================================
-- DM4ML Lab Assignment 1 — Five OLAP operations in Druid SQL
-- Datasource : "dm4ml_2025AG05637"   (Global Superstore, rolled up to DAY at ingestion)
-- Timestamp  : __time = order_date (UTC)
-- Dimensions : market, region, country, segment, category, sub_category, ship_mode,
--              order_priority, order_year, order_quarter, order_month
-- Metrics    : line_count (count of original order lines), sales, quantity, profit,
--              shipping_cost, gross_sales, discount_amount, cost, ship_days,
--              max_unit_price, min_unit_price
-- Note       : because Druid pre-aggregated (rolled up) rows at ingestion time, the number
--              of original order lines is SUM(line_count), not COUNT(*).
-- Run each statement separately in the Druid web console (http://localhost:8888 → Query)
-- or with:  python3 run_queries.py
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- Q1. ROLL UP
-- Climb the hierarchies: time goes from DAY (the stored granularity) up to MONTH, and the
-- dimensions category and sub_category are removed, leaving only market. Each output row
-- summarises every day and every product category of one market in one month.
-- (Baseline for comparison — daily grain with market + category:
--   SELECT TIME_FLOOR(__time, 'P1D') AS order_day, market, category, SUM(sales) AS sales
--   FROM "dm4ml_2025AG05637" GROUP BY 1, 2, 3 ORDER BY 1, 2, 3 LIMIT 20 )
-- -------------------------------------------------------------------------------------
SELECT
  TIME_FLOOR(__time, 'P1M')                     AS order_month,
  market,
  SUM(line_count)                               AS order_lines,
  SUM(quantity)                                 AS units_sold,
  ROUND(SUM(sales), 2)                          AS total_sales,
  ROUND(SUM(profit), 2)                         AS total_profit,
  ROUND(SUM(profit) / SUM(sales) * 100, 2)      AS profit_margin_pct
FROM "dm4ml_2025AG05637"
GROUP BY TIME_FLOOR(__time, 'P1M'), market
ORDER BY order_month, market;


-- -------------------------------------------------------------------------------------
-- Q2. DRILL-DOWN
-- Go from summary to detail. Q2a is the summary: total sales per MONTH per category for 2014.
-- Q2b drills into one cell of that summary (Technology, December 2014): time granularity is
-- reduced from MONTH to DAY and a finer dimension (sub_category) is added.
-- -------------------------------------------------------------------------------------
-- Q2a — summary level (month × category)
SELECT
  TIME_FLOOR(__time, 'P1M')                     AS order_month,
  category,
  ROUND(SUM(sales), 2)                          AS total_sales,
  ROUND(SUM(profit), 2)                         AS total_profit
FROM "dm4ml_2025AG05637"
WHERE __time >= TIMESTAMP '2014-01-01 00:00:00' AND __time < TIMESTAMP '2015-01-01 00:00:00'
GROUP BY TIME_FLOOR(__time, 'P1M'), category
ORDER BY order_month, category;

-- Q2b — detail level (day × sub_category) for Technology in December 2014
SELECT
  TIME_FLOOR(__time, 'P1D')                     AS order_day,
  category,
  sub_category,
  SUM(line_count)                               AS order_lines,
  SUM(quantity)                                 AS units_sold,
  ROUND(SUM(sales), 2)                          AS total_sales,
  ROUND(SUM(profit), 2)                         AS total_profit
FROM "dm4ml_2025AG05637"
WHERE category = 'Technology'
  AND __time >= TIMESTAMP '2014-12-01 00:00:00' AND __time < TIMESTAMP '2015-01-01 00:00:00'
GROUP BY TIME_FLOOR(__time, 'P1D'), category, sub_category
ORDER BY order_day, sub_category;


-- -------------------------------------------------------------------------------------
-- Q3. SLICE
-- Fix ONE dimension to a single value (category = 'Furniture') and view the resulting
-- sub-cube across ALL time periods (by year) and the remaining dimension market.
-- -------------------------------------------------------------------------------------
SELECT
  TIME_FLOOR(__time, 'P1Y')                     AS order_year,
  market,
  SUM(line_count)                               AS order_lines,
  ROUND(SUM(sales), 2)                          AS total_sales,
  ROUND(SUM(profit), 2)                         AS total_profit,
  ROUND(SUM(discount_amount), 2)                AS total_discount_given
FROM "dm4ml_2025AG05637"
WHERE category = 'Furniture'
GROUP BY TIME_FLOOR(__time, 'P1Y'), market
ORDER BY order_year, total_sales DESC;


-- -------------------------------------------------------------------------------------
-- Q4. DICE
-- Filter on SEVERAL dimensions at once to carve out a smaller sub-cube:
--   category = 'Technology' AND market IN ('APAC', 'EU') AND segment = 'Consumer'
--   AND time range = calendar year 2013.
-- -------------------------------------------------------------------------------------
SELECT
  market,
  sub_category,
  order_quarter,
  SUM(line_count)                               AS order_lines,
  SUM(quantity)                                 AS units_sold,
  ROUND(SUM(sales), 2)                          AS total_sales,
  ROUND(SUM(profit), 2)                         AS total_profit,
  ROUND(SUM(ship_days) * 1.0 / SUM(line_count), 2) AS avg_ship_days
FROM "dm4ml_2025AG05637"
WHERE category = 'Technology'
  AND market IN ('APAC', 'EU')
  AND segment = 'Consumer'
  AND __time >= TIMESTAMP '2013-01-01 00:00:00' AND __time < TIMESTAMP '2014-01-01 00:00:00'
GROUP BY market, sub_category, order_quarter
ORDER BY market, sub_category, order_quarter;


-- -------------------------------------------------------------------------------------
-- Q5. PIVOT
-- Cross-tabulation of total sales: category as rows and the four quarters as separate
-- columns (rotating the quarter dimension from rows into columns), plus a row total.
-- Druid's aggregate FILTER (WHERE ...) clause builds each quarter column.
-- -------------------------------------------------------------------------------------
SELECT
  category,
  ROUND(SUM(sales) FILTER (WHERE TIME_EXTRACT(__time, 'QUARTER') = 1), 2) AS q1_sales,
  ROUND(SUM(sales) FILTER (WHERE TIME_EXTRACT(__time, 'QUARTER') = 2), 2) AS q2_sales,
  ROUND(SUM(sales) FILTER (WHERE TIME_EXTRACT(__time, 'QUARTER') = 3), 2) AS q3_sales,
  ROUND(SUM(sales) FILTER (WHERE TIME_EXTRACT(__time, 'QUARTER') = 4), 2) AS q4_sales,
  ROUND(SUM(sales), 2)                                                     AS total_sales
FROM "dm4ml_2025AG05637"
GROUP BY category
ORDER BY total_sales DESC;
