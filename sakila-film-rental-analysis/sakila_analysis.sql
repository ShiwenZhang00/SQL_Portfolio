-- ============================================================
-- Sakila DVD Rental Database - Business Analysis
-- Author: [Your Name]
-- Date:   2026-04-07
-- Tool:   MySQL Workbench 8.0
-- Data:   MySQL Official Sakila Sample Database
--
-- Database contains:
--   1000 films | 599 customers | 16,044 rentals
--   2 stores   | 5,462 payments | 200 actors
--
-- Sections:
--   1. Film & Inventory Analysis
--   2. Customer Analysis
--   3. Revenue Analysis
--   4. Rental Behavior Analysis
--   5. Staff & Store Performance
--   6. Advanced: Window Functions & CTEs
--   7. Executive KPI Dashboard
-- ============================================================

USE sakila;

-- ============================================================
-- SECTION 1: FILM & INVENTORY ANALYSIS
-- ============================================================

-- 1.1  Total films by rental price tier
-- Business use: understand pricing distribution
SELECT
    rental_rate              AS price,
    COUNT(*)                 AS total_films,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM film), 1) AS pct
FROM film
GROUP BY rental_rate
ORDER BY rental_rate;


-- 1.2  Films by rating — which rating dominates?
SELECT
    rating,
    COUNT(*)    AS total_films,
    ROUND(AVG(rental_rate), 2)   AS avg_rental_price,
    ROUND(AVG(length), 0)        AS avg_length_mins
FROM film
GROUP BY rating
ORDER BY total_films DESC;


-- 1.3  Top 10 most-rented films
SELECT
    f.title,
    c.name                   AS category,
    f.rating,
    f.rental_rate,
    COUNT(r.rental_id)       AS times_rented
FROM film f
JOIN film_category fc   ON f.film_id      = fc.film_id
JOIN category c         ON fc.category_id = c.category_id
JOIN inventory i        ON f.film_id      = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
GROUP BY f.film_id
ORDER BY times_rented DESC
LIMIT 10;


-- 1.4  Top 10 least-rented films (candidates for removal)
SELECT
    f.title,
    c.name           AS category,
    f.rental_rate,
    COUNT(r.rental_id) AS times_rented
FROM film f
JOIN film_category fc   ON f.film_id      = fc.film_id
JOIN category c         ON fc.category_id = c.category_id
JOIN inventory i        ON f.film_id      = i.film_id
LEFT JOIN rental r      ON i.inventory_id = r.inventory_id
GROUP BY f.film_id
ORDER BY times_rented ASC
LIMIT 10;


-- 1.5  Rentals and revenue by film category
SELECT
    c.name                       AS category,
    COUNT(r.rental_id)           AS total_rentals,
    ROUND(SUM(p.amount), 2)      AS total_revenue,
    ROUND(AVG(p.amount), 2)      AS avg_revenue_per_rental
FROM category c
JOIN film_category fc   ON c.category_id  = fc.category_id
JOIN film f             ON fc.film_id     = f.film_id
JOIN inventory i        ON f.film_id      = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
JOIN payment p          ON r.rental_id    = p.rental_id
GROUP BY c.name
ORDER BY total_revenue DESC;


-- 1.6  Films in inventory vs never stocked (inventory gap)
SELECT
    COUNT(DISTINCT f.film_id)                          AS total_films,
    COUNT(DISTINCT i.film_id)                          AS films_in_inventory,
    COUNT(DISTINCT f.film_id) - COUNT(DISTINCT i.film_id) AS films_not_stocked
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id;


-- ============================================================
-- SECTION 2: CUSTOMER ANALYSIS
-- ============================================================

-- 2.1  Top 10 highest-spending customers (VIP targets)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.email,
    COUNT(r.rental_id)                       AS total_rentals,
    ROUND(SUM(p.amount), 2)                  AS total_spent
FROM customer c
JOIN rental  r ON c.customer_id = r.customer_id
JOIN payment p ON r.rental_id   = p.rental_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 10;


-- 2.2  Customers who have never rented (re-engagement targets)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    c.create_date
FROM customer c
LEFT JOIN rental r ON c.customer_id = r.customer_id
WHERE r.rental_id IS NULL;


-- 2.3  Customer distribution by country
SELECT
    co.country,
    COUNT(c.customer_id) AS total_customers
FROM customer c
JOIN address a  ON c.address_id  = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
JOIN country co ON ci.country_id = co.country_id
GROUP BY co.country
ORDER BY total_customers DESC
LIMIT 15;


-- 2.4  Active vs inactive customers
SELECT
    CASE WHEN active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer), 1) AS pct
