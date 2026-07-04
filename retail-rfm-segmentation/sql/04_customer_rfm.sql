-- =====================================================================
-- 04 · Customer-level RFM table  (customer_rfm)
--
-- Collapses ~776k line items into ONE ROW PER CUSTOMER with:
--   Recency   = days from the customer's last purchase to the snapshot date
--   Frequency = COUNT(DISTINCT invoice)   -- distinct ORDERS, not rows
--   Monetary  = SUM(quantity * price)
-- then scores each metric 1–5 with NTILE(5) and labels a segment via CASE.
--
-- Snapshot date = 2011-12-10 (one day after the dataset's last transaction).
-- Recency is scored DESC so the most-recent buyers land in the top bucket (5).
-- =====================================================================

DROP TABLE IF EXISTS customer_rfm;

CREATE TABLE customer_rfm AS
WITH rfm AS (                                        -- step 1: raw R, F, M per customer
    SELECT
        customer_id,
        DATE '2011-12-10' - MAX(invoice_date)::date AS recency,
        COUNT(DISTINCT invoice)                      AS frequency,
        ROUND(SUM(quantity * price), 2)              AS monetary
    FROM clean_retail
    GROUP BY customer_id
),
scored AS (                                          -- step 2: 1–5 quintile scores
    SELECT
        customer_id, recency, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,  -- DESC: fewest days -> score 5
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM rfm
)
SELECT                                               -- step 3: map scores -> named segment
    customer_id, recency, frequency, monetary,
    r_score, f_score, m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN f_score >= 4                  THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 3 THEN 'Potential Loyalist'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Others'
    END AS segment
FROM scored;

-- ---- Validation -----------------------------------------------------
-- Expect 5,852 customers:
SELECT COUNT(*) AS customers FROM customer_rfm;

-- Eyeball the top spenders (should read high r/f/m scores, 'Champions'):
SELECT * FROM customer_rfm ORDER BY monetary DESC LIMIT 10;
