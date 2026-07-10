-- Step 2 of the core analysis: delivery lateness per top-15-by-volume category.
--
-- "Days late" = actual delivery date - estimated delivery date (positive = late).
-- Restricted to order_status = 'delivered' (see sql/01_explore_order_status.sql)
-- since only delivered orders have both dates populated.
--
-- Reuses the same category/top-15 logic as sql/05, applied here to orders
-- instead of reviews so the two can be compared side by side in sql/07.

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
delivered_orders AS (
    SELECT
        order_id,
        julianday(order_delivered_customer_date) - julianday(order_estimated_delivery_date) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
)
SELECT
    oc.category,
    COUNT(*) AS num_delivered_orders,
    ROUND(AVG(d.days_late), 2) AS avg_days_late,
    ROUND(100.0 * SUM(CASE WHEN d.days_late > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_delivered_late
FROM order_category oc
JOIN top_categories tc ON oc.category = tc.category
JOIN delivered_orders d ON oc.order_id = d.order_id
GROUP BY oc.category
ORDER BY avg_days_late DESC;
