# Power BI — DAX Measures

The dashboard connects to the `customer_rfm` table (Import mode). Below are the
DAX measures used. The table is referenced as `'public customer_rfm'` — quoted
in single quotes because the name contains a space.

## KPI measures
```dax
Total Revenue = SUM('public customer_rfm'[monetary])

Total Customers = COUNTROWS('public customer_rfm')
```

## At-Risk segment measures (CALCULATE with a segment filter)
```dax
At Risk Customers =
CALCULATE(
    COUNTROWS('public customer_rfm'),
    'public customer_rfm'[segment] = "At Risk"
)

At Risk Revenue =
CALCULATE(
    SUM('public customer_rfm'[monetary]),
    'public customer_rfm'[segment] = "At Risk"
)

At Risk Avg Recency =
CALCULATE(
    AVERAGE('public customer_rfm'[recency]),
    'public customer_rfm'[segment] = "At Risk"
)
```

## Expected values (validate against the SQL)
| Measure              | Value      |
|----------------------|------------|
| Total Revenue        | ~£17.0M    |
| Total Customers      | 5,852      |
| At Risk Customers    | 472        |
| At Risk Revenue      | ~£565K     |
| At Risk Avg Recency  | ~385 days  |

## Model notes
- Set `customer_id`, `r_score`, `f_score`, `m_score`, and `recency` to
  **"Don't summarize"** — they're identifiers / category-scores, not
  quantities to be summed.
- Format `monetary` and the revenue measures as **Currency (£)**.
- `"At Risk"` in the filters must match the SQL `CASE` label exactly
  (capitalisation and spacing).
