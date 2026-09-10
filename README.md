# Olist Supply Chain SQL Analysis

SQL analysis of the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), focused on fulfillment and delivery performance rather than generic sales reporting. Built as part of preparing for operations research / decision science roles — the questions are the kind an operations team would actually ask, not a tutorial walkthrough of the dataset.

Hosted on **Azure Database for PostgreSQL (Flexible Server)**; developed and tested locally on PostgreSQL 17.

## Key findings

**1. Delivery performance varies sharply by seller, not just by season.**
Ranking sellers with 50+ delivered items by their late-delivery rate turns up a clear tail of consistently underperforming sellers — this isn't noise, it's structural.
→ [`analysis/seller_late_delivery_rate.sql`](analysis/seller_late_delivery_rate.sql)

**2. The November 2017 delivery crisis wasn't a one-month blip — it took roughly six months to resolve.**
A trailing 3-month moving average of the monthly late-delivery rate shows the spike around November 2017 (Black Friday volume) stayed elevated through approximately May 2018 rather than snapping back the following month. That's a materially different operational story than "one bad month": it points to sustained capacity strain, not a single-event shock.
→ [`analysis/monthly_late_rate_trend.sql`](analysis/monthly_late_rate_trend.sql)

**3. Revenue is geographically concentrated.**
A small number of customer states account for a disproportionate share of national revenue — relevant to any conversation about regional logistics investment or where a distribution center would have the most impact.
→ [`analysis/revenue_concentration_by_state.sql`](analysis/revenue_concentration_by_state.sql)

**4. Slow delivery is associated with lower seller reviews.**
Joining each seller's late-delivery rate against their average review score shows the two move together directionally — a data-backed link between fulfillment performance and customer satisfaction, not just an assumption.
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
