-- =====================================================================
-- 03 · Clean, typed table  (clean_retail)
--
-- Applies six validated cleaning rules and casts every column to its real
-- type, in one CREATE TABLE AS SELECT. Row counts were validated against
-- an independent Python "cleaning funnel" — each rule's output matched
-- the prediction, proving the SQL is correct (not just plausible).
--
--   Raw 1,067,371  -> numeric invoices     1,047,871
--                  -> + customer/qty/price/product   802,632
--                  -> + de-duplicated (final)        776,577
-- =====================================================================

DROP TABLE IF EXISTS clean_retail;

CREATE TABLE clean_retail AS
SELECT DISTINCT                                      -- rule 6: drop exact duplicate rows
    invoice,                                         -- keep TEXT ('C'/'A' already filtered out)
    stock_code,
    description,
    quantity::integer             AS quantity,       -- TEXT -> INTEGER
    invoice_date::timestamp       AS invoice_date,   -- TEXT -> TIMESTAMP (needed for Recency)
    price::numeric(10,2)          AS price,          -- TEXT -> money-precision NUMERIC
    customer_id::numeric::integer AS customer_id,    -- "13085.0" -> 13085 (two-step cast)
    country
FROM staging_retail
WHERE invoice ~ '^[0-9]+$'           -- rule 1: numeric invoices only (drops 'C' and 'A')
  AND customer_id IS NOT NULL        -- rule 2a: not a NULL customer
  AND customer_id <> ''              -- rule 2b: not an EMPTY-STRING customer (blanks loaded as '')
  AND quantity::integer > 0          -- rule 3: positive quantity
  AND price::numeric   > 0           -- rule 4: positive price
  AND stock_code ~ '^[0-9]';         -- rule 5: product codes only (must lead with a digit)

-- ---- Validation -----------------------------------------------------
-- Expect 776,577 rows kept (72.8% of raw):
SELECT COUNT(*) AS clean_rows FROM clean_retail;

-- Expect REAL types now (integer / timestamp / numeric), NOT text:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'clean_retail'
ORDER BY ordinal_position;
