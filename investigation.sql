-- HYPOTHESIS 1: STORE CONCENTRATION
-- Objective:
-- Determine whether Western Cape's revenue decline is unique to the province and whether specific stores drive the decline.

-- Comparison period:
-- Jan-Jun 2025 vs Jan-Jun 2024

with provincial_sales as (
    select
        s.province,
        year(t.transaction_date) as sales_year,
        sum(
            ti.quantity * ti.unit_price_at_sale
        ) as revenue
    from transactions t
    inner join stores s
        on t.store_id = s.store_id
    inner join transaction_items ti
        on t.transaction_id = ti.transaction_id
    where
        month(t.transaction_date) between 1 and 6
        and year(t.transaction_date) in (2024, 2025)
    group by
        s.province,
        year(t.transaction_date)
),
year_comparison as (
    select
        province,
        sum(
            case when sales_year = 2024
            then revenue else 0 end
        ) as revenue_2024,
        sum(
            case when sales_year = 2025
            then revenue else 0 end
        ) as revenue_2025
    from provincial_sales
    group by province
)
select
    province,
    round(revenue_2024, 2) AS revenue_2024,
    round(revenue_2025, 2) AS revenue_2025,
    round(
        revenue_2025 - revenue_2024,
        2
    ) as revenue_change,
    round(
        100.0 *
        (revenue_2025 - revenue_2024)
        / revenue_2024,
        2
    ) as yoy_change_pct
from year_comparison
order by yoy_change_pct;

-- WC Store Performance:
with store_sales as (
    select
        s.store_id,
        s.store_name,
        s.format,
        year(t.transaction_date) AS sales_year,
        sum(
            ti.quantity * ti.unit_price_at_sale
        ) as revenue
    from transactions t
    inner join stores s
        on t.store_id = s.store_id
    inner join transaction_items ti
        on t.transaction_id = ti.transaction_id
    where
        s.province = 'Western Cape'
        and month(t.transaction_date) BETWEEN 1 AND 6
        and year(t.transaction_date) in (2024, 2025)
    group by
        s.store_id,
        s.store_name,
        s.format,
        year(t.transaction_date)
),
store_comparison as (
    select
        store_id,
        store_name,
        format,
        sum(
            case when sales_year = 2024
            then revenue else 0 end
        ) as revenue_2024,
        sum(
            case when sales_year = 2025
            then revenue else 0 end
        ) as revenue_2025
    from store_sales
    group by
        store_id,
        store_name,
        format
)
select
    store_id,
    store_name,
    format,
    round(revenue_2024, 2) as revenue_2024,
    round(revenue_2025, 2) as revenue_2025,
    round(
        revenue_2025 - revenue_2024,
        2
    ) as revenue_change,
    round(
        100.0 *
        (revenue_2025 - revenue_2024)
        / revenue_2024,
        2
    ) as yoy_change_pct
from store_comparison
order by revenue_change asc;

--Transactions and average basket by store:
with transaction_value as (
    select
        t.transaction_id,
        t.store_id,
        t.transaction_date,
        sum(
            ti.quantity * ti.unit_price_at_sale
        ) as basket_value,
        sum(ti.quantity) as basket_units
    from transactions t
    inner join transaction_items ti
        on t.transaction_id = ti.transaction_id
    group by
        t.transaction_id,
        t.store_id,
        t.transaction_date
),
store_metrics as (
    select
        s.store_id,
        s.store_name,
        s.format,
        year(tv.transaction_date) as sales_year,
        count(distinct tv.transaction_id) as transaction_count,
        sum(tv.basket_value) as revenue,
        avg(tv.basket_value) as avg_basket_value,
        avg(tv.basket_units) as avg_items_per_basket
    from transaction_value tv
    inner join stores s
    where
        s.province = 'Western Cape'
        and month(tv.transaction_date) BETWEEN 1 AND 6
        and year(tv.transaction_date) IN (2024, 2025)
    group by
        s.store_id,
        s.store_name,
        s.format,
        year(tv.transaction_date)
)
select *
from store_metrics
order by 
    store_name, 
    sales_year;


