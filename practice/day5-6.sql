-- =========================================================
-- DAY 5-6: WINDOW FUNCTIONS on the Olist dataset
--
-- Same format as before. Write it yourself, check the self-check line.
-- This is the block to slow down on -- expect it to feel unfamiliar
-- even though everything before this hasn't.
--
-- Day 5 = Exercises 1-4 (ranking and offset functions -- mechanics)
-- Day 6 = Exercises 5-7 (running totals, the frame trap, portfolio piece)
-- =========================================================


-- EX 1 (ROW_NUMBER: top N per group)
-- Within each English product category, find the 3 highest-priced items
-- ever sold. Return category, product_id, price, and its rank.
--
-- Hint: ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC)
--   in a subquery or CTE, then filter WHERE rn <= 3 in the outer query.
--   You cannot filter on a window function's output directly in WHERE
--   in the same SELECT it's defined in -- same rule as HAVING and
--   aggregates from Day 4, and the reason CTEs/subqueries exist for
--   this pattern.
-- Self-check: every category should return at most 3 rows. If some
--   return more, you've partitioned by the wrong thing or the filter
--   isn't in the outer query.




with ranked_prices as (

select ct.product_category_name_english as English_ct,
		oi.product_id,
		oi.price,
		row_number() over (partition by ct.product_category_name_english order by oi.price DESC) as Rank_Price
from order_items oi
join products p on p.product_id = oi.product_id
left join category_translation ct on ct.product_category_name = p.product_category_name
)
select * FROM ranked_prices
where Rank_Price<= 3;



-- EX 2 (RANK vs DENSE_RANK vs ROW_NUMBER: what ties actually do)
-- Rank sellers nationally by total items sold (not revenue -- item
-- count, which will produce real ties). Show all three ranking
-- functions side by side in the same query.
--
-- Hint: ROW_NUMBER() OVER (ORDER BY item_count DESC), RANK() OVER (...),
--   DENSE_RANK() OVER (...) -- same ORDER BY, same output columns.
-- Self-check: find a spot where two sellers tie on item_count. RANK and
--   DENSE_RANK should both show the same rank number for the tied pair,
--   but the NEXT seller after them should differ: RANK skips a number
--   (e.g. 4, 4, 6), DENSE_RANK doesn't (4, 4, 5). ROW_NUMBER never ties
--   at all -- it hands out a unique number even when the underlying
--   values are identical, which means it's making an arbitrary choice
--   about who "wins" the tie. Worth knowing which behavior you actually
--   want before you pick one in an interview.


with seller_items as(select oi.seller_id, count(*) item_count from order_items oi
group by oi.seller_id)
select  seller_id, item_count,
row_number() OVER(ORDER BY item_count DESC) as rn,
rank() OVER(ORDER BY item_count DESC) as rnk,
dense_rank() OVER(ORDER BY item_count DESC) as dense_rnk
FROM seller_items
order by item_count DESC;



-- EX 3 (LAG: period-over-period change)
-- Using the monthly order counts from Day 4 Ex 1, compute month-over-
-- month change in order count and percent growth.
--
-- Hint: build the monthly counts in a CTE first, then
--   LAG(order_count) OVER (ORDER BY year, month) in the outer query to
--   get the prior month's value alongside the current one.
-- Self-check: the very first month in your data should show NULL for
--   both change and growth -- there's no prior month for it to compare
--   against. If you see 0 instead of NULL, you've defaulted a missing
--   value to zero somewhere (a COALESCE you didn't mean, or an
--   accidental join), and that's a real bug: 0% growth and "no data to
--   compare" are not the same claim.



with monthly_orders as(select EXTRACT('year' from o.order_purchase_timestamp) as Year_,
EXTRACT('month' from o.order_purchase_timestamp) as Month_,
count(o.order_id) as order_count
from orders o
group by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp)
order by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp) ASC)
select Year_,Month_,order_count as current_month,
order_count - lag(order_count) over (ORDER BY Year_,Month_) as monthly_change,
(order_count - lag(order_count) over (ORDER BY Year_,Month_))*100.0/(lag(order_count) over (ORDER BY Year_,Month_)) as percent_growth
from monthly_orders;