FROM customer
GROUP BY active;


-- 2.5  Customer rental frequency segments
SELECT
    CASE
        WHEN total_rentals >= 40 THEN '40+ (VIP)'
        WHEN total_rentals >= 30 THEN '30-39 (Loyal)'
        WHEN total_rentals >= 20 THEN '20-29 (Regular)'
        WHEN total_rentals >= 10 THEN '10-19 (Casual)'
        ELSE '< 10 (Rare)'
    END                  AS segment,
    COUNT(*)             AS customers
FROM (
    SELECT customer_id, COUNT(*) AS total_rentals
    FROM rental
    GROUP BY customer_id
) sub
GROUP BY segment
ORDER BY MIN(total_rentals) DESC;


-- ============================================================
-- SECTION 3: REVENUE ANALYSIS
-- ============================================================

-- 3.1  Monthly revenue trend
SELECT
    DATE_FORMAT(payment_date, '%Y-%m')   AS month,
    COUNT(payment_id)                     AS transactions,
    ROUND(SUM(amount), 2)                 AS revenue,
    ROUND(AVG(amount), 2)                 AS avg_transaction
FROM payment
GROUP BY month
ORDER BY month;


-- 3.2  Revenue by store
SELECT
    s.store_id,
    ci.city                          AS city,
    co.country,
    COUNT(p.payment_id)              AS transactions,
    ROUND(SUM(p.amount), 2)          AS total_revenue
FROM store s
JOIN inventory i  ON s.store_id      = i.store_id
JOIN rental r     ON i.inventory_id  = r.inventory_id
JOIN payment p    ON r.rental_id     = p.rental_id
JOIN address a    ON s.address_id    = a.address_id
JOIN city ci      ON a.city_id       = ci.city_id
JOIN country co   ON ci.country_id   = co.country_id
GROUP BY s.store_id
ORDER BY total_revenue DESC;


-- 3.3  Revenue by film rating
SELECT
    f.rating,
    COUNT(p.payment_id)         AS transactions,
    ROUND(SUM(p.amount), 2)     AS total_revenue,
    ROUND(AVG(p.amount), 2)     AS avg_payment
FROM film f
JOIN inventory i ON f.film_id      = i.film_id
JOIN rental r    ON i.inventory_id = r.inventory_id
JOIN payment p   ON r.rental_id    = p.rental_id
GROUP BY f.rating
ORDER BY total_revenue DESC;


-- 3.4  Revenue per film (top 10)
SELECT
    f.title,
    f.rental_rate,
    COUNT(r.rental_id)           AS times_rented,
    ROUND(SUM(p.amount), 2)      AS total_revenue
FROM film f
JOIN inventory i ON f.film_id      = i.film_id
JOIN rental r    ON i.inventory_id = r.inventory_id
JOIN payment p   ON r.rental_id    = p.rental_id
GROUP BY f.film_id
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================
-- SECTION 4: RENTAL BEHAVIOR ANALYSIS
-- ============================================================

-- 4.1  Rentals by day of week (peak demand days)
SELECT
    DAYNAME(rental_date)   AS day_of_week,
    COUNT(*)               AS total_rentals
FROM rental
GROUP BY day_of_week
ORDER BY total_rentals DESC;


-- 4.2  Rentals by hour of day
SELECT
    HOUR(rental_date)  AS hour_of_day,
    COUNT(*)           AS total_rentals
FROM rental
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- 4.3  Average rental duration by category (days kept)
SELECT
    c.name                           AS category,
    ROUND(AVG(
        DATEDIFF(r.return_date, r.rental_date)
    ), 1)                            AS avg_days_kept,
    f.rental_duration                AS allowed_days
FROM rental r
JOIN inventory i     ON r.inventory_id  = i.inventory_id
JOIN film f          ON i.film_id       = f.film_id
JOIN film_category fc ON f.film_id      = fc.film_id
JOIN category c      ON fc.category_id  = c.category_id
WHERE r.return_date IS NOT NULL
GROUP BY c.name, f.rental_duration
ORDER BY avg_days_kept DESC;


-- 4.4  Late returns (returned after allowed rental duration)
SELECT
    COUNT(*) AS late_returns,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM rental WHERE return_date IS NOT NULL), 1) AS late_pct
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f      ON i.film_id      = f.film_id
WHERE r.return_date IS NOT NULL
  AND DATEDIFF(r.return_date, r.rental_date) > f.rental_duration;


-- 4.5  Currently unreturned rentals (overdue)
SELECT
    r.rental_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer,
    c.email,
    f.title,
    r.rental_date,
    f.rental_duration,
    DATEDIFF(NOW(), r.rental_date)          AS days_since_rental
