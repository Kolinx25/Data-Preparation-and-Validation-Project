-- STEP 1: CREATE THE DATABASE AND RAW TABLE
-- Create a new database for this assignment
CREATE DATABASE EmpDB;

-- Select the database so all queries run inside EmpDB
USE EmpDB;

-- Create a raw table to hold the messy dataset
-- All columns are VARCHAR to prevent import errors
-- because some numeric columns contain text values
CREATE TABLE employment_raw
(
    person_id VARCHAR(100),
    name VARCHAR(100),
    gender VARCHAR(100),
    age VARCHAR(100),
    education_years VARCHAR(100),
    region VARCHAR(100),
    employment_status VARCHAR(100),
    industry VARCHAR(100),
    hours_worked_per_week VARCHAR(100),
    monthly_income VARCHAR(100),
    job_search_active VARCHAR(100),
    survey_source VARCHAR(100)
);


-- STEP 2: IMPORT THE RAW CSV FILE

-- Import the messy CSV file into the employment_raw table
-- FIRSTROW = 2 skips the header row
BULK INSERT employment_raw
FROM 'C:\Users\HP\Downloads\02_employment_messy.csv'
WITH (
    DATAFILETYPE  = 'char',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    FIRSTROW        = 2,
    TABLOCK
);

-- Confirm total rows imported
SELECT COUNT(*) AS total_rows
FROM employment_raw;

-- Check for blank strings across all columns
SELECT
    SUM(CASE WHEN TRIM(person_id)             = '' THEN 1 ELSE 0 END) AS blank_personid,
    SUM(CASE WHEN TRIM(name)                  = '' THEN 1 ELSE 0 END) AS blank_name,
    SUM(CASE WHEN TRIM(gender)                = '' THEN 1 ELSE 0 END) AS blank_gender,
    SUM(CASE WHEN TRIM(age)                   = '' THEN 1 ELSE 0 END) AS blank_age,
    SUM(CASE WHEN TRIM(education_years)       = '' THEN 1 ELSE 0 END) AS blank_education,
    SUM(CASE WHEN TRIM(region)                = '' THEN 1 ELSE 0 END) AS blank_region,
    SUM(CASE WHEN TRIM(employment_status)     = '' THEN 1 ELSE 0 END) AS blank_emp_status,
    SUM(CASE WHEN TRIM(industry)              = '' THEN 1 ELSE 0 END) AS blank_industry,
    SUM(CASE WHEN TRIM(hours_worked_per_week) = '' THEN 1 ELSE 0 END) AS blank_hours,
    SUM(CASE WHEN TRIM(monthly_income)        = '' THEN 1 ELSE 0 END) AS blank_income,
    SUM(CASE WHEN TRIM(job_search_active)     = '' THEN 1 ELSE 0 END) AS blank_job_search,
    SUM(CASE WHEN TRIM(survey_source)         = '' THEN 1 ELSE 0 END) AS blank_survey
FROM employment_raw;

-- STEP 3: VARIABLE 1 - PERSON_ID
-- Check for duplicate records and missing IDs

-- Check for NULL person_id values
SELECT COUNT(*) AS null_personid
FROM employment_raw
WHERE person_id IS NULL;

-- Check for fully duplicated rows (all columns identical)
SELECT
    person_id, name, gender, age, education_years, region,
    employment_status, industry, hours_worked_per_week,
    monthly_income, job_search_active, survey_source,
    COUNT(*) AS duplicate_count
FROM employment_raw
GROUP BY
    person_id, name, gender, age, education_years, region,
    employment_status, industry, hours_worked_per_week,
    monthly_income, job_search_active, survey_source
HAVING COUNT(*) > 1;
-- Found: 40 fully duplicated rows

-- Remove duplicate rows, keeping only the first occurrence
-- ROW_NUMBER assigns 1 to the first row, 2+ to duplicates
-- We delete any row where the number is greater than 1
WITH
    CTE
    AS
    (
        SELECT *,
            ROW_NUMBER() OVER (
               PARTITION BY person_id, name, gender, age,
                            education_years, region, employment_status,
                            industry, hours_worked_per_week,
                            monthly_income, job_search_active, survey_source
               ORDER BY (SELECT NULL)
           ) AS row_num
        FROM employment_raw
    )