-- EX 4 (LEAD: time until the next event)
-- For customers who ordered more than once, find the number of days
-- between each order and that same customer's next order.
--
-- Hint: use customer_unique_id, not customer_id -- Olist issues a new
--   customer_id per order, so customer_id can never repeat and
--   PARTITION BY customer_id would make every window exactly one row
--   wide. LEAD(order_purchase_timestamp) OVER (PARTITION BY
--   customer_unique_id ORDER BY order_purchase_timestamp), then
--   subtract to get days.
-- Self-check: most rows will come back NULL for days_to_next_order --
--   that's not a bug, it's the data. Olist's repeat-purchase rate is
--   genuinely low; most customers only ever place one order. Run
--   COUNT(*) FILTER (WHERE days_to_next_order IS NOT NULL) against
--   total row count and you'll see roughly what fraction of orders are
--   repeat purchases. That number is itself a real business metric.


with eligible_customers as (select c.customer_unique_id as customer_unique_id, count(*) as order_count
from  customers c
join orders o on o.customer_id = c.customer_id
group by c.customer_unique_id
HAVING count(*)> 1)
select 
eligible_customers.customer_unique_id, o.order_purchase_timestamp as Current_order,
LEAD(o.order_purchase_timestamp) OVER (PARTITION BY eligible_customers.customer_unique_id ORDER BY o.order_purchase_timestamp ASC) as Next_order,
EXTRACT(days from (LEAD(o.order_purchase_timestamp) OVER (PARTITION BY eligible_customers.customer_unique_id ORDER BY o.order_purchase_timestamp ASC) - o.order_purchase_timestamp)) as Days_Until_Next_Orders
from eligible_customers
join customers c on c.customer_unique_id = eligible_customers.customer_unique_id
join orders o on o.customer_id = c.customer_id;



-- ---------------------------------------------------------
-- DAY 6: RUNNING TOTALS, THE FRAME TRAP, AND PUTTING IT TOGETHER
-- ---------------------------------------------------------
 
-- EX 5 (SUM OVER: running total)
-- Cumulative revenue by month across the full dataset. Return year-
-- month, that month's revenue, and the running total through that
-- month.
--
-- Hint: aggregate to monthly revenue in a CTE first, then
--   SUM(monthly_revenue) OVER (ORDER BY year, month
--   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW).
-- Self-check: the running total on the LAST row should exactly equal
--   SUM(price) FROM order_items with no grouping at all. This is the
--   same control-total habit from the join exercises -- window
--   functions need it just as much as GROUP BY does.


