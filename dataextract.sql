
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


--Q2. DTI (Debt-to-Income) Risk Quartiles and Default Correlation (Using NTILE)
WITH DTITiers AS (
    SELECT 
        id,
        loan_status,
        loan_amount,
        NTILE(4) OVER (ORDER BY dti) AS dti_quartile
    FROM bank_loan_data
    WHERE dti IS NOT NULL
)
SELECT 
    dti_quartile,
    COUNT(id) AS total_loans_in_tier,
    SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND((SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) / COUNT(id)) * 100, 2) AS tier_default_rate_pct
FROM DTITiers
GROUP BY dti_quartile
ORDER BY dti_quartile;


--Q3. The Pareto Principle (80/20 Rule) of State Funding (Using Cumulative Window Functions)

WITH StateTotals AS (
    SELECT address_state, SUM(loan_amount) AS state_funded
    FROM bank_loan_data
    GROUP BY address_state
),
TotalFunding AS (
    SELECT SUM(state_funded) AS grand_total FROM StateTotals
),
CumulativeTotals AS (
    SELECT 
        st.address_state, 
        st.state_funded,
        SUM(st.state_funded) OVER(ORDER BY st.state_funded DESC) AS running_total,
        tf.grand_total
    FROM StateTotals st
    CROSS JOIN TotalFunding tf
)
SELECT 
    address_state, 
    state_funded, 
    ROUND((running_total / grand_total) * 100, 2) AS cumulative_pct_of_total
FROM CumulativeTotals
WHERE (running_total / grand_total) <= 0.85 -- Grabs the states making up ~85% of total portfolio
ORDER BY state_funded DESC;


--Q4. Rolling 3-Month Moving Average of Loan Disbursal (Using Window Frames)
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


--Q5. Finding the Highest Risk Loan Purpose for EACH State (Using DENSE_RANK)
--Business Value: Allows state managers to see exactly which loan purpose (e.g., 'Small Business', 'Medical') is failing the most in their specific region.
WITH StatePurposeRisk AS (
    SELECT 
        address_state,
        purpose,
        COUNT(id) AS total_loans,
        SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) AS defaulted_loans,
        (SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) / COUNT(id)) * 100 AS default_rate
    FROM bank_loan_data
    GROUP BY address_state, purpose
    HAVING total_loans > 50 -- Filters out statistically insignificant sample sizes
),
RankedRisk AS (
    SELECT 
        address_state,
        purpose,
        total_loans,
        ROUND(default_rate, 2) AS default_rate_pct,
        DENSE_RANK() OVER(PARTITION BY address_state ORDER BY default_rate DESC) AS risk_rank
    FROM StatePurposeRisk
)
SELECT 
    address_state, 
    purpose AS riskiest_loan_purpose, 
    total_loans, 
    default_rate_pct
FROM RankedRisk
WHERE risk_rank = 1
ORDER BY default_rate_pct DESC;


--Q6. Portfolio Recovery Rate by Interest Rate Bands (Using CASE and Aggregations)
--Business Value: Determines if the higher interest charged on risky loans actually offsets the losses from defaults.
WITH IntRateBands AS (
    SELECT 
        CASE 
            WHEN int_rate <= 0.10 THEN '1. Low (<=10%)'
            WHEN int_rate > 0.10 AND int_rate <= 0.15 THEN '2. Medium (10%-15%)'
            WHEN int_rate > 0.15 AND int_rate <= 0.20 THEN '3. High (15%-20%)'
            ELSE '4. Very High (>20%)'
        END AS int_rate_band,
        loan_amount,
        total_payment
    FROM bank_loan_data
)
SELECT 
    int_rate_band,
    COUNT(*) AS total_loans_issued,
    SUM(loan_amount) AS total_funded,
    SUM(total_payment) AS total_recovered,
    ROUND((SUM(total_payment) / SUM(loan_amount)) * 100, 2) AS recovery_rate_pct
FROM IntRateBands
GROUP BY int_rate_band
ORDER BY int_rate_band;