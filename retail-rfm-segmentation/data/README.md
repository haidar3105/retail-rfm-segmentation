# Data

This project uses the **UCI Online Retail II** dataset — transactions from a
UK-based online gift retailer, ~1.07M line items, Dec 2009 – Dec 2011.

The raw CSV (~90 MB) is **not committed** to this repository (too large for
Git, and raw data shouldn't live in version control). Download it yourself:

## Where to get it
- **Kaggle — single CSV, easiest:**
  https://www.kaggle.com/datasets/mashlyn/online-retail-ii-uci
  → gives `online_retail_II.csv` (both years already combined into one file).
- **UCI ML Repository — authoritative source, cite this:**
  https://archive.ics.uci.edu/dataset/502/online+retail+ii
  → an Excel workbook with two sheets (one per year) that you'd need to stack.

## How it's used
1. Download `online_retail_II.csv` and place it in this `data/` folder
   (or anywhere convenient).
2. Load it into the `staging_retail` table — see `../sql/02_staging_load.sql`.
   Import settings: comma delimiter, header row, quote char `"`, UTF-8,
   and map the CSV columns to the table columns **by position**.

## Columns (Online Retail II schema)
| Column       | Notes                                                      |
|--------------|------------------------------------------------------------|
| Invoice      | order number; a `C` prefix marks a cancellation            |
| StockCode    | product code (e.g. 85048, 79323P); `POST`/`DOT`/`M` are non-products |
| Description  | product name                                               |
| Quantity     | units on the line (can be negative on returns)             |
| InvoiceDate  | timestamp                                                  |
| Price        | unit price in GBP (note the column is "Price", not "UnitPrice") |
| Customer ID  | stored as a float string, e.g. "13085.0"; frequently blank |
| Country      | mostly United Kingdom                                       |

## Known data-quality notes (handled in the SQL pipeline)
- ~22.8% of rows have no Customer ID (blanks load as empty strings `''`).
- `C`/`A` invoices are cancellations/adjustments; non-product stock codes,
  zero/negative prices, and exact-duplicate rows are all filtered in
  `../sql/03_clean_retail.sql`.
