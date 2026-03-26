-- =========================================
-- H1B VISA DATA CLEANING & TRANSFORMAYION
-- =========================================

-- STEP 1: SELECT REQUIRED COLUMNS (Q1)

CREATE TABLE h1b_q1_clean AS 
SELECT 
    CASE_NUMBER,
    CASE_STATUS,
    RECEIVED_DATE,
    DECISION_DATE,
    VISA_CLASS,
    JOB_TITLE,
    SOC_TITLE,
    SOC_CODE,
    FULL_TIME_POSITION,
    EMPLOYER_NAME,
    EMPLOYER_COUNTRY,
    EMPLOYER_STATE,
    EMPLOYER_CITY,
    EMPLOYER_POSTAL_CODE,
    AGENT_REPRESENTING_EMPLOYER,
    PREVAILING_WAGE,
    WAGE_RATE_OF_PAY_FROM,
    WAGE_RATE_OF_PAY_TO,
    WAGE_UNIT_OF_PAY,
    WORKSITE_CITY,
    WORKSITE_COUNTY,
    WORKSITE_STATE,
    WORKSITE_POSTAL_CODE,
    TOTAL_WORKER_POSITIONS,
    NAICS_CODE
FROM h1b_q1;


-- STEP 2: STANDARDIZE CASE STATUS

UPDATE h1b_q1_clean
SET case_status = 'Withdrawn'
WHERE case_status = 'Certified - Withdrawn';


-- STEP 3: CLEAN FULL TIME POSITION

UPDATE h1b_q1_clean
SET FULL_TIME_POSITION = NULL
WHERE FULL_TIME_POSITION NOT IN ('Y','N');

-- STEP 4: CLEAN TOTAL WORKER POSITIONS

UPDATE h1b_q1_clean
SET total_worker_positions = 
    CASE 
        WHEN total_worker_positions REGEXP '^[0-9]+$' 
        THEN CAST(total_worker_positions AS SIGNED)
        ELSE 0
    END;

ALTER TABLE h1b_q1_clean
MODIFY total_worker_positions INT;

-- STEP 5: CLEAN WAGE COLUMNS

UPDATE h1b_q1_clean 
SET WAGE_RATE_OF_PAY_FROM = REPLACE(REPLACE(WAGE_RATE_OF_PAY_FROM,'$',''),',',''),
    WAGE_RATE_OF_PAY_TO   = REPLACE(REPLACE(WAGE_RATE_OF_PAY_TO,'$',''),',',''),
    PREVAILING_WAGE       = REPLACE(REPLACE(PREVAILING_WAGE,'$',''),',','');

UPDATE h1b_q1_clean
SET WAGE_RATE_OF_PAY_FROM = 
    CASE WHEN TRIM(WAGE_RATE_OF_PAY_FROM) REGEXP '^[0-9.]+$'
         THEN CAST(WAGE_RATE_OF_PAY_FROM AS DECIMAL(10,2))
         ELSE NULL END,
    WAGE_RATE_OF_PAY_TO = 
    CASE WHEN TRIM(WAGE_RATE_OF_PAY_TO) REGEXP '^[0-9.]+$'
         THEN CAST(WAGE_RATE_OF_PAY_TO AS DECIMAL(10,2))
         ELSE NULL END,
    PREVAILING_WAGE = 
    CASE WHEN TRIM(PREVAILING_WAGE) REGEXP '^[0-9.]+$'
         THEN CAST(PREVAILING_WAGE AS DECIMAL(10,2))
         ELSE NULL END;

ALTER TABLE h1b_q1_clean 
MODIFY WAGE_RATE_OF_PAY_FROM DECIMAL(10,2),
MODIFY WAGE_RATE_OF_PAY_TO DECIMAL(10,2),
MODIFY PREVAILING_WAGE DECIMAL(10,2);

-- =========================================
-- STEP 6: CREATE YEARLY SALARY
-- =========================================
ALTER TABLE h1b_q1_clean
ADD yearly_salary DECIMAL(12,2);

UPDATE h1b_q1_clean
SET yearly_salary = 
CASE 
    WHEN wage_unit_of_pay = 'Year' THEN wage_rate_of_pay_from
    WHEN wage_unit_of_pay = 'Month' THEN wage_rate_of_pay_from * 12
    WHEN wage_unit_of_pay = 'Week' THEN wage_rate_of_pay_from * 52
    WHEN wage_unit_of_pay = 'Bi-Weekly' THEN wage_rate_of_pay_from * 26
    WHEN wage_unit_of_pay = 'Hour' THEN wage_rate_of_pay_from * 2080
    ELSE NULL
