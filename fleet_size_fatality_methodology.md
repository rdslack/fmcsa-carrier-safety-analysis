# Fleet Size and Fatal Crash Risk: Dataset, Methodology, and SQL Queries

**Prepared by:** Reed Slack, Tanjentz LLC  
**Data source:** FMCSA public datasets (links below)  
**Analysis date:** May 10, 2026  
**SMS data snapshot:** March 31, 2026 (covering 24-month window April 1, 2024 through March 31, 2026)

---

## Summary of Findings

**Key finding:** Among interstate motor carriers with 1 to 500 power units, representing 99.86% of all active interstate carriers, exposure-adjusted fatal crash rates are essentially identical across all four fleet size cohorts, ranging from 0.1020 to 0.1308 fatal crashes per 100 power units. No meaningful safety gradient exists. Fatal crash severity, measured as fatalities per crash event, is virtually identical across all four cohorts (1.16 to 1.21) regardless of fleet size. The data does not support the claim that larger carriers have materially better fatal crash outcomes than smaller carriers on a per-unit exposure basis.

The 500+ power unit cohort is excluded from the per-100-PU rate analysis due to systemic data quality problems in the FMCSA census field documented below. That cohort represents 0.14% of the interstate carrier population and its exclusion does not affect the analytical conclusion.

| Metric | Value |
|---|---|
| Interstate carriers analyzed (CARRIER_OPERATION = 'A') | 641,019 |
| Fleet size cohorts in rate analysis | 1-5, 6-25, 26-100, 101-500 power units |
| Carriers in rate analysis | 640,105 (99.86% of interstate population) |
| Fatal crash rate per 100 PU, 1-5 cohort | 0.1308 |
| Fatal crash rate per 100 PU, 6-25 cohort | 0.1213 |
| Fatal crash rate per 100 PU, 26-100 cohort | 0.1020 |
| Fatal crash rate per 100 PU, 101-500 cohort | 0.1043 |
| Fatalities per fatal crash event, all four cohorts | 1.16 to 1.21 |
| Carriers with any fatal crash, 1-5 cohort | 0.23% |
| Carriers with any fatal crash, 6-25 cohort | 1.35% |
| Carriers with any fatal crash, 26-100 cohort | 4.67% |
| Carriers with any fatal crash, 101-500 cohort | 17.03% |

---

## Background and Motivation

This analysis was prompted by commentary in freight industry media and legal proceedings suggesting that larger carriers are meaningfully safer than smaller carriers due to their access to safety technology including collision mitigation systems, dashcams, and telematics systems. The premise is that financial resources allow large carriers to adopt safety technology that small carriers cannot afford, producing better safety outcomes.

This analysis examines whether that premise is supported by FMCSA fatal crash data when carrier size is accounted for as an exposure variable.

---

## Data Sources

Both datasets are publicly available from the U.S. Department of Transportation and downloadable at no cost. No proprietary data, cleaning, or transformation beyond direct ingestion into BigQuery has been applied.

**SMS Input - Motor Carrier Census Information**  
FMCSA registration data for active Interstate and Intrastate motor carriers. One carrier per row. Includes power unit counts (NBR_POWER_UNIT) and carrier operation type (CARRIER_OPERATION).  
https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Motor-Carrier-Census-Information/kjg3-diqy/about_data  
Ingested as: `fmcsa_raw_v11.census_staging`

**SMS Input - Crash**  
State-reported crash records for commercial motor vehicles included in the FMCSA Safety Measurement System. Each row represents one reportable crash event.  
https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Crash/4wxs-vbns/about_data  
Ingested as: `fmcsa_raw_v11.crash_staging`

Note: This analysis uses two tables only. The AuthHist dataset is not required.

---

## A Note on Table Names and SQL Environments

The table names used in these queries reflect the naming conventions used in the author's Google BigQuery project. These tables are not publicly accessible. To reproduce this analysis, download the two public FMCSA datasets linked above and ingest them into any SQL environment of your choosing. Update the table references in the queries to match the names assigned during your ingestion. The queries are written in BigQuery SQL dialect. `SAFE_CAST` and `APPROX_QUANTILES` are BigQuery-specific; equivalent functions exist in other SQL environments.

