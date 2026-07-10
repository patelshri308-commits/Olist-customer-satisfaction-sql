-- Step 1 of the core analysis: average review score per top-15-by-volume
-- product category.
--
-- Design decisions baked in here (see sql/01-04 exploration):
--   - 547 orders have >1 review row; we keep only the most recent
--     (by review_answer_timestamp) so each order contributes exactly one score.
--   - Category = COALESCE(english translation, raw name, 'UNKNOWN'), with
--     empty-string categories treated as UNKNOWN via NULLIF.
--   - "Top 15 by volume" = top 15 categories by distinct order count
--     (see sql/03_explore_category_volume.sql).
--   - An order can appear in 2 categories in the rare multi-category case
--     (<1% of orders) -- its review counts toward both. Documented, not fixed,
--     since excluding those orders would remove real signal for negligible gain.

WITH one_review_per_order AS (
    SELECT
        order_id,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC
        ) AS rn
    FROM order_reviews
),
order_category AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'UNKNOWN') AS category
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
),
top_categories AS (
    SELECT category
    FROM order_category
    GROUP BY category
    ORDER BY COUNT(DISTINCT order_id) DESC
    LIMIT 15
)
SELECT
    oc.category,
    COUNT(DISTINCT oc.order_id) AS num_orders,
    ROUND(AVG(r.review_score), 3) AS avg_review_score
FROM order_category oc
JOIN top_categories tc ON oc.category = tc.category
JOIN one_review_per_order r ON oc.order_id = r.order_id AND r.rn = 1
GROUP BY oc.category
ORDER BY avg_review_score ASC;
