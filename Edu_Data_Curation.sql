
-- SETTING UP THE DATABASE AND TABLE
--create the database and use it
CREATE DATABASE EduDB;
USE EduDB;

-- We assigned all columns as VARCHAR to avoid import errors from messy data
CREATE TABLE education_raw (
    student_id           VARCHAR(100),
    name                 VARCHAR(100),
    gender               VARCHAR(100),
    age                  VARCHAR(100),
    gpa                  VARCHAR(100),
    study_hours_per_week VARCHAR(100),
    programme            VARCHAR(100),
    region               VARCHAR(100),
    scholarship          VARCHAR(100),
    tuition_paid         VARCHAR(100)
);


-- WE USED BULK IMPORT THE RAW CSV FILE
BULK INSERT education_raw
FROM 'C:\Users\HP\Downloads\01_education_messy.csv'
WITH (
    DATAFILETYPE    = 'char',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    FIRSTROW        = 2,
    TABLOCK
);

-- Confirming total rows imported (expected: 1,535)
SELECT COUNT(*) AS total_rows
FROM education_raw;

-- DATA DIAGNOSIS
-- Counting NULL values in every column to know exactly how many cells are NULL
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN student_id           IS NULL THEN 1 ELSE 0 END) AS null_student_id,
    SUM(CASE WHEN name                 IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN gender               IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN age                  IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN gpa                  IS NULL THEN 1 ELSE 0 END) AS null_gpa,
    SUM(CASE WHEN study_hours_per_week IS NULL THEN 1 ELSE 0 END) AS null_study_hours,
    SUM(CASE WHEN programme            IS NULL THEN 1 ELSE 0 END) AS null_programme,
    SUM(CASE WHEN region               IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN scholarship          IS NULL THEN 1 ELSE 0 END) AS null_scholarship,
    SUM(CASE WHEN tuition_paid         IS NULL THEN 1 ELSE 0 END) AS null_tuition_paid
FROM education_raw;

--Counting blank strings (empty cells imported as '' instead of NULL)
SELECT
    SUM(CASE WHEN LTRIM(RTRIM(name))                 = '' THEN 1 ELSE 0 END) AS blank_name,
    SUM(CASE WHEN LTRIM(RTRIM(gender))               = '' THEN 1 ELSE 0 END) AS blank_gender,
    SUM(CASE WHEN LTRIM(RTRIM(programme))            = '' THEN 1 ELSE 0 END) AS blank_programme,
    SUM(CASE WHEN LTRIM(RTRIM(region))               = '' THEN 1 ELSE 0 END) AS blank_region,
    SUM(CASE WHEN LTRIM(RTRIM(scholarship))          = '' THEN 1 ELSE 0 END) AS blank_scholarship,
    SUM(CASE WHEN LTRIM(RTRIM(study_hours_per_week)) = '' THEN 1 ELSE 0 END) AS blank_study_hours,
    SUM(CASE WHEN LTRIM(RTRIM(tuition_paid))         = '' THEN 1 ELSE 0 END) AS blank_tuition_paid
FROM education_raw;

--Checking for duplicate rows so we can remove them
SELECT
    student_id, name, gender, age, gpa,
    study_hours_per_week, programme, region, scholarship, tuition_paid,
    COUNT(*) AS duplicate_count
FROM education_raw
GROUP BY
    student_id, name, gender, age, gpa,
    study_hours_per_week, programme, region, scholarship, tuition_paid
HAVING COUNT(*) > 1;

-- Removing duplicates, keeping only the first occurrence
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY student_id, name, gender, age, gpa,
                            study_hours_per_week, programme, region,
                            scholarship, tuition_paid
               ORDER BY (SELECT NULL)
           ) AS row_num
    FROM education_raw
)
DELETE FROM CTE WHERE row_num > 1;

-- Confirming row count after deduplication (expected: 1,500)
SELECT COUNT(*) AS rows_after_dedup
FROM education_raw;