END;


-- STEP 7: STANDARDIZE EMPLOYER NAME

UPDATE h1b_q1_clean
SET employer_name = UPPER(employer_name);


-- STEP 8: ADD QUARTER COLUMN


ALTER TABLE h1b_q1_clean
ADD quarter_2025 VARCHAR(5);

UPDATE h1b_q1_clean
SET quarter_2025 = 'Q1';


-- =========================================
--  REPEAT SAME STEPS FOR Q2, Q3, Q4
-- (Only change table name + quarter value)
-- =========================================



-- STEP 9: COMBINE ALL QUARTERS


CREATE TABLE h1b_final_data AS
SELECT * FROM h1b_q1_clean
UNION ALL
SELECT * FROM h1b_q2_clean
UNION ALL
SELECT * FROM h1b_q3_clean
UNION ALL
SELECT * FROM h1b_q4_clean;

-- STEP 10: FINAL CHECK


SELECT COUNT(*) AS total_records
FROM h1b_final_data;

SELECT DISTINCT quarter_2025
FROM h1b_final_data;



-- ANALYSIS QUERIES - H1B FINAL DATA




-- 1. TOTAL APPLICATIONS
-- Purpose: Get total number of H1B applications

SELECT COUNT(*) AS total_applications
FROM h1b_final_data;




-- 2. CASE STATUS DISTRIBUTION
-- Purpose: Understand approval, denial, withdrawn trends

SELECT case_status, COUNT(*) AS total
FROM h1b_final_data
GROUP BY case_status
ORDER BY total DESC;



-- 3. TOP 10 EMPLOYERS
-- Purpose: Identify companies sponsoring most H1B visa
SELECT employer_name, COUNT(*) AS total_cases
FROM h1b_final_data
GROUP BY employer_name
ORDER BY total_cases DESC
LIMIT 10;


-- 4. TOP STATES BY JOB COUNT
-- Purpose: Identify states with highest H1B job opportunities


SELECT worksite_state, COUNT(*) AS total_jobs
FROM h1b_final_data
GROUP BY worksite_state
ORDER BY total_jobs DESC
LIMIT 10;


-- 5. TOP JOB TITLES BY AVERAGE SALARY
-- Purpose: Find highest paying job roles

SELECT job_title, 
       ROUND(AVG(yearly_salary), 2) AS avg_salary
FROM h1b_final_data
WHERE yearly_salary IS NOT NULL
GROUP BY job_title
ORDER BY avg_salary DESC
LIMIT 10;


-- 6. VISA CLASS DISTRIBUTION
-- Purpose: Analyze types of visa applications

SELECT visa_class, COUNT(*) AS total
FROM h1b_final_data
GROUP BY visa_class;




-- 7. AVERAGE SALARY BY STATE
-- Purpose: Identify states offering highest salaries

SELECT worksite_state, 
       ROUND(AVG(yearly_salary), 2) AS avg_salary
FROM h1b_final_data
GROUP BY worksite_state
ORDER BY avg_salary DESC
LIMIT 10;




-- 8. QUARTERLY TREND
-- Purpose: Analyze number of applications per quarter


SELECT quarter_2025, COUNT(*) AS total_cases
FROM h1b_final_data
GROUP BY quarter_2025
ORDER BY total_cases;




-- 9. CASE STATUS SUMMARY (RECHECK)
-- Purpose: Validate distribution of case statuses


SELECT case_status, COUNT(*) 
FROM h1b_final_data
GROUP BY case_status;


-- 10. FULL-TIME VS PART-TIME
-- Purpose: Understand job type distribution
SELECT full_time_position, COUNT(*) AS total
FROM h1b_final_data
GROUP BY full_time_position;


-- APPROVAL RATE (AFTER CLEANING)
-- Purpose: Calculate percentage of approved applications

SELECT 
    ROUND(
        SUM(CASE WHEN case_status = 'Certified' THEN 1 ELSE 0 END) * 100.0 
        / COUNT(*), 
    2
    ) AS approval_rate_percentage
FROM h1b_final_data;
