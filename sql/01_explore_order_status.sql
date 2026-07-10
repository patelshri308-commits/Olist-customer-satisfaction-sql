-- Explore: how many orders are in each status, and do non-"delivered" orders
-- account for a meaningful share of the data? This determines whether we need
-- to filter the dataset before computing delivery lateness.

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;