--VARIABLE-BY-VARIABLE CLEANING
-- We will create cleaned versions of each variable, keeping the original raw columns for reference
-- STUDENT_ID


-- Check whether all student_id values are numeric and identify invalid entries
 SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN TRY_CAST(student_id AS INT) IS NULL AND LTRIM(RTRIM(student_id)) <> '' THEN 1 ELSE 0 END) AS non_numeric_ids,
    SUM(CASE WHEN TRY_CAST(student_id AS INT) IS NOT NULL THEN 1 ELSE 0 END) AS numeric_ids
 FROM education_raw;


-- Checking the ID range
SELECT
    MIN(CAST(student_id AS INT)) AS min_id,
    MAX(CAST(student_id AS INT)) AS max_id
FROM education_raw;
 
-- NAME
-- Remove leading and trailing spaces from all names
UPDATE education_raw
SET name = LTRIM(RTRIM(name));

-- GENDER
-- Issue: Six variants found: Male, male, M, Female, female, F
-- Also: Some female names are coded Male and vice versa

-- let's look at all raw gender values
SELECT gender, COUNT(*) AS frequency
FROM education_raw
GROUP BY gender
ORDER BY frequency DESC;

-- Standardizing all variants to 'Male' or 'Female'
UPDATE education_raw
SET gender = CASE
    WHEN UPPER(LTRIM(RTRIM(gender))) IN ('M', 'MALE')   THEN 'Male'
    WHEN UPPER(LTRIM(RTRIM(gender))) IN ('F', 'FEMALE') THEN 'Female'
    ELSE gender
END;

-- Confirming only Male and Female remain
SELECT gender, COUNT(*) AS frequency
FROM education_raw
GROUP BY gender
ORDER BY frequency DESC;

-- Adding a flag column to detect name-gender mismatches
ALTER TABLE education_raw ADD gender_flag VARCHAR(100);

UPDATE education_raw
SET gender_flag = CASE
    WHEN gender = 'Female' AND (
        name LIKE 'Kofi %'    OR name LIKE 'Kwame %'   OR
        name LIKE 'Yaw %'     OR name LIKE 'Kojo %'    OR
        name LIKE 'Daniel %'  OR name LIKE 'Samuel %'  OR
        name LIKE 'Joseph %'  OR name LIKE 'Michael %' OR
        name LIKE 'Isaac %'   OR name LIKE 'Emmanuel %'
    ) THEN 'Possible mismatch - verify'
    WHEN gender = 'Male' AND (
        name LIKE 'Akosua %' OR name LIKE 'Abena %'  OR
        name LIKE 'Ama %'    OR name LIKE 'Adwoa %'  OR
        name LIKE 'Efua %'   OR name LIKE 'Irene %'  OR
        name LIKE 'Grace %'  OR name LIKE 'Fatima %' OR
        name LIKE 'Selina %'
    ) THEN 'Possible mismatch - verify'
    ELSE 'OK'
END;

-- Viewing flagged records
SELECT student_id, name, gender, gender_flag
FROM education_raw
WHERE gender_flag = 'Possible mismatch - verify'
ORDER BY name;

-- Correcting female names wrongly coded as Male
UPDATE education_raw
SET gender = 'Female'
WHERE gender = 'Male'
  AND (
    name LIKE 'Abena %'  OR name LIKE 'Akosua %' OR
    name LIKE 'Adwoa %'  OR name LIKE 'Ama %'    OR
    name LIKE 'Efua %'   OR name LIKE 'Fatima %' OR
    name LIKE 'Grace %'  OR name LIKE 'Irene %'  OR
    name LIKE 'Selina %'
  );