DELETE FROM CTE WHERE row_num > 1;

-- Confirm duplicates have been removed
SELECT COUNT(*) AS total_rows_after_deduplication
FROM employment_raw;


-- STEP 4: VARIABLE 2 - NAME
-- Check for missing or blank names
-- Check for blank names (empty strings imported from CSV)
SELECT COUNT(*) AS blank_names
FROM employment_raw
WHERE TRIM(name) = '';



-- STEP 5: VARIABLE 3 - GENDER
-- Issues found:
-- (a) Inconsistent labels: Male, male, M, Female, female, F
-- (b) Name-gender mismatches: female names coded as Male and vice versa

-- First, see all unique gender values in the raw data
SELECT gender, COUNT(*) AS frequency
FROM employment_raw
GROUP BY gender
ORDER BY frequency DESC;

-- Fix (a): Standardise all gender labels to 'Male' or 'Female'
-- UPPER and TRIM handle any extra spaces or case differences
UPDATE employment_raw
SET gender =
    CASE
        WHEN UPPER(TRIM(gender)) IN ('M', 'MALE')   THEN 'Male'
        WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'Female'
        ELSE gender
    END;

-- Confirm gender now has only two categories
SELECT gender, COUNT(*) AS frequency
FROM employment_raw
GROUP BY gender
ORDER BY frequency DESC;

-- Fix (b): Detect name-gender mismatches
-- Add a flag column to mark suspicious records
ALTER TABLE employment_raw
ADD gender_flag VARCHAR(100);

-- Flag records where a clearly female name is coded Male, or vice versa
UPDATE employment_raw
SET gender_flag =
    CASE
        WHEN gender = 'Male' AND (
            name LIKE 'Abena %' OR name LIKE 'Akosua %' OR
    name LIKE 'Adwoa %' OR name LIKE 'Ama %' OR
    name LIKE 'Efua %' OR name LIKE 'Fatima %' OR
    name LIKE 'Grace %' OR name LIKE 'Irene %' OR
    name LIKE 'Selina %'
        ) THEN 'Mismatch - corrected'
        WHEN gender = 'Female' AND (
            name LIKE 'Kofi %' OR name LIKE 'Kwame %' OR
    name LIKE 'Yaw %' OR name LIKE 'Kojo %' OR
    name LIKE 'Daniel %' OR name LIKE 'Samuel %' OR
    name LIKE 'Joseph %' OR name LIKE 'Michael %' OR
    name LIKE 'Isaac %' OR name LIKE 'Emmanuel %'
        ) THEN 'Mismatch - corrected'
        ELSE 'OK'
    END;

-- See how many mismatches were found
SELECT gender_flag, COUNT(*) AS frequency
FROM employment_raw
GROUP BY gender_flag;

-- Correct female names wrongly coded as Male
UPDATE employment_raw
SET gender = 'Female'
WHERE gender = 'Male'
    AND (
    name LIKE 'Abena %' OR name LIKE 'Akosua %' OR
    name LIKE 'Adwoa %' OR name LIKE 'Ama %' OR
    name LIKE 'Efua %' OR name LIKE 'Fatima %' OR
    name LIKE 'Grace %' OR name LIKE 'Irene %' OR
    name LIKE 'Selina %'
  );

-- Correct male names wrongly coded as Female
UPDATE employment_raw
SET gender = 'Male'
WHERE gender = 'Female'
    AND (
    name LIKE 'Kofi %' OR name LIKE 'Kwame %' OR
    name LIKE 'Yaw %' OR name LIKE 'Kojo %' OR
    name LIKE 'Daniel %' OR name LIKE 'Samuel %' OR
    name LIKE 'Joseph %' OR name LIKE 'Michael %' OR
    name LIKE 'Isaac %' OR name LIKE 'Emmanuel %'
  );

-- Confirm all mismatches are resolved
SELECT gender_flag, COUNT(*) AS frequency
FROM employment_raw
GROUP BY gender_flag;



-- STEP 6: VARIABLE 4 - AGE
-- Issues found:
-- (a) Written-out age: 'twenty-five' instead of 25 (62 records)
-- (b) Impossible age: 110 which is not realistic (20 records)

-- First, see the raw age values to understand what we are dealing with
SELECT age, COUNT(*) AS frequency
FROM employment_raw
GROUP BY age
ORDER BY frequency DESC;

