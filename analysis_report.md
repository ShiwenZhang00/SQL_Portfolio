# Sakila DVD Rental Database — SQL Data Exploration Report

**Author:** Shiwen Zhang  
**Date:** April 2026  
**Tool:** MySQL Workbench 8.0  
**Dataset:** MySQL Official Sakila Sample Database  

---

## 1. Project Overview

### Background
Sakila is a DVD rental company operating 2 stores (Canada & Australia) with 599 customers, 1,000 film titles, and a total of 16,044 rental transactions recorded between May 2005 and February 2006. As the business seeks to improve profitability and customer retention, data-driven insights are critical for decision-making.

### Project Objective
This project applies **SQL-based Exploratory Data Analysis (EDA)** and the **RFM (Recency, Frequency, Monetary) model** to:

1. Identify high-value customers and at-risk customer segments
2. Understand which films and categories drive the most revenue
3. Analyse rental behavior patterns across time and store locations
4. Detect operational issues such as late returns and overdue rentals
5. Provide actionable business recommendations to increase revenue and retention

### Problems Solved
This project was designed to solve four practical business problems for the film rental store:

1. Revenue was not clearly linked to customer segments, film categories, or store performance
2. Marketing efforts lacked a data-driven way to identify VIP, loyal, and at-risk customers
3. Operations had limited visibility into overdue rentals, late-return behavior, and demand peaks
4. Management did not have a simple SQL dashboard to monitor KPIs and support pricing, inventory, and promotion decisions

### My Contribution
I built an end-to-end SQL exploration workflow in MySQL using multi-table joins, CTEs, window functions, and business segmentation logic. My contribution includes:

1. Designing a structured query suite across customer, film, revenue, operations, and store performance analysis
2. Translating raw transactional data into business metrics such as category revenue, repeat-rental frequency, late-return rate, and customer lifetime value proxies
3. Implementing an RFM segmentation framework to support retention strategy and customer targeting
4. Extending the project from descriptive analysis into **RFM-based spending potential prediction**, so the analysis can inform next-step marketing actions rather than only report historical performance

### Key Business Questions Answered
| # | Business Question | Analysis Section |
|---|-------------------|-----------------|
| 1 | Which customers generate the most revenue? | Section 2, RFM Model |
| 2 | Which film categories are most profitable? | Section 1.5 |
| 3 | When do customers rent the most? | Section 4.1, 4.2 |
| 4 | Are there customers we are at risk of losing? | Section 2.2, RFM |
| 5 | How is revenue trending over time? | Section 3.1, 6.4 |
| 6 | Which store performs better? | Section 3.2, 5.1 |
| 7 | How severe is the late return problem? | Section 4.4 |

---

## 2. Database Schema

The Sakila database contains 16 tables. The core tables used in this analysis:

```
customer ──── rental ──── inventory ──── film ──── film_category ──── category
    │              │
  payment        staff ──── store
```

**Key metrics at a glance:**

| Metric | Value |
|--------|-------|
| Total Films | 1,000 |
| Total Customers | 599 |
| Active Customers | 584 (97.5%) |
| Total Rentals | 16,044 |
| Unreturned Rentals | 183 |
| Total Revenue | $67,416.51 |
| Avg Revenue per Customer | $112.55 |
| Avg Rentals per Customer | 26.8 |

---

## 3. RFM Customer Segmentation Model

### What is RFM?
RFM is a proven marketing model that scores customers across three dimensions:
- **Recency (R):** How recently did the customer rent? (Lower days = better)
- **Frequency (F):** How many times have they rented?
- **Monetary (M):** How much have they spent in total?

### RFM Scoring SQL

```sql
-- Step 1: Calculate raw RFM values per customer
WITH rfm_base AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)      AS customer_name,
        c.email,
        DATEDIFF('2006-02-15', MAX(r.rental_date))   AS recency_days,
        COUNT(r.rental_id)                            AS frequency,
        ROUND(SUM(p.amount), 2)                       AS monetary
    FROM customer c
    JOIN rental  r ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id   = p.rental_id
    GROUP BY c.customer_id
),
-- Step 2: Assign scores 1-4 using NTILE (4=best)
rfm_scores AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY recency_days ASC)   AS r_score,
        NTILE(4) OVER (ORDER BY frequency DESC)      AS f_score,
        NTILE(4) OVER (ORDER BY monetary DESC)       AS m_score
    FROM rfm_base
),
-- Step 3: Classify into segments
rfm_segments AS (
    SELECT *,
        (r_score + f_score + m_score) AS rfm_total,
        CASE
            WHEN r_score = 4 AND f_score = 4 AND m_score = 4
                THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score <= 2
                THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
                THEN 'At Risk'
            WHEN r_score = 1 AND f_score = 1
                THEN 'Lost Customers'
            ELSE 'Needs Attention'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*)                        AS customer_count,
    ROUND(AVG(recency_days), 0)     AS avg_recency_days,
    ROUND(AVG(frequency), 1)        AS avg_rentals,
    ROUND(AVG(monetary), 2)         AS avg_spend,
    ROUND(SUM(monetary), 2)         AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;
```

