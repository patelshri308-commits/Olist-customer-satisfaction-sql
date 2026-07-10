-- Explore: reviews are recorded per order, but category lives at the
-- product/item level. If orders commonly span multiple categories, a
-- category-level review-score analysis needs a rule for handling that
-- (e.g. restrict to single-category orders, or attribute by dominant item).

SELECT
    categories_in_order,
    COUNT(*) AS num_orders,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(DISTINCT order_id) FROM order_items), 2) AS pct_of_orders
FROM (
    SELECT
        oi.order_id,
        COUNT(DISTINCT COALESCE(NULLIF(p.product_category_name, ''), 'UNKNOWN')) AS categories_in_order
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY oi.order_id
)
GROUP BY categories_in_order
ORDER BY categories_in_order;
