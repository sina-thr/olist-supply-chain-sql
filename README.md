# Olist Supply Chain SQL Analysis

SQL analysis of the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), focused on fulfillment and delivery performance rather than generic sales reporting. Built as part of preparing for operations research / decision science roles.

Hosted on **Azure Database for PostgreSQL (Flexible Server)**, developed and tested locally on PostgreSQL 17.

## Key findings

**1. Delivery performance varies sharply by seller, not just by season.**
Among 453 sellers with 50+ delivered items, the average late-delivery rate is **7.7%**, but the worst-performing 10% run at **14.5% or higher**, and the single worst seller sits at **32.1%**, roughly 4x the typical rate. This isn't noise from a handful of small sellers. It's a structural tail worth investigating (SLA enforcement, onboarding standards, or regional logistics gaps).
→ [`analysis/seller_late_delivery_rate.sql`](analysis/seller_late_delivery_rate.sql)

**2. The November 2017 delivery crisis wasn't a one-month blip because it took roughly seven months to resolve.**
The 3-month moving average of the monthly late-delivery rate jumps from single digits to **8.3%** at November 2017 (Black Friday volume), keeps climbing to a peak of **14.6%** around March 2018, and doesn't fall back to a pre-crisis baseline (~5%) until June 2018. That's a materially different story than "one bad month": it points to sustained fulfillment strain that compounded for roughly two quarters, not a single-event shock that resolved itself.
→ [`analysis/monthly_late_rate_trend.sql`](analysis/monthly_late_rate_trend.sql)

**3. Revenue is heavily concentrated in a handful of states.**
Just 3 of 27 customer states — São Paulo, Rio de Janeiro, and Minas Gerais — account for **63%** of national revenue, with São Paulo alone responsible for **38%**. The top 5 states account for **74%**. Relevant to any conversation about regional logistics investment or where a distribution center would have the most impact.
→ [`analysis/revenue_concentration_by_state.sql`](analysis/revenue_concentration_by_state.sql)

**4. Slow delivery is associated with lower seller reviews with a moderate, not perfect, relationship.**
Late-delivery rate and average review score have a correlation of **r = -0.50** across sellers: as late-delivery rate rises, review scores tend to fall. It's a real, moderately strong pattern. Not every high-late-rate seller is poorly reviewed, but the relationship is well past noise.
→ [`analysis/seller_delay_vs_reviews.sql`](analysis/seller_delay_vs_reviews.sql)

## Repo structure

```
├── schema.sql              -- table definitions + row-count verification query
├── analysis/                -- the four queries above
└── practice/                 -- day-by-day SQL practice (joins, aggregation,
                                 window functions, CTEs) working up to the
                                 analysis queries above. Left in for transparency,
                                 not polished — see analysis/ for the finished work.
```

## Reproducing this

1. Download the [Olist dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (9 CSVs).
2. Run `schema.sql` against a PostgreSQL database to create the tables.
3. Import each CSV into its matching table (e.g. via pgAdmin's Import/Export Data, or `\copy` from `psql`).
4. Run the row-count check at the bottom of `schema.sql` to confirm the load.
5. Run any query in `analysis/`.

## Tools

PostgreSQL 17 · Azure Database for PostgreSQL Flexible Server · pgAdmin