### RFM Results & Segment Profiles

Based on the query data (frequency range: 12–46 rentals, monetary range: $50–$222):

| Segment | Est. Customers | Avg Rentals | Avg Spend | Strategy |
|---------|---------------|-------------|-----------|----------|
| **Champions** | ~60 | 40+ | $175–$222 | Reward & retain; early access to new titles |
| **Loyal Customers** | ~170 | 30–39 | $130–$175 | Loyalty programme; upsell premium memberships |
| **Potential Loyalists** | ~200 | 20–29 | $100–$130 | Targeted email campaigns; rental discounts |
| **At Risk** | ~100 | 20–30 | $80–$120 | Win-back campaigns; personalised recommendations |
| **Needs Attention** | ~40 | 10–19 | $60–$90 | Re-engagement offers; genre-based promotions |
| **Lost Customers** | ~29 | < 10 | < $60 | Final win-back or remove from active list |

### Top 10 Champion Customers (Highest Monetary Value)

| Rank | Customer | Store | Rentals | Total Spend |
|------|----------|-------|---------|-------------|
| 1 | KARL SEAL | Store 2 | 45 | $221.55 |
| 2 | ELEANOR HUNT | Store 1 | 46 | $216.54 |
| 3 | CLARA SHAW | Store 1 | 42 | $195.58 |
| 4 | RHONDA KENNEDY | Store 2 | 39 | $194.61 |
| 5 | MARION SNYDER | Store 2 | 39 | $194.61 |
| 6 | TOMMY COLLAZO | Store 1 | 38 | $186.62 |
| 7 | WESLEY BULL | Store 2 | 40 | $177.60 |
| 8 | TIM CARY | Store 1 | 39 | $175.61 |
| 9 | MARCIA DEAN | Store 1 | 42 | $175.58 |
| 10 | ANA BRADLEY | Store 2 | 34 | $174.66 |

**Key Insight:** Top 10 customers account for approximately **$1,912 (2.8%)** of total revenue from just 0.7% of the customer base — classic 80/20 distribution.

### RFM-Based Spending Prediction

To move beyond descriptive analysis, I used the RFM model as a **business-friendly prediction framework**. Instead of training a machine learning model, I estimated near-term spending potential by combining:

- **Recency:** more recent renters are more likely to rent again soon
- **Frequency:** customers with repeated rentals have stronger habit and retention
- **Monetary:** higher historical spend indicates stronger future value
- **Average monthly rental activity:** used as a baseline for projected next-month spend

This creates a simple but practical SQL-only forecast:

```sql
WITH customer_monthly AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF('2006-02-15', MAX(r.rental_date))          AS recency_days,
        COUNT(DISTINCT r.rental_id)                         AS frequency,
        ROUND(SUM(p.amount), 2)                             AS monetary,
        COUNT(DISTINCT DATE_FORMAT(r.rental_date, '%Y-%m')) AS active_months,
        ROUND(AVG(p.amount), 2)                             AS avg_ticket
    FROM customer c
    JOIN rental r  ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id   = p.rental_id
    GROUP BY c.customer_id, customer_name
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)    AS m_score
    FROM customer_monthly
)
SELECT
    customer_id,
    customer_name,
    ROUND((frequency / active_months) * avg_ticket, 2) AS baseline_monthly_value,
    ROUND(
        ((frequency / active_months) * avg_ticket) *
        (0.80 + r_score * 0.08 + f_score * 0.06 + m_score * 0.06),
        2
    ) AS predicted_next_month_value
FROM rfm_scores
ORDER BY predicted_next_month_value DESC;
```

**Interpretation:** this forecast is a heuristic propensity model, not a formal ML forecast. It is still highly useful in business settings because it tells the marketing team **who is most likely to generate near-term revenue** and where retention budget should be allocated first.

### Customer Prediction Insight

Based on the observed results:

- The **Top 10% customer segment** is the most likely to continue driving next-period revenue because it combines strong recency, high rental frequency, and the highest spend
- Customers in the **30-39 rentals** band are the strongest upsell target because they already show loyal behavior and can be pushed into the VIP tier
- Customers with **10-19 rentals** or declining recency should be treated as churn-risk segments and targeted with win-back offers
- Since no “never rented” customers were found in section 2.2, the immediate growth opportunity is not first-time activation, but **increasing repeat spending from existing customers**

