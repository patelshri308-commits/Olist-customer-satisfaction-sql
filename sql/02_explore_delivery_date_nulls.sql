-- Explore: within delivered orders, are the two dates we need to compute
-- "days late" (actual delivery vs. estimate) actually populated?
-- If either is frequently null, we can't trust a lateness metric built on them.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_actual_delivery,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS missing_estimate,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS missing_purchase_ts
FROM orders
WHERE order_status = 'delivered';