-- Correcting male names wrongly coded as Female
UPDATE education_raw
SET gender = 'Male'
WHERE gender = 'Female'
  AND (
    name LIKE 'Kofi %'    OR name LIKE 'Kwame %'   OR
    name LIKE 'Yaw %'     OR name LIKE 'Kojo %'    OR
    name LIKE 'Daniel %'  OR name LIKE 'Samuel %'  OR
    name LIKE 'Joseph %'  OR name LIKE 'Michael %' OR
    name LIKE 'Isaac %'   OR name LIKE 'Emmanuel %'
  );

-- Updating flag to show corrections were made
UPDATE education_raw
SET gender_flag = 'Corrected - name-gender mismatch fixed'
WHERE gender_flag = 'Possible mismatch - verify';

-- Finaling gender check
SELECT gender, COUNT(*) AS frequency
FROM education_raw
GROUP BY gender
ORDER BY frequency DESC;


-- AGE
-- Issue 1: 60 records say 'twenty-two' instead of 22
-- Issue 2: 18 records have age = 120 (impossible)
-- Converting text, then set impossible values to NULL
--          We are only cleaning, not imputing

-- looking at raw age values
SELECT age, COUNT(*) AS frequency
FROM education_raw
GROUP BY age
ORDER BY frequency DESC;

-- Adding a cleaned age column
ALTER TABLE education_raw ADD age_clean INT;

-- Converting 'twenty-two' to 22; converting all other valid numbers
UPDATE education_raw
SET age_clean = CASE
    WHEN LOWER(LTRIM(RTRIM(age))) IN ('twenty-two', 'twenty two') THEN 22
    ELSE TRY_CAST(age AS INT)
END;

-- Adding a final validated age column
ALTER TABLE education_raw ADD age_final INT;

-- Keeping ages between 16 and 80; set anything else to NULL
UPDATE education_raw
SET age_final = CASE
    WHEN age_clean BETWEEN 16 AND 80 THEN age_clean
    ELSE NULL
END;

-- Confirming age 120 is now NULL
SELECT student_id, name, age, age_clean, age_final
FROM education_raw
WHERE age_clean = 120;

-- Summary of the cleaned age column
SELECT
    MIN(age_final)                           AS min_age,
    MAX(age_final)                           AS max_age,
    ROUND(AVG(CAST(age_final AS FLOAT)), 2)  AS avg_age,
    SUM(CASE WHEN age_final IS NULL THEN 1 ELSE 0 END) AS null_count
FROM education_raw;


-- GPA
-- Issue 1: 78 records have NULL GPA
-- Issue 2: 15 records have GPA = 4.80 (exceeds valid range of 0-4.0)

-- Seeing raw GPA values
SELECT gpa, COUNT(*) AS frequency
FROM education_raw
GROUP BY gpa
ORDER BY TRY_CAST(gpa AS DECIMAL(4,2));

-- Adding a cleaned GPA column
ALTER TABLE education_raw ADD gpa_clean DECIMAL(4,2);

-- Converting to numeric; blank or non-convertible values become NULL
UPDATE education_raw
SET gpa_clean = TRY_CAST(NULLIF(LTRIM(RTRIM(gpa)), '') AS DECIMAL(4,2));

-- Adding a final validated GPA column
ALTER TABLE education_raw ADD gpa_final DECIMAL(4,2);

-- Accepting only 0.00 to 4.00; anything else becomes NULL
UPDATE education_raw
SET gpa_final = CASE
    WHEN gpa_clean BETWEEN 0.00 AND 4.00 THEN gpa_clean
    ELSE NULL
END;

-- Seeing which records have invalid or missing GPA
SELECT student_id, name, gpa, gpa_clean, gpa_final
FROM education_raw
WHERE gpa_clean > 4.00 OR gpa_final IS NULL
ORDER BY gpa_clean DESC;

-- Counting how many need imputation
SELECT COUNT(*) AS records_to_impute
FROM education_raw
WHERE gpa_final IS NULL;

-- Final GPA summary
SELECT
    MIN(gpa_final)                           AS min_gpa,
    MAX(gpa_final)                           AS max_gpa,
    ROUND(AVG(CAST(gpa_final AS FLOAT)), 3)  AS avg_gpa,
    SUM(CASE WHEN gpa_final IS NULL THEN 1 ELSE 0 END) AS null_count
