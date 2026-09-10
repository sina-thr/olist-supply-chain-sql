-- =========================================================
-- DAY 4: AGGREGATION on the Olist dataset
--
-- Same format as Day 2-3: write it yourself, then check against
-- the self-check line. This day is shorter -- GROUP BY and CASE
-- are mechanics you already know from the job. The point here is
-- WHERE-vs-HAVING precision and getting fast at conditional
-- aggregation, since that's the building block for every
-- "breakdown by segment" report you'll ever be asked for.
-- =========================================================


-- EX 1 (WARM-UP: basic GROUP BY on a date)
-- How many orders were placed per month? Return year-month and count,
-- oldest first.
--
-- Hint: DATE_TRUNC('month', order_purchase_timestamp) collapses a
--   timestamp down to the first of its month -- group and order by that
--   expression directly.
-- Self-check: you should see a clear ramp-up over 2017 and a cliff at
--   the very end of the range where the dataset simply stops -- not a
--   real drop in orders, just where the extract ends. Worth noticing
--   now, because it'll look like a demand crash if you don't catch it
--   later.

select EXTRACT('year' from o.order_purchase_timestamp) as Year_,
EXTRACT('month' from o.order_purchase_timestamp) as Month_,
count(o.order_id)
from orders o
group by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp)
order by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp) ASC;



-- EX 2 (WHERE vs HAVING, used correctly together)
-- Among DELIVERED orders only, which product categories have an average
-- item price above $100? Return the English category name, item count,
-- and average price, highest average first.
--
-- Hint: this needs both clauses, doing different jobs. WHERE removes
--   non-delivered orders before any grouping happens -- a row-level
--   filter. HAVING then removes whole groups after AVG(price) is
--   computed -- a group-level filter. Try writing it with the
--   condition in the wrong clause first: put order_status = 'delivered'
--   in HAVING, or AVG(price) > 100 in WHERE, and read the error message
--   Postgres gives you.
-- Self-check: the WHERE-in-HAVING version should fail outright --
--   'order_status' isn't in the GROUP BY and isn't wrapped in an
--   aggregate, so Postgres won't allow it there. That error is useful:
--   it's the engine confirming HAVING only sees grouped/aggregated
--   output, never raw rows.


select COALESCE(ct.product_category_name_english, 'No Translation') as English_category_name, count(oi.order_item_id), avg(oi.price) from products p
left join category_translation ct
on p.product_category_name = ct.product_category_name
inner join order_items oi
on oi.product_id = p.product_id
inner join orders o
on o.order_id = oi.order_id and o.order_status = 'delivered'
group by English_category_name
having avg(oi.price)> 100
order by avg(oi.price) DESC;


-- EX 3 (CONDITIONAL AGGREGATION: CASE inside SUM)
-- For each customer state, how many orders were paid by each payment
-- type -- credit_card, boleto, voucher, debit_card -- as separate
-- columns in one row per state?
--
-- Hint: SUM(CASE WHEN payment_type = 'credit_card' THEN 1 ELSE 0 END)
--   AS credit_card, repeated once per payment type. This is the
--   "pivot without PIVOT" pattern -- Postgres has no native PIVOT
--   keyword, so conditional aggregation is how you turn row values into
--   columns.
-- Self-check: order_payments is one-to-many off orders (an order can
--   be split across payment types), so you're joining another
--   one-to-many child table again. Decide, deliberately, whether you're
--   counting orders or counting payment-rows here -- they're not the
--   same number, and it's the Ex 8 grain question showing up again.
--   State which one you picked in a comment.

SELECT payment_type, COUNT(*) FROM order_payments GROUP BY 1 ORDER BY 2 DESC;


select c.customer_state,
	count(*) as total_payments,
	-- sum(case when op.payment_type = 'non_defined' then 1 else 0 end) as non_defined,
	sum(case when op.payment_type = 'boleto' then 1 else 0 end) as boleto,
	sum(case when op.payment_type = 'debit_card' then 1 else 0 end) as debit_card,
	sum(case when op.payment_type = 'voucher' then 1 else 0 end) as voucher,
	sum(case when op.payment_type = 'credit_card' then 1 else 0 end) as credit_card 
	from customers c