---

## Methodology

### Scope: Interstate carriers only

This analysis is restricted to carriers with `CARRIER_OPERATION = 'A'` (interstate motor carriers) throughout. This restriction applies to both the exposure denominator (power unit counts and carrier population) and the fatal crash numerator. Intrastate carriers (operation codes B and C) are excluded from all calculations.

This restriction was chosen for two reasons. First, analytical consistency requires that the numerator and denominator draw from the same population. Second, the policy question being examined, whether large carriers are safer due to technology access, pertains specifically to interstate for-hire operations.

### Fleet size cohort definitions

Carriers are assigned to cohorts based on the `NBR_POWER_UNIT` field in the census table:

| Cohort | Power unit range |
|--------|-----------------|
| 1-5 | 1 to 5 |
| 6-25 | 6 to 25 |
| 26-100 | 26 to 100 |
| 101-500 | 101 to 500 |
| 500+ | Greater than 500 (excluded from rate analysis — see below) |

Carriers with NULL or zero reported power units are excluded from rate calculations and reported separately as Unknown.

### Data integrity issue in the 500+ cohort and its exclusion from rate analysis

The `NBR_POWER_UNIT` field in the FMCSA census contains a systemic data quality problem concentrated in carriers reporting more than 500 power units. This was identified through a series of diagnostic queries and is documented fully in the SQL section below.

Key findings from the diagnostic queries:

- The full 500+ cohort (all carrier operation types) contained 2,336 carriers reporting a total of 70.4 million power units, a figure implausible for any segment of the U.S. trucking industry
- The median reported fleet size in the 500+ cohort was 8,002 power units; the maximum was 1,299,987
- The top 20 carriers by reported PU count included a lawn service, a junk removal company, and multiple carriers each reporting exactly 599,994 units, strongly suggesting a corrupted default value in the FMCSA registration system
- Restricting to interstate carriers (CARRIER_OPERATION = 'A') reduced the total to 963 carriers reporting 5.4 million power units. This remains implausible: the entire U.S. commercial trucking industry operates approximately 4 million power units total across all carrier types
- A further cap at 30,000 power units, generous enough to include the largest legitimate U.S. fleets (FedEx Freight at approximately 29,000 tractors, Knight-Swift at approximately 27,000), still produced 914 carriers reporting 1.77 million power units, averaging 1,939 power units per carrier, far above any realistic large fleet average

The bin structure of this analysis amplifies the data quality problem. In the 1-5, 6-25, 26-100, and 101-500 cohorts, any corrupted PU value above the bin ceiling is automatically re-assigned to the 500+ bin. The smaller bins are therefore bounded by their own ceiling: the worst-case contamination in the 101-500 bin is a carrier reporting 500 power units when it should report fewer. In the 500+ bin, there is no ceiling, and corrupted values ranging from tens of thousands to over a million accumulate without bound.

The per-100-PU rate for the 500+ cohort cannot be computed reliably because the denominator (total power units) is inflated by an unknown but substantial amount. The cohort is excluded from the rate analysis. This exclusion covers 914 interstate carriers out of 641,019 total, representing 0.14% of the population. The four cohorts included in the rate analysis cover 99.86% of all active interstate carriers.

Note for reproducibility: users who attempt to apply a power unit cap to retain the 500+ cohort in the rate analysis should be aware that the data quality problem is systemic, not limited to extreme outliers. Any cap below approximately 30,000 will exclude legitimate large carriers; any cap at or above that threshold still produces implausible total power unit counts.

### Defining fatal crash involvement

A crash record is included in the fatal crash population if `SAFE_CAST(fatalities AS INT64) >= 1`. All fields in `crash_staging` are stored as strings; numeric comparison requires casting. Records with NULL or empty fatality fields are excluded.

Three distinct metrics are reported:

- **Carriers with fatal crashes:** count of distinct carrier DOT numbers appearing in fatal crash records
- **Fatal crash events:** count of distinct crash report numbers (Report_number) with at least one fatality. A single carrier may appear in multiple crash events.
- **Total fatalities:** sum of fatalities across all qualifying crash records

