# Olist Customer Satisfaction: SQL Analysis

**Which product categories underperform on customer satisfaction, and what's actually driving the gap?**

An end-to-end SQL analysis of the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~99K orders, 9 relational tables) — from raw CSVs to a business recommendation.

## The headline finding

The obvious hypothesis "low review scores mean slow shipping" turned out to be only a small part of the story (r = -0.49 between late-delivery rate and review score, explaining ~24% of the category-to-category variance). For the worst-performing category, `bed_bath_table`, the real driver was **volume concentration in mediocre sellers**: 28 sellers scoring 3.7-4.0 (not terrible, just below average) together handle 51% of the category's order volume, while the largest group of sellers by headcount (85 of them) actually score 4.3+ but carry only 12% of volume. That reframes the fix from "launch a category-wide logistics initiative" to "run a targeted improvement program for ~28 named sellers."

Full write-up with methodology, data-quality decisions, and the complete recommendation: **[analysis/write_up.md](analysis/write_up.md)**

## Repo structure

```
sql/                   All SQL, numbered in the order it was run
  00_schema.sql               table definitions
  01-04_explore_*.sql          data quality checks (order status, nulls, category volume, multi-category orders)
  05_avg_review_score_by_category.sql
  06_delivery_lateness_by_category.sql
  07_review_score_vs_delivery_lateness.sql   correlation test
  08-10_*bed_bath_table*.sql    seller-level drill-down on the worst category
analysis/
  write_up.md            full business write-up: question, approach, findings, recommendation, limitations
data/
  raw/                   source CSVs (gitignored -- see setup below)
  olist.db               built SQLite database (gitignored, rebuild with load_db.sh)
load_db.sh              builds data/olist.db from the raw CSVs
```

## Reproduce this locally

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and unzip the CSVs into `data/raw/`.
2. Run `./load_db.sh` (requires `sqlite3`) — builds `data/olist.db` from scratch and prints row counts to confirm the load.
3. Run any query: `sqlite3 -header -column data/olist.db < sql/07_review_score_vs_delivery_lateness.sql`

## Why SQLite

No server to spin up. The whole analysis is reproducible from a single script and the CLI. Every query in `sql/` runs standalone against `data/olist.db`.

## Tools

SQL (SQLite), shell scripting for the data pipeline.
