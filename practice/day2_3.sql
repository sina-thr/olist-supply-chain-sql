-- 2 3 join exercises · SQL
-- =========================================================
-- DAY 2-3: JOINS on the Olist dataset
--
-- Work top to bottom. Write each query yourself before reading
-- the hint. The self-check line tells you what SHOULD be true
-- about your result -- if it isn't, your join is wrong.
--
-- Day 2 = Exercises 1-5 (the four join types + chains)
-- Day 3 = Exercises 6-9 (the traps)  <-- this is the valuable half
-- =========================================================
 
 
-- ---------------------------------------------------------
-- DAY 2: MECHANICS
-- ---------------------------------------------------------
 
-- EX 1 (INNER JOIN)
-- How many delivered orders came from each customer state?
-- Return state and order count, highest first.
--
-- Hint: orders -> customers on customer_id. Filter order_status = 'delivered'.
-- Self-check: your counts should sum to fewer than 99,441, since not
--   every order reaches 'delivered' status.




SELECT c.customer_state, count(o.order_id) from orders o 
inner join customers c
on c.customer_id = o.customer_id
where o.order_status = 'delivered'
group by c.customer_state
order by count(o.order_id) desc;


-- EX 2 (LEFT JOIN as an anti-join)
-- Which orders never received a review? Return the count, and a sample
-- of 10 order_ids.
--
-- Hint: orders LEFT JOIN order_reviews on order_id, then keep only rows
--   where the review side came back NULL. This is the standard
--   "find what's missing" pattern -- worth internalizing, it comes up
--   in interviews constantly.
-- Self-check: order_reviews has 99,224 rows but NOT 99,224 distinct
--   order_ids. Run a COUNT(DISTINCT order_id) on order_reviews first so
--   you know what number you're working against.



select count(o.order_id) from orders o
left outer join order_reviews r
on o.order_id = r.order_id
where r.order_id is null;

select o.order_id from orders o
left outer join order_reviews r
on o.order_id = r.order_id
where r.order_id is null
limit 10;



-- EX 3 (LEFT JOIN / RIGHT JOIN equivalence)
-- Which products in the catalogue have never been sold?
-- Return the count.
--
-- Hint: products LEFT JOIN order_items, keep the NULLs. Then rewrite the
--   exact same query using RIGHT JOIN with the table order reversed, and
--   confirm you get the identical number. That's the whole lesson on
--   RIGHT JOIN: it's LEFT JOIN with the operands swapped, and most teams
--   in practice standardise on LEFT for readability.


select COUNT(*) from products p
left outer join order_items oi
on p.product_id = oi.product_id
where oi.product_id is null;

select COUNT(*) from order_items oi
right outer join products p
on oi.product_id = p.product_id
where oi.product_id is null;




-- EX 4 (FULL OUTER JOIN)
-- Compare the zip prefixes that appear in customers against those in
-- sellers. How many prefixes have customers but no sellers, sellers but
-- no customers, and both?
--
-- Hint: build two DISTINCT zip-prefix lists, FULL OUTER JOIN them, then
--   use CASE to bucket each row by which side is NULL. This is one of the
--   few situations where FULL OUTER is genuinely the right tool --
--   reconciling two sets when you care about both directions of mismatch.
-- Self-check: all three buckets should be non-zero. Sellers cluster
--   heavily in a few states, so expect the "customer only" bucket to
--   dominate -- which is itself a real supply-chain observation about
--   how far the average parcel has to travel.




select count(*) as only_customer from (select distinct c.customer_zip_code_prefix from customers c) customer
full outer join (select distinct s.seller_zip_code_prefix from sellers s) seller
on customer.customer_zip_code_prefix = seller.seller_zip_code_prefix
where customer.customer_zip_code_prefix is not null and seller.seller_zip_code_prefix is null;

select count(*) as only_seller from (select distinct c.customer_zip_code_prefix from customers c) customer
full outer join (select distinct s.seller_zip_code_prefix from sellers s) seller
on customer.customer_zip_code_prefix = seller.seller_zip_code_prefix
where customer.customer_zip_code_prefix is null and seller.seller_zip_code_prefix is not null;