Separating crash frequency from fatality count is methodologically important. Total fatalities can be influenced by factors outside the carrier's control, including the number of occupants in other vehicles and whether seatbelts were worn. Fatal crash event count is a cleaner measure of carrier crash frequency.

### Exposure normalization

Fatal crash rates are expressed per 100 power units, using the total power units reported across all active carriers in each cohort as the denominator. This normalizes for fleet size and allows direct comparison across cohorts of different sizes.

Power units is an imperfect exposure proxy because it does not capture differences in annual miles driven across carrier types and operations. Reliable carrier-level mileage data is not publicly available in the FMCSA public datasets; the MCS-150 mileage field is self-reported and not independently verified. A fully mileage-normalized rate is therefore not possible with public data alone. This limitation applies equally across all four cohorts and does not explain the flat pattern observed.

The denominator includes all active interstate carriers in each cohort, not only those involved in crashes. This produces a population-level rate rather than a crash-conditional rate.

---

## What This Analysis Cannot Tell Us

This analysis measures crash outcomes, not the safety technology inputs that may influence them. A finding that no meaningful fatal crash rate gradient exists across the four cohorts does not rule out that collision mitigation systems, dashcams, or telematics reduce crash risk and that some other factor offsets the benefit. Factors that could complicate the comparison include annual miles driven per power unit, freight type and route characteristics, and driver experience and turnover rates, none of which are available in the public FMCSA datasets.

What the data can say is that the outcome evidence does not support the size-equals-safety claim as stated. If large carrier technology access were producing meaningfully better fatal crash outcomes at the fleet level, a gradient would be visible in the per-100-PU rates. No such gradient exists across the four reliable cohorts.

---

## SQL Queries and Validated Results

Note: Queries are written in Google BigQuery SQL dialect. `SAFE_CAST` and `APPROX_QUANTILES` are BigQuery-specific; equivalent syntax exists in other SQL environments. All fields in both source tables are stored as strings; numeric comparisons require casting.

---

### Diagnostic Query A: Power unit distribution statistics for the 500+ cohort

Run this query first to understand the data quality problem before proceeding to the main analysis.

```sql
SELECT
  COUNT(*)                                      AS carrier_count,
  MIN(SAFE_CAST(NBR_POWER_UNIT AS INT64))       AS min_pu,
  MAX(SAFE_CAST(NBR_POWER_UNIT AS INT64))       AS max_pu,
  ROUND(AVG(SAFE_CAST(NBR_POWER_UNIT AS INT64)), 0) AS avg_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(50)]
                                                AS median_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(90)]
                                                AS p90_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(99)]
                                                AS p99_pu,
  SUM(SAFE_CAST(NBR_POWER_UNIT AS INT64))       AS total_pu
FROM fmcsa_raw_v11.census_staging
WHERE SAFE_CAST(NBR_POWER_UNIT AS INT64) > 500;
```

**Validated results (March 2026 snapshot, all carrier operation types):**

| carrier_count | min_pu | max_pu | avg_pu | median_pu | p90_pu | p99_pu | total_pu |
|---|---|---|---|---|---|---|---|
| 2,336 | 501 | 1,299,987 | 30,158 | 8,002 | 70,000 | 400,000 | 70,448,732 |

---

### Diagnostic Query B: Top 20 carriers by reported power unit count

```sql
SELECT
  LPAD(TRIM(DOT_NUMBER), 8, '0') AS usdot_str_8,
  LEGAL_NAME,
  SAFE_CAST(NBR_POWER_UNIT AS INT64) AS power_units
FROM fmcsa_raw_v11.census_staging
WHERE SAFE_CAST(NBR_POWER_UNIT AS INT64) > 500
ORDER BY SAFE_CAST(NBR_POWER_UNIT AS INT64) DESC
LIMIT 20;
```

**Validated results (March 2026 snapshot):** Top reported carriers include Reliable Transporters (1,299,987), Premium Holdings (799,992), and eight unrelated carriers each reporting exactly 599,994, including a lawn service and a junk removal company. None are legitimate large carriers.

---

### Diagnostic Query C: Power unit distribution by band within the 500+ cohort