FROM education_raw;



-- STUDY HOURS PER WEEK
-- Issue: 55 records say 'ten' instead of 10

-- Seeing raw values
SELECT study_hours_per_week, COUNT(*) AS frequency
FROM education_raw
GROUP BY study_hours_per_week
ORDER BY frequency DESC;

-- Adding a cleaned column
ALTER TABLE education_raw ADD study_hr_clean INT;

-- Converting 'ten' to 10; convert all other valid numbers
UPDATE education_raw
SET study_hr_clean = CASE
    WHEN LOWER(LTRIM(RTRIM(study_hours_per_week))) IN ('ten', '10') THEN 10
    ELSE TRY_CAST(study_hours_per_week AS INT)
END;

-- Adding a final validated column (valid range: 0 to 100 hours)
ALTER TABLE education_raw ADD study_hr_final INT;

UPDATE education_raw
SET study_hr_final = CASE
    WHEN study_hr_clean BETWEEN 0 AND 100 THEN study_hr_clean
    ELSE NULL
END;

-- Summarizing study hours
SELECT
    MIN(study_hr_final)                           AS min_hours,
    MAX(study_hr_final)                           AS max_hours,
    ROUND(AVG(CAST(study_hr_final AS FLOAT)), 2)  AS avg_hours,
    SUM(CASE WHEN study_hr_final IS NULL THEN 1 ELSE 0 END) AS null_count
FROM education_raw;


-- PROGRAMME
-- Expected categories: MSc Economics, MSc Data Science,
--                      MBA, MPhil Statistics

-- Seeing all programme values
SELECT programme, COUNT(*) AS frequency
FROM education_raw
GROUP BY programme
ORDER BY frequency DESC;

-- FINDING: Four valid programmes. No issues found.
-- REGION

-- Issue: Mixed cases e.g. 'greater accra', 'Greater Accra', 'GREATER ACCRA'

-- Seeing all raw region values
SELECT region, COUNT(*) AS frequency
FROM education_raw
GROUP BY region
ORDER BY region;

-- Adding a cleaned region column
ALTER TABLE education_raw ADD region_clean VARCHAR(100);

-- Standardizing each region to proper case
UPDATE education_raw
SET region_clean = CASE
    WHEN region IS NULL OR LTRIM(RTRIM(region)) = '' THEN NULL
    WHEN LOWER(LTRIM(RTRIM(region))) = 'greater accra' THEN 'Greater Accra'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'ashanti'       THEN 'Ashanti'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'western'       THEN 'Western'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'central'       THEN 'Central'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'eastern'       THEN 'Eastern'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'volta'         THEN 'Volta'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'northern'      THEN 'Northern'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'upper east'    THEN 'Upper East'
    WHEN LOWER(LTRIM(RTRIM(region))) = 'upper west'    THEN 'Upper West'
    ELSE LTRIM(RTRIM(region))
END;

-- Confirming all regions are now standardised
SELECT region_clean, COUNT(*) AS frequency
FROM education_raw
GROUP BY region_clean
ORDER BY region_clean;


-- SCHOLARSHIP
-- Issue: Six variants: Yes, YES, yes, No, NO, no

-- Seeing raw values
SELECT scholarship, COUNT(*) AS frequency
FROM education_raw
GROUP BY scholarship
ORDER BY frequency DESC;

-- Adding a cleaned scholarship column
ALTER TABLE education_raw ADD scholarship_clean VARCHAR(10);

-- Standardizing to 'Yes' or 'No'
UPDATE education_raw
SET scholarship_clean = CASE
    WHEN scholarship IS NULL OR LTRIM(RTRIM(scholarship)) = '' THEN NULL
    WHEN LOWER(LTRIM(RTRIM(scholarship))) = 'yes' THEN 'Yes'
    WHEN LOWER(LTRIM(RTRIM(scholarship))) = 'no'  THEN 'No'
    ELSE LTRIM(RTRIM(scholarship))
