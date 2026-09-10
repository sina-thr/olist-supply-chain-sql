-- =========================================================
-- DAY 7, PART 1: CTEs on the Olist dataset
--
-- You've actually been writing CTEs since Day 4 without it being
-- named as its own topic -- every WITH block in your Day 4-6 answers
-- was one. So this isn't new syntax. What's new: chaining several
-- CTEs together deliberately, and one genuinely new tool (recursive
-- CTEs) for a problem you've been quietly exposed to without knowing
-- it -- months with zero orders just vanishing from a GROUP BY.
--
-- 4 exercises, then move to the timed self-test.
-- =========================================================


-- EX 1 (NAME WHAT YOU ALREADY KNOW: CTE vs subquery)
-- Take your Day 4 Ex 1 monthly order count query. Write it two ways:
-- once as a CTE (WITH ... AS (...) SELECT ...), once as the exact same
-- logic with the aggregation nested as a nested subquery in the FROM
-- clause instead. Confirm both return identical results.
--
-- Hint: this isn't really an exercise in new syntax -- it's confirming
--   for yourself that a CTE and a subquery-in-FROM are functionally the
--   same thing to the query planner. The difference is entirely
--   readability: a CTE gets a name and sits above the query where you
--   read it top to bottom; a nested subquery sits inline and reads
--   inside-out.
-- Self-check: identical row counts, identical values. If they differ,
--   you introduced a change in translating between the two forms, not
--   a real CTE-vs-subquery difference -- there isn't one for a query
--   this simple.

with timely_order_count as (select EXTRACT('year' from o.order_purchase_timestamp) as Year_,
EXTRACT('month' from o.order_purchase_timestamp) as Month_,
count(o.order_id) as order_count
from orders o
group by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp)
)
select * from timely_order_count
order by Year_, Month_ ASC;

select * from (
select EXTRACT('year' from o.order_purchase_timestamp) as Year_,
EXTRACT('month' from o.order_purchase_timestamp) as Month_,
count(o.order_id) as order_count
from orders o
group by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp)
order by EXTRACT('year' from o.order_purchase_timestamp), EXTRACT('month' from o.order_purchase_timestamp) ASC);



-- EX 2 (CHAINING CTEs: one referencing another)
-- Build a report with two layers: first, monthly revenue AND monthly
-- order count in one CTE; second, a CTE that takes THAT CTE's output
-- and computes revenue-per-order for each month. Final SELECT pulls
-- from the second CTE.
--
-- Hint: WITH monthly_stats AS (...), revenue_per_order AS (SELECT ...,
--   revenue / order_count AS rpo FROM monthly_stats) SELECT * FROM
--   revenue_per_order. Each CTE can reference any CTE defined before it
--   in the same WITH block -- that's the whole mechanism. This is the
--   real reason to reach for CTEs over subqueries once you're three
--   layers deep: nested subqueries at that depth get genuinely hard to
--   read, while named CTEs read as a sequence of labeled steps.
-- Self-check: pick one month and hand-verify revenue_per_order equals
--   that month's revenue divided by that month's order count from the
--   first CTE's own output. Cheap to check, easy to get an off-by-one
--   join wrong here.


with monthly_rev_ord as(
select extract('year' from o.order_purchase_timestamp) as year_, extract('month' from o.order_purchase_timestamp) as month_,
count(DISTINCT o.order_id) as count_order,
sum(oi.price) as revenue
from orders o
join order_items oi on oi.order_id = o.order_id
GROUP BY extract('year' from o.order_purchase_timestamp), extract('month' from o.order_purchase_timestamp)
),

revenue_per_order as(
select *, (revenue/count_order) as revenue_per_order from monthly_rev_ord
)

select * from revenue_per_order






