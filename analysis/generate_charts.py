"""
Generates the three charts referenced in the README and write-up, straight
from data/olist.db. Re-run any time after rebuilding the database to keep
the charts in sync with the SQL (mirrors the logic in sql/05-07 and sql/09).

Usage: python3 analysis/generate_charts.py
"""
import sqlite3
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "olist.db"
OUT_DIR = ROOT / "analysis" / "charts"
OUT_DIR.mkdir(exist_ok=True)

WORST_CATEGORY = "bed_bath_table"
BEST_CATEGORY = "perfumery"

CATEGORY_CTE = """
    order_category AS (
        SELECT DISTINCT
            oi.order_id,
            COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'UNKNOWN') AS category
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    ),
    top_categories AS (
        SELECT category FROM order_category
        GROUP BY category ORDER BY COUNT(DISTINCT order_id) DESC LIMIT 15
    )
"""


def get_conn():
    if not DB_PATH.exists():
        raise SystemExit(f"{DB_PATH} not found -- run ./load_db.sh first.")
    return sqlite3.connect(DB_PATH)


def chart_review_score_by_category(conn):
    query = f"""
    WITH {CATEGORY_CTE},
    one_review_per_order AS (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
        FROM order_reviews
    )
    SELECT oc.category, AVG(r.review_score) AS avg_review_score
    FROM order_category oc
    JOIN top_categories tc ON oc.category = tc.category
    JOIN one_review_per_order r ON oc.order_id = r.order_id AND r.rn = 1
    GROUP BY oc.category
    ORDER BY avg_review_score ASC;
    """
    df = pd.read_sql_query(query, conn)

    colors = [
        "#c0392b" if cat == WORST_CATEGORY else "#27ae60" if cat == BEST_CATEGORY else "#7f8c8d"
        for cat in df["category"]
    ]

    fig, ax = plt.subplots(figsize=(8, 6))
    ax.barh(df["category"], df["avg_review_score"], color=colors)
    ax.set_xlim(3.5, 4.4)
    ax.set_xlabel("Average review score (1-5)")
    ax.set_title("Average Review Score by Category (Top 15 by Volume)")
    ax.invert_yaxis()
    for i, v in enumerate(df["avg_review_score"]):
        ax.text(v + 0.01, i, f"{v:.2f}", va="center", fontsize=8)
    fig.tight_layout()
    fig.savefig(OUT_DIR / "01_avg_review_score_by_category.png", dpi=150)
    plt.close(fig)


def chart_review_vs_lateness(conn):
    query = f"""
    WITH {CATEGORY_CTE},
    one_review_per_order AS (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
        FROM order_reviews
    ),
    delivered_orders AS (
        SELECT order_id,
               julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS days_late
        FROM orders WHERE order_status = 'delivered'
    ),
    review_by_category AS (
        SELECT oc.category, AVG(r.review_score) AS avg_review_score
        FROM order_category oc
        JOIN top_categories tc ON oc.category = tc.category
        JOIN one_review_per_order r ON oc.order_id = r.order_id AND r.rn = 1
        GROUP BY oc.category
    ),
    lateness_by_category AS (
        SELECT oc.category,
               100.0 * SUM(CASE WHEN d.days_late > 0 THEN 1 ELSE 0 END) / COUNT(*) AS pct_delivered_late
        FROM order_category oc
        JOIN top_categories tc ON oc.category = tc.category
        JOIN delivered_orders d ON oc.order_id = d.order_id
        GROUP BY oc.category
    )
    SELECT r.category, r.avg_review_score, l.pct_delivered_late
    FROM review_by_category r JOIN lateness_by_category l ON r.category = l.category;
    """
    df = pd.read_sql_query(query, conn)
    r = df["avg_review_score"].corr(df["pct_delivered_late"])

    fig, ax = plt.subplots(figsize=(7, 6))
    ax.scatter(df["pct_delivered_late"], df["avg_review_score"], color="#2980b9", s=60, zorder=3)
    for _, row in df.iterrows():
        ax.annotate(row["category"], (row["pct_delivered_late"], row["avg_review_score"]),
                    fontsize=7, xytext=(4, 4), textcoords="offset points")

    import numpy as np
    m, b = np.polyfit(df["pct_delivered_late"], df["avg_review_score"], 1)
    xs = pd.Series([df["pct_delivered_late"].min(), df["pct_delivered_late"].max()])
    ax.plot(xs, m * xs + b, color="#c0392b", linestyle="--", linewidth=1.5, zorder=2)

    ax.set_xlabel("% of orders delivered late")
    ax.set_ylabel("Average review score")
    ax.set_title(f"Review Score vs. Late-Delivery Rate by Category (r = {r:.2f})")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "02_review_score_vs_late_delivery.png", dpi=150)
    plt.close(fig)


def chart_seller_tiers(conn):
    query = f"""
    WITH one_review_per_order AS (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
        FROM order_reviews
    ),
    bbt_order_seller AS (
        SELECT DISTINCT oi.order_id, oi.seller_id
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
        WHERE COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'UNKNOWN') = '{WORST_CATEGORY}'
    ),
    seller_stats AS (
        SELECT bos.seller_id, COUNT(*) AS num_orders, AVG(r.review_score) AS avg_review_score
        FROM bbt_order_seller bos
        JOIN one_review_per_order r ON bos.order_id = r.order_id AND r.rn = 1
        GROUP BY bos.seller_id
    )
    SELECT
        CASE
            WHEN avg_review_score < 3.7 THEN '1. Under 3.7\n(poor)'
            WHEN avg_review_score < 4.0 THEN '2. 3.7-4.0\n(below avg)'
            WHEN avg_review_score < 4.3 THEN '3. 4.0-4.3\n(above avg)'
            ELSE '4. 4.3+\n(strong)'
        END AS score_tier,
        COUNT(*) AS num_sellers,
        SUM(num_orders) AS total_orders
    FROM seller_stats
    GROUP BY score_tier ORDER BY score_tier;
    """
    df = pd.read_sql_query(query, conn)
    df["pct_of_volume"] = 100.0 * df["total_orders"] / df["total_orders"].sum()

    fig, axes = plt.subplots(1, 2, figsize=(11, 5))

    colors = ["#c0392b", "#e67e22", "#2980b9", "#27ae60"]

    axes[0].bar(df["score_tier"], df["num_sellers"], color=colors)
    axes[0].set_title("Sellers by Score Tier (count)")
    axes[0].set_ylabel("# of sellers")

    axes[1].bar(df["score_tier"], df["pct_of_volume"], color=colors)
    axes[1].set_title("Order Volume by Score Tier (%)")
    axes[1].set_ylabel("% of category order volume")

    for ax in axes:
        for i, v in enumerate(ax.containers[0].datavalues):
            ax.text(i, v, f"{v:.0f}", ha="center", va="bottom", fontsize=9)

    fig.suptitle(f"{WORST_CATEGORY}: Sellers Are Mostly Strong, but Volume Sits with the Mediocre Tier")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "03_bed_bath_table_seller_tiers.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    conn = get_conn()
    plt.style.use("seaborn-v0_8-whitegrid")
    chart_review_score_by_category(conn)
    chart_review_vs_lateness(conn)
    chart_seller_tiers(conn)
    conn.close()
    print(f"Charts written to {OUT_DIR}")
