/*
===============================================================================
HEALTHCARE OPERATIONS & BILLING ANALYSIS
SQLite Portfolio Project
===============================================================================

Objective
---------
Analyze admission volume, length of stay (LOS), patient-day utilization, billed
charges, and condition-specific billing variation to identify patterns that may
warrant operational review.

Source Table
------------
Healthcare_Dataset_for_SQL

Interpretation Notes
--------------------
- COUNT(*) represents admission records, not unique patients.
- "Billing Amount" represents billed charges, not reimbursement, revenue,
  profit, or cost.
- LOS = JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
- Billing Amount is converted to REAL where needed because currency symbols and
  commas can cause the imported field to be stored as text.

Sections
--------
1. Data Validation
2. Admission Volume & Distribution
3. Length of Stay & Patient Utilization
4. Insurance & Billing Analysis
5. Billing Benchmark & Variance Analysis
6. Integrated Utilization & Billing Analysis
7. Management Priority Analysis
===============================================================================
*/


/* ============================================================================
   1. DATA VALIDATION
   ============================================================================ */

-- Inspect table schema and declared data types.
PRAGMA table_info(Healthcare_Dataset_for_SQL);

-- Validate date fields and LOS calculation on a sample.
SELECT
    "Date of Admission",
    "Discharge Date",
    JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission") AS "Length of Stay"
FROM Healthcare_Dataset_for_SQL
LIMIT 10;

-- Establish the overall Average LOS benchmark.
SELECT
    ROUND(AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")), 1)
        AS "Average LOS"
FROM Healthcare_Dataset_for_SQL;


/* ============================================================================
   2. ADMISSION VOLUME & DISTRIBUTION
   ============================================================================ */

-- Business Question:
-- How is total admission volume distributed across Medical Conditions?
SELECT
    "Medical Condition",
    COUNT(*) AS "Admission Count",
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM Healthcare_Dataset_for_SQL),
        2
    ) AS "Percentage of Total Admissions"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition"
ORDER BY "Admission Count" DESC;

-- Business Question:
-- How are admission types distributed within each Medical Condition?
SELECT
    admission_data."Medical Condition",
    admission_data."Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        COUNT(*) * 100.0 /
        (
            SELECT COUNT(*)
            FROM Healthcare_Dataset_for_SQL AS condition_data
            WHERE condition_data."Medical Condition" =
                  admission_data."Medical Condition"
        ),
        2
    ) AS "% of Condition Admissions"
FROM Healthcare_Dataset_for_SQL AS admission_data
GROUP BY
    admission_data."Medical Condition",
    admission_data."Admission Type"
ORDER BY
    admission_data."Medical Condition",
    "Admission Count" DESC;


/* ============================================================================
   3. LENGTH OF STAY & PATIENT UTILIZATION
   ============================================================================ */

-- Business Question:
-- Which Medical Condition × Admission Type combinations have the highest
-- Average LOS?
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition", "Admission Type"
ORDER BY "Average LOS" DESC;

-- Business Question:
-- Which combinations have Average LOS above the overall dataset benchmark?
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition", "Admission Type"
HAVING
    AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")) >
    (
        SELECT AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        )
        FROM Healthcare_Dataset_for_SQL
    )
ORDER BY "Average LOS" DESC;

-- Business Question:
-- Which combinations have both above-average admission volume and
-- above-average LOS? Both benchmarks are calculated dynamically.
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition", "Admission Type"
HAVING
    COUNT(*) >
    (
        SELECT
            COUNT(*) * 1.0 /
            COUNT(DISTINCT "Medical Condition" || '|' || "Admission Type")
        FROM Healthcare_Dataset_for_SQL
    )
    AND AVG(
        JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
    ) >
    (
        SELECT AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        )
        FROM Healthcare_Dataset_for_SQL
    )
ORDER BY "Admission Count" DESC;

-- Business Question:
-- Which combinations generate the highest Estimated Patient-Days?
-- Estimated Patient-Days = Admission Count × unrounded Average LOS.
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS",
    ROUND(
        COUNT(*) *
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        0
    ) AS "Estimated Patient-Days"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition", "Admission Type"
