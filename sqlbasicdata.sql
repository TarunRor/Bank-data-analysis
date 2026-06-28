Q1. What is the Total Loan Applications count?
SELECT COUNT(id) AS Total_Applications 
FROM bank_loan_data;

Q2. What is the Total Funded Amount?
SELECT SUM(loan_amount) AS Total_Funded_Amount 
FROM bank_loan_data;

Q3. What is the Total Amount Received from borrowers?
SELECT SUM(total_payment) AS Total_Amount_Collected 
FROM bank_loan_data;

Q4. What is the Average Interest Rate across all loans?
SELECT ROUND(AVG(int_rate), 4) * 100 AS Avg_Int_Rate 
FROM bank_loan_data;

Q5. What is the Average Debt-to-Income (DTI) Ratio?
SELECT ROUND(AVG(dti), 4) * 100 AS Avg_DTI 
FROM bank_loan_data;

Q6. Good Loan vs. Bad Loan Percentage 
(Assuming 'Fully Paid' and 'Current' represent Good Loans)
SELECT
    ROUND((COUNT(CASE WHEN loan_status = 'Fully Paid' OR loan_status = 'Current' THEN id END) * 100.0) / 
    COUNT(id), 2) AS Good_Loan_Percentage
FROM bank_loan_data;

Q7. What is the status of loans issued (Grid view with grand totals)?
SELECT
    loan_status,
    COUNT(id) AS Total_Loan_Applications,
    SUM(loan_amount) AS Total_Funded_Amount,
    SUM(total_payment) AS Total_Amount_Received,
    ROUND(AVG(int_rate * 100), 2) AS Average_Interest_Rate,
    ROUND(AVG(dti * 100), 2) AS Average_DTI
FROM bank_loan_data
GROUP BY loan_status
ORDER BY Total_Funded_Amount DESC;
