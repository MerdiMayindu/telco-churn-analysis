-- 1. How many rows?
-- Finding: The dataset contains 7,043 customers, one row per customer.
SELECT COUNT (*)
FROM telco_churn;

-- 2. Any duplicate customers?
-- Finding: 7,043 unique customer IDs, matching the 7,043 rows,
-- so there are no duplicate customers.
SELECT COUNT (DISTINCT customerID)
FROM telco_churn;

--3. How many customers left vs stayed?
-- Finding: Of the 7,043 customers, 5,174 stayed and 1,869 left,
-- an overall churn rate of 26.5% (roughly 1 in 4 customers).
SELECT Churn, count (*) 
FROM telco_churn
GROUP BY Churn;

-- 4. Any blank TotalCharges values?
-- Finding: 11 of the 7,043 rows have a missing (NULL) TotalCharges value.
-- All 11 have tenure = 0, meaning they are brand-new customers
-- who haven't received a bill yet, so it's not an error in the data.
SELECT customerID, tenure, MonthlyCharges, TotalCharges
FROM telco_churn
WHERE trim (TotalCharges) = '' OR TotalCharges IS NULL;

-- 5. Create a clean view of the data for analysis
-- Finding: Converted text columns to numbers, set the 11 missing
-- TotalCharges values to 0 (new customers, tenure = 0), and added
-- a 1/0 churn flag so churn rates can be calculated easily.
CREATE VIEW churn_clean AS 
SELECT *,
CAST(tenure AS INTEGER) AS tenure_months,
CAST(MonthlyCharges AS REAL) AS monthly_charges,
CASE WHEN TotalCharges IS NULL OR TRIM(TotalCharges) = '' THEN 0
ELSE CAST(TotalCharges AS REAL) END AS total_Charges,
CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END AS churned
FROM telco_churn;

-- 6. What is the overall churn rate?
-- Finding: 1,869 of 7,043 customers churned, an overall churn rate of 26.5%.
-- This is the baseline used to judge every group below.
SELECT COUNT(*) AS customers,
  SUM(churned) AS churners,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean;

-- 7. Churn rate by contract type
-- Finding: Month-to-month customers churn at ~43%, compared with ~11% on
-- one-year and ~3% on two-year contracts. Contract length is the
-- strongest single driver of churn.
SELECT Contract,
  COUNT(*) AS customers,
  SUM(churned) AS churners,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
GROUP BY Contract
ORDER BY churn_rate_pct DESC;

-- 8. Churn rate by payment method
-- Finding: Electronic check customers churn at ~45%, roughly 3x the rate
-- of customers on automatic bank transfer or credit card (~15-17%).
SELECT PaymentMethod,
  COUNT(*) AS customers,
  SUM(churned) AS churners,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;

-- 9. Churn rate by internet service
-- Finding: Fibre optic customers churn at ~42%, double the DSL rate (~19%).
-- Fibre is the premium product, so this suggests a price or service
-- quality issue worth investigating.
SELECT InternetService,
  COUNT(*) AS customers,
  SUM(churned) AS churners,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;

-- 10. Do customers without tech support or online security churn more?
-- Finding: Customers with neither add-on churn far more than those with
-- both. Add-ons appear to make customers "stickier".
SELECT TechSupport, OnlineSecurity,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
WHERE InternetService <> 'No'
GROUP BY TechSupport, OnlineSecurity
ORDER BY churn_rate_pct DESC;

-- 11. Do senior citizens churn more?
-- Finding: Senior citizens churn at ~42% vs ~24% for non-seniors.
SELECT CASE WHEN SeniorCitizen = 1 THEN 'Senior' ELSE 'Non-senior' END AS age_group,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
GROUP BY age_group
ORDER BY churn_rate_pct DESC;

-- 12. Churn rate by tenure band
-- Finding: Nearly half of customers in their first year churn (~47%),
-- falling to under 10% after 4 years. The first 12 months are the
-- highest-risk period.
SELECT CASE
    WHEN tenure_months <= 12 THEN '1. 0-12 months'
    WHEN tenure_months <= 24 THEN '2. 13-24 months'
    WHEN tenure_months <= 48 THEN '3. 25-48 months'
    ELSE '4. 49+ months'
  END AS tenure_band,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
GROUP BY tenure_band
ORDER BY tenure_band;

-- 13. Average monthly charges: churned vs stayed
-- Finding: Churned customers paid ~74 per month on average vs ~61 for
-- those who stayed. Higher bills are linked to higher churn.
SELECT Churn,
  ROUND(AVG(monthly_charges), 2) AS avg_monthly_charges
FROM churn_clean
GROUP BY Churn;

-- 14. How much monthly revenue is lost to churn?
-- Finding: Churned customers accounted for ~139k in monthly revenue,
-- roughly 30% of total monthly revenue, despite being 26.5% of customers.
SELECT ROUND(SUM(CASE WHEN churned = 1 THEN monthly_charges ELSE 0 END), 2) AS revenue_lost,
  ROUND(SUM(monthly_charges), 2) AS total_revenue,
  ROUND(100.0 * SUM(CASE WHEN churned = 1 THEN monthly_charges ELSE 0 END)
        / SUM(monthly_charges), 1) AS pct_revenue_lost
FROM churn_clean;

-- 15. Highest-risk group: month-to-month + fibre + electronic check
-- Finding: 1,307 customers fall into this group, with a churn rate of
-- 60.4%, more than double the 26.5% baseline. This group alone accounts
-- for 789 of the 1,869 churners (42%), despite being under 19% of
-- customers. This is the clearest target for a retention campaign.
SELECT COUNT(*) AS customers,
  SUM(churned) AS churners,
  ROUND(100.0 * SUM(churned) / COUNT(*), 1) AS churn_rate_pct
FROM churn_clean
WHERE Contract = 'Month-to-month'
  AND InternetService = 'Fiber optic'
  AND PaymentMethod = 'Electronic check';
  
-- Recommendations & Summary
-- 1. Contract length is the biggest churn driver. Offer incentives, a good 
--    exmaple of this would be by offering discounts or free add-ons to move 
--    month-to-month customers onto 12-month contracts.
-- 2. From the data, the first year seems to be the danger zone. Introduce an early-life retention
--    programme with check-ins at months 1, 3 and 6 would prove beneficial
-- 3. Target the highest-risk group (month-to-month, fibre, electronic
--    check), which makes up 42% of all churners. Encourage switching to
--    automatic payment and review fibre pricing and service quality.