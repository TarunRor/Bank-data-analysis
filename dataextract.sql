
--Q1. Month-over-Month (MoM) Growth Rate of Loan Defaults (Using LAG Window Function)
WITH MonthlyDefaults AS (
    SELECT 
        DATE_FORMAT(issue_date, '%Y-%m') AS loan_month,
        COUNT(id) AS default_count,
        SUM(loan_amount) AS total_lost_amount
    FROM bank_loan_data
    WHERE loan_status = 'Charged Off'
    GROUP BY DATE_FORMAT(issue_date, '%Y-%m')
),
MoM_Calc AS (
    SELECT 
        loan_month,
        default_count,
        total_lost_amount,
        LAG(default_count) OVER(ORDER BY loan_month) AS prev_month_defaults
    FROM MonthlyDefaults
)
SELECT 
    loan_month,
    default_count,
    prev_month_defaults,
    ROUND(((default_count - prev_month_defaults) / prev_month_defaults) * 100, 2) AS MoM_Growth_Pct,
    total_lost_amount
FROM MoM_Calc
WHERE prev_month_defaults IS NOT NULL;




--Q2. Rolling 3-Month Moving Average of Loan Disbursal (Using Window Frames)
--Business Value: Smooths out monthly volatility to show the true trend of loan issuance for the overview dashboard line chart.
WITH MonthlyVolume AS (
    SELECT 
        DATE_FORMAT(issue_date, '%Y-%m') AS issue_month,
        SUM(loan_amount) AS total_funded
    FROM bank_loan_data
    GROUP BY issue_month
)
SELECT 
    issue_month,
    total_funded AS actual_monthly_funded,
    ROUND(AVG(total_funded) OVER(
        ORDER BY issue_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3_month_avg
FROM MonthlyVolume;