```sql
SELECT
  CASE
    WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 1000   THEN '501-1000'
    WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 2500   THEN '1001-2500'
    WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5000   THEN '2501-5000'
    WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 10000  THEN '5001-10000'
    WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 50000  THEN '10001-50000'
    ELSE '50000+'
  END AS pu_band,
  COUNT(*)                                            AS carrier_count,
  SUM(SAFE_CAST(NBR_POWER_UNIT AS INT64))             AS total_pu,
  MIN(SAFE_CAST(NBR_POWER_UNIT AS INT64))             AS min_pu,
  MAX(SAFE_CAST(NBR_POWER_UNIT AS INT64))             AS max_pu
FROM fmcsa_raw_v11.census_staging
WHERE SAFE_CAST(NBR_POWER_UNIT AS INT64) > 500
GROUP BY pu_band
ORDER BY MIN(SAFE_CAST(NBR_POWER_UNIT AS INT64));
```

**Validated results (March 2026 snapshot):**

| pu_band | carrier_count | total_pu | min_pu | max_pu |
|---|---|---|---|---|
| 501-1000 | 636 | 442,463 | 501 | 1,000 |
| 1001-2500 | 323 | 514,317 | 1,002 | 2,500 |
| 2501-5000 | 139 | 534,032 | 2,501 | 5,000 |
| 5001-10000 | 181 | 1,546,635 | 5,002 | 10,000 |
| 10001-50000 | 685 | 17,521,007 | 10,001 | 50,000 |
| 50000+ | 372 | 49,890,278 | 50,001 | 1,299,987 |

The 50,000+ band accounts for 372 carriers and 49.9 million of the 70.4 million total reported power units. These are not legitimate large carriers.

---

### Query 1: Fatal crash carriers (1+ fatalities) by fleet size cohort vs. active population share

```sql
WITH census_with_bins AS (
  SELECT
    LPAD(TRIM(DOT_NUMBER), 8, '0') AS usdot_str_8,
    SAFE_CAST(NBR_POWER_UNIT AS INT64) AS power_units,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 'Unknown'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN '1-5'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN '6-25'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN '26-100'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN '101-500'
      ELSE '500+'
    END AS fleet_size_cohort,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 6
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN 1
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN 2
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN 3
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN 4
      ELSE 5
    END AS cohort_sort
  FROM fmcsa_raw_v11.census_staging
  WHERE CARRIER_OPERATION = 'A'
),

fatal_crash_carriers AS (
  SELECT
    LPAD(CAST(DOT_Number AS STRING), 8, '0') AS usdot_str_8,
    SUM(SAFE_CAST(fatalities AS INT64)) AS total_fatalities
  FROM fmcsa_raw_v11.crash_staging
  WHERE SAFE_CAST(fatalities AS INT64) >= 1
    AND fatalities IS NOT NULL
    AND fatalities != ''
  GROUP BY usdot_str_8
),

active_by_cohort AS (
  SELECT
    fleet_size_cohort,
    cohort_sort,
    COUNT(*) AS active_carriers
  FROM census_with_bins
  GROUP BY fleet_size_cohort, cohort_sort
),

fatal_with_cohort AS (
  SELECT
    COALESCE(c.fleet_size_cohort, 'Unknown') AS fleet_size_cohort,
    COALESCE(c.cohort_sort, 6)               AS cohort_sort,
    COUNT(*)                                  AS fatal_crash_carriers,
    SUM(f.total_fatalities)                   AS total_fatalities
  FROM fatal_crash_carriers f
  INNER JOIN census_with_bins c ON f.usdot_str_8 = c.usdot_str_8
  GROUP BY fleet_size_cohort, cohort_sort
)

SELECT
  fw.fleet_size_cohort,
  fw.fatal_crash_carriers,
  fw.total_fatalities,
  ROUND(fw.total_fatalities / fw.fatal_crash_carriers, 2)
    AS fatalities_per_carrier,
  ROUND(fw.fatal_crash_carriers
    / SUM(fw.fatal_crash_carriers) OVER () * 100, 1)
    AS pct_of_fatal_crash_carriers,
  ac.active_carriers,
  ROUND(ac.active_carriers
    / SUM(ac.active_carriers) OVER () * 100, 1)
    AS pct_of_active_carriers,
  ROUND(
    (fw.fatal_crash_carriers / SUM(fw.fatal_crash_carriers) OVER ())
    / NULLIF(ac.active_carriers / SUM(ac.active_carriers) OVER (), 0)
  , 2) AS representation_ratio
FROM fatal_with_cohort fw
LEFT JOIN active_by_cohort ac
  ON fw.fleet_size_cohort = ac.fleet_size_cohort
ORDER BY fw.cohort_sort;
```

