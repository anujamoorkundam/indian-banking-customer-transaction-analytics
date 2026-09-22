USE DATABASE BANKING_ANALYTICS_DB;
USE SCHEMA BANKING;
USE WAREHOUSE COMPUTE_WH;

-- Q1. What are the overall transaction KPIs?
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT CustomerID) AS total_customers,
    ROUND(SUM(TransactionAmount_INR), 2) AS total_transaction_amount,
    ROUND(AVG(TransactionAmount_INR), 2) AS avg_transaction_amount
FROM BANK_TRANSACTIONS;

-- Q2. What is the transaction distribution by gender?
SELECT
    COALESCE(CustGender, 'Unknown') AS gender,
    COUNT(*) AS total_transactions
FROM BANK_TRANSACTIONS
GROUP BY COALESCE(CustGender, 'Unknown')
ORDER BY total_transactions DESC;

-- Q3. Which age groups are most active based on transactions?
SELECT
    COALESCE(AgeGroup, 'Unknown') AS age_group,
    COUNT(*) AS total_transactions,
    ROUND(SUM(TransactionAmount_INR), 2) AS total_transaction_amount
FROM BANK_TRANSACTIONS
GROUP BY COALESCE(AgeGroup, 'Unknown')
ORDER BY total_transactions DESC;

-- Q4. Which are the top 10 locations by total transaction amount?
SELECT
    COALESCE(CustLocation, 'Unknown') AS location,
    COUNT(*) AS total_transactions,
    ROUND(SUM(TransactionAmount_INR), 2) AS total_transaction_amount
FROM BANK_TRANSACTIONS
GROUP BY COALESCE(CustLocation, 'Unknown')
ORDER BY total_transaction_amount DESC
LIMIT 10;

-- Q5. At what time of day are customers most active?
SELECT
    TimeOfDay,
    COUNT(*) AS total_transactions,
    ROUND(SUM(TransactionAmount_INR), 2) AS total_transaction_amount,
    ROUND(AVG(TransactionAmount_INR), 2) AS avg_transaction_amount
FROM BANK_TRANSACTIONS
GROUP BY TimeOfDay
ORDER BY total_transactions DESC;

-- Q6. Who are the top 10 customers by total transaction value?
WITH customer_spending AS (
    SELECT
        CustomerID,
        COUNT(*) AS transaction_count,
        SUM(TransactionAmount_INR) AS total_spent
    FROM BANK_TRANSACTIONS
    GROUP BY CustomerID
)

SELECT
    CustomerID,
    transaction_count,
    ROUND(total_spent, 2) AS total_spent,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) AS customer_rank
FROM customer_spending
QUALIFY customer_rank <= 10
ORDER BY customer_rank;

-- Q7. Which customers made more than one transaction, and what is their average transaction value?
SELECT
    CustomerID,
    COUNT(*) AS transaction_count,
    ROUND(SUM(TransactionAmount_INR), 2) AS total_spent,
    ROUND(AVG(TransactionAmount_INR), 2) AS avg_transaction_amount
FROM BANK_TRANSACTIONS
GROUP BY CustomerID
HAVING COUNT(*) > 1
ORDER BY transaction_count DESC, total_spent DESC;

-- Q8. Find month-over-month growth in transaction amount
-- NOTE : October is a partial month, so the MoM result should not be interpreted as a true full-month business decline.
WITH monthly_transactions AS (
    SELECT
        DATE_TRUNC('MONTH', TransactionDate) AS transaction_month,
        SUM(TransactionAmount_INR) AS total_transaction_amount
    FROM BANK_TRANSACTIONS
    GROUP BY DATE_TRUNC('MONTH', TransactionDate)
),

previous_month_transactions AS (
    SELECT *,
        LAG(total_transaction_amount, 1) OVER (ORDER BY transaction_month) AS previous_month_amount
    FROM monthly_transactions
)

SELECT *,
    ROUND((total_transaction_amount - previous_month_amount) * 100.0 / NULLIF(previous_month_amount, 0),2) AS mom_growth_percentage
FROM previous_month_transactions
ORDER BY transaction_month;

-- Q9. Classify transactions based on transaction amount
SELECT
    TransactionID,
    CustomerID,
    TransactionAmount_INR,
    CASE
        WHEN TransactionAmount_INR < 500 THEN 'Low Value'
        WHEN TransactionAmount_INR < 5000 THEN 'Medium Value'
        WHEN TransactionAmount_INR < 50000 THEN 'High Value'
        ELSE 'Very High Value'
    END AS transaction_category
FROM BANK_TRANSACTIONS
ORDER BY TransactionAmount_INR DESC;

-- Q10. Find the highest-spending customer in each location
WITH customer_location_spending AS (
    SELECT
        CustLocation,
        CustomerID,
        SUM(TransactionAmount_INR) AS total_spent
    FROM BANK_TRANSACTIONS
    WHERE CustLocation IS NOT NULL
    GROUP BY CustLocation, CustomerID
),

ranked_customers AS (
    SELECT *,
        DENSE_RANK() OVER (
            PARTITION BY CustLocation
            ORDER BY total_spent DESC
        ) AS customer_rank
    FROM customer_location_spending
)

SELECT *
FROM ranked_customers
WHERE customer_rank = 1
ORDER BY total_spent DESC;