-- Contribution to Western Cape decline:
with store_sales as (
    select
        s.store_id,
        s.store_name,
        year(t.transaction_date) as sales_year,
        sum(
            ti.quantity * ti.unit_price_at_sale
        ) as revenue
    from transactions t
    inner join stores s
        on t.store_id = s.store_id
    inner join transaction_items ti
        on t.transaction_id = ti.transaction_id
    where
        s.province = 'Western Cape'
        and month(t.transaction_date) BETWEEN 1 AND 6
        and year(t.transaction_date) IN (2024, 2025)
    group by
        s.store_id,
        s.store_name,
        YEAR(t.transaction_date)
),
store_change as (
    select
        store_id,
        store_name,
        sum(
            case when sales_year = 2024
            then revenue else 0 end
        ) as revenue_2024,
        sum(
            case when sales_year = 2025
            then revenue else 0 end
        ) as revenue_2025
    from store_sales
    group by
        store_id,
        store_name
),
changes as (
    select
        *,
        revenue_2025 - revenue_2024 as revenue_change
    from store_change
),
wc_total as (
    select
        sum(revenue_change) as wc_total_change
    from changes
)
select
    c.store_id,
    c.store_name,
    round(c.revenue_change, 2) as revenue_change,
    round(
        100.0 * c.revenue_change / w.wc_total_change,
        2
    ) as contribution_to_wc_net_change_pct
from changes c
cross join wc_total w
order by revenue_change asc;

-- HYPOTHESIS 2: BASKET AND PURCHASING BEHAVIOUR

-- Objective:
-- Determine whether Western Cape revenue declined because
-- customers purchased fewer items and/or spent less per basket.

-- Comparison:
-- Jan-Jun 2025 versus Jan-Jun 2024
WITH transaction_baskets AS (
    SELECT
        t.transaction_id,
        t.store_id,
        t.transaction_date,
        SUM(ti.quantity * ti.unit_price_at_sale) AS basket_value,
        SUM(ti.quantity) AS basket_units
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    GROUP BY
        t.transaction_id,
        t.store_id,
        t.transaction_date
),
province_metrics AS (
    SELECT
        s.province,
        YEAR(tb.transaction_date) AS sales_year,
        COUNT(DISTINCT tb.transaction_id) AS transactions,
        SUM(tb.basket_value) AS revenue,
        SUM(tb.basket_units) AS units_sold,
        AVG(tb.basket_value) AS avg_basket_value,
        AVG(tb.basket_units) AS avg_items_per_basket
    FROM transaction_baskets tb
    INNER JOIN stores s
        ON tb.store_id = s.store_id
    WHERE
        MONTH(tb.transaction_date) BETWEEN 1 AND 6
        AND YEAR(tb.transaction_date) IN (2024, 2025)
    GROUP BY
        s.province,
        YEAR(tb.transaction_date)
)
SELECT
    province,
    sales_year,
    ROUND(revenue, 2) AS revenue,
    transactions,
    units_sold,
    ROUND(avg_basket_value, 2) AS avg_basket_value,
    ROUND(avg_items_per_basket, 2) AS avg_items_per_basket,
    ROUND(
        revenue / NULLIF(units_sold, 0),
        2
    ) AS avg_revenue_per_unit
FROM province_metrics
ORDER BY province, sales_year;


--Store-level basket drivers
WITH transaction_baskets AS (
    SELECT
        t.transaction_id,
        t.store_id,
        t.transaction_date,
        SUM(
            ti.quantity * ti.unit_price_at_sale
        ) AS basket_value,
        SUM(ti.quantity) AS basket_units
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    GROUP BY
        t.transaction_id,
        t.store_id,
        t.transaction_date
),
store_metrics AS (
    SELECT
        s.store_id,
        s.store_name,
        YEAR(tb.transaction_date) AS sales_year,
        COUNT(DISTINCT tb.transaction_id) AS transactions,
        SUM(tb.basket_value) AS revenue,
        SUM(tb.basket_units) AS units_sold,
        AVG(tb.basket_value) AS avg_basket_value,
        AVG(tb.basket_units) AS avg_items_per_basket
    FROM transaction_baskets tb
    INNER JOIN stores s
        ON tb.store_id = s.store_id
    WHERE
        s.province = 'Western Cape'
        AND MONTH(tb.transaction_date) BETWEEN 1 AND 6
        AND YEAR(tb.transaction_date) IN (2024, 2025)
    GROUP BY
        s.store_id,
        s.store_name,
        YEAR(tb.transaction_date)
),
store_comparison AS (
    SELECT
        store_id,
        store_name,
        MAX(CASE WHEN sales_year = 2024
            THEN revenue END) AS revenue_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN revenue END) AS revenue_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN transactions END) AS transactions_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN transactions END) AS transactions_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN avg_basket_value END) AS basket_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN avg_basket_value END) AS basket_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN avg_items_per_basket END) AS items_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN avg_items_per_basket END) AS items_2025
    FROM store_metrics
    GROUP BY
        store_id,
        store_name
)
SELECT
    store_name,
    ROUND(
        100.0 * (revenue_2025 - revenue_2024)
        / revenue_2024, 2
    ) AS revenue_yoy_pct,
    ROUND(
        100.0 * (transactions_2025 - transactions_2024)
        / transactions_2024, 2
    ) AS transaction_yoy_pct,
    ROUND(
        100.0 * (basket_2025 - basket_2024)
        / basket_2024, 2
    ) AS basket_yoy_pct,
    ROUND(
        100.0 * (items_2025 - items_2024)
        / items_2024, 2
    ) AS items_per_basket_yoy_pct
