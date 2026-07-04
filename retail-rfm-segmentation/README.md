# Retail Customer Analytics — RFM Segmentation

Using **SQL** to clean 1.07M retail transactions, apply rules-based **RFM**
(Recency, Frequency, Monetary) segmentation, and build a **Power BI** dashboard
that recommends **where to spend a fixed customer-retention budget**.

**Stack:** PostgreSQL · DBeaver · Power BI
**Dataset:** UCI Online Retail II — a UK online gift retailer, Dec 2009 – Dec 2011

> 📊 **Live dashboard:** (https://app.powerbi.com/view?r=eyJrIjoiMTg4NTM4YzEtY2QxNC00ODM3LWJkMjItOWE1MTE5ZTAyMjU5IiwidCI6ImIyZDUwYTg3LTU1ZTYtNDA0ZS04YjJlLTQ1ZDg5NTMwZTNmOSJ9) 
> 🖼️ Screenshots in [`dashboard/screenshots/`](dashboard/screenshots)

---

## The problem
A retailer has a *fixed* retention budget and needs to know which customers to
spend it on — before they churn. Spending evenly is wasteful: some customers
stay regardless, some are already gone. The budget should target the
**valuable-but-slipping** group.

## Approach (CRISP-DM)
1. **Data understanding** — profiled the raw CSV in Python before writing any SQL.
2. **Data preparation (SQL)** — three tables, each validated against a known
   row count:
   | Table | What it is | Rows |
   |---|---|---|
   | `staging_retail` | raw CSV loaded as-is, all `TEXT` | 1,067,371 |
   | `clean_retail` | 6 cleaning rules + type casts | 776,577 |
   | `customer_rfm` | one row per customer, R/F/M scores + segment | 5,852 |
3. **Modeling** — RFM scoring with `NTILE(5)` window functions; segments
   assigned via `CASE` on the R and F scores.
4. **Deployment** — live PostgreSQL → Power BI dashboard ending in a
   recommendation.

The full, commented pipeline is in [`sql/`](sql) — run `01`→`05` in order.

## Key findings

| Segment | Customers | Revenue | % Revenue | Avg Recency |
|---|---|---|---|---|
| Champions | ~1,470 | £11.8M | 69% | 20 days |
| Loyal | ~870 | £2.7M | 16% | 200 days |
| Potential Loyalist | ~870 | £0.83M | 5% | 27 days |
| Hibernating | ~1,515 | £0.62M | 3.6% | 458 days |
| **At Risk** | **~472** | **£0.57M** | **3.3%** | **385 days** |
| Others | ~655 | £0.54M | 3.1% | 109 days |

**Insight:** revenue and headcount concentrate *differently*. Champions are
~25% of customers but ~69% of revenue. **At Risk** is the smallest segment by
count, yet holds revenue comparable to the 3× larger Hibernating group.

## Recommendation
**Focus the retention budget on the At-Risk segment** — ~472 previously
high-value customers (~£565K in lifetime value) now averaging **385 days** since
their last purchase. They have a proven buying habit that has lapsed, so they
are winnable. Champions are already loyal and need no spend; Hibernating
customers warrant only low-cost reactivation. Prioritise outreach by spend —
the call-list query is in [`sql/05_segment_analysis.sql`](sql/05_segment_analysis.sql).

## Repository structure
```
├── sql/                 # the PostgreSQL pipeline — run 01 -> 05
├── dashboard/           # Power BI DAX measures + screenshots
├── docs/                # SQL reference module, project deck (optional)
└── data/                # dataset source & download instructions
```

## How to reproduce
1. Install PostgreSQL and download the dataset (see [`data/README.md`](data/README.md)).
2. Run `sql/01_create_database.sql`, then reconnect your client to `retail_rfm`.
3. Run `sql/02_staging_load.sql` → load the CSV into `staging_retail` →
   run `sql/03`, `sql/04`, `sql/05`.
4. Connect Power BI to the `customer_rfm` table (Import mode) and recreate the
   measures in [`dashboard/dax_measures.md`](dashboard/dax_measures.md).

## Limitations
- ~15.4% of revenue sits on rows with **no Customer ID** — unscorable by RFM.
- Monetary is *lifetime* spend, not recent — At-Risk customers look valuable
  precisely because their recent spend has dropped.
- Segment thresholds are a deliberate design choice, not the only valid scheme.
- `NTILE` boundary ties can shift per-segment counts by ±1–2 between runs.
