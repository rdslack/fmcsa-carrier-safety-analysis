-- ============================================================
-- Fatal Crash Analysis by Fleet Size Cohort
-- Prepared by: Reed Slack, Tanjentz LLC
-- Data source: FMCSA public datasets
-- SMS data snapshot: March 31, 2026
-- Two-table analysis: crash_staging + census_staging only
-- ============================================================
--
-- TABLE NAME NOTE:
-- Table names below reflect the author's BigQuery project naming
-- (fmcsa_raw_v11.crash_staging, fmcsa_raw_v11.census_staging).
-- To reproduce, download the public FMCSA datasets linked in the
-- methodology document and update table references to match your
-- environment. Queries are written in BigQuery SQL dialect.
-- SAFE_CAST and APPROX_QUANTILES are BigQuery-specific; equivalent
-- functions exist in other SQL environments.
--
-- Archived March 2026 FMCSA datasets:
--   https://www.kaggle.com/datasets/reedslack/fmcsa-public-safety-data-march-2026-sms-snapshot
--
-- Public dataset URLs (current snapshots):
--   Crash:   https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Crash/4wxs-vbns/about_data
--   Census:  https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Motor-Carrier-Census-Information/kjg3-diqy/about_data
-- ============================================================
--
-- IMPORTANT NOTE ON 500+ COHORT EXCLUSION FROM RATE ANALYSIS:
-- The NBR_POWER_UNIT field in census_staging contains systemic
-- data quality problems concentrated in carriers reporting more
-- than 500 power units. Run the diagnostic queries below first
-- to understand the issue before proceeding to the main analysis.
-- The per-100-PU rate for the 500+ cohort is excluded from
-- Query 3 because the denominator (total power units) is
-- unreliable. This exclusion covers 0.14% of the interstate
-- carrier population and does not affect the analytical conclusion.
-- ============================================================


-- ============================================================
-- DIAGNOSTIC QUERY A: Power unit distribution statistics
-- for the 500+ cohort (all carrier operation types)
-- Run this first to understand the data quality issue.
-- ============================================================

SELECT
  COUNT(*)                                          AS carrier_count,
  MIN(SAFE_CAST(NBR_POWER_UNIT AS INT64))           AS min_pu,
  MAX(SAFE_CAST(NBR_POWER_UNIT AS INT64))           AS max_pu,
  ROUND(AVG(SAFE_CAST(NBR_POWER_UNIT AS INT64)), 0) AS avg_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(50)]
                                                    AS median_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(90)]
                                                    AS p90_pu,
  APPROX_QUANTILES(SAFE_CAST(NBR_POWER_UNIT AS INT64), 100)[OFFSET(99)]
                                                    AS p99_pu,
  SUM(SAFE_CAST(NBR_POWER_UNIT AS INT64))           AS total_pu
FROM fmcsa_raw_v11.census_staging
WHERE SAFE_CAST(NBR_POWER_UNIT AS INT64) > 500;

-- Validated results (March 2026, all operation types):
-- carrier_count: 2,336 | max_pu: 1,299,987 | median_pu: 8,002
-- total_pu: 70,448,732 (implausible for any segment of U.S. trucking)


-- ============================================================
-- DIAGNOSTIC QUERY B: Top 20 carriers by reported PU count
-- Confirms corrupted values are not legitimate large carriers.
-- ============================================================

SELECT
  LPAD(TRIM(DOT_NUMBER), 8, '0')     AS usdot_str_8,
  LEGAL_NAME,
  SAFE_CAST(NBR_POWER_UNIT AS INT64)  AS power_units
FROM fmcsa_raw_v11.census_staging
WHERE SAFE_CAST(NBR_POWER_UNIT AS INT64) > 500
ORDER BY SAFE_CAST(NBR_POWER_UNIT AS INT64) DESC
LIMIT 20;

-- Validated results include: Reliable Transporters (1,299,987),
-- Premium Holdings (799,992), and eight unrelated carriers each
-- reporting exactly 599,994, including a lawn service and a
-- junk removal company. None are legitimate large carriers.


-- ============================================================
-- DIAGNOSTIC QUERY C: PU distribution by band within 500+ cohort
-- Shows that corruption is concentrated in the largest values
-- but the problem extends throughout the distribution.
-- ============================================================

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

-- Note: Even after restricting to CARRIER_OPERATION = 'A' and
-- capping at 30,000 PU (generous enough to include the largest
-- legitimate U.S. fleets), 914 carriers report 1.77 million
-- total PUs, averaging 1,939 per carrier. This remains
-- implausible, indicating the corruption is systemic.


-- ============================================================
-- QUERY 1: Fatal crash carriers (1+ fatalities) by fleet size
-- vs. active carrier population share
-- Restricted to CARRIER_OPERATION = 'A' (interstate carriers)
-- The 500+ cohort is shown for context but rate analysis
-- (Query 3) excludes it due to data quality issues.
-- ============================================================

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

-- representation_ratio interpretation:
--   1.0 = proportional representation in fatal crashes
--   < 1.0 = under-represented (fewer crashes than fleet share predicts)
--   > 1.0 = over-represented (more crashes than fleet share predicts)


-- ============================================================
-- QUERY 2: Catastrophic crash carriers (3+ fatalities)
-- by fleet size vs. active population share
-- ============================================================

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


-- ============================================================
-- QUERY 3: Fatal crash frequency and severity rates by cohort
-- Exposure-adjusted: fatal crashes and fatalities per 100 PU
--
-- The 500+ cohort is EXCLUDED from this query.
-- The NBR_POWER_UNIT denominator for the 500+ cohort is
-- unreliable due to systemic data quality issues documented
-- in the diagnostic queries above. The four cohorts below
-- cover 640,105 of 641,019 interstate carriers (99.86%).
-- ============================================================

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
  -- Exclude Unknown and 500+ from rate analysis
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
-- INNER JOIN ensures only cohorts with reliable denominators returned
INNER JOIN cohort_exposure ce ON fb.fleet_size_cohort = ce.fleet_size_cohort
ORDER BY fb.cohort_sort;

-- Validated results (March 2026, interstate carriers, 1-500 PU):
-- 1-5:     0.1308 fatal crashes per 100 PU | 1.17 fatalities per event
-- 6-25:    0.1213 fatal crashes per 100 PU | 1.21 fatalities per event
-- 26-100:  0.1020 fatal crashes per 100 PU | 1.16 fatalities per event
-- 101-500: 0.1043 fatal crashes per 100 PU | 1.17 fatalities per event