-- Add a cleaned age column (numeric)
ALTER TABLE employment_raw
ADD age_clean INT;

-- Convert written-out age to number, and all other valid numbers too
UPDATE employment_raw
SET age_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(age))) IN ('25', 'twenty five', 'twenty-five') THEN 25
        ELSE TRY_CAST(age AS INT)
    END;

-- Check the range of cleaned age values
SELECT
    MIN(age_clean) AS minimum_age,
    MAX(age_clean) AS maximum_age,
    ROUND(AVG(CAST(age_clean AS FLOAT)), 2) AS average_age
FROM employment_raw;

-- See which records have impossible ages (above 80 for working-age adults)
SELECT person_id, name, age, age_clean
FROM employment_raw
WHERE age_clean > 80 OR age_clean < 15;

-- Add a final validated age column
ALTER TABLE employment_raw
ADD age_final INT;

-- Keep realistic working-age values (15 to 80)
-- Anything outside this range is set to NULL
-- We are only cleaning the data, not imputing
UPDATE employment_raw
SET age_final =
    CASE
        WHEN age_clean BETWEEN 15 AND 80 THEN age_clean
        ELSE NULL
    END;

-- Confirm age 110 has been set to NULL
SELECT age, age_clean, age_final
FROM employment_raw
WHERE age_clean = 110;

-- Final summary of the cleaned age column
SELECT
    MIN(age_final) AS min_age,
    MAX(age_final) AS max_age,
    ROUND(AVG(CAST(age_final AS FLOAT)), 2) AS avg_age,
    SUM(CASE WHEN age_final IS NULL THEN 1 ELSE 0 END) AS null_count
FROM employment_raw;



-- STEP 7: VARIABLE 5 - EDUCATION_YEARS
-- Check for missing values and out-of-range numbers

-- See raw values
SELECT education_years, COUNT(*) AS frequency
FROM employment_raw
GROUP BY education_years
ORDER BY frequency DESC;

-- Add a cleaned numeric education column
ALTER TABLE employment_raw
ADD education_clean INT;

-- Convert to numeric (blanks and non-numeric values become NULL)
UPDATE employment_raw
SET education_clean = TRY_CAST(NULLIF(LTRIM(RTRIM(education_years)), '') AS INT);

-- Check the range
SELECT
    MIN(education_clean) AS min_years,
    MAX(education_clean) AS max_years,
    ROUND(AVG(CAST(education_clean AS FLOAT)), 2) AS avg_years,
    SUM(CASE WHEN education_clean IS NULL THEN 1 ELSE 0 END) AS null_count
FROM employment_raw;


-- STEP 8: VARIABLE 6 - REGION
-- Issue: Inconsistent capitalisation e.g. 'ashanti' vs 'Ashanti'
-- See all unique raw region values
SELECT region, COUNT(*) AS frequency
FROM employment_raw
GROUP BY region
ORDER BY region;

-- Add a cleaned region column
ALTER TABLE employment_raw
ADD region_clean VARCHAR(100);

-- Standardise all region names to proper capitalisation
UPDATE employment_raw
SET region_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(region))) = 'greater accra' THEN 'Greater Accra'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'ashanti'       THEN 'Ashanti'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'western'       THEN 'Western'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'central'       THEN 'Central'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'eastern'       THEN 'Eastern'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'northern'      THEN 'Northern'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'upper east'    THEN 'Upper East'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'upper west'    THEN 'Upper West'
        WHEN LOWER(LTRIM(RTRIM(region))) = 'volta'         THEN 'Volta'
        ELSE LTRIM(RTRIM(region))
    END;

-- Confirm cleaned region values
SELECT region_clean, COUNT(*) AS frequency
FROM employment_raw
GROUP BY region_clean
ORDER BY region_clean;



-- STEP 9: VARIABLE 7 - EMPLOYMENT_STATUS
-- Issue: Abbreviations used: 'emp' instead of 'Employed', 'unemp' instead of 'Unemployed'
-- See all unique raw values
SELECT employment_status, COUNT(*) AS frequency
FROM employment_raw
GROUP BY employment_status
ORDER BY frequency DESC;
-- Found: Employed, Unemployed, emp, unemp, Informal, Self-employed, Not in Labour Force