**Validated results (March 2026 snapshot, interstate carriers only):**

| fleet_size_cohort | fatal_crash_carriers | total_fatalities | fatalities_per_carrier | pct_of_fatal_crash_carriers | active_carriers | pct_of_active_carriers | representation_ratio |
|---|---|---|---|---|---|---|---|
| 1-5 | 1,219 | 1,406 | 1.15 | 27.3 | 534,090 | 81.1 | 0.34 |
| 6-25 | 1,098 | 1,333 | 1.21 | 24.6 | 81,386 | 12.4 | 1.99 |
| 26-100 | 931 | 1,122 | 1.21 | 20.8 | 19,920 | 3.0 | 6.89 |
| 101-500 | 802 | 1,156 | 1.44 | 17.9 | 4,709 | 0.7 | 25.10 |
| 500+ | 414 | 1,478 | 3.57 | 9.3 | 963 | 0.1 | 63.37 |
| Unknown | 6 | 8 | 1.33 | 0.1 | 17,799 | 2.7 | 0.05 |

*Note: The 500+ row is included here for completeness. The representation ratio for this cohort is reported but the per-100-PU rates in Query 3 are excluded for this cohort due to the data integrity issue documented above.*

*representation_ratio: 1.0 = proportional; < 1.0 = under-represented; > 1.0 = over-represented relative to active carrier share*

---

### Query 2: Catastrophic crash carriers (3+ fatalities) by fleet size vs. active population share

```sql
WITH census_with_bins AS (
  SELECT
    LPAD(TRIM(DOT_NUMBER), 8, '0') AS usdot_str_8,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 'Unknown'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN '1-5'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN '6-25'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN '26-100'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN '101-500'
      ELSE '500+'
    END AS fleet_size_cohort,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 6
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN 1
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN 2
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN 3
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN 4
      ELSE 5
    END AS cohort_sort
  FROM fmcsa_raw_v11.census_staging
  WHERE CARRIER_OPERATION = 'A'
),

catastrophic_crash_carriers AS (
  SELECT
    LPAD(CAST(DOT_Number AS STRING), 8, '0') AS usdot_str_8,
    SUM(SAFE_CAST(fatalities AS INT64)) AS total_fatalities
  FROM fmcsa_raw_v11.crash_staging
  WHERE SAFE_CAST(fatalities AS INT64) >= 3
    AND fatalities IS NOT NULL
    AND fatalities != ''
  GROUP BY usdot_str_8
),

active_by_cohort AS (
  SELECT
    fleet_size_cohort,
    cohort_sort,
    COUNT(*) AS active_carriers
  FROM census_with_bins
  GROUP BY fleet_size_cohort, cohort_sort
),

catastrophic_with_cohort AS (
  SELECT
    COALESCE(c.fleet_size_cohort, 'Unknown') AS fleet_size_cohort,
    COALESCE(c.cohort_sort, 6)               AS cohort_sort,
    COUNT(*)                                  AS catastrophic_crash_carriers,
    SUM(cc.total_fatalities)                  AS total_fatalities
  FROM catastrophic_crash_carriers cc
  INNER JOIN census_with_bins c ON cc.usdot_str_8 = c.usdot_str_8
  GROUP BY fleet_size_cohort, cohort_sort
)

SELECT
  cw.fleet_size_cohort,
  cw.catastrophic_crash_carriers,
  cw.total_fatalities,
  ROUND(cw.total_fatalities / cw.catastrophic_crash_carriers, 2)
    AS fatalities_per_carrier,
  ROUND(cw.catastrophic_crash_carriers
    / SUM(cw.catastrophic_crash_carriers) OVER () * 100, 1)
    AS pct_of_catastrophic_carriers,
  ac.active_carriers,
  ROUND(ac.active_carriers
    / SUM(ac.active_carriers) OVER () * 100, 1)
    AS pct_of_active_carriers,
  ROUND(
    (cw.catastrophic_crash_carriers / SUM(cw.catastrophic_crash_carriers) OVER ())
    / NULLIF(ac.active_carriers / SUM(ac.active_carriers) OVER (), 0)
  , 2) AS representation_ratio
FROM catastrophic_with_cohort cw
LEFT JOIN active_by_cohort ac
  ON cw.fleet_size_cohort = ac.fleet_size_cohort
ORDER BY cw.cohort_sort;
```

