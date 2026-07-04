-- =====================================================================
-- 02 · Raw staging table  (staging_retail)
--
-- Load the Online Retail II CSV EXACTLY as-is — every column as TEXT.
-- Rationale: a text landing zone means the import can never fail on a
-- messy value (e.g. Customer ID is stored as the float-string "13085.0",
-- which would break an INTEGER column). All casting happens later, in 03.
-- =====================================================================

DROP TABLE IF EXISTS staging_retail;

CREATE TABLE staging_retail (
    invoice       TEXT,   -- may carry 'C' (cancellation) / 'A' (adjustment) prefixes
    stock_code    TEXT,   -- e.g. 85048, 79323P; non-products like POST/DOT/M
    description   TEXT,
    quantity      TEXT,   -- cast to INTEGER in script 03
    invoice_date  TEXT,   -- cast to TIMESTAMP in script 03
    price         TEXT,   -- cast to NUMERIC  in script 03
    customer_id   TEXT,   -- "13085.0" or blank -> cast to INTEGER in script 03
    country       TEXT
);

-- ---------------------------------------------------------------------
-- LOAD THE DATA (done in your SQL client, not in SQL):
--   DBeaver: right-click staging_retail -> Import Data -> CSV.
--   Settings: comma delimiter, header row = top, quote char = ",
--   encoding = UTF-8, and map the CSV columns to the table columns
--   BY POSITION (the CSV headers won't auto-match the renamed columns).
--   See data/README.md for where to download online_retail_II.csv.
-- ---------------------------------------------------------------------

-- ---- Validation -----------------------------------------------------
-- Expect exactly 1,067,371 rows:
SELECT COUNT(*) AS staged_rows FROM staging_retail;

-- Expect exactly 8 TEXT columns with the correct names:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'staging_retail'
ORDER BY ordinal_position;
