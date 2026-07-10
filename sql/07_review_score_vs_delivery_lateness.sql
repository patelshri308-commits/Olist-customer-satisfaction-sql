-- Combines sql/05 (review score) and sql/06 (delivery lateness) per category,
-- then computes the Pearson correlation between pct_delivered_late and
-- avg_review_score across the 15 categories to test the hypothesis
-- "categories with worse review scores are the ones with later deliveries."
--
-- SQLite has no built-in CORR(); computed manually from the standard formula:
--   r = covariance(x,y) / (stddev(x) * stddev(y))

WITH order_category AS (
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
),
one_review_per_order AS (
    SELECT order_id, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
    FROM order_reviews
),
delivered_orders AS (
    SELECT order_id,
           julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
),
review_by_category AS (
    SELECT oc.category, AVG(r.review_score) AS avg_review_score, COUNT(*) AS num_orders
    FROM order_category oc
    JOIN top_categories tc ON oc.category = tc.category
    JOIN one_review_per_order r ON oc.order_id = r.order_id AND r.rn = 1
    GROUP BY oc.category
),
lateness_by_category AS (
    SELECT oc.category, AVG(d.days_late) AS avg_days_late,
           100.0 * SUM(CASE WHEN d.days_late > 0 THEN 1 ELSE 0 END) / COUNT(*) AS pct_delivered_late
    FROM order_category oc
    JOIN top_categories tc ON oc.category = tc.category
    JOIN delivered_orders d ON oc.order_id = d.order_id
    GROUP BY oc.category
)
SELECT
    r.category,
    r.num_orders,
    ROUND(r.avg_review_score, 3) AS avg_review_score,
    ROUND(l.avg_days_late, 2) AS avg_days_late,
    ROUND(l.pct_delivered_late, 2) AS pct_delivered_late
FROM review_by_category r
JOIN lateness_by_category l ON r.category = l.category
ORDER BY r.avg_review_score ASC;

-- Second statement: correlation coefficient across the same 15 category rows.
WITH order_category AS (
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
),
one_review_per_order AS (
    SELECT order_id, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
    FROM order_reviews
),
delivered_orders AS (
    SELECT order_id,
           julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
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
),
combined AS (
    SELECT r.avg_review_score AS x, l.pct_delivered_late AS y
    FROM review_by_category r
    JOIN lateness_by_category l ON r.category = l.category
),
stats AS (
    SELECT AVG(x) AS mean_x, AVG(y) AS mean_y FROM combined
)
SELECT
    ROUND(
        SUM((c.x - s.mean_x) * (c.y - s.mean_y)) /
        (SQRT(SUM((c.x - s.mean_x) * (c.x - s.mean_x))) * SQRT(SUM((c.y - s.mean_y) * (c.y - s.mean_y))))
    , 3) AS pearson_r_review_score_vs_pct_late
FROM combined c, stats s;