FROM rental r
JOIN customer c  ON r.customer_id  = c.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f      ON i.film_id      = f.film_id
WHERE r.return_date IS NULL
ORDER BY days_since_rental DESC
LIMIT 20;


-- ============================================================
-- SECTION 5: STAFF & STORE PERFORMANCE
-- ============================================================

-- 5.1  Rentals processed per staff member
SELECT
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    s.store_id,
    COUNT(r.rental_id)                      AS rentals_processed
FROM staff s
JOIN rental r ON s.staff_id = r.staff_id
GROUP BY s.staff_id
ORDER BY rentals_processed DESC;


-- 5.2  Revenue collected per staff member
SELECT
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    COUNT(p.payment_id)                     AS payments_collected,
    ROUND(SUM(p.amount), 2)                 AS total_revenue
FROM staff s
JOIN payment p ON s.staff_id = p.staff_id
GROUP BY s.staff_id
ORDER BY total_revenue DESC;


-- 5.3  Store inventory depth by category
SELECT
    s.store_id,
    c.name              AS category,
    COUNT(i.inventory_id) AS copies_in_stock
FROM store s
JOIN inventory i     ON s.store_id     = i.store_id
JOIN film f          ON i.film_id      = f.film_id
JOIN film_category fc ON f.film_id     = fc.film_id
JOIN category c      ON fc.category_id = c.category_id
GROUP BY s.store_id, c.name
ORDER BY s.store_id, copies_in_stock DESC;


-- ============================================================
-- SECTION 6: ADVANCED — WINDOW FUNCTIONS & CTEs
-- ============================================================

-- 6.1  Customer ranking by total spend within each store
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)   AS customer_name,
    c.store_id,
    ROUND(SUM(p.amount), 2)                   AS total_spent,
    RANK() OVER (
        PARTITION BY c.store_id
        ORDER BY SUM(p.amount) DESC
    )                                         AS rank_in_store
FROM customer c
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id
ORDER BY c.store_id, rank_in_store;


-- 6.2  Running total revenue by month
SELECT
    DATE_FORMAT(payment_date, '%Y-%m')    AS month,
    ROUND(SUM(amount), 2)                  AS monthly_revenue,
    ROUND(SUM(SUM(amount)) OVER (
        ORDER BY DATE_FORMAT(payment_date, '%Y-%m')
    ), 2)                                  AS cumulative_revenue
FROM payment
GROUP BY month
ORDER BY month;


-- 6.3  CTE: identify top 10% spending customers (high-value segment)
WITH customer_spend AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        ROUND(SUM(p.amount), 2)                 AS total_spent
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
),
percentiles AS (
    SELECT
        customer_id,
        customer_name,
        email,
        total_spent,
        NTILE(10) OVER (ORDER BY total_spent DESC) AS decile
    FROM customer_spend
)
SELECT
    customer_id,
    customer_name,
    email,
    total_spent,
    'Top 10%' AS segment
FROM percentiles
WHERE decile = 1
ORDER BY total_spent DESC;


-- 6.4  Month-over-month revenue growth rate
WITH monthly AS (
    SELECT
        DATE_FORMAT(payment_date, '%Y-%m') AS month,
        ROUND(SUM(amount), 2)               AS revenue
    FROM payment
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)    AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month) * 100,
        1
    )                                      AS mom_growth_pct
FROM monthly
ORDER BY month;


-- 6.5  Film performance: rental rank within category
SELECT
    c.name                              AS category,
    f.title,
    COUNT(r.rental_id)                  AS times_rented,
    RANK() OVER (
        PARTITION BY c.name
        ORDER BY COUNT(r.rental_id) DESC
    )                                   AS rank_in_category
FROM film f
JOIN film_category fc   ON f.film_id      = fc.film_id
JOIN category c         ON fc.category_id = c.category_id
JOIN inventory i        ON f.film_id      = i.film_id
JOIN rental r           ON i.inventory_id = r.inventory_id
GROUP BY c.name, f.film_id
ORDER BY c.name, rank_in_category
LIMIT 30;


-- 6.6  RFM customer segmentation
-- Business use: classify customers into retention and marketing segments
WITH rfm_base AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.store_id,
        DATEDIFF('2006-02-15', MAX(r.rental_date)) AS recency_days,
        COUNT(DISTINCT r.rental_id)               AS frequency,
        ROUND(SUM(p.amount), 2)                   AS monetary
    FROM customer c
    JOIN rental r  ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id   = p.rental_id
    GROUP BY c.customer_id, customer_name, c.email, c.store_id
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)    AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    customer_name,
    email,
    store_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score)             AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating'
        ELSE 'Needs Attention'
    END                                           AS rfm_segment
