-- Is bed_bath_table's low review score (3.971, worst of top 15) broad-based
-- across many sellers, or concentrated in a handful of bad-performing ones?
-- This determines whether the recommendation is "systemic category fix"
-- (packaging/logistics for bulky goods) or "seller-specific fix" (audit a
-- short list of underperforming sellers).

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
        ROUND(AVG(r.review_score), 3) AS avg_review_score
    FROM bbt_order_seller bos
    JOIN one_review_per_order r ON bos.order_id = r.order_id AND r.rn = 1
    GROUP BY bos.seller_id
)
SELECT
    seller_id,
    num_orders,
    avg_review_score,
    ROUND(100.0 * num_orders / (SELECT SUM(num_orders) FROM seller_stats), 2) AS pct_of_category_orders
FROM seller_stats
ORDER BY num_orders DESC
LIMIT 20;
