-- Quantify how much of bed_bath_table's low average is attributable to a
-- concentrated set of underperforming sellers vs. spread evenly across all
-- sellers in the category. Buckets sellers into score tiers and shows what
-- share of category order volume each tier represents.

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
    WHERE COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'UNKNOWN') = 'bed_bath_table'
),
seller_stats AS (
    SELECT
        bos.seller_id,
        COUNT(*) AS num_orders,
        AVG(r.review_score) AS avg_review_score
    FROM bbt_order_seller bos
    JOIN one_review_per_order r ON bos.order_id = r.order_id AND r.rn = 1
    GROUP BY bos.seller_id
)
SELECT
    CASE
        WHEN avg_review_score < 3.7 THEN '1. Under 3.7 (poor)'
        WHEN avg_review_score < 4.0 THEN '2. 3.7-4.0 (below category avg)'
        WHEN avg_review_score < 4.3 THEN '3. 4.0-4.3 (above category avg)'
        ELSE '4. 4.3+ (strong)'
    END AS score_tier,
    COUNT(*) AS num_sellers,
    SUM(num_orders) AS total_orders,
    ROUND(100.0 * SUM(num_orders) / (SELECT SUM(num_orders) FROM seller_stats), 2) AS pct_of_category_orders
FROM seller_stats
GROUP BY score_tier
ORDER BY score_tier;