-- Add a cleaned employment status column
ALTER TABLE employment_raw
ADD employment_status_clean VARCHAR(100);

-- Expand abbreviations and standardise labels
UPDATE employment_raw
SET employment_status_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(employment_status))) = 'emp'   THEN 'Employed'
        WHEN LOWER(LTRIM(RTRIM(employment_status))) = 'unemp' THEN 'Unemployed'
        ELSE LTRIM(RTRIM(employment_status))
    END;

-- Confirm all categories are now standardised
SELECT employment_status_clean, COUNT(*) AS frequency
FROM employment_raw
GROUP BY employment_status_clean
ORDER BY frequency DESC;


-- STEP 10: VARIABLE 8 - INDUSTRY
-- Issue: Abbreviations used: 'agric' instead of 'Agriculture', 'serv' instead of 'Services'

-- See all unique raw values
SELECT industry, COUNT(*) AS frequency
FROM employment_raw
GROUP BY industry
ORDER BY frequency DESC;
-- Found: Agriculture, agric, Services, serv, Construction, Manufacturing, etc.

-- Add a cleaned industry column
ALTER TABLE employment_raw
ADD industry_clean VARCHAR(100);

-- Expand abbreviations and standardise labels
UPDATE employment_raw
SET industry_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(industry))) = 'agric' THEN 'Agriculture'
        WHEN LOWER(LTRIM(RTRIM(industry))) = 'serv'  THEN 'Services'
        ELSE LTRIM(RTRIM(industry))
    END;

-- Confirm all industry categories are now standardised
SELECT industry_clean, COUNT(*) AS frequency
FROM employment_raw
GROUP BY industry_clean
ORDER BY frequency DESC;



-- STEP 11: VARIABLE 9 - HOURS_WORKED_PER_WEEK
-- Issue: Word 'forty' used instead of number 40 (60 records)

-- See the raw values to identify all problems
SELECT hours_worked_per_week, COUNT(*) AS frequency
FROM employment_raw
GROUP BY hours_worked_per_week
ORDER BY frequency DESC;

-- Add a cleaned hours column
ALTER TABLE employment_raw
ADD hours_clean INT;

-- Convert the word 'forty' to 40 and all other valid numbers too
UPDATE employment_raw
SET hours_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(hours_worked_per_week))) IN ('40', 'forty') THEN 40
        ELSE TRY_CAST(hours_worked_per_week AS INT)
    END;

-- Check the range of cleaned hours values
SELECT
    MIN(hours_clean) AS min_hours,
    MAX(hours_clean) AS max_hours,
    ROUND(AVG(CAST(hours_clean AS FLOAT)), 2) AS avg_hours,
    SUM(CASE WHEN hours_clean IS NULL THEN 1 ELSE 0 END) AS null_count
FROM employment_raw;

-- Flag any impossible values (more than 168 hours in a week is not possible)
SELECT person_id, name, hours_worked_per_week, hours_clean
FROM employment_raw
WHERE hours_clean > 168;



-- STEP 12: VARIABLE 10 - MONTHLY_INCOME
-- Issues found:
-- (a) 30 records have '?' instead of a number (disguised missing)
-- (b) 89 records are true NULL values
-- Total missing: 119 records

-- See raw income values - especially the problematic ones
SELECT monthly_income, COUNT(*) AS frequency
FROM employment_raw
WHERE monthly_income IS NULL OR monthly_income = '?'
GROUP BY monthly_income;

-- Add a cleaned income column
ALTER TABLE employment_raw
ADD income_clean DECIMAL(10,2);

-- Convert to numeric:
-- '?' is treated as missing (NULL)
-- Blank cells are treated as missing (NULL)
-- All valid numbers are converted
UPDATE employment_raw
SET income_clean =
    CASE
        WHEN monthly_income IS NULL              THEN NULL
        WHEN LTRIM(RTRIM(monthly_income)) = ''   THEN NULL
        WHEN LTRIM(RTRIM(monthly_income)) = '?'  THEN NULL
        ELSE TRY_CAST(LTRIM(RTRIM(monthly_income)) AS DECIMAL(10,2))
    END;

