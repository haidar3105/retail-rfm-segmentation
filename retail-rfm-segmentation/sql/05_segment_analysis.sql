-- =====================================================================
-- 05 · Segment analysis — the queries behind the dashboard & recommendation
--
-- Reads from the materialized customer_rfm table (built in script 04).
-- =====================================================================

-- ---- Segment summary ------------------------------------------------
-- Customers, revenue, and average recency per segment.
-- This is the table that drives the budget decision: compare a segment's
-- share of REVENUE against its AVERAGE RECENCY. A segment that is both
-- valuable and drifting (high revenue, high recency) is the target.
SELECT
    segment,
    COUNT(*)                                             AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)   AS pct_customers,
    ROUND(SUM(monetary), 0)                              AS total_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
    ROUND(AVG(recency), 0)                               AS avg_recency
FROM customer_rfm
GROUP BY segment
ORDER BY total_revenue DESC;

-- ---- The retention "call list" --------------------------------------
-- Top At-Risk customers ranked by spend: the highest-value LAPSED
-- customers a retention campaign should contact first.
SELECT
    customer_id,
    recency  AS recency_days,
    frequency,
    monetary
FROM customer_rfm
WHERE segment = 'At Risk'
ORDER BY monetary DESC;

-- NOTE: NTILE quintile boundaries can shift per-segment counts by ±1–2
-- when values tie on a bucket edge — a known, harmless property of
-- quantile bucketing. Segment counts still sum to 5,852 customers.