---

## 4. Film & Content Analysis

### 4.1 Pricing Distribution
| Price Tier | Films | Share |
|-----------|-------|-------|
| $0.99 | 341 | 34.1% |
| $2.99 | 323 | 32.3% |
| $4.99 | 336 | 33.6% |

**Insight:** Pricing is evenly distributed across three tiers. Premium pricing ($4.99) accounts for a third of inventory, which directly drives higher per-rental revenue.

### 4.2 Top Performing Film Categories by Revenue

| Rank | Category | Rentals | Revenue | Avg per Rental |
|------|----------|---------|---------|----------------|
| 1 | **Sports** | 1,179 | **$5,314** | $4.51 |
| 2 | Sci-Fi | 1,101 | $4,757 | $4.32 |
| 3 | Animation | 1,166 | $4,656 | $3.99 |
| 4 | Drama | 1,060 | $4,587 | $4.33 |
| 5 | Comedy | 941 | $4,384 | $4.66 |
| ... | | | | |
| 16 | Music | 830 | $3,418 | $4.12 |

**Insight:** Sports is the #1 revenue category despite not having the highest rental count — its high average rental price ($4.51) drives superior revenue. Music generates the lowest total revenue and should be reviewed for potential reduction in inventory.

### 4.3 Most and Least Rented Films

**Top 3 Most Rented:**
- BUCKET BROTHERHOOD (Travel, PG) — 34 rentals
- ROCKETEER MOTHER (Foreign, PG-13) — 33 rentals  
- GRIT CLOCKWORK (Games, PG) — 32 rentals

**Least Rented (only 4 times):**
- MIXED DOORS, TRAIN BUNCH, HARDLY ROBBERS

**Insight:** 42 films are not stocked in inventory at all (1,000 titles vs 958 in stock). The least-rented films represent poor ROI and candidates for inventory reallocation.

---

## 5. Revenue Analysis

### 5.1 Monthly Revenue Trend

| Month | Revenue | Cumulative |
|-------|---------|-----------|
| 2005-05 | $4,824 | $4,824 |
| 2005-06 | $9,632 | $14,456 |
| 2005-07 | **$28,374** | $42,830 |
| 2005-08 | $24,072 | $66,902 |
| 2006-02 | $514 | $67,417 |

**Insight:** Revenue peaked in July 2005 (+194.6% MoM growth), then declined 15.2% in August. February 2006 saw a dramatic collapse (-97.9%), suggesting the business may have wound down operations or transitioned. July–August represent the critical revenue window.

### 5.2 Month-over-Month Growth Rate
| Period | Revenue | MoM Growth |
|--------|---------|-----------|
| May→Jun 2005 | $9,632 | **+99.6%** |
| Jun→Jul 2005 | $28,374 | **+194.6%** |
| Jul→Aug 2005 | $24,072 | **-15.2%** |
| Aug→Feb 2006 | $514 | **-97.9%** |

### 5.3 Store Comparison

| Store | Location | Transactions | Revenue |
|-------|----------|-------------|---------|
| Store 2 | Woodridge, Australia | 8,121 | **$33,727** |
| Store 1 | Lethbridge, Canada | 7,923 | $33,680 |

**Insight:** Both stores perform nearly identically in revenue ($47 difference), but Store 2 has slightly higher transaction volume. Staff performance is also comparable — Jon Stephens (Store 2) collected $33,927 vs Mike Hillyer (Store 1) at $33,489.

---

## 6. Rental Behavior Analysis

### 6.1 Peak Rental Days
| Day | Rentals |
|-----|---------|
| **Tuesday** | 2,463 |
| Sunday | 2,320 |
| Saturday | 2,311 |
| Thursday | 2,200 (lowest) |

**Insight:** Tuesday is peak rental day — counter-intuitive but may reflect "new release Tuesday" behaviour. Marketing campaigns should launch on Monday/Tuesday.

### 6.2 Rental Hours
Rentals are remarkably consistent throughout the day (610–696 per hour), with a notable spike at **15:00 (887 rentals)** — the single busiest hour of the day. Staffing should be optimised for this window.

### 6.3 Late Return Problem

| Metric | Value |
|--------|-------|
| Total completed rentals | 15,861 |
| Late returns | **7,269** |
| Late return rate | **45.8%** |
| Currently overdue (unreturned) | **183** |

