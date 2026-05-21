# Data Curation and Quality Management Project

A structured SQL-based data curation project covering two real-world messy datasets - one on student education records and another on employment survey data. The work covers end-to-end data diagnosis, validation, cleaning, and final table production using **T-SQL (SQL Server Management Studio)**.

The goal was to systematically identify and resolve data quality issues to produce clean, analysis-ready datasets suitable for empirical research.

---

## Project Overview

Raw datasets rarely come clean. This project demonstrates how to approach messy data professionally: diagnosing what is wrong, documenting every issue, applying targeted fixes column by column, and validating that the output is reliable before any analysis begins.

Both scripts follow the same rigorous pipeline — import → diagnose → clean variable by variable → validate → export clean table — and are fully reproducible from the raw CSV files.

---

## Datasets

| Dataset | Raw Rows | Variables | Output Table |
|---------|----------|-----------|--------------|
| Education | 1,535 | 10 | `education_clean` |
| Employment | 1,540 | 12 | `employment_clean` |

---

## Scripts

### `Edu_Data_Curation.sql` - Student Education Records

**Variables:** `student_id`, `name`, `gender`, `age`, `gpa`, `study_hours_per_week`, `programme`, `region`, `scholarship`, `tuition_paid`

**Issues identified and resolved:**

| Variable | Issue | Fix Applied |
|----------|-------|------------|
| Full dataset | 35 fully duplicated rows | Removed using `ROW_NUMBER()` CTE; 1,500 clean records retained |
| `gender` | Six label variants: Male, male, M, Female, female, F | Standardised to `'Male'` / `'Female'` using `UPPER()` + `TRIM()` |
| `gender` | Name-gender mismatches (e.g. female Ghanaian names coded Male) | Detected via name-pattern logic; corrected and flagged |
| `age` | 60 records stored as `'twenty-two'` (text) | Converted to `22` using `CASE`; validated range 16–80 |
| `age` | 18 records with `age = 120` (impossible value) | Set to `NULL` - flagged for imputation in analysis stage |
| `gpa` | Values stored as text; some exceed valid range (> 4.0) | Cleaned to `DECIMAL`, invalid values set to `NULL` |
| `study_hours_per_week` | 55 records stored as `'ten'` (text) | Converted to `10`; validated range 0–100 |
| `region` | Mixed capitalisation: `'greater accra'`, `'GREATER ACCRA'` | Standardised to proper case for all 9 Ghanaian regions |
| `scholarship` | Six label variants: Yes, YES, yes, No, NO, no | Standardised to `'Yes'` / `'No'` |
| `tuition_paid` | 35 records stored as `'?'` (disguised missing) | Converted to `NULL` |

---

### `Employ_Data_Curation.sql` - Employment Survey Records

**Variables:** `person_id`, `name`, `gender`, `age`, `education_years`, `region`, `employment_status`, `industry`, `hours_worked_per_week`, `monthly_income`, `job_search_active`, `survey_source`

**Issues identified and resolved:**

| Variable | Issue | Fix Applied |
|----------|-------|------------|
| Full dataset | 40 fully duplicated rows | Removed using `ROW_NUMBER()` CTE; 1,500 clean records retained |
| `gender` | Six label variants (same pattern as education dataset) | Standardised to `'Male'` / `'Female'` |
| `gender` | Name-gender mismatches (Ghanaian name-pattern detection) | Corrected and flagged in `gender_flag` column |
| `age` | Out-of-range values | Validated range 18–80; extremes set to `NULL` |
| `education_years` | Non-numeric entries | Cleaned to `INT` using `TRY_CAST()` |
| `region` | Mixed capitalisation across all regions | Standardised to proper case |
| `employment_status` | Inconsistent labels | Standardised to canonical categories |
| `industry` | Abbreviated entries: `'Agric'`, `'Serv'` | Expanded to `'Agriculture'`, `'Services'` |
| `hours_worked_per_week` | 60 records stored as `'forty'` (text) | Converted to `40`; validated against 168-hour weekly ceiling |
| `monthly_income` | 30 `'?'` records + 89 true NULLs (119 total missing) | All converted to `NULL` via `TRY_CAST()` |
| `job_search_active` | Inconsistent case: `YES`, `no`, etc. | Standardised to `'Yes'` / `'No'` |
| `survey_source` | Mixed case: `hs`, `HS`, `lfs`, `LFS`, `hies`, `HIES` | Standardised to uppercase (`HIES`, `LFS`, `HS`) |