ORDER BY "Estimated Patient-Days" DESC;

-- Business Question:
-- Which combinations account for the highest Total Patient-Days when
-- individual admission LOS values are summed directly?
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS",
    ROUND(
        SUM(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        0
    ) AS "Total Patient-Days"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Medical Condition", "Admission Type"
ORDER BY "Total Patient-Days" DESC;

-- Business Question:
-- Which Insurance Providers account for the highest inpatient utilization?
SELECT
    "Insurance Provider",
    COUNT(*) AS "Admission Count",
    ROUND(
        AVG(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        1
    ) AS "Average LOS",
    ROUND(
        SUM(JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")),
        0
    ) AS "Total Patient-Days"
FROM Healthcare_Dataset_for_SQL
GROUP BY "Insurance Provider"
ORDER BY "Total Patient-Days" DESC;


/* ============================================================================
   4. INSURANCE & BILLING ANALYSIS
   ============================================================================ */

-- Business Question:
-- Which Insurance Providers account for the highest Total Billing, and how
-- does their Average Billing compare?
WITH cleaned_billing AS (
    SELECT
        "Insurance Provider",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
)
SELECT
    "Insurance Provider",
    COUNT(*) AS "Admission Count",
    ROUND(AVG(billing_amount), 2) AS "Average Billing",
    ROUND(SUM(billing_amount), 2) AS "Total Billing"
FROM cleaned_billing
GROUP BY "Insurance Provider"
ORDER BY "Total Billing" DESC;

-- Business Question:
-- Which Medical Condition × Admission Type combinations account for the
-- highest Total Billing, and what is the Average Billing for each?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
)
SELECT
    "Medical Condition",
    "Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(AVG(billing_amount), 2) AS "Average Billing",
    ROUND(SUM(billing_amount), 2) AS "Total Billing"
FROM cleaned_billing
GROUP BY "Medical Condition", "Admission Type"
ORDER BY "Total Billing" DESC;


/* ============================================================================
   5. BILLING BENCHMARK & VARIANCE ANALYSIS
   ============================================================================ */

-- Business Question:
-- Which combinations have Average Billing above the overall Average Billing
-- for their respective Medical Condition?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
)
SELECT
    billing_data."Medical Condition",
    billing_data."Admission Type",
    COUNT(*) AS "Admission Count",
    ROUND(AVG(billing_data.billing_amount), 2) AS "Average Billing",
    ROUND(
        (
            SELECT AVG(benchmark_data.billing_amount)
            FROM cleaned_billing AS benchmark_data
            WHERE benchmark_data."Medical Condition" =
                  billing_data."Medical Condition"
        ),
        2
    ) AS "Condition Billing Benchmark"
FROM cleaned_billing AS billing_data
GROUP BY
    billing_data."Medical Condition",
    billing_data."Admission Type"
HAVING
    AVG(billing_data.billing_amount) >
    (
        SELECT AVG(benchmark_data.billing_amount)
        FROM cleaned_billing AS benchmark_data
        WHERE benchmark_data."Medical Condition" =
              billing_data."Medical Condition"
    )
ORDER BY "Average Billing" DESC;

-- Business Question:
-- How much does Average Billing for each combination vary in dollars from
-- its condition-specific benchmark?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
)
SELECT
    billing_data."Medical Condition",
    billing_data."Admission Type",
    ROUND(AVG(billing_data.billing_amount), 2) AS "Average Billing",
    ROUND(billing_benchmark.condition_benchmark, 2)
        AS "Condition Billing Benchmark",
    ROUND(
        AVG(billing_data.billing_amount) -
        billing_benchmark.condition_benchmark,
        2
    ) AS "Billing Variance $"
FROM cleaned_billing AS billing_data
JOIN condition_benchmarks AS billing_benchmark
    ON billing_data."Medical Condition" =
       billing_benchmark."Medical Condition"
GROUP BY
    billing_data."Medical Condition",
    billing_data."Admission Type",
    billing_benchmark.condition_benchmark