FROM rfm_scores
ORDER BY monetary DESC, frequency DESC;


-- 6.7  RFM segment summary
WITH rfm_base AS (
    SELECT
        c.customer_id,
        DATEDIFF('2006-02-15', MAX(r.rental_date)) AS recency_days,
        COUNT(DISTINCT r.rental_id)               AS frequency,
        ROUND(SUM(p.amount), 2)                   AS monetary
    FROM customer c
    JOIN rental r  ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id   = p.rental_id
    GROUP BY c.customer_id
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)    AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating'
            ELSE 'Needs Attention'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT
    rfm_segment,
    COUNT(*)                            AS customer_count,
    ROUND(AVG(recency_days), 1)         AS avg_recency_days,
    ROUND(AVG(frequency), 1)            AS avg_rentals,
    ROUND(AVG(monetary), 2)             AS avg_spend,
    ROUND(SUM(monetary), 2)             AS segment_revenue
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY segment_revenue DESC;


-- 6.8  RFM-based spending potential forecast
-- Simple business forecast: estimate near-term customer value from
-- average monthly activity and RFM strength. This is a heuristic model,
-- not a machine learning forecast.
WITH customer_monthly AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.store_id,
        DATEDIFF('2006-02-15', MAX(r.rental_date))          AS recency_days,
        COUNT(DISTINCT r.rental_id)                         AS frequency,
        ROUND(SUM(p.amount), 2)                             AS monetary,
        COUNT(DISTINCT DATE_FORMAT(r.rental_date, '%Y-%m')) AS active_months,
        ROUND(AVG(p.amount), 2)                             AS avg_ticket
    FROM customer c
    JOIN rental r  ON c.customer_id = r.customer_id
    JOIN payment p ON r.rental_id   = p.rental_id
    GROUP BY c.customer_id, customer_name, c.email, c.store_id
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)    AS m_score
    FROM customer_monthly
),
forecasted AS (
    SELECT
        customer_id,
        customer_name,
        email,
        store_id,
        recency_days,
        frequency,
        monetary,
        active_months,
        avg_ticket,
        r_score,
        f_score,
        m_score,
        ROUND(frequency / NULLIF(active_months, 0), 2) AS avg_monthly_rentals,
        ROUND((frequency / NULLIF(active_months, 0)) * avg_ticket, 2) AS baseline_monthly_value,
        ROUND(
            ((frequency / NULLIF(active_months, 0)) * avg_ticket) *
            (0.80 + r_score * 0.08 + f_score * 0.06 + m_score * 0.06),
            2
        ) AS predicted_next_month_value
    FROM rfm_scores
)
SELECT
    customer_id,
    customer_name,
    email,
    store_id,
    recency_days,
    frequency,
    monetary,
    avg_monthly_rentals,
    baseline_monthly_value,
    predicted_next_month_value,
    CASE
        WHEN predicted_next_month_value >= 45 THEN 'High Potential'
        WHEN predicted_next_month_value >= 30 THEN 'Medium Potential'
        ELSE 'Low Potential'
    END AS spend_potential
FROM forecasted
ORDER BY predicted_next_month_value DESC
LIMIT 50;


-- ============================================================
-- SECTION 7: EXECUTIVE KPI DASHBOARD
-- ============================================================

SELECT 'Total Films'            AS metric, COUNT(*)              AS value FROM film
UNION ALL
SELECT 'Total Customers',                  COUNT(*)              FROM customer
UNION ALL
SELECT 'Active Customers',                 COUNT(*)              FROM customer WHERE active = 1
UNION ALL
SELECT 'Total Rentals',                    COUNT(*)              FROM rental
UNION ALL
SELECT 'Unreturned Rentals',               COUNT(*)              FROM rental WHERE return_date IS NULL
UNION ALL
SELECT 'Total Revenue ($)',
       ROUND(SUM(amount), 2)
FROM payment
UNION ALL
SELECT 'Avg Revenue per Customer ($)',
       ROUND(SUM(amount) / (SELECT COUNT(DISTINCT customer_id) FROM payment), 2)
FROM payment
UNION ALL
SELECT 'Avg Rentals per Customer',
       ROUND(COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM rental), 1)
FROM rental
UNION ALL
SELECT 'Total Actors',                     COUNT(*)              FROM actor
UNION ALL
SELECT 'Film Categories',                  COUNT(*)              FROM category
UNION ALL
SELECT 'Number of Stores',                 COUNT(*)              FROM store;