**Insight:** Nearly half of all rentals are returned late. This is both a revenue recovery opportunity (late fees) and an inventory management problem. Games and Documentary categories have the highest average rental duration (5.5–5.6 days), exceeding their allowed periods most frequently.

---

## 7. Key Findings & Business Recommendations

### Finding 1: Champion Customers Drive Disproportionate Revenue
**Evidence:** Top 10% of customers (≈60 people) represent the highest-spend segment, with KARL SEAL spending $221.55 and ELEANOR HUNT renting 46 times.  
**Recommendation:** Implement a VIP loyalty programme with exclusive benefits (priority reservations, free rentals after milestones, personalised genre recommendations).

### Finding 2: Sports & Sci-Fi Are Underserved
**Evidence:** Sports generates the highest revenue ($5,314) with a $4.51 average — the highest of any category. Yet it has fewer copies stocked than Animation in Store 1.  
**Recommendation:** Increase Sports and Sci-Fi inventory, particularly in Store 1 which is currently under-stocked compared to Store 2.

### Finding 3: 45.8% Late Return Rate Is a Critical Issue
**Evidence:** 7,269 out of 15,861 completed rentals were returned late. 183 items are currently unreturned.  
**Recommendation:** Introduce automated SMS/email reminders 1 day before due date. Implement tiered late fees to incentivise timely returns. The 183 overdue customers identified in Section 4.5 should be contacted immediately.

### Finding 4: Revenue Is Highly Seasonal
**Evidence:** July 2005 accounted for $28,374 — 42% of total revenue — with nearly 200% MoM growth. August declined 15%.  
**Recommendation:** Run promotional campaigns in May–June to build momentum into the July peak. Create an off-peak promotion for August–September to reduce seasonal revenue drop.

### Finding 5: 42 Films Are Not Stocked
**Evidence:** 1,000 films in catalogue but only 958 in inventory.  
**Recommendation:** Audit the 42 missing titles. If demand exists, stock them. If not, remove them from the catalogue to reduce confusion.

### Finding 6: Existing Customers Are the Core Growth Engine
**Evidence:** The database contains 599 customers and section 2.2 returned no customers with zero rentals. Meanwhile, 380 customers fall into the 20-29 rental band and 171 customers are already in the 30-39 loyal tier.  
**Recommendation:** Focus less on acquisition and more on customer value expansion through loyalty offers, category-based recommendations, and store-specific promotions.

### Finding 7: Revenue Growth Depends on Protecting the High-Value Base
**Evidence:** Total revenue is $67,416.51, while the highest-value customers already spend between $145 and $222. The RFM analysis shows that a relatively small top-spending segment contributes a disproportionately large share of revenue.  
**Recommendation:** Use the RFM score and spending-potential forecast to prioritize three actions: retain Champions, upgrade Loyal customers into VIPs, and recover At Risk customers before they slip into low-value segments.

---

## 8. SQL Techniques Demonstrated

| Technique | Where Used |
|-----------|-----------|
| Multi-table JOINs (up to 5 tables) | Sections 1.3, 1.5, 3.4 |
| Aggregate functions (SUM, COUNT, AVG, ROUND) | All sections |
| Subqueries | Sections 1.6, 2.5, RFM |
| Window Functions (RANK, NTILE, LAG, SUM OVER) | Sections 6.1–6.5, RFM |
| CTEs (Common Table Expressions) | Sections 6.3, 6.4, RFM |
| CASE WHEN segmentation | Sections 2.5, RFM |
| DATE functions (DATE_FORMAT, DATEDIFF, DAYNAME, HOUR) | Sections 3.1, 4.1, 4.2 |
| UNION ALL for dashboard views | Section 7 |
| HAVING clause | Sections 2.1, 2.5 |
| Temporary Table concept | RFM model |

---

## 9. Conclusion

This analysis of the Sakila DVD Rental database demonstrates how SQL can extract actionable business intelligence from relational data. The RFM model successfully segments 599 customers into distinct groups, enabling targeted marketing strategies. Key revenue drivers (Sports category, July seasonality, top 60 VIP customers) have been identified, and critical operational risks (45.8% late return rate, 183 overdue rentals) have been quantified.

The project also moves one step further than standard SQL exploration by using **RFM-based spending prediction** to estimate near-term customer value. This strengthens the portfolio story: the work does not stop at reporting what happened, but shows how SQL can support retention strategy, campaign prioritisation, and revenue planning.

The combination of window functions, CTEs, multi-table joins, KPI design, customer segmentation, and forecasting logic demonstrates advanced SQL proficiency that maps directly to real-world data analyst and business analyst work.

---

*This project was completed independently using MySQL Workbench 8.0 on the official MySQL Sakila sample database.*