END;

-- Confirming only Yes and No remain
SELECT scholarship_clean, COUNT(*) AS frequency
FROM education_raw
GROUP BY scholarship_clean
ORDER BY scholarship_clean;


-- TUITION PAID
-- Issue: 35 records have '?' instead of a number

-- Seeing raw values
SELECT tuition_paid, COUNT(*) AS frequency
FROM education_raw
GROUP BY tuition_paid
ORDER BY frequency DESC;

-- Adding a cleaned tuition column
ALTER TABLE education_raw ADD tuition_clean INT;

-- Converting '?' and blanks to NULL; convert all valid numbers
UPDATE education_raw
SET tuition_clean = CASE
    WHEN tuition_paid IS NULL             THEN NULL
    WHEN LTRIM(RTRIM(tuition_paid)) = ''  THEN NULL
    WHEN LTRIM(RTRIM(tuition_paid)) = '?' THEN NULL
    ELSE TRY_CAST(LTRIM(RTRIM(tuition_paid)) AS INT)
END;

-- Summarizing of cleaned tuition
SELECT
    MIN(tuition_clean)                           AS min_tuition,
    MAX(tuition_clean)                           AS max_tuition,
    ROUND(AVG(CAST(tuition_clean AS FLOAT)), 2)  AS avg_tuition,
    SUM(CASE WHEN tuition_clean IS NULL THEN 1 ELSE 0 END) AS null_count
FROM education_raw;


-- POST-CLEANING VALIDATION
-- Confirming every issue has been resolved

-- Gender: should only be Male or Female
SELECT gender, COUNT(*) AS frequency
FROM education_raw
GROUP BY gender;

-- Age: confirm 120 is gone
SELECT COUNT(*) AS impossible_ages
FROM education_raw
WHERE age_final > 80;

-- GPA: confirm nothing above 4.0
SELECT COUNT(*) AS invalid_gpa
FROM education_raw
WHERE gpa_clean > 4.0;

-- Region: confirm standard categories only
SELECT region_clean, COUNT(*) FROM education_raw
GROUP BY region_clean ORDER BY region_clean;

-- Scholarship: confirm only Yes and No
SELECT scholarship_clean, COUNT(*) FROM education_raw
GROUP BY scholarship_clean;


-- CREATE THE FINAL CLEAN TABLE

SELECT
    CAST(student_id AS INT) AS student_id,
    name,
    gender,
    age_final               AS age,
    gpa_final               AS gpa,
    study_hr_final          AS study_hours_per_week,
    programme,
    region_clean            AS region,
    scholarship_clean       AS scholarship,
    tuition_clean           AS tuition_paid
INTO education_clean
FROM education_raw;

-- Confirming the final clean table
SELECT COUNT(*) AS total_cleaned_rows FROM education_clean;

-- Previewing the first 20 records
SELECT TOP 20 * FROM education_clean ORDER BY student_id;

-- Final NULL audit on the clean table
SELECT
    SUM(CASE WHEN student_id          IS NULL THEN 1 ELSE 0 END) AS null_student_id,
    SUM(CASE WHEN name                IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN gender              IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN age                 IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN gpa                 IS NULL THEN 1 ELSE 0 END) AS null_gpa,
    SUM(CASE WHEN study_hours_per_week IS NULL THEN 1 ELSE 0 END) AS null_study_hours,
    SUM(CASE WHEN programme           IS NULL THEN 1 ELSE 0 END) AS null_programme,
    SUM(CASE WHEN region              IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN scholarship         IS NULL THEN 1 ELSE 0 END) AS null_scholarship,
    SUM(CASE WHEN tuition_paid        IS NULL THEN 1 ELSE 0 END) AS null_tuition_paid
FROM education_clean;
