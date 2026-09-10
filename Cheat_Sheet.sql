-- where r.order_id is null

-- limit 10

-- where / group / HAVING count(oi.order_item_id)>50 / order

-- where something is null or is not null

-- SELECT SUM(CASE WHEN s.zip IS NULL THEN 1 ELSE 0 END) AS customer_only

-- SELECT DISTINCT

-- COALESCE(product_category_name_english, 'unknown')

-- condition on the joined table: on o.order_id = orw.order_id 
-- AND 
-- condition on the original table: where orw.review_score >= 4 VS. where orw.review_score >= 4

--  EXTRACT('year' from o.order_purchase_timestamp)  EXTRACT('month' from o.order_purchase_timestamp)

--------------------------------------------------------------------------------------------------------------
-- Window functions:

-- row_number() over (partition by ct.product_category_name_english order by oi.price DESC) as Rank_Price

-- row_number() OVER(ORDER BY item_count DESC) as rn,
-- rank() OVER(ORDER BY item_count DESC) as rnk,
-- dense_rank() OVER(ORDER BY item_count DESC) as dense_rnk

-- order_count - lag(order_count) over (ORDER BY Year_,Month_) as monthly_change

-- LEAD(o.order_purchase_timestamp) OVER (PARTITION BY eligible_customers.customer_unique_id ORDER BY o.order_purchase_timestamp ASC) as Next_order

-- sum(monthly_revenue) OVER(ORDER BY order_year, order_month
							-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as Cumulative_Revenue

-- SUM(oi.price) OVER (ORDER BY o.order_purchase_timestamp::date)

-- avg(monthly_delay_ratio) over(order by year_, month_
							-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as monthly_delay_ratio_MA

--------------------------------------------------------------------------------------------------------------
-- CTEs:

-- with timely_order_count as (
--
--
--) select * from timely_order_count



-- with RECURSIVE month_spine as (select DATE_TRUNC('month', MIN(order_purchase_timestamp)) as month_ from orders
-- UNION ALL
-- select month_ + INTERVAL '1 MONTH' from month_spine
-- WHERE month_ + INTERVAL '1 MONTH' <= (select DATE_TRUNC('month', MAX(order_purchase_timestamp)) from orders))
-- select month_, count(order_id) from month_spine
-- left join orders o on DATE_TRUNC('month', o.order_purchase_timestamp) = month_
-- group by month_
-- order by month_;