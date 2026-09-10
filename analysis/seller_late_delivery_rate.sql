-- Seller late-delivery rate
-- For sellers with at least 50 delivered items, what share of their
-- orders arrived after the estimated delivery date?

SELECT s.seller_id,
       s.seller_state,
       COUNT(oi.order_item_id) AS total_delivered_items,
       SUM(CASE WHEN o.order_estimated_delivery_date < o.order_delivered_customer_date
                THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS late_percentage
FROM sellers s
JOIN order_items oi ON oi.seller_id = s.seller_id
JOIN orders o ON o.order_id = oi.order_id
    AND o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_id, s.seller_state
HAVING COUNT(oi.order_item_id) > 50
ORDER BY late_percentage DESC;