inner join orders o
on o.customer_id = c.customer_id
inner join order_payments op
on o.order_id = op.order_id
group by c.customer_state;



-- EX 4 (CONDITIONAL AGGREGATION: a funnel in one pass)
-- For each customer state: total orders, delivered orders, canceled
-- orders, and delivered-rate as a percentage. One row per state.
--
-- Hint: COUNT(*) for total, then SUM(CASE WHEN order_status =
--   'delivered' THEN 1 ELSE 0 END) and the same for 'canceled', then
--   divide. Watch for integer division -- in Postgres, int / int
--   truncates, so multiply by 100.0 (not 100) before dividing, or cast
--   one side to numeric.
-- Self-check: pick any state and manually eyeball total = delivered +
--   canceled + everything else (shipped, processing, unavailable, etc).
--   If your delivered + canceled ever exceeds total, you've double
--   counted somewhere upstream, likely a join fan-out from a table you
--   didn't mean to bring in.

select c.customer_state, count(o.order_id),
sum(case when o.order_status = 'delivered' then 1 else 0 end) as delivered,
sum(case when o.order_status = 'canceled' then 1 else 0 end) as canceled,
sum(case when o.order_status = 'delivered' then 1 else 0 end)*100.0/count(o.order_id) as delivery_ratio
from customers c
inner join orders o
on c.customer_id = o.customer_id
group by c.customer_state;





-- EX 5 (HAVING on a computed aggregate, with a floor AND a filter)
-- Which sellers have sold at least 100 items AND have an average item
-- price above $50? Return seller_id, item count, and average price,
-- highest average first.
--
-- Hint: two conditions in HAVING, joined with AND -- COUNT(*) >= 100
--   AND AVG(price) > 50. Try writing HAVING count(*) >= 100 AND
--   avg_price > 50 using an alias for avg_price defined in the SELECT,
--   and see whether Postgres accepts it.
-- Self-check: Postgres actually allows referencing a SELECT alias in
--   HAVING (this is a Postgres-specific relaxation of the standard --
--   some other engines, like older MySQL/SQL Server versions, reject
--   it and require you to repeat the full AVG(price) expression). Good
--   to know which camp whatever engine you're tested on in an
--   interview falls into; don't assume it always works.



select s.seller_id, count(oi.order_item_id) as order_count, avg(oi.price) as avg_price from sellers s
inner join order_items oi
on oi.seller_id = s.seller_id
group by s.seller_id
having count(oi.order_item_id) >= 100 and avg(oi.price) >= 50
order by avg_price DESC;



-- EX 6 (PUTTING IT TOGETHER -- portfolio material)
-- Late-delivery rate by month: for each month of order_purchase_timestamp,
-- what percentage of delivered orders arrived after their estimated
-- delivery date? Include only rows where order_delivered_customer_date
-- is not null. Return year-month, total delivered orders, late orders,
-- and late percentage, in chronological order.
--
-- Hint: DATE_TRUNC('month', ...) to group, conditional SUM for the late
--   flag, COUNT(*) for the denominator, WHERE for order_status =
--   'delivered' AND the not-null guard (both are row-level filters, so
--   both belong in WHERE, not HAVING).
-- Self-check: watch for a trend, not just a table of numbers -- does
--   the late rate spike anywhere? Olist had a well-documented delivery
--   crisis around November 2017 (Black Friday volume). If your query is
--   right, you should be able to see that spike in the data without me
--   telling you which month it lands on.
--
-- This is the natural companion to Ex 9 from Day 2-3 -- that one was
-- "which sellers are worst," this one is "is the whole system getting
-- better or worse over time." Together they're most of a real
-- operations dashboard.


select EXTRACT('year' from o.order_purchase_timestamp) as year_, EXTRACT('month' from o.order_purchase_timestamp) as month_, count(*) as total_orders,
sum(case when o.order_estimated_delivery_date < o.order_delivered_customer_date then 1 else 0 end) as total_late,
sum(case when o.order_estimated_delivery_date < o.order_delivered_customer_date then 1 else 0 end)*100.0/count(*) as late_ratio
from orders o
where o.order_delivered_customer_date is not null and o.order_status = 'delivered'
group by year_, month_
order by year_, month_;