select count(*) as common from (select distinct c.customer_zip_code_prefix from customers c) customer
full outer join (select distinct s.seller_zip_code_prefix from sellers s) seller
on customer.customer_zip_code_prefix = seller.seller_zip_code_prefix
where customer.customer_zip_code_prefix is not null and seller.seller_zip_code_prefix is not null;



SELECT
    SUM(CASE WHEN s.zip IS NULL THEN 1 ELSE 0 END)                           AS customer_only,
    SUM(CASE WHEN c.zip IS NULL THEN 1 ELSE 0 END)                           AS seller_only,
    SUM(CASE WHEN c.zip IS NOT NULL AND s.zip IS NOT NULL THEN 1 ELSE 0 END) AS both_groups
FROM (SELECT DISTINCT customer_zip_code_prefix AS zip FROM customers) c
FULL OUTER JOIN (SELECT DISTINCT seller_zip_code_prefix AS zip FROM sellers) s
    ON c.zip = s.zip;


-- EX 5 (MULTI-TABLE CHAIN)
-- For delivered orders only: what is total revenue (item price, excluding
-- freight) by English product category and customer state? Return the top
-- 20 rows by revenue.
--
-- Hint: order_items -> products -> category_translation for the English
--   name, and order_items -> orders -> customers for the state. Five
--   tables. Use LEFT JOIN to category_translation -- a handful of
--   categories have no translation row, and an INNER JOIN would silently
--   drop that revenue. Wrap the category name in COALESCE so those rows
--   stay visible instead of showing as NULL.
-- Self-check: your grand total across ALL rows (drop the top-20 limit)
--   should match SUM(price) from order_items restricted to delivered
--   orders. If it's higher, you've fanned out somewhere.



select customer_state, COALESCE(product_category_name_english, 'unknown'), sum(revenue) as total_revenue from
(select o.order_id, c.customer_state, oi.order_item_id, oi.product_id, ct.product_category_name_english, oi.price as revenue from orders o
LEFT OUTER JOIN order_items oi
on o.order_id = oi.order_id
LEFT OUTER JOIN customers c
on o.customer_id = c.customer_id
LEFT OUTER JOIN products p
on p.product_id = oi.product_id
LEFT OUTER JOIN category_translation ct
on p.product_category_name = ct.product_category_name
where o.order_status = 'delivered')
GROUP BY customer_state, product_category_name_english
ORDER BY total_revenue DESC
LIMIT 20;



-- ---------------------------------------------------------
-- DAY 3: THE TRAPS
-- These are the ones that show up in real reporting bugs.
-- For each, write the WRONG version first, look at the number,
-- then write the RIGHT version and quantify the gap.
-- ---------------------------------------------------------
 