ORDER BY "Billing Variance $" DESC;

-- Business Question:
-- What is the percentage difference between each combination's Average Billing
-- and its condition-specific benchmark?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
)
SELECT
    billing_data."Medical Condition",
    billing_data."Admission Type",
    ROUND(AVG(billing_data.billing_amount), 2) AS "Average Billing",
    ROUND(billing_benchmark.condition_benchmark, 2)
        AS "Condition Billing Benchmark",
    ROUND(
        AVG(billing_data.billing_amount) -
        billing_benchmark.condition_benchmark,
        2
    ) AS "Billing Variance $",
    ROUND(
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100,
        2
    ) AS "Billing Variance %"
FROM cleaned_billing AS billing_data
JOIN condition_benchmarks AS billing_benchmark
    ON billing_data."Medical Condition" =
       billing_benchmark."Medical Condition"
GROUP BY
    billing_data."Medical Condition",
    billing_data."Admission Type",
    billing_benchmark.condition_benchmark
ORDER BY "Billing Variance %" DESC;

-- Business Question:
-- Which combinations are Above, Near, or Below their condition-specific
-- billing benchmark?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        AVG(billing_data.billing_amount) AS average_billing,
        billing_benchmark.condition_benchmark,
        AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark AS billing_variance_dollars,
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
)
SELECT
    "Medical Condition",
    "Admission Type",
    ROUND(average_billing, 2) AS "Average Billing",
    ROUND(condition_benchmark, 2) AS "Condition Billing Benchmark",
    ROUND(billing_variance_dollars, 2) AS "Billing Variance $",
    ROUND(billing_variance_percent, 2) AS "Billing Variance %",
    CASE
        WHEN billing_variance_percent > 2 THEN 'Above Benchmark'
        WHEN billing_variance_percent < 0 THEN 'Below Benchmark'
        ELSE 'Near Benchmark'
    END AS "Billing Variance Classification"
FROM billing_variance_analysis
ORDER BY "Billing Variance %" DESC;

-- Business Question:
-- Which combinations have the largest percentage deviation from their
-- condition-specific benchmarks, regardless of direction?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        AVG(billing_data.billing_amount) AS average_billing,
        billing_benchmark.condition_benchmark,
        AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark AS billing_variance_dollars,
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
)
SELECT
    "Medical Condition",
    "Admission Type",
    ROUND(average_billing, 2) AS "Average Billing",
    ROUND(condition_benchmark, 2) AS "Condition Billing Benchmark",
    ROUND(billing_variance_dollars, 2) AS "Billing Variance $",
    ROUND(billing_variance_percent, 2) AS "Billing Variance %",
    ROUND(ABS(billing_variance_percent), 2) AS "Absolute Billing Variance %",
    CASE
        WHEN billing_variance_percent > 2 THEN 'Above Benchmark'
        WHEN billing_variance_percent < 0 THEN 'Below Benchmark'
        ELSE 'Near Benchmark'
    END AS "Billing Variance Classification"
FROM billing_variance_analysis
ORDER BY "Absolute Billing Variance %" DESC;

-- Business Question:
-- For each Medical Condition, which Admission Type has the largest Absolute
-- Billing Variance %? Ties would return more than one row for a condition.
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        AVG(billing_data.billing_amount) AS average_billing,
        billing_benchmark.condition_benchmark,
        AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark AS billing_variance_dollars,
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
)
SELECT
    variance_data."Medical Condition",
    variance_data."Admission Type",
    ROUND(variance_data.average_billing, 2) AS "Average Billing",
    ROUND(variance_data.condition_benchmark, 2)
        AS "Condition Billing Benchmark",
    ROUND(variance_data.billing_variance_dollars, 2) AS "Billing Variance $",
    ROUND(variance_data.billing_variance_percent, 2) AS "Billing Variance %",
    ROUND(ABS(variance_data.billing_variance_percent), 2)
        AS "Absolute Billing Variance %"
