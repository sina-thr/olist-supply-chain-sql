-- =========================================================
-- DAY 7: TIMED SELF-TEST
--
-- Read all 5 questions before starting the clock. Then: 40 minutes,
-- no notes beyond your own one-page cheat sheet, no going back to
-- the practice files. If you're stuck past roughly double a
-- question's budget, move on -- come back at the end if time
-- remains. No hints, no self-checks below -- that's the point.
-- Verify your own answers after time is up, not during.
--
-- Suggested budget (soft -- let time roll forward between questions,
-- just don't blow the 40-minute wall clock):
--   Q1  ~6 min   Q2  ~7 min   Q3 ~10 min   Q4  ~8 min   Q5  ~9 min
-- =========================================================


-- Q1
-- For each customer state, how many DISTINCT sellers have customers
-- in that state ever bought from? Return state and seller count,
-- highest first.


select c.customer_state, count(DISTINCT oi.seller_id)  from customers c
join orders o on o.customer_id = c.customer_id
join order_items oi on oi.order_id = o.order_id
group by c.customer_state
ORDER by count(DISTINCT oi.seller_id) DESC;



-- Q2
-- For each English product category, total items sold and total
-- revenue -- but exclude items belonging to canceled orders, and
-- only show categories with more than 1,000 items sold. Highest
-- revenue first.

select COALESCE(ct.product_category_name_english, 'No Translation'), count(oi.order_item_id),
sum(oi.price) as Revenue
from products p
left join category_translation ct on ct.product_category_name = p.product_category_name
join order_items oi on oi.product_id = p.product_id
join orders o on o.order_id = oi.order_id and o.order_status != 'canceled'
group by COALESCE(ct.product_category_name_english, 'No Translation')
having count(oi.order_item_id)>1000
order by sum(oi.price) DESC;



-- Q3
-- For each seller, find their single best-selling product by item
-- count (i.e. just the top product per seller, not the full ranked
-- list). Return seller_id, product_id, and that product's item count.


with final_output as (with sellers_accumulative as (select distinct s.seller_id, oi.product_id, count(oi.order_item_id) as item_count from sellers s
join order_items oi on oi.seller_id = s.seller_id 
group by s.seller_id, oi.product_id)
select *,row_number() OVER(PARTITION BY sellers_accumulative.seller_id ORDER BY item_count DESC) as rn from sellers_accumulative)
select * from final_output
where final_output.rn = 1;




-- Q4
-- Using a CTE, find sellers whose average delivery time (days between
-- order_purchase_timestamp and order_delivered_customer_date, delivered
-- orders only) is WORSE (slower) than the average delivery time across
-- all delivered orders in the whole dataset. Return seller_id and
-- their average delivery time, worst first.


with seller_orders as (
    select distinct oi.seller_id, o.order_id,
           o.order_delivered_customer_date - o.order_purchase_timestamp as delivery_time
    from order_items oi
    join orders o on o.order_id = oi.order_id and o.order_status = 'delivered'
),
worse_sellers as (
    select seller_id, avg(delivery_time) as avg_worse
    from seller_orders
    group by seller_id
)
select * from worse_sellers
where avg_worse > (select avg(delivery_time) from seller_orders)
order by avg_worse desc;



-- Q5
-- For each customer state: total revenue, that state's rank by revenue,
-- its percentage of total national revenue, and the cumulative
-- percentage of national revenue accounted for as you move down the
-- ranking (i.e. a running total of the percentage column, ordered by
-- rank). This is a Pareto-style "how much of our revenue comes from how
-- few states" report.



with final_output as (select c.customer_state, sum(oi.price) total_state_revenue,
sum(oi.price) *100.0/(select sum(oi.price) as total_national from order_items oi) as national_share,
row_number() over(order by sum(oi.price) desc)as state_rank
from customers c
join orders o on o.customer_id = c.customer_id
join order_items oi on oi.order_id = o.order_id
group by c.customer_state)
select *,
sum(final_output.national_share) over(order by total_state_revenue DESC
										rows between unbounded preceding and current row) as running_total_percentage
from final_output
order by state_rank ASC