FROM store_comparison
ORDER BY revenue_yoy_pct;


--Category performance
WITH category_sales AS (
    SELECT
        p.category,
        YEAR(t.transaction_date) AS sales_year,
        SUM(
            ti.quantity * ti.unit_price_at_sale
        ) AS revenue,
        SUM(ti.quantity) AS units_sold
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    INNER JOIN products p
        ON ti.product_id = p.product_id
    INNER JOIN stores s
        ON t.store_id = s.store_id
    WHERE
        s.province = 'Western Cape'
        AND MONTH(t.transaction_date) BETWEEN 1 AND 6
        AND YEAR(t.transaction_date) IN (2024, 2025)
    GROUP BY
        p.category,
        YEAR(t.transaction_date)
),
category_comparison AS (
    SELECT
        category,
        SUM(CASE WHEN sales_year = 2024
         THEN revenue ELSE 0 END) AS revenue_2024,
        SUM(CASE WHEN sales_year = 2025
            THEN revenue ELSE 0 END) AS revenue_2025,
        SUM(CASE WHEN sales_year = 2024
            THEN units_sold ELSE 0 END) AS units_2024,
        SUM(CASE WHEN sales_year = 2025
            THEN units_sold ELSE 0 END) AS units_2025
    FROM category_sales
    GROUP BY category
)
SELECT
    category,
    ROUND(revenue_2024, 2) AS revenue_2024,
    ROUND(revenue_2025, 2) AS revenue_2025,
    ROUND(
        revenue_2025 - revenue_2024,
        2
    ) AS revenue_change,
    ROUND(
        100.0 * (revenue_2025 - revenue_2024)
        / revenue_2024,
        2
    ) AS revenue_yoy_pct,
    ROUND(
        100.0 * (units_2025 - units_2024)
        / units_2024,
        2
    ) AS units_yoy_pct,
    ROUND(
        revenue_2024 / units_2024,
        2
    ) AS avg_unit_value_2024,
    ROUND(
        revenue_2025 / units_2025,
        2
    ) AS avg_unit_value_2025
FROM category_comparison
ORDER BY revenue_change;

-- Category contribution by store
SELECT
    s.store_name,
    p.category,
    ROUND(
        SUM(
            CASE
                WHEN YEAR(t.transaction_date) = 2024
                THEN ti.quantity * ti.unit_price_at_sale
                ELSE 0
            END
        ),
        2
    ) AS revenue_2024,
    ROUND(
        SUM(
            CASE
                WHEN YEAR(t.transaction_date) = 2025
                THEN ti.quantity * ti.unit_price_at_sale
                ELSE 0
            END
        ),
        2
    ) AS revenue_2025
FROM transactions t
INNER JOIN transaction_items ti
    ON t.transaction_id = ti.transaction_id
INNER JOIN products p
    ON ti.product_id = p.product_id
INNER JOIN stores s
    ON t.store_id = s.store_id
WHERE
    s.province = 'Western Cape'
    AND MONTH(t.transaction_date) BETWEEN 1 AND 6
    AND YEAR(t.transaction_date) IN (2024, 2025)
GROUP BY
    s.store_name,
    p.category
ORDER BY
    s.store_name,
    p.category;


-- HYPOTHESIS 3: CUSTOMER & LOYALTY MIX
--
-- Objective:
-- Determine whether changes in loyalty customer behaviour contributed to Western Cape's revenue decline.