FROM billing_variance_analysis AS variance_data
WHERE
    ABS(variance_data.billing_variance_percent) =
    (
        SELECT MAX(ABS(comparison_data.billing_variance_percent))
        FROM billing_variance_analysis AS comparison_data
        WHERE comparison_data."Medical Condition" =
              variance_data."Medical Condition"
    )
ORDER BY variance_data."Medical Condition";

-- Business Question:
-- How many combinations fall into each Billing Variance Classification?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
),
classified_billing_variance AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        billing_variance_percent,
        CASE
            WHEN billing_variance_percent > 2 THEN 'Above Benchmark'
            WHEN billing_variance_percent < 0 THEN 'Below Benchmark'
            ELSE 'Near Benchmark'
        END AS "Billing Variance Classification"
    FROM billing_variance_analysis
)
SELECT
    "Billing Variance Classification",
    COUNT(*) AS "Combination Count"
FROM classified_billing_variance
GROUP BY "Billing Variance Classification"
ORDER BY "Combination Count" DESC;

-- Business Question:
-- What percentage of all combinations belongs to each Billing Variance
-- Classification?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
),
classified_billing_variance AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        billing_variance_percent,
        CASE
            WHEN billing_variance_percent > 2 THEN 'Above Benchmark'
            WHEN billing_variance_percent < 0 THEN 'Below Benchmark'
            ELSE 'Near Benchmark'
        END AS "Billing Variance Classification"
    FROM billing_variance_analysis
)
SELECT
    "Billing Variance Classification",
    COUNT(*) AS "Combination Count",
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM classified_billing_variance),
        2
    ) AS "Percentage of Total Combinations"
FROM classified_billing_variance
GROUP BY "Billing Variance Classification"
ORDER BY "Combination Count" DESC;


/* ============================================================================
   6. INTEGRATED UTILIZATION & BILLING ANALYSIS
   ============================================================================ */

-- Business Question:
-- Which combinations have both Average LOS above the overall dataset average
-- and positive Billing Variance %?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
),
utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS average_los
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
)
SELECT
    utilization_data."Medical Condition",
    utilization_data."Admission Type",
    utilization_data.admission_count AS "Admission Count",
    ROUND(utilization_data.average_los, 2) AS "Average LOS",
    ROUND(billing_data.billing_variance_percent, 2) AS "Billing Variance %"
FROM utilization_analysis AS utilization_data
JOIN billing_variance_analysis AS billing_data
    ON utilization_data."Medical Condition" =
       billing_data."Medical Condition"
   AND utilization_data."Admission Type" =
       billing_data."Admission Type"
WHERE
    utilization_data.average_los >
    (
        SELECT AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        )
        FROM Healthcare_Dataset_for_SQL
    )
    AND billing_data.billing_variance_percent > 0
ORDER BY utilization_data.average_los DESC;

-- Business Question:
-- Among combinations with positive Billing Variance %, which account for the
-- greatest Total Patient-Days?
WITH cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
),
utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
)
SELECT
    utilization_data."Medical Condition",
    utilization_data."Admission Type",
    utilization_data.admission_count AS "Admission Count",
    ROUND(utilization_data.total_patient_days, 0) AS "Total Patient-Days",
    ROUND(billing_data.billing_variance_percent, 2) AS "Billing Variance %"
FROM utilization_analysis AS utilization_data
JOIN billing_variance_analysis AS billing_data
    ON utilization_data."Medical Condition" =
       billing_data."Medical Condition"
   AND utilization_data."Admission Type" =
       billing_data."Admission Type"
WHERE billing_data.billing_variance_percent > 0
ORDER BY utilization_data.total_patient_days DESC;

-- Business Question:
-- What percentage of overall Total Patient-Days does each combination account for?
WITH utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
)
SELECT
    "Medical Condition",
    "Admission Type",
    admission_count AS "Admission Count",
    ROUND(total_patient_days, 0) AS "Total Patient-Days",
    ROUND(
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis),
        2
    ) AS "Percentage of Total Patient-Days"
FROM utilization_analysis
ORDER BY total_patient_days DESC;