-- EX 6 (TRAP: LEFT JOIN silently demoted to INNER JOIN)
-- Goal: for every order, show the order_id and its review score, keeping
-- orders that have no review at all -- but only counting reviews of 4 or 5
-- stars as "positive".
--
-- Step A: write orders LEFT JOIN order_reviews, then add
--   WHERE review_score >= 4. Count the rows.
-- Step B: write the same query but move the condition into the ON clause:
--   LEFT JOIN order_reviews r ON o.order_id = r.order_id AND r.review_score >= 4
--   Count the rows again.
--
-- Self-check: Step B should return roughly 99,441 rows (one per order,
--   with NULLs where there's no qualifying review). Step A returns far
--   fewer, because the WHERE clause evaluates AFTER the join and discards
--   every NULL row the LEFT JOIN just preserved -- turning it into an
--   INNER JOIN without any error or warning.
-- The rule worth memorising: conditions on the LEFT-joined table belong in
--   ON. Conditions on the base table belong in WHERE. The one exception is
--   the deliberate anti-join from EX 2, where WHERE ... IS NULL is exactly
--   what you want.

select count(*) from orders o
left join order_reviews orw
on o.order_id = orw.order_id
where orw.review_score >= 4;

select count(*) from orders o
left join order_reviews orw
on o.order_id = orw.order_id AND orw.review_score >= 4;


-- EX 7 (TRAP: fan-out inflating a sum) -- THE BIG ONE
-- Goal: for each order, total item revenue and total amount paid,
-- side by side.
--
-- Step A (wrong): orders JOIN order_items JOIN order_payments, then
--   SUM(price) and SUM(payment_value), grouped by order_id.
--   Now compare your total SUM(price) against a plain
--   SELECT SUM(price) FROM order_items.
--
-- Self-check: the joined version will be dramatically larger. Reason:
--   order_items and order_payments are BOTH one-to-many children of
--   orders. An order with 3 items and 2 payment rows produces 3 x 2 = 6
--   rows, so every price is counted twice and every payment three times.
--   Nothing errors. The report just quietly overstates revenue.
--
-- Step B (right): pre-aggregate each child to one row per order_id in its
--   own CTE, THEN join those CTEs to orders. Confirm your total now
--   matches the standalone SUM(price).
--
-- This pattern -- collapse to the grain you want BEFORE joining -- is the
-- single most transferable thing in this whole week. Any time you join two
-- one-to-many tables to the same parent, you need it.

select o.order_id, sum(oi.price) as Revenue, sum(op.payment_value) as Payment from orders o
left join order_items oi
on o.order_id = oi.order_id
left join order_payments op
on o.order_id = op.order_id
GROUP BY o.order_id;

select o.order_id, grouped_oi.Revenue, grouped_op.Payment from orders o
left join (select oi.order_id, sum(oi.price) as Revenue from order_items oi GROUP BY oi.order_id) grouped_oi
on o.order_id = grouped_oi.order_id
left join (select op.order_id, sum(op.payment_value) as Payment from order_payments op GROUP BY op.order_id) grouped_op
on o.order_id = grouped_op.order_id;



-- EX 8 (TRAP: counting at the wrong grain)
-- Goal: how many distinct orders contain at least one item from a seller
-- based in Sao Paulo state?
--
-- Step A (wrong): join orders -> order_items -> sellers, filter
--   seller_state = 'SP', and use COUNT(*).
-- Step B (right): same query with COUNT(DISTINCT o.order_id).
--
-- Self-check: Step A counts ITEMS, not orders, and will overstate. The
--   gap is exactly the multi-item orders. Once a join changes your grain,
--   COUNT(*) stops answering the question you asked -- and this one is
--   easy to miss because the number still looks plausible.

SELECT COUNT(*)
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id AND s.seller_state = 'SP';

select count(distinct oi.order_id) from order_items oi
inner join sellers s
on oi.seller_id = s.seller_id and s.seller_state = 'SP';








-- EX 9 (PUTTING IT TOGETHER -- operations framing)
-- For sellers with at least 50 delivered items: what share of their
-- orders arrived AFTER the estimated delivery date? Return seller_id,
-- seller_state, total delivered items, and late percentage, sorted worst
-- first.
--
-- Hint: order_items -> orders for the dates, -> sellers for the state.
--   Late means order_delivered_customer_date > order_estimated_delivery_date.
--   Use conditional aggregation -- SUM(CASE WHEN ... THEN 1 ELSE 0 END) --
--   over a COUNT, which is a soft preview of Day 4. Apply the 50-item
--   floor with HAVING, not WHERE.
-- Self-check: watch your grain. Are you measuring items or orders? Both
--   are defensible, but the column name must match what you actually
--   computed. Also confirm you're only including rows where the delivery
--   date is non-NULL -- undelivered orders aren't "late", they're a
--   separate category, and lumping them in is a judgment call you should
--   make deliberately rather than by accident.
--
-- This one is portfolio material. It's a real operations question, it
-- exercises everything above, and the answer is genuinely interesting.



select s.seller_id, s.seller_state, count(oi.order_item_id) as Total_delivered,
(sum(case when o.order_estimated_delivery_date<o.order_delivered_customer_date then 1 else 0 end)* 100.0 / COUNT(*)) as Late_percentage
from sellers s
inner join order_items oi
on oi.seller_id = s.seller_id
inner join orders o
on o.order_id = oi.order_id and o.order_status = 'delivered' and o.order_delivered_customer_date is not null
group by s.seller_id, s.seller_state
HAVING count(oi.order_item_id)>50
order by Late_percentage DESC










