/*
===============================================================================
Change Over Time Analysis
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.

SQL Functions Used:
    - Date Functions: DATEPART(), DATETRUNC(), FORMAT()
    - Aggregate Functions: SUM(), COUNT(), AVG()
===============================================================================
*/

-- Analyze sales performance over time

SELECT 
YEAR(order_date) AS  Order_year,
MONTH(order_date) AS  Order_Month,
SUM(sales_amount) AS total_sales,
count(distinct customer_key) AS total_customers,
sum(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL 
GROUP BY YEAR(order_date),Month(order_date)
ORDER BY YEAR(order_date) ,Month(order_date) 

/*
===============================================================================
Cumulative Analysis
===============================================================================
Purpose:
    - To calculate running totals or moving averages for key metrics.
    - To track performance over time cumulatively.
    - Useful for growth analysis or identifying long-term trends.

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
*/

--Calculate the total sales per month 
--and the running total of sales over time
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) AS moving_avg_price
FROM
(
SELECT 
DATETRUNC(YEAR,order_date) AS order_date,
sum(sales_amount) AS total_sales,
avg(price) as avg_price
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
)t

/*
===============================================================================
Performance Analysis (Year-over-Year, Month-over-Month)
===============================================================================
Purpose:
    - To measure the performance of products, customers, or regions over time.
    - For benchmarking and identifying high-performing entities.
    - To track yearly trends and growth.

SQL Functions Used:
    - LAG(): Accesses data from previous rows.
    - AVG() OVER(): Computes average values within partitions.
    - CASE: Defines conditional logic for trend analysis.
===============================================================================
*/

/* Analyze the yearly performance of products by comparing their sales 
to both average sales performance of the product and the previous year's sales performance. */

with Yearly_product_sales AS(
SELECT
year(s.order_date) AS order_year,
p.product_name,
sum(s.sales_amount) AS current_sales
FROM dbo.fact_sales s
left join dbo.dim_products p
on s.product_key = p.product_key
where s.order_date IS NOT NULL
GROUP BY
year(s.order_date),
p.product_name
)
SELECT 
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS Diff_from_avg,
case when current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0  then 'Above Average'
when current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 then 'Below Average'
else 'Average' 
end as Performance_vs_avg,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS Diff_from_previous_year,
case when current_sales -LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0  then 'increase'
when current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 then 'decrease'
else 'No change' 
end as Py_change
FROM Yearly_product_sales
ORDER BY order_year, current_sales 

/*
===============================================================================
Part-to-Whole Analysis
===============================================================================
Purpose:
    - To compare performance or metrics across dimensions or time periods.
    - To evaluate differences between categories.
    - Useful for A/B testing or regional comparisons.

SQL Functions Used:
    - SUM(), AVG(): Aggregates values for comparison.
    - Window Functions: SUM() OVER() for total calculations.
===============================================================================
*/

--which categories contribute the most overall sales ?
with cte_sales AS (
SELECT 
category,
sum(sales_amount) AS total_sales
FROM dbo.fact_sales s
left join dbo.dim_products p
on s.product_key=p.product_key
GROUP BY category
)
SELECT 
category,
total_sales,
sum(total_sales) over() overall_sales,
concat(round((cast(total_sales AS float)/sum(total_sales) over())  * 100,2),'%') AS percentage_contribution
FROM cte_sales
ORDER BY total_sales DESC

/*
===============================================================================
Data Segmentation Analysis
===============================================================================
Purpose:
    - To group data into meaningful categories for targeted insights.
    - For customer segmentation, product categorization, or regional analysis.

SQL Functions Used:
    - CASE: Defines custom segmentation logic.
    - GROUP BY: Groups data into segments.
===============================================================================
*/

/* segment products into cost ranges
and count how many products fall into each segment*/
with cte_cost_ranges AS (
SELECT
product_key,
product_name,
cost,
case when cost < 100 then 'below 100'
	 when cost between 100 and 500 then '100-500'
	 when cost between 500 and 1000 then '500-1000'
	 else 'Above 1000' 
end as cost_range
FROM dbo.dim_products
)
SELECT
cost_range,
count(product_key) AS num_products
FROM cte_cost_ranges
GROUP BY cost_range
ORDER BY num_products DESC

/* Group customers into three segments based on their spending behavior
-vip: at least 12 months of purchase history and  spending  more than $5000
-regular: at least 12 months of purchase history but spending  $5000 or less
-new: less than 12 months of purchase history*/
with cte_customer_segments AS (
SELECT 
c.customer_key,
sum(s.sales_amount) AS total_spending,
min (order_date) AS first_purchase_date,
max (order_date) AS last_purchase_date,
DATEDIFF(MONTH, min(order_date), max(order_date)) AS purchase_history_months
FROM dbo.fact_sales s
left join dbo.dim_customers c
on s.customer_key = c.customer_key
GROUP BY c.customer_key
)
SELECT 
customer_key,
total_spending,
purchase_history_months,
case when purchase_history_months >= 12 and total_spending > 5000 then 'VIP'
when purchase_history_months >= 12 and total_spending <= 5000 then 'Regular'
else 'New' 
end as customer_segment
from cte_customer_segments







