-- Names the specific high-volume, below-average sellers in bed_bath_table
-- (the 3.7-4.0 score tier from sql/09) that together carry 51% of category
-- volume. These are the concrete targets for the "seller improvement program"
-- recommendation, rather than a vague "fix the category" statement.

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
SELECT seller_id, num_orders, avg_review_score
FROM seller_stats
WHERE avg_review_score >= 3.7 AND avg_review_score < 4.0
ORDER BY num_orders DESC;