with yearly_monthly_orders as (select extract('year' from o.order_purchase_timestamp) as order_year, extract('month' from o.order_purchase_timestamp) as order_month, sum(oi.price) as monthly_revenue
from order_items oi
join orders o on o.order_id = oi.order_id
GROUP BY extract('year' from o.order_purchase_timestamp), extract('month' from o.order_purchase_timestamp))
select order_year, order_month, monthly_revenue,
sum(monthly_revenue) OVER(ORDER BY order_year, order_month
							ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as Cumulative_Revenue
from yearly_monthly_orders;



SELECT SUM(price) FROM order_items;



-- EX 6 (TRAP: the default frame, and what ties do to it)
-- Running total of daily item revenue, ordered by purchase date,
-- computed WITHOUT pre-aggregating to one row per day first -- i.e.
-- straight off order_items joined to orders, one row per item.
--
-- Step A (the trap): 
--   SUM(oi.price) OVER (ORDER BY o.order_purchase_timestamp::date)
--   with no explicit frame. Pick a date that had multiple items sold
--   and look at the running-total value on each of those rows.
--
-- Step B (fixed): rerun with an explicit frame and a tiebreaker:
--   SUM(oi.price) OVER (
--       ORDER BY o.order_purchase_timestamp::date, oi.order_item_id
--       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   )
--
-- Self-check: in Step A, EVERY row sharing the same date shows the
--   identical running-total value -- the total AFTER all of that day's
--   items, not a partial sum building up row by row within the day.
--   Reason: when ORDER BY is present but no frame is specified,
--   Postgres defaults to RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT
--   ROW, and under RANGE, rows with equal ORDER BY values ("peers") all
--   see the same window -- the one extending through the LAST peer, not
--   their own position. ROWS, by contrast, is strictly positional: row
--   3 only ever sees rows 1-3, tie or no tie. Step B's tiebreaker
--   (order_item_id) also matters on its own -- without it, ties still
--   exist even under ROWS, just resolved by whatever order Postgres
--   happens to read them in, which isn't guaranteed to be stable.
--
-- This is the Day 3 fan-out trap's cousin: nothing errors, the numbers
-- look completely plausible, and it's wrong specifically on days with
-- more than one order -- which in this dataset is most days.


-- Version A
select o.order_purchase_timestamp, oi.price,
sum(oi.price) over(order by o.order_purchase_timestamp)
from order_items oi
join orders o on o.order_id = oi.order_id
order by o.order_purchase_timestamp;

SELECT o.order_purchase_timestamp::date AS order_date, oi.price,
       SUM(oi.price) OVER (ORDER BY o.order_purchase_timestamp::date) AS running_total
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
ORDER BY order_date;




-- Version B
select o.order_purchase_timestamp, oi.price,
sum(oi.price) over(order by o.order_purchase_timestamp
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
from order_items oi
join orders o on o.order_id = oi.order_id
order by o.order_purchase_timestamp;

SELECT o.order_purchase_timestamp::date AS order_date, oi.price,
       SUM(oi.price) OVER (
           ORDER BY o.order_purchase_timestamp::date, oi.order_item_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
ORDER BY order_date, oi.order_item_id;




-- EX 7 (PUTTING IT TOGETHER -- portfolio material)
-- Smooth the late-delivery-rate series from Day 4 Ex 6 with a trailing
-- 3-month moving average, so you can see whether the November spike was
-- a one-month blip or the start of a sustained trend.
--
-- Hint: put Day 4 Ex 6 in a CTE (year, month, late_percentage), then
--   AVG(late_percentage) OVER (ORDER BY year, month
--   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW).
-- Self-check: the first two months of the series will average over
--   only 1 and 2 rows respectively, not 3 -- ROWS BETWEEN 2 PRECEDING
--   just clips to whatever's actually available at the start of the
--   window rather than padding with NULLs or erroring. That's different
--   from LAG, which returns a hard NULL when there's nothing N rows
--   back. Same idea, two different behaviors -- worth being able to
--   state that distinction out loud in an interview.
-- Also worth doing: plot both series (raw monthly rate and the 3-month
--   average) mentally against each other. If the moving average stays
--   elevated for a couple of months after November rather than snapping
--   straight back down, that's evidence of a sustained operational
--   problem, not a one-off spike -- a materially different conclusion
--   for a report to draw, and the whole reason a moving average exists.


with CTE as(select EXTRACT('year' from o.order_purchase_timestamp) as year_, EXTRACT('month' from o.order_purchase_timestamp) as month_, count(*) as total_orders,
sum(case when o.order_estimated_delivery_date < o.order_delivered_customer_date then 1 else 0 end) as total_delayed,
sum(case when o.order_estimated_delivery_date < o.order_delivered_customer_date then 1 else 0 end)*100.0/count(*) as monthly_delay_ratio from orders o
where o.order_delivered_customer_date is not null and o.order_status = 'delivered'
group by year_, month_
order by year_, month_)
select *,
avg(monthly_delay_ratio) over(order by year_, month_
							ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as monthly_delay_ratio_MA
from CTE;

-- It seems that the November spike was started exactly on November, but it started a trend which continued until May of next year!