-- Business Question:
-- Which combinations contribute a greater share of Total Patient-Days than
-- their share of Total Admissions?
WITH utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
)
SELECT
    "Medical Condition",
    "Admission Type",
    admission_count AS "Admission Count",
    ROUND(total_patient_days, 0) AS "Total Patient-Days",
    ROUND(
        admission_count * 100.0 /
        (SELECT SUM(admission_count) FROM utilization_analysis),
        2
    ) AS "Admission Share %",
    ROUND(
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis),
        2
    ) AS "Patient-Day Share %",
    ROUND(
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis)
        -
        admission_count * 100.0 /
        (SELECT SUM(admission_count) FROM utilization_analysis),
        2
    ) AS "Share Difference"
FROM utilization_analysis
WHERE
    total_patient_days * 1.0 /
    (SELECT SUM(total_patient_days) FROM utilization_analysis)
    >
    admission_count * 1.0 /
    (SELECT SUM(admission_count) FROM utilization_analysis)
ORDER BY "Share Difference" DESC;

-- Business Question:
-- Among combinations with positive Share Difference, which has the
-- highest Average LOS?
WITH utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS average_los,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
),
share_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        admission_count,
        average_los,
        total_patient_days,
        admission_count * 100.0 /
        (SELECT SUM(admission_count) FROM utilization_analysis)
            AS admission_share,
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis)
            AS patient_day_share,
        (
            total_patient_days * 100.0 /
            (SELECT SUM(total_patient_days) FROM utilization_analysis)
            -
            admission_count * 100.0 /
            (SELECT SUM(admission_count) FROM utilization_analysis)
        ) AS share_difference
    FROM utilization_analysis
)
SELECT
    "Medical Condition",
    "Admission Type",
    admission_count AS "Admission Count",
    ROUND(average_los, 2) AS "Average LOS",
    ROUND(admission_share, 2) AS "Admission Share %",
    ROUND(patient_day_share, 2) AS "Patient-Day Share %",
    ROUND(share_difference, 2) AS "Share Difference"
FROM share_analysis
WHERE share_difference > 0
ORDER BY average_los DESC
LIMIT 1;


/* ============================================================================
   7. MANAGEMENT PRIORITY ANALYSIS
   ============================================================================ */

-- Business Question:
-- Which combinations have both positive Share Difference and positive
-- Billing Variance %?
WITH utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS average_los,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
),
share_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        admission_count,
        average_los,
        total_patient_days,
        admission_count * 100.0 /
        (SELECT SUM(admission_count) FROM utilization_analysis)
            AS admission_share,
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis)
            AS patient_day_share,
        (
            total_patient_days * 100.0 /
            (SELECT SUM(total_patient_days) FROM utilization_analysis)
            -
            admission_count * 100.0 /
            (SELECT SUM(admission_count) FROM utilization_analysis)
        ) AS share_difference
    FROM utilization_analysis
),
cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        AVG(billing_data.billing_amount) AS average_billing,
        billing_benchmark.condition_benchmark,
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
)
SELECT
    share_data."Medical Condition",
    share_data."Admission Type",
    ROUND(share_data.average_los, 2) AS "Average LOS",
    ROUND(share_data.share_difference, 2) AS "Share Difference",
    ROUND(billing_data.average_billing, 2) AS "Average Billing",
    ROUND(billing_data.condition_benchmark, 2)
        AS "Condition Billing Benchmark",
    ROUND(billing_data.billing_variance_percent, 2) AS "Billing Variance %"
FROM share_analysis AS share_data
JOIN billing_variance_analysis AS billing_data
    ON share_data."Medical Condition" =
       billing_data."Medical Condition"
   AND share_data."Admission Type" =
       billing_data."Admission Type"
WHERE
    share_data.share_difference > 0
    AND billing_data.billing_variance_percent > 0
ORDER BY share_data.share_difference DESC;