**Validated results (March 2026 snapshot, interstate carriers only):**

| fleet_size_cohort | catastrophic_crash_carriers | total_fatalities | fatalities_per_carrier | pct_of_catastrophic_carriers | active_carriers | pct_of_active_carriers | representation_ratio |
|---|---|---|---|---|---|---|---|
| 1-5 | 30 | 103 | 3.43 | 23.8 | 534,090 | 83.3 | 0.29 |
| 6-25 | 34 | 140 | 4.12 | 27.0 | 81,386 | 12.7 | 2.13 |
| 26-100 | 17 | 65 | 3.82 | 13.5 | 19,920 | 3.1 | 4.34 |
| 101-500 | 19 | 67 | 3.53 | 15.1 | 4,709 | 0.7 | 20.53 |
| 500+ | 26 | 104 | 4.00 | 20.6 | 963 | 0.2 | 137.37 |

---

### Query 3: Fatal crash frequency and severity rates by fleet size cohort (exposure-adjusted)

The 500+ cohort is excluded from this query due to the data integrity issue documented above. The WHERE clause restricts to cohorts with reliable power unit denominators.

```sql
WITH census_with_bins AS (
  SELECT
    LPAD(TRIM(DOT_NUMBER), 8, '0')    AS usdot_str_8,
    SAFE_CAST(NBR_POWER_UNIT AS INT64) AS power_units,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 'Unknown'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN '1-5'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN '6-25'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN '26-100'
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN '101-500'
      ELSE '500+'
    END AS fleet_size_cohort,
    CASE
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) IS NULL
        OR SAFE_CAST(NBR_POWER_UNIT AS INT64) = 0    THEN 6
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 5   THEN 1
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 25  THEN 2
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 100 THEN 3
      WHEN SAFE_CAST(NBR_POWER_UNIT AS INT64) <= 500 THEN 4
      ELSE 5
    END AS cohort_sort
  FROM fmcsa_raw_v11.census_staging
  WHERE CARRIER_OPERATION = 'A'
),

cohort_exposure AS (
  SELECT
    fleet_size_cohort,
    cohort_sort,
    COUNT(*)         AS active_carriers,
    SUM(power_units) AS total_power_units
  FROM census_with_bins
  -- Exclude Unknown and 500+ cohorts from rate analysis
  WHERE fleet_size_cohort NOT IN ('Unknown', '500+')
  GROUP BY fleet_size_cohort, cohort_sort
),

fatal_crashes AS (
  SELECT
    LPAD(CAST(DOT_Number AS STRING), 8, '0') AS usdot_str_8,
    Report_number,
    SAFE_CAST(fatalities AS INT64)            AS fatalities
  FROM fmcsa_raw_v11.crash_staging
  WHERE SAFE_CAST(fatalities AS INT64) >= 1
    AND fatalities IS NOT NULL
    AND fatalities != ''
),

fatalities_by_cohort AS (
  SELECT
    COALESCE(c.fleet_size_cohort, 'Unknown') AS fleet_size_cohort,
    COALESCE(c.cohort_sort, 6)               AS cohort_sort,
    COUNT(DISTINCT f.usdot_str_8)             AS carriers_with_fatal_crashes,
    COUNT(DISTINCT f.Report_number)           AS fatal_crash_events,
    SUM(f.fatalities)                         AS total_fatalities
  FROM fatal_crashes f
  INNER JOIN census_with_bins c ON f.usdot_str_8 = c.usdot_str_8
  GROUP BY fleet_size_cohort, cohort_sort
)

SELECT
  fb.fleet_size_cohort,
  ce.active_carriers,
  ce.total_power_units,
  fb.carriers_with_fatal_crashes,
  fb.fatal_crash_events,
  fb.total_fatalities,
  ROUND(fb.fatal_crash_events
    / NULLIF(ce.total_power_units, 0) * 100, 4)
    AS fatal_crashes_per_100_pu,
  ROUND(fb.total_fatalities
    / NULLIF(ce.total_power_units, 0) * 100, 4)
    AS fatalities_per_100_pu,
  ROUND(fb.total_fatalities
    / NULLIF(fb.fatal_crash_events, 0), 2)
    AS fatalities_per_crash_event,
  ROUND(fb.carriers_with_fatal_crashes
    / NULLIF(ce.active_carriers, 0) * 100, 4)
    AS pct_carriers_with_any_fatal_crash
FROM fatalities_by_cohort fb
-- Inner join ensures only cohorts with reliable denominators are returned
INNER JOIN cohort_exposure ce ON fb.fleet_size_cohort = ce.fleet_size_cohort
ORDER BY fb.cohort_sort;
```

