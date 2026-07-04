# SQL Reference Module — Retail RFM Segmentation (Complete)

**Project 1 · Business Intelligence Track · PostgreSQL + DBeaver + Power BI**

A complete, reusable reference for every command used to take **1,067,371 raw
retail transactions → a clean typed table → RFM-scored & segmented customers →
a Power BI dashboard** ending in a retention-budget recommendation.

> **How to use this module.**
> **Part 1** is a command dictionary — look up any keyword to see what it does, its syntax, and the exact way it was used here.
> **Part 2** is the complete pipeline in order, with the full annotated SQL.
> **Part 3** is the Power BI DAX appendix.
> **Part 4** lists the errors hit and fixed.
> **Part 5** is a one-page cheat sheet.
> **Part 6** is a *reusable RFM template* — how to adapt this to a new dataset.

---

## Table of Contents
- [Part 1 — SQL Command Reference](#part-1--sql-command-reference)
  1. [Database & table management (DDL)](#1-database--table-management-ddl)
  2. [Querying basics (DQL)](#2-querying-basics-dql)
  3. [Filtering with WHERE](#3-filtering-with-where)
  4. [Pattern matching (regex)](#4-pattern-matching-regex)
  5. [Type casting](#5-type-casting)
  6. [Aggregation, grouping & sorting](#6-aggregation-grouping--sorting)
  7. [Window functions — the scoring engine](#7-window-functions--the-scoring-engine)
  8. [CTEs (WITH … AS)](#8-ctes-with--as)
  9. [Conditional logic — CASE](#9-conditional-logic--case)
  10. [Date & time handling](#10-date--time-handling)
  11. [De-duplication & subqueries](#11-de-duplication--subqueries)
  12. [Table introspection](#12-table-introspection)
- [Part 2 — The Complete Pipeline](#part-2--the-complete-pipeline)
- [Part 3 — DAX Appendix (Power BI)](#part-3--dax-appendix-power-bi)
- [Part 4 — Errors Encountered & Fixes](#part-4--errors-encountered--fixes)
- [Part 5 — One-Page Cheat Sheet](#part-5--one-page-cheat-sheet)
- [Part 6 — Reusable RFM Template](#part-6--reusable-rfm-template)
- [Glossary](#glossary)

---

# Part 1 — SQL Command Reference

Each entry: **what it does → syntax → in this project → watch out.**

---

## 1. Database & table management (DDL)

*DDL = Data Definition Language: commands that define structure.*

### `CREATE DATABASE`
Creates a new, empty database.
```sql
CREATE DATABASE retail_rfm;
```
**Watch out:** PostgreSQL has **no `CREATE DATABASE IF NOT EXISTS`** — re-running errors with `42P04`. Names use `snake_case` (no spaces/hyphens). After creating, **Refresh (F5)** the client to see it.

### `CREATE TABLE`
Defines a table's columns and types.
```sql
CREATE TABLE staging_retail (
    invoice TEXT, stock_code TEXT, description TEXT, quantity TEXT,
    invoice_date TEXT, price TEXT, customer_id TEXT, country TEXT
);
```
**In this project:** the staging table is **all `TEXT`** so a raw load can't fail on a messy value. **Watch out:** unlike databases, tables *do* support `CREATE TABLE IF NOT EXISTS`.

### `DROP TABLE IF EXISTS`
Deletes a table (and its data); `IF EXISTS` avoids an error if absent.
```sql
DROP TABLE IF EXISTS staging_retail;
```
The safe "rebuild" pattern — in staging, a bad load costs nothing.

### `CREATE TABLE AS SELECT` (CTAS)
Runs a query and **stores its result** as a new permanent table. The bridge from *querying* to *owning* a dataset.
```sql
CREATE TABLE clean_retail AS
SELECT ... FROM staging_retail WHERE ...;
```
Used to materialize both `clean_retail` and `customer_rfm`.

### Data types used
| Type | Stores | Example | Used for |
|---|---|---|---|
| `TEXT` | any characters | `"79323P"` | all staging columns; final text fields |
| `INTEGER` | whole numbers | `12` | `quantity`, `customer_id` (after cast) |
| `NUMERIC(10,2)` | exact decimals | `6.95` | `price` (money precision) |
| `TIMESTAMP` | date + time | `2009-12-01 07:45:00` | `invoice_date` (enables date math) |

**Prefer `NUMERIC` over `FLOAT` for money** — floats drift on decimals.

---

## 2. Querying basics (DQL)

### `SELECT … FROM`
Retrieves columns or computed values.
```sql
SELECT customer_id, monetary FROM customer_rfm;
SELECT * FROM clean_retail;          -- all columns
```

### `SELECT` without a table
```sql
SELECT version();     -- built-in function; the first "is SQL running?" check
SELECT 2 + 2;         -- arithmetic, no FROM needed
```

### `LIMIT`
Caps returned rows — for previewing a large table.
```sql
SELECT * FROM staging_retail LIMIT 10;
```

### Column aliases (`AS`)
Renames a column *in the output*.
```sql
SELECT COUNT(*) AS rows_after_rule1 FROM staging_retail WHERE invoice ~ '^[0-9]+$';
```

### Comments & execution
```sql
-- single-line comment (everything to its RIGHT is ignored)
/* multi-line block comment */
```
End statements with `;`. In DBeaver, **Ctrl+Enter** runs the statement at the cursor (or the highlighted selection only). **Watch out:** `--` only comments text *to its right* — pasting a note like `value::type -- note` runs the `value::type` part and errors.

---

## 3. Filtering with `WHERE`
Keeps rows where a condition is `TRUE`. Data cleaning here is a stack of `WHERE` conditions.

| Operator | Meaning | Example |
|---|---|---|
| `=` | equal | `country = 'United Kingdom'` |
| `<>` / `!=` | not equal | `customer_id <> ''` |
| `>` `>=` `<` `<=` | comparisons | `quantity::integer > 0` |

### `IS NULL` / `IS NOT NULL`
Tests for `NULL` ("unknown"). You **cannot** use `=`/`<>` for NULL.
```sql
WHERE customer_id IS NOT NULL
```
**Critical gotcha:** `NULL` ≠ empty string `''`. `IS NOT NULL` does *not* catch `''`. Blanks that loaded as `''` needed **both** `IS NOT NULL AND <> ''`.

### `AND` / `OR`
Combine conditions; with `AND`, all must be true.

### `NULLIF(a, b)`
Returns `NULL` if `a = b`, else `a`. Compact way to treat `''` as NULL:
```sql
WHERE NULLIF(customer_id, '') IS NOT NULL
```

---

## 4. Pattern matching (regex)
The `~` operator tests whether text **matches a regular expression**.

| Operator | Meaning |
|---|---|
| `~` | matches (case-sensitive) |
| `~*` | matches, case-insensitive |
| `!~` | does NOT match |

| Token | Meaning |
|---|---|
| `^` | start of string |
| `$` | end of string |
| `[0-9]` | any digit |
| `+` | one or more of the previous token |

```sql
WHERE invoice ~ '^[0-9]+$'     -- ENTIRELY digits → drops 'C…' and 'A…'
WHERE stock_code ~ '^[0-9]'    -- STARTS with a digit → keeps '79323P', drops 'POST'
```
**The `$` matters:** invoices must be fully numeric (anchored both ends); stock codes only need to *start* with a digit (anchored start only).

---

## 5. Type casting
Converts a value's type — mandatory before math on text columns.
```sql
value::type            -- Postgres shorthand
CAST(value AS type)    -- standard SQL (identical effect)
```
```sql
SELECT price::numeric, quantity::integer, invoice_date::timestamp FROM staging_retail;
```
**The two-step cast** (for the `"13085.0"` float-string):
```sql
customer_id::numeric::integer   -- "13085.0" → 13085.0 → 13085
```
A direct `::integer` fails on the decimal; cast through an intermediate type that understands the format.

---

## 6. Aggregation, grouping & sorting
Aggregate functions collapse many rows into one summary value.

### `COUNT` — three flavours (know the difference)
| Form | Counts | NULLs |
|---|---|---|
| `COUNT(*)` | all rows | included |
| `COUNT(col)` | non-null rows | ignored |
| `COUNT(DISTINCT col)` | distinct values | ignored |

**Frequency = `COUNT(DISTINCT invoice)`** — distinct *orders*, not rows. `COUNT(*)` would inflate frequency for large orders (the grain trap).

### Other aggregates & arithmetic
```sql
SUM(quantity * price)   -- Monetary (line revenue summed)
MAX(invoice_date)       -- last purchase (for Recency)
MIN()   AVG()
```

### `GROUP BY`
Collapses rows sharing the listed values into one group; aggregates compute per group.
```sql
SELECT customer_id, SUM(quantity*price) FROM clean_retail GROUP BY customer_id;
```
**Rule:** every selected column must be in the `GROUP BY` or inside an aggregate.

### `HAVING`
Filters **groups** (after `GROUP BY`) — vs `WHERE`, which filters rows before grouping.
```sql
GROUP BY invoice, stock_code, price
HAVING COUNT(*) > 1        -- groups appearing 2+ times (find duplicates)
```

### `ORDER BY`
Sorts output; `DESC` = descending.
```sql
ORDER BY monetary DESC;
```

---

## 7. Window functions — the scoring engine
**The idea:** a window function computes a value *across a set of rows* while **keeping every row** — unlike `GROUP BY`, which *collapses* rows. It looks "through a window" at other rows to rank the current one. The `OVER (…)` clause is what makes a function a window function.

### `NTILE(n)`
Sorts rows and splits them into `n` equal buckets. `NTILE(5)` = quintiles (1–5).
```sql
NTILE(5) OVER (ORDER BY monetary ASC) AS m_score   -- top fifth by spend → 5
```
- The `ORDER BY` *inside* `OVER (…)` decides the ranking used for bucketing (separate from a final display `ORDER BY`).

**The Recency flip (key correctness point):** Frequency and Monetary sort **ASC** (higher = better = bucket 5). Recency is reversed (fewer days = better), so sort **DESC** so the most-recent buyers get 5:
```sql
NTILE(5) OVER (ORDER BY recency DESC) AS r_score
```

**Related window functions** (not used here, but same family): `ROW_NUMBER()` (unique rank), `RANK()` (ties share a rank, gaps after), `DENSE_RANK()` (ties share, no gaps).

---

## 8. CTEs (`WITH … AS`)
A **Common Table Expression** is a named temporary result you can reference — it makes multi-step SQL readable instead of deeply nested.
```sql
WITH rfm AS (
    SELECT customer_id, ... FROM clean_retail GROUP BY customer_id
)
SELECT * FROM rfm;
```
**Chaining** — separate CTEs with commas; each can build on the previous:
```sql
WITH rfm AS ( ... ),
     scored AS ( SELECT ..., NTILE(5) OVER (...) FROM rfm ),
     segmented AS ( SELECT *, CASE ... END AS segment FROM scored )
SELECT * FROM segmented;
```
This separated the pipeline into readable stages: **aggregate → score → segment.**

---

## 9. Conditional logic — `CASE`
SQL's if/then/else — produces a value based on conditions, checked top to bottom.
```sql
CASE
    WHEN condition_1 THEN 'Label A'
    WHEN condition_2 THEN 'Label B'
    ELSE 'Label C'
END AS segment
```
**In this project** — mapping R/F scores to named segments:
```sql
CASE
    WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
    WHEN f_score >= 4                  THEN 'Loyal'
    WHEN r_score >= 4 AND f_score <= 3 THEN 'Potential Loyalist'
    WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
    WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
    ELSE 'Others'
END AS segment
```
**Watch out:** `CASE` stops at the *first* matching `WHEN`, so **order matters** — put the most specific/valuable segments first. `CASE` is an *expression* (lives inside `SELECT`), not a standalone statement.

---

## 10. Date & time handling
Recency is date arithmetic against a fixed **snapshot date**.

- **`DATE '2011-12-10'`** — a literal date value.
- **`MAX(invoice_date)`** — the customer's most recent purchase timestamp.
- **`::date`** — strips the time off a timestamp.
- **`date − date` returns an integer** (number of days); `date − timestamp` returns a messy interval.

```sql
DATE '2011-12-10' - MAX(invoice_date)::date AS recency   -- clean integer days
```
**Snapshot date concept:** the data ends 2011-12-09, so Recency is measured against **2011-12-10** (max date + 1 day), never `NOW()` — the data is historical.

---

## 11. De-duplication & subqueries

### `SELECT DISTINCT`
Collapses rows identical across **all selected columns** into one. This is how rule 6 (drop exact duplicates) works — `WHERE` can't, because a duplicate is only identifiable by comparing rows.
```sql
SELECT DISTINCT * FROM staging_retail WHERE ...;
```

### Subqueries (derived tables)
A query nested in another, used like a temporary table. **Needs an alias.**
```sql
SELECT COUNT(*) FROM ( SELECT DISTINCT * FROM staging_retail WHERE ... ) AS deduped;
```
(You can't write `COUNT(DISTINCT *)`, so you nest.)

---

## 12. Table introspection

### `information_schema.columns`
A system view listing every column's metadata — used to *prove* a table's structure.
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'clean_retail'
ORDER BY ordinal_position;
```

---

# Part 2 — The Complete Pipeline

The whole project in order. Each stage lists its goal, SQL, and the number it was validated against.

### Stage 0 — Environment
PostgreSQL (localhost:5432) + DBeaver as client + Power BI (Import mode, via `127.0.0.1`). Notable setup: added the JDBC driver manually in DBeaver; used `127.0.0.1` (not `localhost`) for Power BI to avoid an IPv6 loopback failure.

### Stage 1 — Create the database
```sql
CREATE DATABASE retail_rfm;   -- then Refresh (F5)
```

### Stage 2 — Raw staging table (all TEXT)
```sql
CREATE TABLE staging_retail (
    invoice TEXT, stock_code TEXT, description TEXT, quantity TEXT,
    invoice_date TEXT, price TEXT, customer_id TEXT, country TEXT
);
```
Load CSV via DBeaver import (comma delimiter, header top, quote `"`, map **by position**).
**Validate:** `SELECT COUNT(*) FROM staging_retail;` → **1,067,371**.

### Stage 3 — Clean, typed table (6 rules + casts)
```sql
DROP TABLE IF EXISTS clean_retail;
CREATE TABLE clean_retail AS
SELECT DISTINCT                                      -- rule 6: drop duplicates
    invoice, stock_code, description,
    quantity::integer            AS quantity,
    invoice_date::timestamp      AS invoice_date,
    price::numeric(10,2)         AS price,
    customer_id::numeric::integer AS customer_id,
    country
FROM staging_retail
WHERE invoice ~ '^[0-9]+$'          -- rule 1: numeric invoices
  AND customer_id IS NOT NULL       -- rule 2a
  AND customer_id <> ''             -- rule 2b (empty-string fix)
  AND quantity::integer > 0         -- rule 3
  AND price::numeric   > 0          -- rule 4
  AND stock_code ~ '^[0-9]';        -- rule 5
```
**Validate:** `SELECT COUNT(*) FROM clean_retail;` → **776,577** (72.8% of raw).

### Stage 4 — Customer-level RFM (aggregate → score → segment)
```sql
DROP TABLE IF EXISTS customer_rfm;
CREATE TABLE customer_rfm AS
WITH rfm AS (                                        -- aggregate to one row/customer
    SELECT
        customer_id,
        DATE '2011-12-10' - MAX(invoice_date)::date AS recency,
        COUNT(DISTINCT invoice)                      AS frequency,
        ROUND(SUM(quantity * price), 2)              AS monetary
    FROM clean_retail
    GROUP BY customer_id
),
scored AS (                                          -- 1–5 quintile scores
    SELECT customer_id, recency, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,   -- DESC flip
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM rfm
)
SELECT customer_id, recency, frequency, monetary,    -- map to segment
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
```
**Validate:** `SELECT COUNT(*) FROM customer_rfm;` → **5,852**.

### Stage 5 — Segment analysis (drives the recommendation)
```sql
-- Segment summary
SELECT
    segment,
    COUNT(*)                                            AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_customers,
    ROUND(SUM(monetary), 0)                             AS total_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
    ROUND(AVG(recency), 0)                              AS avg_recency
FROM customer_rfm
GROUP BY segment
ORDER BY total_revenue DESC;

-- The retention "call list": top At-Risk customers by spend
SELECT customer_id, recency AS recency_days, frequency, monetary
FROM customer_rfm
WHERE segment = 'At Risk'
ORDER BY monetary DESC;
```

### Stage 6 — Deployment
Connect Power BI to `customer_rfm` (Import mode) → build KPI cards, segment charts, and the At-Risk call list → add the recommendation callout → publish to web + GitHub.

**Result:** 1.07M raw rows → 776,577 clean rows → 5,852 segmented customers → a live dashboard ending in a budget recommendation, every stage validated against a known number.

---

# Part 3 — DAX Appendix (Power BI)

The dashboard connects to `customer_rfm` (Import mode). Table referenced as
`'public customer_rfm'` (quoted — the name has a space).

```dax
Total Revenue   = SUM('public customer_rfm'[monetary])
Total Customers = COUNTROWS('public customer_rfm')

At Risk Customers =
CALCULATE( COUNTROWS('public customer_rfm'),
           'public customer_rfm'[segment] = "At Risk" )

At Risk Revenue =
CALCULATE( SUM('public customer_rfm'[monetary]),
           'public customer_rfm'[segment] = "At Risk" )

At Risk Avg Recency =
CALCULATE( AVERAGE('public customer_rfm'[recency]),
           'public customer_rfm'[segment] = "At Risk" )
```

| Concept | Note |
|---|---|
| **Measure vs column** | A measure is a named DAX calc computed on the fly under the current filter context; reusable and self-formatting. |
| **`CALCULATE(expr, filter)`** | The most important DAX function — evaluates an expression under a filter you specify (e.g. one segment). |
| **`Table[Column]`** | DAX references columns as `Table[Column]`; names with spaces need `'single quotes'`. |
| **Model hygiene** | Set identifiers/score-codes (`customer_id`, `r_score`…) to **Don't summarize**; format money as **Currency (£)**. |

Expected values (validate against SQL): Total Revenue ≈ **£17M**, Total Customers **5,852**, At Risk Customers **472**, At Risk Revenue ≈ **£565K**, At Risk Avg Recency ≈ **385 days**.

---

# Part 4 — Errors Encountered & Fixes

| Error / issue | Cause | Fix |
|---|---|---|
| `42P04 database already exists` | Ran `CREATE DATABASE` twice (no `IF NOT EXISTS` in Postgres) | Harmless; don't re-run |
| Data loaded into wrong columns | Renamed columns → importer matched by name, created extras | Reload, map **by position** |
| 234,245 rows slipped past filter | Blanks loaded as `''`, not `NULL`; `IS NOT NULL` didn't catch them | Add `AND customer_id <> ''` |
| `42601 syntax error near "CASE"`/`"value"` | An illustration snippet run as SQL (`CASE`/`value::type` aren't standalone) | Run only complete `SELECT`/`WITH` statements |
| `invalid input syntax for integer "13085.0"` | Direct `::integer` on a decimal string | Two-step cast `::numeric::integer` |
| Power BI "unreachable network" | `localhost` resolved to IPv6 `::1` | Use `127.0.0.1` |

**Overarching discipline:** validate every stage against an independently-computed known number — that's how the empty-string leak was caught instantly (1,036,877 vs the expected 802,632).

---

# Part 5 — One-Page Cheat Sheet

```sql
-- DDL
CREATE DATABASE db;                    CREATE TABLE t (col TYPE, ...);
DROP TABLE IF EXISTS t;                CREATE TABLE new AS SELECT ...;

-- Query
SELECT a, b FROM t;   SELECT * FROM t LIMIT 10;   SELECT expr AS alias FROM t;

-- Filter
WHERE col = 'x'  |  col <> ''  |  col > 0  |  col IS [NOT] NULL  |  a AND b
NULLIF(col, '')                        -- '' becomes NULL

-- Regex ( ~ matches )
col ~ '^[0-9]+$'   (entirely digits)   col ~ '^[0-9]'  (starts with digit)

-- Cast
val::type   CAST(val AS type)   val::numeric::integer   -- two-step

-- Aggregate
COUNT(*) | COUNT(col) | COUNT(DISTINCT col)   SUM() MAX() MIN() AVG()
GROUP BY col     HAVING COUNT(*) > 1     ORDER BY col DESC

-- Window (keeps rows)
NTILE(5) OVER (ORDER BY monetary ASC)   -- quintile; recency uses DESC

-- CTE (readable pipeline)
WITH a AS (...), b AS (SELECT ... FROM a) SELECT * FROM b;

-- Conditional
CASE WHEN cond THEN 'x' ELSE 'y' END AS label   -- order matters

-- Dates
DATE '2011-12-10' - MAX(invoice_date)::date      -- integer days

-- De-dup / subquery
SELECT DISTINCT * FROM t;   SELECT COUNT(*) FROM (SELECT ...) AS a;

-- Introspect
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name='t' ORDER BY ordinal_position;
```

---

# Part 6 — Reusable RFM Template

To adapt this pipeline to **any transactional dataset** (telco, SaaS, e-commerce),
change only the marked pieces. The structure — stage → clean → RFM → score →
segment — stays identical.

```sql
-- 1) Aggregate to one row per customer
WITH rfm AS (
    SELECT
        <customer_key>,                                              -- ← your customer id
        DATE '<snapshot_date>' - MAX(<date_col>)::date AS recency,   -- ← snapshot = max date + 1 day
        COUNT(DISTINCT <order_key>)                     AS frequency,-- ← distinct ORDER id (not rows)
        SUM(<amount_expr>)                              AS monetary  -- ← revenue expression
    FROM <clean_table>
    GROUP BY <customer_key>
),
-- 2) Score into quintiles (recency DESC, others ASC)
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency   DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC ) AS f_score,
        NTILE(5) OVER (ORDER BY monetary  ASC ) AS m_score
    FROM rfm
)
-- 3) Map scores to segments (tune thresholds to the business)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN f_score >= 4                  THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 3 THEN 'Potential Loyalist'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Others'
    END AS segment
FROM scored;
```

**Checklist for a new dataset:**
1. **Define the grain** — is one row a line item or an order? Frequency must count distinct *orders*.
2. **Set the snapshot date** — the dataset's max date + 1 day (not "today") if the data is historical.
3. **Confirm the amount expression** — `quantity * price`, or a single `amount` column.
4. **Clean first** — filter cancellations, missing customers (NULL *and* `''`), non-positive amounts, junk codes, duplicates; validate each filter's row count.
5. **Decide Monetary window** — lifetime vs. trailing-N-months (a real business choice).
6. **Tune segment thresholds** — the R×F scheme above is a starting point, not a law.
7. **Document limitations** — unscorable rows (no customer id), lifetime-vs-recent value, quantile ties.

---

# Glossary
| Term | Meaning |
|---|---|
| **DDL / DQL** | Data Definition (structure) / Data Query (reading) language. |
| **Staging table** | Raw landing table (all `TEXT` here) holding source data as-is before cleaning. |
| **Casting** | Converting a value's type (`text → integer`). |
| **NULL vs `''`** | "Unknown" vs a real empty string — different; test NULL with `IS [NOT] NULL`. |
| **Regex** | A text pattern; matched with `~` in Postgres. |
| **Aggregate function** | Collapses many rows into one value (`COUNT`, `SUM`…). |
| **Window function** | Computes across rows while keeping each row (`NTILE … OVER`). |
| **CTE** | A named temporary result (`WITH … AS`) for readable multi-step queries. |
| **Grain** | The level one row represents (line item vs order). |
| **Snapshot date** | Fixed "as-of" reference for Recency (max date + 1 day). |
| **CTAS** | `CREATE TABLE AS SELECT` — materialize a query result into a table. |
| **Filter context (DAX)** | The set of filters under which a measure is evaluated. |

---

*Complete SQL + DAX reference for the Retail RFM project — reusable as a template for similar customer-segmentation work. Stack: PostgreSQL · DBeaver · Power BI.*