-- Q11. Find customers whose total spending is above the average customer spending
WITH customer_spending AS (
    SELECT
        CustomerID,
        SUM(TransactionAmount_INR) AS total_spent
    FROM BANK_TRANSACTIONS
    GROUP BY CustomerID
)

SELECT
    CustomerID,
    ROUND(total_spent, 2) AS total_spent
FROM customer_spending
WHERE total_spent > (
    SELECT AVG(total_spent)
    FROM customer_spending
)
ORDER BY total_spent DESC;

-- Q12. Find each location's percentage contribution to total transaction amount
WITH location_spending AS (
    SELECT
        CustLocation,
        SUM(TransactionAmount_INR) AS location_amount
    FROM BANK_TRANSACTIONS
    WHERE CustLocation IS NOT NULL
    GROUP BY CustLocation
),

total_spending AS (
    SELECT
        SUM(TransactionAmount_INR) AS total_amount
    FROM BANK_TRANSACTIONS
)

SELECT
    l.CustLocation,
    ROUND(l.location_amount, 2) AS location_amount,
    ROUND(l.location_amount * 100.0 / NULLIF(t.total_amount, 0),2) AS contribution_percentage
FROM location_spending l
CROSS JOIN total_spending t
ORDER BY contribution_percentage DESC;

-- Q13. Find the cumulative transaction amount over time
WITH daily_transactions AS (
    SELECT
        TransactionDate,
        ROUND(SUM(TransactionAmount_INR), 2) AS daily_transaction_amount
    FROM BANK_TRANSACTIONS
    GROUP BY TransactionDate
)

SELECT
    TransactionDate,
    daily_transaction_amount,
    ROUND(
        SUM(daily_transaction_amount) OVER (
            ORDER BY TransactionDate
        ),
        2
    ) AS cumulative_transaction_amount
FROM daily_transactions
ORDER BY TransactionDate;

-- Q14. Find locations that together contribute at least 80% of total transaction value
WITH location_spending AS (
    SELECT
        CustLocation,
        SUM(TransactionAmount_INR) AS total_transaction_amount
    FROM BANK_TRANSACTIONS
    WHERE CustLocation IS NOT NULL
    GROUP BY CustLocation
),

location_contribution AS (
    SELECT
        CustLocation,
        total_transaction_amount,
        SUM(total_transaction_amount) OVER (ORDER BY total_transaction_amount DESC) AS cumulative_amount,
        SUM(total_transaction_amount) OVER () AS overall_amount
    FROM location_spending
),

percentage_calculation AS (
    SELECT
        CustLocation,
        total_transaction_amount,
        cumulative_amount,
        overall_amount,
        ROUND(cumulative_amount * 100.0 / NULLIF(overall_amount, 0),2) AS cumulative_percentage,
        LAG(cumulative_amount * 100.0 / NULLIF(overall_amount, 0)) OVER (ORDER BY total_transaction_amount DESC) 
            AS previous_cumulative_percentage
    FROM location_contribution
)

SELECT
    CustLocation,
    ROUND(total_transaction_amount, 2) AS total_transaction_amount,
    cumulative_percentage
FROM percentage_calculation
WHERE cumulative_percentage <= 80 OR previous_cumulative_percentage < 80
ORDER BY total_transaction_amount DESC;

-- Q15. Find the highest transaction amount age group in each location
WITH age_location_spending AS (
    SELECT
        CustLocation,
        AgeGroup,
        SUM(TransactionAmount_INR) AS total_transaction_amount
    FROM BANK_TRANSACTIONS
    WHERE CustLocation IS NOT NULL AND AgeGroup IS NOT NULL
    GROUP BY CustLocation, AgeGroup
),

ranked_age_groups AS (
    SELECT
        CustLocation,
        AgeGroup,
        total_transaction_amount,
        DENSE_RANK() OVER (PARTITION BY CustLocation ORDER BY total_transaction_amount DESC) AS age_group_rank
    FROM age_location_spending
)

SELECT
    CustLocation,
    AgeGroup,
    ROUND(total_transaction_amount, 2) AS total_transaction_amount
FROM ranked_age_groups
WHERE age_group_rank = 1
ORDER BY total_transaction_amount DESC;

-- Q16. Which location reached 1,000 transactions fastest within the available data period?
WITH ranked_transactions AS (
    SELECT
        CustLocation,
        TransactionDate,
        TransactionID,
        ROW_NUMBER() OVER (PARTITION BY CustLocation ORDER BY TransactionDate, TransactionID) AS transaction_number
    FROM BANK_TRANSACTIONS
    WHERE CustLocation IS NOT NULL
),

location_milestones AS (
    SELECT
        CustLocation,
        MIN(TransactionDate) AS first_transaction_date,
        MAX(CASE WHEN transaction_number = 1000 THEN TransactionDate END) AS transaction_1000_date
    FROM ranked_transactions
    GROUP BY CustLocation
)

SELECT
    CustLocation,
    first_transaction_date,
    transaction_1000_date,
    DATEDIFF('DAY', first_transaction_date, transaction_1000_date) AS days_to_1000_transactions
FROM location_milestones
WHERE transaction_1000_date IS NOT NULL
ORDER BY days_to_1000_transactions;