WITH transaction_baskets AS (
    SELECT
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date,
        SUM(
            ti.quantity * ti.unit_price_at_sale
        ) AS basket_value,
        SUM(ti.quantity) AS basket_units
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    GROUP BY
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date
),
customer_metrics AS (
    SELECT
        CASE
            WHEN tb.customer_id IS NULL
                THEN 'Unidentified'  -- Null customer IDs are retained as "Unidentified"
            ELSE c.loyalty_tier
        END AS customer_segment,
        YEAR(tb.transaction_date) AS sales_year,
        COUNT(DISTINCT tb.transaction_id) AS transactions,
        SUM(tb.basket_value) AS revenue,
        SUM(tb.basket_units) AS units_sold,
        AVG(tb.basket_value) AS avg_basket_value,
        AVG(tb.basket_units) AS avg_items_per_basket
    FROM transaction_baskets tb
    INNER JOIN stores s
        ON tb.store_id = s.store_id
    LEFT JOIN customers c
        ON tb.customer_id = c.customer_id
    WHERE
        s.province = 'Western Cape'
        AND MONTH(tb.transaction_date) BETWEEN 1 AND 6
        AND YEAR(tb.transaction_date) IN (2024, 2025)
    GROUP BY
        CASE
            WHEN tb.customer_id IS NULL
                THEN 'Unidentified'
            ELSE c.loyalty_tier
        END,
        YEAR(tb.transaction_date)
)
SELECT
    customer_segment,
    sales_year,
    ROUND(revenue, 2) AS revenue,
    transactions,
    units_sold,
    ROUND(avg_basket_value, 2) AS avg_basket_value,
    ROUND(avg_items_per_basket, 2) AS avg_items_per_basket
FROM customer_metrics
ORDER BY customer_segment, sales_year;

--YoY comparison
WITH transaction_baskets AS (
    SELECT
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date,
        SUM(ti.quantity * ti.unit_price_at_sale) AS basket_value,
        SUM(ti.quantity) AS basket_units
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    GROUP BY
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date
),
segment_metrics AS (
    SELECT
        CASE
            WHEN tb.customer_id IS NULL
                THEN 'Unidentified'
            ELSE c.loyalty_tier
        END AS customer_segment,
        YEAR(tb.transaction_date) AS sales_year,
        COUNT(DISTINCT tb.transaction_id) AS transactions,
        SUM(tb.basket_value) AS revenue,
        AVG(tb.basket_value) AS avg_basket_value,
        AVG(tb.basket_units) AS avg_items_per_basket
    FROM transaction_baskets tb
    INNER JOIN stores s
        ON tb.store_id = s.store_id
    LEFT JOIN customers c
        ON tb.customer_id = c.customer_id
    WHERE
        s.province = 'Western Cape'
        AND MONTH(tb.transaction_date) BETWEEN 1 AND 6
        AND YEAR(tb.transaction_date) IN (2024, 2025)
    GROUP BY
        CASE
            WHEN tb.customer_id IS NULL
                THEN 'Unidentified'
            ELSE c.loyalty_tier
        END,
        YEAR(tb.transaction_date)
),
comparison AS (
    SELECT
        customer_segment,
        MAX(CASE WHEN sales_year = 2024
            THEN revenue END) AS revenue_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN revenue END) AS revenue_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN transactions END) AS transactions_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN transactions END) AS transactions_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN avg_basket_value END) AS basket_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN avg_basket_value END) AS basket_2025,
        MAX(CASE WHEN sales_year = 2024
            THEN avg_items_per_basket END) AS items_2024,
        MAX(CASE WHEN sales_year = 2025
            THEN avg_items_per_basket END) AS items_2025
    FROM segment_metrics
    GROUP BY customer_segment
)
SELECT
    customer_segment,
    ROUND(revenue_2024, 2) AS revenue_2024,
    ROUND(revenue_2025, 2) AS revenue_2025,
    ROUND(
        revenue_2025 - revenue_2024,
        2
    ) AS revenue_change,
    ROUND(
        100.0 * (revenue_2025 - revenue_2024)
        / NULLIF(revenue_2024, 0),
        2
    ) AS revenue_yoy_pct,
    ROUND(
        100.0 * (transactions_2025 - transactions_2024)
        / NULLIF(transactions_2024, 0),
        2
    ) AS transaction_yoy_pct,
    ROUND(
        100.0 * (basket_2025 - basket_2024)
        / NULLIF(basket_2024, 0),
        2
    ) AS basket_yoy_pct,
    ROUND(
        100.0 * (items_2025 - items_2024)
        / NULLIF(items_2024, 0),
        2
    ) AS items_per_basket_yoy_pct
FROM comparison
ORDER BY revenue_yoy_pct;