-- EX 3 (RECURSIVE CTE: filling in the gaps a GROUP BY hides)
-- Generate a complete list of every calendar month from the earliest to
-- the latest order_purchase_timestamp in the dataset -- including any
-- month that happens to have ZERO orders. LEFT JOIN your monthly order
-- counts onto that list so missing months show up as 0, not as an
-- absent row.
--
-- Hint:
--   WITH RECURSIVE month_spine AS (
--       SELECT DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS m
--       FROM orders
--       UNION ALL
--       SELECT m + INTERVAL '1 month'
--       FROM month_spine
--       WHERE m + INTERVAL '1 month' <= (SELECT DATE_TRUNC('month', MAX(order_purchase_timestamp)) FROM orders)
--   )
--   SELECT ... FROM month_spine LEFT JOIN (your monthly counts) ON ...
--
--   Read the recursive part as: the first SELECT (the "anchor") produces
--   the starting row, then the second SELECT (after UNION ALL) keeps
--   generating one new row per month, each one built from the row
--   before it, stopping once the WHERE condition fails. It's a loop
--   written in SQL.
-- Self-check: check whether Olist's real data actually HAS a zero-order
--   month in range, or whether every month has at least one order. Either
--   answer is fine -- the point isn't that you'll necessarily find a gap
--   in this particular dataset, it's that your query no longer silently
--   ASSUMES there isn't one. A plain GROUP BY has no way to produce a row
--   for a month with zero matching orders; it can only report on months
--   that exist in the data. If you ever ran LAG() over a GROUP BY result
--   with a real gap in it, LAG would happily grab the nearest EXISTING
--   month as "prior," not the calendar month before -- silently wrong,
--   the same family of bug as the fan-out and frame traps, just hiding
--   in the input instead of the calculation.


with RECURSIVE month_spine as (select DATE_TRUNC('month', MIN(order_purchase_timestamp)) as month_ from orders
UNION ALL
select month_ + INTERVAL '1 MONTH' from month_spine
WHERE month_ + INTERVAL '1 MONTH' <= (select DATE_TRUNC('month', MAX(order_purchase_timestamp)) from orders))
select month_, count(order_id) from month_spine
left join orders o on DATE_TRUNC('month', o.order_purchase_timestamp) = month_
group by month_
order by month_;


-- EX 4 (PUTTING IT TOGETHER -- portfolio material)
-- One readable report, in named CTEs, combining: (a) each seller's total
-- delivered items and late-delivery rate (Day 2-3 Ex 9), and (b) each
-- seller's average review score (join order_items -> order_reviews).
-- Return seller_id, seller_state, delivered items, late percentage, and
-- average review score -- for sellers with at least 50 delivered items
-- -- ordered worst late-percentage first.
--
-- Hint: two independent CTEs (one for delivery performance, one for
--   review scores), each grouped by seller_id, then a final SELECT that
--   JOINs the two CTEs together on seller_id. Don't try to compute both
--   in a single CTE with one set of joins -- order_items joins to BOTH
--   orders and order_reviews, and reviews are keyed by order, not by
--   item, so combining them naively reintroduces the Day 3 fan-out
--   trap. Two clean CTEs, joined once at the end, sidesteps it entirely.
-- Self-check: does a high late-delivery rate correlate with a low
--   average review score, at least loosely? It should, directionally --
--   if it doesn't at all, something's probably off in one of the two
--   CTEs.
--
-- This is the query to actually put in your README. It answers a real
-- question (does slow delivery hurt seller reputation) using a join
-- trap, conditional aggregation, and CTE composition all in one place --
-- which is a fair summary of the whole week.

with seller_late as (select s.seller_id, s.seller_state, count(oi.order_item_id) as Total_delivered,
(sum(case when o.order_estimated_delivery_date<o.order_delivered_customer_date then 1 else 0 end)* 100.0 / COUNT(*)) as Late_percentage
from sellers s
inner join order_items oi
on oi.seller_id = s.seller_id
inner join orders o
on o.order_id = oi.order_id and o.order_status = 'delivered' and o.order_delivered_customer_date is not null
group by s.seller_id, s.seller_state
HAVING count(oi.order_item_id)>50
order by Late_percentage DESC),

seller_score AS (
    SELECT si.seller_id,
           AVG(r.order_review_score) AS Average_Review
    FROM (SELECT DISTINCT seller_id, order_id FROM order_items) si
    LEFT JOIN (
        SELECT order_id, AVG(review_score) AS order_review_score
        FROM order_reviews
        GROUP BY order_id
    ) r ON r.order_id = si.order_id
    GROUP BY si.seller_id
)



select sl.seller_id, sl.seller_state, sl.Total_delivered, sl.Late_percentage,ss.Average_Review  from seller_late sl
join seller_score ss on sl.seller_id = ss.seller_id



