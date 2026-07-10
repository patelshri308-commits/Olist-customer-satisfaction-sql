-- Explore: order volume per product category (English names), to decide
-- where the "top N categories" cutoff should land for the main analysis.
--
-- Data quality note: 610 products (~1.9%) have product_category_name = ''
-- (empty string, not NULL -- a CSV blank-field artifact). NULLIF converts
-- these to true NULL so COALESCE catches them under 'UNKNOWN' instead of
-- silently forming their own blank-named group.

SELECT
    COALESCE(t.product_category_name_english, NULLIF(p.product_category_name, ''), 'UNKNOWN') AS category,
    COUNT(DISTINCT oi.order_id) AS distinct_orders,
    COUNT(*) AS line_items
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY distinct_orders DESC
LIMIT 20;