--Customer segment by store:
WITH transaction_baskets AS (
    SELECT
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date,
        SUM(
            ti.quantity * ti.unit_price_at_sale
        ) AS basket_value
    FROM transactions t
    INNER JOIN transaction_items ti
        ON t.transaction_id = ti.transaction_id
    GROUP BY
        t.transaction_id,
        t.store_id,
        t.customer_id,
        t.transaction_date
)
SELECT
    s.store_name,
    CASE
        WHEN tb.customer_id IS NULL
            THEN 'Unidentified'
        ELSE c.loyalty_tier
    END AS customer_segment,
    ROUND(
        SUM(
            CASE
                WHEN YEAR(tb.transaction_date) = 2024
                THEN tb.basket_value
                ELSE 0
            END
        ),
        2
    ) AS revenue_2024,
    ROUND(
        SUM(
            CASE
                WHEN YEAR(tb.transaction_date) = 2025
                THEN tb.basket_value
                ELSE 0
            END
        ),
        2
    ) AS revenue_2025
FROM transaction_baskets tb
INNER JOIN stores s
    ON tb.store_id = s.store_id
LEFT JOIN customers c
    ON tb.customer_id = c.customer_id
WHERE
    s.province = 'Western Cape'
    AND MONTH(tb.transaction_date) BETWEEN 1 AND 6
    AND YEAR(tb.transaction_date) IN (2024, 2025)
GROUP BY
    s.store_name,
    CASE
        WHEN tb.customer_id IS NULL
            THEN 'Unidentified'
        ELSE c.loyalty_tier
    END
ORDER BY
    s.store_name,
    customer_segment;


-- HYPOTHESIS 4: PAP POWER PROMOTION
-- Objective:
-- Determine whether the April 2025 Pap Power promotion improved sales of the promoted product.
-- Comparison:
-- April 2025 vs April 2024

SELECT
    YEAR(t.transaction_date) AS sales_year,
    ROUND(
        SUM(ti.quantity * ti.unit_price_at_sale),
        2
    ) AS revenue,
    SUM(ti.quantity) AS units_sold,
    COUNT(DISTINCT t.transaction_id) AS transactions,
    ROUND(
        SUM(
            (ti.quantity * ti.unit_price_at_sale)
            - (ti.quantity * p.unit_cost)
        ),
        2
    ) AS gross_margin
FROM transactions t
INNER JOIN transaction_items ti
    ON t.transaction_id = ti.transaction_id
INNER JOIN products p
    ON ti.product_id = p.product_id
INNER JOIN stores s
    ON t.store_id = s.store_id
WHERE
    s.province = 'Western Cape'
    AND ti.product_id = 'P001'
    AND MONTH(t.transaction_date) = 4
    AND YEAR(t.transaction_date) IN (2024, 2025)
GROUP BY
    YEAR(t.transaction_date)
ORDER BY sales_year;

--Maize Meal category impact
SELECT
    YEAR(t.transaction_date) AS sales_year,
    ROUND(
        SUM(ti.quantity * ti.unit_price_at_sale),
        2
    ) AS maize_revenue,
    SUM(ti.quantity) AS maize_units,
    COUNT(DISTINCT t.transaction_id) AS transactions,
    ROUND(
        SUM(
            (ti.quantity * ti.unit_price_at_sale)
            - (ti.quantity * p.unit_cost)
        ),
        2
    ) AS gross_margin
FROM transactions t
INNER JOIN transaction_items ti
    ON t.transaction_id = ti.transaction_id
INNER JOIN products p
    ON ti.product_id = p.product_id
INNER JOIN stores s
    ON t.store_id = s.store_id
WHERE
    s.province = 'Western Cape'
    AND p.sub_category = 'Maize Meal'
    AND MONTH(t.transaction_date) = 4
    AND YEAR(t.transaction_date) IN (2024, 2025)
GROUP BY
    YEAR(t.transaction_date)
ORDER BY sales_year;

--Promotion by store
SELECT
    s.store_name,
    COUNT(DISTINCT t.transaction_id) AS promo_transactions,
    SUM(ti.quantity) AS promo_units,
    ROUND(
        SUM(ti.quantity * ti.unit_price_at_sale),
        2
    ) AS promo_revenue,
    ROUND(
        SUM(
            (ti.quantity * ti.unit_price_at_sale)
            - (ti.quantity * p.unit_cost)
        ),
        2
    ) AS estimated_gross_margin
FROM transactions t
INNER JOIN transaction_items ti
    ON t.transaction_id = ti.transaction_id
INNER JOIN products p
    ON ti.product_id = p.product_id
INNER JOIN stores s
    ON t.store_id = s.store_id
WHERE
    s.province = 'Western Cape'
    AND ti.product_id = 'P001'
    AND ti.discount_applied = 33.33
    AND DATE(t.transaction_date)
        BETWEEN '2025-04-01' AND '2025-04-30'
GROUP BY
    s.store_name
ORDER BY promo_units DESC;