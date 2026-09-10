-- Revenue concentration by customer state (Pareto-style).
-- How much of national revenue comes from how few states?

WITH state_revenue AS (
    SELECT c.customer_state,
           SUM(oi.price) AS total_state_revenue,
           SUM(oi.price) * 100.0 / (SELECT SUM(price) FROM order_items) AS national_share,
           ROW_NUMBER() OVER (ORDER BY SUM(oi.price) DESC) AS state_rank
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_state
)
SELECT *,
       SUM(national_share) OVER (
           ORDER BY total_state_revenue DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total_percentage
FROM state_revenue
ORDER BY state_rank;
