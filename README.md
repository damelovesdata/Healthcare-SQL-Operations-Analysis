# Healthcare Operations & Billing Analysis — SQL

## Project Overview

This project uses **SQLite** to analyze **54,966 healthcare admission records** and evaluate inpatient utilization and billed-charge patterns across medical conditions, admission types, and insurance providers.

The analysis progresses from admission volume and length of stay (LOS) to patient-day utilization, condition-specific billing benchmarks, billing variance, and combined operational priority indicators. The goal is to demonstrate how SQL can be used to move from descriptive analysis to more focused management questions.

> **Important:** Each row represents an admission record, not necessarily a unique patient. `Billing Amount` represents billed charges and should not be interpreted as reimbursement, revenue, profit, or cost.

## Business Questions

The analysis addresses questions such as:

- How are admissions distributed across medical conditions and admission types?
- Which Medical Condition × Admission Type combinations have above-average LOS?
- Which combinations generate the greatest Total Patient-Days?
- Which insurance providers account for the greatest inpatient utilization and Total Billing?
- How does Average Billing for each Medical Condition × Admission Type combination compare with its condition-specific benchmark?
- Which combinations have the largest Billing Variance % regardless of direction?
- Which combinations contribute a greater share of patient-days than their share of admissions?
- Which combinations simultaneously have a positive Share Difference and positive Billing Variance %?
- Among those priority combinations, which Medical Condition accounts for the greatest combined Total Patient-Days?

## Tools & SQL Techniques

**Tools:** SQLite, DBeaver

**SQL techniques demonstrated:**

- `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, and `ORDER BY`
- Aggregate functions including `COUNT()`, `AVG()`, `SUM()`, and `MAX()`
- Common Table Expressions (CTEs)
- Subqueries and correlated subqueries
- `JOIN` operations using multiple matching fields
- `CASE` expressions for classification
- `CAST()`, `REPLACE()`, `ROUND()`, and `ABS()`
- SQLite `JULIANDAY()` for Length of Stay calculations
- Dynamic benchmark calculations
- Percentage-of-total and share-difference calculations

## Dataset Fields Used

The analysis primarily uses:

- `Medical Condition`
- `Admission Type`
- `Insurance Provider`
- `Billing Amount`
- `Date of Admission`
- `Discharge Date`

Length of Stay is calculated as:

```sql
JULIANDAY("Discharge Date") - JULIANDAY("Date of Admission")
```

Because `Billing Amount` may contain currency symbols and commas, billing analyses convert it to a numeric value:

```sql
CAST(
    REPLACE(REPLACE("Billing Amount", '$', ''), ',', '')
    AS REAL
)
```

## Analysis Workflow

### 1. Data Validation

The project begins by inspecting the SQLite table schema, validating the admission and discharge date fields, testing the LOS calculation, and establishing the overall Average LOS benchmark.

### 2. Admission Volume & Distribution

Admission counts and percentages are analyzed by Medical Condition and Admission Type. Dynamic benchmarks are then used to identify combinations with both above-average admission volume and above-average LOS.

### 3. Length of Stay & Patient Utilization

Utilization is evaluated using Average LOS, Estimated Patient-Days, and Total Patient-Days.

**Total Patient-Days** is calculated by summing the LOS of individual admission records:

```sql
SUM(
    JULIANDAY("Discharge Date")
    - JULIANDAY("Date of Admission")
)
```

This analysis is also extended to the Insurance Provider level.

### 4. Insurance & Billing Analysis

Billing Amount is cleaned and converted to a numeric field before calculating Average Billing and Total Billing by Insurance Provider and by Medical Condition × Admission Type.

### 5. Billing Benchmark & Variance Analysis

A condition-specific billing benchmark is calculated using Average Billing across all admissions belonging to each Medical Condition.

For each Medical Condition × Admission Type combination:

**Billing Variance $**

```text
Combination Average Billing - Condition Billing Benchmark
```

**Billing Variance %**

```text
((Combination Average Billing - Condition Billing Benchmark)
 / Condition Billing Benchmark) × 100
```

Combinations are classified as:

| Classification | Rule |
|---|---|
| Above Benchmark | Billing Variance % > 2% |
| Near Benchmark | 0% ≤ Billing Variance % ≤ 2% |
| Below Benchmark | Billing Variance % < 0% |

Absolute Billing Variance % is also calculated to identify the largest deviations regardless of whether the variance is positive or negative.

### 6. Integrated Utilization & Billing Analysis

The analysis then combines utilization and billing metrics.

Admission Share and Patient-Day Share are calculated for each Medical Condition × Admission Type combination.

**Share Difference**

```text
Patient-Day Share % - Admission Share %
```

A positive Share Difference means a combination accounts for a greater proportion of total patient-days than its proportion of total admissions.

### 7. Management Priority Analysis

The final analysis identifies combinations meeting both of the following criteria:

- Positive Share Difference
- Positive Billing Variance %

These criteria highlight combinations whose relative patient-day contribution exceeds their admission share while their Average Billing is also above the benchmark for their Medical Condition.

The qualifying combinations are then aggregated to the Medical Condition level to determine which condition accounts for the greatest combined Total Patient-Days within this filtered group.

## Key Findings

- The dataset contains **54,966 admission records**, with an overall Average LOS of approximately **15.5 days**.
- **Hypertension × Elective** had the highest Total Patient-Days among all Medical Condition × Admission Type combinations.
- **Medicaid** had the highest Total Patient-Days and highest Average LOS among Insurance Providers.
- **Cigna** had the highest Total Billing among Insurance Providers.
- **Diabetes × Urgent** had the highest Total Billing among Medical Condition × Admission Type combinations.
- **Cancer × Elective** had the largest positive and absolute Billing Variance %, at approximately **+2.07%**.
- Across the 18 Medical Condition × Admission Type combinations, billing classifications were **10 Below Benchmark, 7 Near Benchmark, and 1 Above Benchmark**.
- **Eight combinations** had a positive Share Difference.
- **Asthma × Urgent** had the largest positive Share Difference.
- **Cancer × Emergency** had the highest Average LOS among combinations with a positive Share Difference.
- Three combinations had both positive Share Difference and positive Billing Variance %: **Asthma × Urgent, Asthma × Emergency, and Diabetes × Elective**.
- Among those three, **Asthma × Urgent** ranked first by Share Difference.
- When the qualifying combinations were aggregated by Medical Condition, **Asthma accounted for 94,317 combined Total Patient-Days**, the highest total within the filtered priority group.

## Interpretation

The final results identify areas that may warrant additional operational review rather than establishing that a particular condition or admission type is inefficient.

For example, a positive Share Difference indicates that a combination contributes more patient-days relative to its admission volume. A positive Billing Variance % indicates that its Average Billing is above the overall Average Billing for the same Medical Condition. When both occur together, the combination may be useful for deeper investigation.

Additional clinical, staffing, capacity, reimbursement, and case-severity information would be required before drawing conclusions about causes or operational performance.

## Project Limitations

This dataset does not provide enough information to evaluate:

- Hospital staffing levels
- Bed capacity or occupancy constraints
- Actual treatment costs
- Insurance reimbursement
- Revenue or profitability
- Clinical severity or case complexity
- Causal relationships between LOS and billed charges