-- Business Question:
-- Among the priority combinations above, which Medical Condition accounts
-- for the greatest combined Total Patient-Days?
WITH utilization_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        COUNT(*) AS admission_count,
        AVG(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS average_los,
        SUM(
            JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
        ) AS total_patient_days
    FROM Healthcare_Dataset_for_SQL
    GROUP BY "Medical Condition", "Admission Type"
),
share_analysis AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        admission_count,
        average_los,
        total_patient_days,
        admission_count * 100.0 /
        (SELECT SUM(admission_count) FROM utilization_analysis)
            AS admission_share,
        total_patient_days * 100.0 /
        (SELECT SUM(total_patient_days) FROM utilization_analysis)
            AS patient_day_share,
        (
            total_patient_days * 100.0 /
            (SELECT SUM(total_patient_days) FROM utilization_analysis)
            -
            admission_count * 100.0 /
            (SELECT SUM(admission_count) FROM utilization_analysis)
        ) AS share_difference
    FROM utilization_analysis
),
cleaned_billing AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        CAST(REPLACE(REPLACE("Billing Amount", '$', ''), ',', '') AS REAL)
            AS billing_amount
    FROM Healthcare_Dataset_for_SQL
),
condition_benchmarks AS (
    SELECT
        "Medical Condition",
        AVG(billing_amount) AS condition_benchmark
    FROM cleaned_billing
    GROUP BY "Medical Condition"
),
billing_variance_analysis AS (
    SELECT
        billing_data."Medical Condition",
        billing_data."Admission Type",
        (
            AVG(billing_data.billing_amount) -
            billing_benchmark.condition_benchmark
        ) / billing_benchmark.condition_benchmark * 100
            AS billing_variance_percent
    FROM cleaned_billing AS billing_data
    JOIN condition_benchmarks AS billing_benchmark
        ON billing_data."Medical Condition" =
           billing_benchmark."Medical Condition"
    GROUP BY
        billing_data."Medical Condition",
        billing_data."Admission Type",
        billing_benchmark.condition_benchmark
),
priority_combinations AS (
    SELECT
        share_data."Medical Condition",
        share_data."Admission Type",
        share_data.total_patient_days,
        share_data.share_difference,
        billing_data.billing_variance_percent
    FROM share_analysis AS share_data
    JOIN billing_variance_analysis AS billing_data
        ON share_data."Medical Condition" =
           billing_data."Medical Condition"
       AND share_data."Admission Type" =
           billing_data."Admission Type"
    WHERE
        share_data.share_difference > 0
        AND billing_data.billing_variance_percent > 0
)
SELECT
    "Medical Condition",
    ROUND(SUM(total_patient_days), 0) AS "Combined Total Patient-Days"
FROM priority_combinations
GROUP BY "Medical Condition"
ORDER BY SUM(total_patient_days) DESC
LIMIT 1;


/* ============================================================================
   VERIFIED FINDINGS FROM THE ANALYSIS
   ============================================================================

   - Total admissions: 54,966.
   - Overall Average LOS: approximately 15.5 days.
   - Hypertension × Elective had the highest Total Patient-Days among all
     Medical Condition × Admission Type combinations.
   - Medicaid had the highest Total Patient-Days and highest Average LOS among
     Insurance Providers.
   - Cigna had the highest Total Billing among Insurance Providers.
   - Diabetes × Urgent had the highest Total Billing among Medical Condition ×
     Admission Type combinations.
   - Cancer × Elective had the largest positive and absolute Billing Variance %:
     approximately +2.07%.
   - Billing Variance Classification distribution across 18 combinations:
       Below Benchmark: 10
       Near Benchmark:   7
       Above Benchmark:  1
   - Eight combinations had a positive Patient-Day Share minus Admission Share.
   - Asthma × Urgent had the largest positive Share Difference.
   - Cancer × Emergency had the highest Average LOS among combinations with a
     positive Share Difference.
   - Three combinations had both positive Share Difference and positive Billing
     Variance %:
       Asthma × Urgent
       Asthma × Emergency
       Diabetes × Elective
   - Asthma × Urgent ranked first among those three by Share Difference.
   - Across those priority combinations, Asthma accounted for the greatest
     combined Total Patient-Days: 94,317.

   These findings describe associations in the supplied admission-level data.
   They do not establish causation or measure clinical quality, staffing
   efficiency, profitability, reimbursement, or hospital capacity.
===============================================================================
*/
