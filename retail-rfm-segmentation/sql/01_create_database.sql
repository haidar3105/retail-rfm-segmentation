-- =====================================================================
-- 01 · Create the project database
-- Retail Customer Analytics (RFM) — PostgreSQL
--
-- Run this while connected to the default 'postgres' database, then
-- reconnect your client to 'retail_rfm' before running scripts 02–05.
-- =====================================================================

-- NOTE: PostgreSQL has no "CREATE DATABASE IF NOT EXISTS" — run this once.
-- Re-running after it exists returns error 42P04 (harmless: it already exists).
CREATE DATABASE retail_rfm;

-- After running: reconnect your SQL client to the retail_rfm database,
-- then continue with 02_staging_load.sql.