**Validated results (March 2026 snapshot, interstate carriers only, 1-500 PU cohorts):**

| fleet_size_cohort | active_carriers | total_power_units | carriers_with_fatal_crashes | fatal_crash_events | total_fatalities | fatal_crashes_per_100_pu | fatalities_per_100_pu | fatalities_per_crash_event | pct_carriers_with_any_fatal_crash |
|---|---|---|---|---|---|---|---|---|---|
| 1-5 | 534,090 | 919,239 | 1,219 | 1,202 | 1,406 | 0.1308 | 0.1530 | 1.17 | 0.2282 |
| 6-25 | 81,386 | 911,535 | 1,098 | 1,106 | 1,333 | 0.1213 | 0.1462 | 1.21 | 1.3491 |
| 26-100 | 19,920 | 951,551 | 931 | 971 | 1,122 | 0.1020 | 0.1179 | 1.16 | 4.6737 |
| 101-500 | 4,709 | 945,784 | 802 | 986 | 1,156 | 0.1043 | 0.1222 | 1.17 | 17.0312 |

---

## Important Limitations

**Power units as exposure proxy:** Power units are an imperfect proxy for true exposure, which is best measured by vehicle miles traveled. Reliable carrier-level mileage data is not publicly available; the MCS-150 annual mileage field is self-reported and not independently verified. A fully mileage-normalized rate is not possible with public data alone. This limitation applies equally across all four cohorts and does not explain the flat pattern observed.

**Crash involvement vs. fault:** FMCSA crash data records carrier involvement in crashes, not carrier fault or causation. A carrier may appear in a fatal crash record as a party to the crash without being the proximate cause. According to FMCSA research, approximately 64% of fatal truck-involved crashes carry no truck causation determination. Crash involvement in this dataset does not imply carrier fault.

**Interstate carriers only:** This analysis covers CARRIER_OPERATION = 'A' carriers exclusively. Intrastate carriers (operation codes B and C) are excluded from all calculations. Results do not apply to local or regional intrastate operations.

**500+ cohort excluded from rate analysis:** As documented above, the NBR_POWER_UNIT field contains systemic data quality problems that make the per-100-PU denominator unreliable for carriers reporting more than 500 power units. The excluded cohort represents 0.14% of the interstate carrier population.

**Single snapshot:** Results reflect the March 31, 2026 FMCSA SMS data snapshot. Results will vary with subsequent monthly snapshots as new crash data is reported and carrier registrations change.

**BigQuery syntax:** Queries are written in Google BigQuery SQL dialect. SAFE_CAST and APPROX_QUANTILES are BigQuery-specific. Equivalent functions exist in other SQL environments.

---

## Reproducibility

These queries were validated against the raw FMCSA staging tables in the author's BigQuery environment. The March 2026 FMCSA snapshot used for validation is archived at:

https://www.kaggle.com/datasets/reedslack/fmcsa-public-safety-data-march-2026-sms-snapshot

Anyone who ingests the archived datasets and runs the queries above should obtain identical results. Update the table references to match your environment.

---

*Reed Slack is a commercial truck driver, safety analyst, and founder of Tanjentz LLC (tanjentz.com), which provides FMCSA carrier safety analytics to freight brokers.*
