-- Monthly late-delivery rate, with a trailing 3-month moving average.
-- Shows whether the November 2017 delivery spike was a one-month blip
-- or the start of a sustained trend.

WITH monthly_late_rate AS (
    SELECT EXTRACT(YEAR FROM o.order_purchase_timestamp)  AS year_,
           EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month_,
           COUNT(*) AS total_orders,
           SUM(CASE WHEN o.order_estimated_delivery_date < o.order_delivered_customer_date
                    THEN 1 ELSE 0 END) AS total_late,
           SUM(CASE WHEN o.order_estimated_delivery_date < o.order_delivered_customer_date
                    THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS late_percentage
    FROM orders o
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_status = 'delivered'
    GROUP BY year_, month_
)
SELECT *,
       AVG(late_percentage) OVER (
           ORDER BY year_, month_
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS late_percentage_3mo_avg
FROM monthly_late_rate
ORDER BY year_, month_;

-- Finding: the November 2017 spike wasn't a one-month blip -- the
-- 3-month moving average stayed elevated through roughly May 2018,
-- pointing to a sustained fulfillment recovery rather than a single
-- bad month.