-- Check actual income missing counts after deduplication
SELECT
    SUM(CASE WHEN monthly_income = '?' THEN 1 ELSE 0 END) AS question_mark_count,
    SUM(CASE WHEN monthly_income IS NULL THEN 1 ELSE 0 END) AS true_null_count,
    SUM(CASE WHEN monthly_income IS NULL
        OR LTRIM(RTRIM(monthly_income)) = '?' 
             THEN 1 ELSE 0 END) AS total_missing
FROM employment_raw;

-- Check how many NULLs remain after conversion
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN income_clean IS NULL THEN 1 ELSE 0 END) AS total_missing,
    MIN(income_clean) AS min_income,
    MAX(income_clean) AS max_income,
    ROUND(AVG(income_clean), 2) AS avg_income
FROM employment_raw;


-- STEP 13: VARIABLE 11 - JOB_SEARCH_ACTIVE
-- Issue: Inconsistent labels:YES, no
-- See all unique raw values
SELECT job_search_active, COUNT(*) AS frequency
FROM employment_raw
GROUP BY job_search_active
ORDER BY frequency DESC;

-- Add a cleaned job search column
ALTER TABLE employment_raw
ADD job_search_clean VARCHAR(10);

-- Standardise all variants to 'Yes' or 'No'
UPDATE employment_raw
SET job_search_clean =
    CASE
        WHEN LOWER(LTRIM(RTRIM(job_search_active))) = 'yes' THEN 'Yes'
        WHEN LOWER(LTRIM(RTRIM(job_search_active))) = 'no'  THEN 'No'
        ELSE NULL
    END;

-- Confirm only Yes and No remain
SELECT job_search_clean, COUNT(*) AS frequency
FROM employment_raw
GROUP BY job_search_clean
ORDER BY job_search_clean;



-- STEP 14: VARIABLE 12 - SURVEY_SOURCE
-- Issue: Inconsistent capitalisation: hs, HS, lfs, LFS, hies, HIES
-- See all unique raw values
SELECT survey_source, COUNT(*) AS frequency
FROM employment_raw
GROUP BY survey_source
ORDER BY frequency DESC;

-- Add a cleaned survey source column
ALTER TABLE employment_raw
ADD survey_source_clean VARCHAR(10);

-- Standardise to uppercase (HIES, LFS, HS)
UPDATE employment_raw
SET survey_source_clean = UPPER(LTRIM(RTRIM(survey_source)));

-- Confirm only three clean categories remain
SELECT survey_source_clean, COUNT(*) AS frequency
FROM employment_raw
GROUP BY survey_source_clean
ORDER BY survey_source_clean;




-- STEP 15: NULL VALUE CHECK ACROSS ALL VARIABLES
SELECT
    SUM(CASE WHEN person_id             IS NULL THEN 1 ELSE 0 END) AS null_personid,
    SUM(CASE WHEN name                  IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN gender                IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN age_final             IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN education_clean       IS NULL THEN 1 ELSE 0 END) AS null_education,
    SUM(CASE WHEN region_clean          IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN employment_status_clean IS NULL THEN 1 ELSE 0 END) AS null_emp_status,
    SUM(CASE WHEN industry_clean        IS NULL THEN 1 ELSE 0 END) AS null_industry,
    SUM(CASE WHEN hours_clean           IS NULL THEN 1 ELSE 0 END) AS null_hours,
    SUM(CASE WHEN income_clean          IS NULL THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN job_search_clean      IS NULL THEN 1 ELSE 0 END) AS null_job_search,
    SUM(CASE WHEN survey_source_clean   IS NULL THEN 1 ELSE 0 END) AS null_survey
FROM employment_raw;



-- STEP 16: CREATE THE FINAL CLEAN TABLE
-- Select only the cleaned columns into a new table ready for analysis
SELECT
    person_id,
    name,
    gender,
    age_final             AS age,
    education_clean       AS education_years,
    region_clean          AS region,
    employment_status_clean AS employment_status,
    industry_clean        AS industry,
    hours_clean           AS hours_worked_per_week,
    income_clean          AS monthly_income,
    job_search_clean      AS job_search_active,
    survey_source_clean   AS survey_source,
    gender_flag
INTO employment_clean
FROM employment_raw;

-- Confirm the final clean table
SELECT COUNT(*) AS total_clean_rows
FROM employment_clean;
SELECT TOP 10
    *
FROM employment_clean;
