-- Does slow delivery hurt seller reputation?
-- Combines each seller's late-delivery rate with their average review score.

WITH seller_late AS (
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
),
seller_score AS (
    SELECT si.seller_id,
           AVG(r.order_review_score) AS avg_review_score
    FROM (SELECT DISTINCT seller_id, order_id FROM order_items) si
    LEFT JOIN (
        SELECT order_id, AVG(review_score) AS order_review_score
        FROM order_reviews
        GROUP BY order_id
    ) r ON r.order_id = si.order_id
    GROUP BY si.seller_id
)
SELECT sl.seller_id, sl.seller_state, sl.total_delivered_items, sl.late_percentage, ss.avg_review_score
FROM seller_late sl
JOIN seller_score ss ON sl.seller_id = ss.seller_id
ORDER BY sl.late_percentage DESC;