---

## Data Quality Techniques Demonstrated

- **Bulk import** of raw CSV files with all columns as `VARCHAR` to prevent type-mismatch import failures
- **NULL and blank-string audits** across all columns (distinguishing true NULLs from `''` imported as empty strings)
- **Duplicate detection and removal** using `ROW_NUMBER()` window functions inside a CTE
- **Text-to-number conversion** for word-form values (`'twenty-two'` → 22, `'ten'` → 10, `'forty'` → 40) using `CASE` + `TRY_CAST()`
- **Disguised missing value handling** (`'?'` treated as `NULL`)
- **Range validation** with domain-appropriate bounds (age, GPA, hours worked)
- **Name-pattern logic** for detecting and correcting name-gender mismatches using Ghanaian first-name conventions
- **Label standardisation** for categorical variables using `UPPER()`, `TRIM()`, and `CASE` mapping
- **Audit flag columns** (`gender_flag`) to document corrections transparently
- **Final clean table creation** via `SELECT INTO`, retaining only validated, typed columns

---

## Technologies Used

| Tool | Purpose |
|------|---------|
| SQL Server Management Studio (SSMS) | Query development and database management |
| T-SQL | All curation, transformation, and validation logic |

---


## Authors

- **Collins Amoo** - [@Kolinx25](https://github.com/Kolinx25)
- **Winifred Mensah-Amoah** - [@winnifredmensahamoah](https://github.com/winnifredmensahamoah)

---


## How We Approached This Task

The work followed a structured four-phase pipeline applied consistently across both datasets.

---

### Phase 1 - Dataset Profiling

Before writing a single cleaning query, we profiled each dataset to understand its structure, variable types, and surface-level issues.

**Education dataset** (`01_education_messy.csv`) - 1,535 observations, 10 variables:
- All columns imported as `VARCHAR` to avoid type-mismatch errors at the ingestion stage
- Row count confirmed post-import against the expected 1,535
- A full NULL audit was run across every column using `SUM(CASE WHEN IS NULL ...)`
- A separate blank-string audit detected empty cells imported as `''` rather than true `NULL`

**Employment dataset** (`02_employment_messy.csv`) - 1,540 observations, 12 variables:
- Same import strategy applied
- Both NULL and blank-string audits run before any cleaning began

This profiling stage gave us a complete map of what was wrong before we touched anything.

---

### Phase 2 - Issues Diagnosed

We documented every data quality problem by variable. The full inventory across both datasets:

**Education dataset:**

| Variable | Issue Found |
|----------|------------|
| Full dataset | 35 fully duplicated rows |
| `gender` | 6 label variants (Male, male, M, Female, female, F) + name-gender mismatches |
| `age` | 60 records stored as `'twenty-two'`; 18 records with `age = 120` |
| `gpa` | 78 NULL values; 15 records with GPA = 4.80 (exceeds maximum of 4.0) |
| `study_hours_per_week` | 55 records stored as `'ten'` |
| `region` | Mixed capitalisation across all 9 Ghanaian regions |
| `scholarship` | 6 label variants (Yes/YES/yes, No/NO/no) |
| `tuition_paid` | 35 records using `'?'` as a placeholder |

**Employment dataset:**

| Variable | Issue Found |
|----------|------------|
| Full dataset | 40 fully duplicated rows |
| `gender` | Same 6 label variants + name-gender mismatches |
| `age` | 62 records stored as `'twenty-five'`; 20 records with `age = 110` |
| `employment_status` | Abbreviations used: `'emp'` and `'unemp'` |
| `industry` | Abbreviations used: `'agric'` and `'serv'` |
| `hours_worked_per_week` | 60 records stored as `'forty'` |
| `monthly_income` | 119 records missing: 30 disguised as `'?'` + 89 true NULLs (7.9% of dataset) |
| `job_search_active` | Inconsistent case: `YES`, `no`, etc. |
| `survey_source` | Mixed case across all three sources: `hs/HS`, `lfs/LFS`, `hies/HIES` |

---

### Phase 3 - Cleaning and Validation (Variable by Variable)

Every issue was addressed with a targeted SQL fix. We preserved the raw columns throughout and added cleaned counterparts, so the original data remained visible for comparison. Key decisions:

**Deduplication**
Used `ROW_NUMBER()` inside a CTE to rank rows within each duplicate group and deleted any row ranked higher than 1, keeping the first occurrence. Removed 35 rows from education and 40 from employment - both datasets reduced to 1,500 clean records.

**Gender standardisation**
Applied `UPPER()` and `TRIM()` to collapse all six variants (`M`, `male`, `Male`, `F`, `female`, `Female`) into two canonical labels. Then used `LIKE` pattern matching on Ghanaian first names (`Akosua`, `Abena`, `Kofi`, `Kwame`, etc.) to detect and correct name-gender mismatches. A `gender_flag` column was added to mark every corrected record for full transparency.

**Text-as-numbers**
Used `CASE WHEN LOWER(TRIM(col)) IN ('twenty-two', ...)` to convert word-form numbers to integers before applying `TRY_CAST()` to the rest. This approach catches the specific known offenders while safely handling everything else. Applied to `age` (`'twenty-two'` → 22, `'twenty-five'` → 25), `study_hours_per_week` (`'ten'` → 10), and `hours_worked_per_week` (`'forty'` → 40).

**Range validation**
Rather than silently accepting any numeric value, we applied domain-appropriate bounds:
- Age: 16–80 (education), 15–80 (employment) - 18 and 20 impossible values set to `NULL` respectively
- GPA: 0.00–4.00 - 15 records at 4.80 set to `NULL`
- Hours worked: 0–168 (weekly ceiling) - checked against impossibility

**Disguised missing values**
Records using `'?'` to represent missing data were identified and converted to proper `NULL` using `CASE WHEN LTRIM(RTRIM(col)) = '?'`. This affected 35 tuition records and 30 income records.

**Abbreviation expansion**
Employment status abbreviations (`'emp'` → `'Employed'`, `'unemp'` → `'Unemployed'`) and industry abbreviations (`'agric'` → `'Agriculture'`, `'serv'` → `'Services'`) were expanded using `CASE WHEN` mapping.

**Capitalisation standardisation**
All categorical fields with mixed case - regions, scholarship, job search, survey source - were normalised using combinations of `LOWER()`, `UPPER()`, `TRIM()`, and explicit `CASE` mappings to proper-case or uppercase as appropriate.

**Post-cleaning validation**
After every fix, a verification query confirmed the issue was resolved - checking that only `'Male'` and `'Female'` remained, that no ages above 80 survived, that no GPA exceeded 4.0, and so on. Nothing was declared clean without a verification step.

---

### Phase 4 - Final Clean Tables

Once all variables passed validation, the cleaned columns were written to new tables (`education_clean`, `employment_clean`) using `SELECT ... INTO`, selecting only the typed, validated columns and excluding all the intermediate raw and staging fields.

A final NULL audit was run on both clean tables to confirm the residual missing counts and ensure no new issues were introduced during the export step.

**Cleaning philosophy - conservative by design:** Out-of-range and ambiguous values were set to `NULL` rather than imputed. Imputation is an analytical decision that belongs in the modelling stage, not the data curation stage. Flagging these records preserves data integrity and keeps the curation pipeline fully reproducible.
