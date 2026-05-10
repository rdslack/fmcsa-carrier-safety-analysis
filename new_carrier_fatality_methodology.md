# New Carrier Fatality Crash Analysis: Dataset, Methodology, and SQL Queries

**Prepared by:** Reed Slack, Tanjentz LLC  
**Data source:** FMCSA public datasets (links below)  
**Analysis date:** May 2, 2026  
**SMS data snapshot:** March 31, 2026 (covering 24-month window April 1, 2024 through March 31, 2026)

---

## Summary of Findings

| Metric | Value |
|---|---|
| Total carriers involved in any fatality crash (24 months) | 5,592 |
| New carriers (under 24 months authority) as % of fatality crash carriers* | 5.2% |
| New carriers as % of total active carrier population* | 21.3% |
| Under-representation ratio | ~4x |
| Carriers in any fatality crash with NULL first authority date | 32.8% |
| Carriers in catastrophic crashes (3+ fatalities) with NULL first authority date | 22.8% |
| New carriers in catastrophic crash population (3+ fatalities)* | 0.0% |
| Carriers in total active population with NULL first authority date | 76.9% |

*Percentages computed against carriers with verifiable first authority dates only. Carriers with NULL first authority dates are excluded from new/established breakdowns.

**Key finding:** New carriers (under 24 months of operating authority) are involved in fatal crashes at roughly one quarter of the rate their share of the active carrier population would predict. Among carriers involved in the most catastrophic crashes (3 or more fatalities per event), zero new carriers appear among the 115 with verifiable first authority dates. The data does not support the claim that new carriers represent an elevated fatal crash risk relative to established carriers.

---

## Data Sources

All three datasets are publicly available from the U.S. Department of Transportation and downloadable at no cost. No proprietary data, cleaning, or transformation beyond direct ingestion into BigQuery has been applied. The queries below run directly against the ingested raw tables and are fully reproducible by anyone with access to these public datasets.

**AuthHist - All With History**  
History of each authority action granted to a carrier, broker, or freight forwarder, including original grant date and disposition.  
https://data.transportation.gov/Trucking-and-Motorcoaches/AuthHist-All-With-History/9mw4-x3tu/about_data  
Ingested as: `fmcsa_raw_v11.authhist_staging`

**SMS Input - Motor Carrier Census Information**  
FMCSA registration data for all active Interstate and Intrastate Hazmat motor carriers. One carrier per row. Pre-filtered by FMCSA to active carriers only. Carrier operation codes: A = Interstate, B = Intrastate Hazmat, C = Intrastate Non-Hazmat.  
https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Motor-Carrier-Census-Information/kjg3-diqy/about_data  
Ingested as: `fmcsa_raw_v11.census_staging`

**SMS Input - Crash**  
State-reported crash records for commercial motor vehicles included in the FMCSA Safety Measurement System. Each row represents one reportable crash event.  
https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Crash/4wxs-vbns/about_data  
Ingested as: `fmcsa_raw_v11.crash_staging`

---

## A Note on Table Names and SQL Environments

The table names used in these queries (for example, `fmcsa_raw_v11.authhist_staging`) reflect the naming conventions used in the author's Google BigQuery project. These tables are not publicly accessible. To reproduce this analysis, download the three public FMCSA datasets linked above and ingest them into any SQL environment of your choosing. Once ingested, update the table references in the queries to match the names assigned during your ingestion. The queries will work in any standard SQL environment with minor syntax adjustments where noted.

---

## Methodology

### Defining "new carrier"

A carrier is classified as **new** if the number of months between its first authority grant date and the analysis date (March 31, 2026) is 24 months or fewer, corresponding to carriers granted authority on or after April 1, 2024.

First authority grant date is derived from the AuthHist dataset as the earliest `ORIG_SERVED_DATE` where `ORIGINAL_ACTION_DESC` = 'GRANTED' for a given DOT number.

### Defining "fatality crash carrier"

A carrier is included in the fatality crash population if it appears in the Crash dataset with at least one crash record where `FATALITIES >= 1`. The crash dataset as provided by FMCSA reflects the 24-month SMS measurement window ending March 31, 2026.

### Active carrier population

The active carrier population is drawn from the SMS Input Motor Carrier Census dataset, which FMCSA pre-filters to active Interstate, Intrastate Hazmat, and Intrastate Non-HAZMAT motor carriers. No additional filtering was applied. The full 2,078,584 row population was used as the base rate denominator.

### Handling NULL first authority dates

A substantial portion of carriers in both the crash population and the general active carrier population have no recorded first authority date in the AuthHist dataset. These carriers are counted and reported separately. All percentage calculations for new versus established carrier comparisons are computed against carriers with verifiable first authority dates only, and this caveat is noted explicitly in all reported figures.

The NULL authority date population appears to consist predominantly of established carriers. Visual inspection of large-fleet NULL carriers in the catastrophic fatal crash dataset reveals fleet sizes ranging from 58 to 13,618 power units, consistent with long-established operations rather than new entrants concealing their history.

### Reproducibility

These queries were validated against both the raw FMCSA staging tables and a proprietary analytics pipeline built on the same source data. Results were identical across both environments, confirming that no pipeline distortion was introduced. Anyone with access to the three public datasets listed above can reproduce these results by ingesting the raw files and running the SQL queries below.

---

## SQL Queries and Validated Results

Note: Queries are written in Google BigQuery SQL dialect. The `SAFE.PARSE_DATE` and `SAFE_CAST` functions are BigQuery-specific. Equivalent syntax exists in other SQL environments. All fields in the crash_staging table are stored as strings; fatality counts require casting before numeric comparison.

---

### Query 1: New vs. established carriers in any fatality crash

```sql
WITH first_authority AS (
  SELECT
    LPAD(TRIM(dot_number), 8, '0') AS usdot_str_8,
    MIN(SAFE.PARSE_DATE('%m/%d/%Y', orig_served_date)) AS first_authority_granted_date
  FROM fmcsa_raw_v11.authhist_staging
  WHERE UPPER(TRIM(original_action_desc)) = 'GRANTED'
    AND orig_served_date IS NOT NULL
  GROUP BY usdot_str_8
),

fatal_crashes AS (
  SELECT
    LPAD(CAST(DOT_Number AS STRING), 8, '0') AS usdot_str_8,
    COUNT(*) AS crash_count,
    SUM(SAFE_CAST(fatalities AS INT64)) AS total_fatalities
  FROM fmcsa_raw_v11.crash_staging
  WHERE SAFE_CAST(fatalities AS INT64) >= 1
    AND fatalities IS NOT NULL
    AND fatalities != ''
  GROUP BY usdot_str_8
),

carrier_ages AS (
  SELECT
    fc.usdot_str_8,
    fa.first_authority_granted_date,
    DATE_DIFF(DATE('2026-03-31'), fa.first_authority_granted_date, MONTH)
      AS months_operating
  FROM fatal_crashes fc
  LEFT JOIN first_authority fa ON fc.usdot_str_8 = fa.usdot_str_8
)

SELECT
  COUNT(*) AS total_carriers,
  COUNTIF(first_authority_granted_date IS NULL) AS null_fad,
  ROUND(COUNTIF(first_authority_granted_date IS NULL)
    / COUNT(*) * 100, 1) AS pct_null_fad_of_total,
  COUNTIF(months_operating <= 24) AS new_carriers,
  ROUND(COUNTIF(months_operating <= 24)
    / NULLIF(COUNTIF(first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_new_of_known_fad,
  COUNTIF(months_operating > 24) AS established_carriers,
  ROUND(COUNTIF(months_operating > 24)
    / NULLIF(COUNTIF(first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_est_of_known_fad
FROM carrier_ages
```

**Validated results (March 2026 snapshot):**

| total_carriers | null_fad | pct_null_fad_of_total | new_carriers | pct_new_of_known_fad | established_carriers | pct_est_of_known_fad |
|---|---|---|---|---|---|---|
| 5,592 | 1,834 | 32.8% | 197 | 5.2% | 3,561 | 94.8% |

---

### Query 2: New vs. established in total active carrier population

```sql
WITH first_authority AS (
  SELECT
    LPAD(TRIM(dot_number), 8, '0') AS usdot_str_8,
    MIN(SAFE.PARSE_DATE('%m/%d/%Y', orig_served_date)) AS first_authority_granted_date
  FROM fmcsa_raw_v11.authhist_staging
  WHERE UPPER(TRIM(original_action_desc)) = 'GRANTED'
    AND orig_served_date IS NOT NULL
  GROUP BY usdot_str_8
),

active_carriers AS (
  SELECT
    LPAD(TRIM(DOT_NUMBER), 8, '0') AS usdot_str_8
  FROM fmcsa_raw_v11.census_staging
)

SELECT
  COUNT(*) AS total_active_carriers,
  COUNTIF(fa.first_authority_granted_date IS NULL) AS null_fad,
  ROUND(COUNTIF(fa.first_authority_granted_date IS NULL)
    / COUNT(*) * 100, 1) AS pct_null,
  COUNTIF(DATE_DIFF(DATE('2026-03-31'),
    fa.first_authority_granted_date, MONTH) <= 24) AS new_carriers,
  ROUND(COUNTIF(DATE_DIFF(DATE('2026-03-31'),
    fa.first_authority_granted_date, MONTH) <= 24)
    / NULLIF(COUNTIF(fa.first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_new_of_known,
  COUNTIF(DATE_DIFF(DATE('2026-03-31'),
    fa.first_authority_granted_date, MONTH) > 24) AS est_carriers,
  ROUND(COUNTIF(DATE_DIFF(DATE('2026-03-31'),
    fa.first_authority_granted_date, MONTH) > 24)
    / NULLIF(COUNTIF(fa.first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_est_of_known
FROM active_carriers ac
LEFT JOIN first_authority fa ON ac.usdot_str_8 = fa.usdot_str_8
```

**Validated results (March 2026 snapshot):**

| total_active_carriers | null_fad | pct_null | new_carriers | pct_new_of_known | est_carriers | pct_est_of_known |
|---|---|---|---|---|---|---|
| 2,078,584 | 1,597,485 | 76.9% | 102,391 | 21.3% | 378,708 | 78.7% |

---

### Query 3: New vs. established carriers in catastrophic crashes (3+ fatalities)

```sql
WITH first_authority AS (
  SELECT
    LPAD(TRIM(dot_number), 8, '0') AS usdot_str_8,
    MIN(SAFE.PARSE_DATE('%m/%d/%Y', orig_served_date)) AS first_authority_granted_date
  FROM fmcsa_raw_v11.authhist_staging
  WHERE UPPER(TRIM(original_action_desc)) = 'GRANTED'
    AND orig_served_date IS NOT NULL
  GROUP BY usdot_str_8
),

catastrophic_crashes AS (
  SELECT
    LPAD(CAST(DOT_Number AS STRING), 8, '0') AS usdot_str_8,
    COUNT(*) AS crash_count,
    SUM(SAFE_CAST(fatalities AS INT64)) AS total_fatalities,
    MAX(SAFE_CAST(fatalities AS INT64)) AS max_fatalities_single_crash
  FROM fmcsa_raw_v11.crash_staging
  WHERE SAFE_CAST(fatalities AS INT64) >= 3
    AND fatalities IS NOT NULL
    AND fatalities != ''
  GROUP BY usdot_str_8
),

carrier_ages AS (
  SELECT
    cc.usdot_str_8,
    fa.first_authority_granted_date,
    DATE_DIFF(DATE('2026-03-31'), fa.first_authority_granted_date, MONTH)
      AS months_operating
  FROM catastrophic_crashes cc
  LEFT JOIN first_authority fa ON cc.usdot_str_8 = fa.usdot_str_8
)

SELECT
  COUNT(*) AS total_carriers,
  COUNTIF(first_authority_granted_date IS NULL) AS null_fad,
  ROUND(COUNTIF(first_authority_granted_date IS NULL)
    / COUNT(*) * 100, 1) AS pct_null_fad_of_total,
  COUNTIF(months_operating <= 24) AS new_carriers,
  ROUND(COUNTIF(months_operating <= 24)
    / NULLIF(COUNTIF(first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_new_of_known_fad,
  COUNTIF(months_operating > 24) AS established_carriers,
  ROUND(COUNTIF(months_operating > 24)
    / NULLIF(COUNTIF(first_authority_granted_date IS NOT NULL), 0)
    * 100, 1) AS pct_est_of_known_fad
FROM carrier_ages
```

**Validated results (March 2026 snapshot):**

| total_carriers | null_fad | pct_null_fad_of_total | new_carriers | pct_new_of_known_fad | established_carriers | pct_est_of_known_fad |
|---|---|---|---|---|---|---|
| 149 | 34 | 22.8% | 0 | 0.0% | 115 | 100.0% |

---

## Important Limitations

**NULL first authority date population:** A significant portion of carriers have no recorded first authority date in the AuthHist dataset. These carriers cannot be classified as new or established and are excluded from percentage calculations. The true representation of new carriers in the fatality crash population may differ from reported figures. However, visual inspection of the NULL carrier population in the catastrophic crash dataset strongly suggests this group skews toward large, established operations rather than new entrants.

**Crash dataset scope:** The FMCSA Crash dataset covers reportable crashes as defined under 49 CFR 390.5 (crashes involving a fatality, injury, or tow-away on a public roadway). Reporting completeness varies by state.

**Causation not assessed:** This analysis counts carrier involvement in fatal crashes, not carrier fault. According to FMCSA research, approximately 64% of fatal truck-involved crashes carry no truck causation determination. Carrier involvement in a crash does not imply carrier responsibility for the outcome.

**Network carrier structures:** This analysis operates at the individual carrier DOT number level. Carrier networks operating multiple affiliated entities under separate DOT numbers would not be captured as a single entity. Network-level crash risk analysis would require investigative data beyond FMCSA's public datasets.

**Single snapshot:** Results reflect the March 31, 2026 FMCSA SMS data snapshot. Results will vary with subsequent monthly snapshots as new crash data is reported and carrier authority dates are updated.

**BigQuery syntax:** Queries are written in Google BigQuery SQL dialect. The `SAFE.PARSE_DATE` and `SAFE_CAST` functions are BigQuery-specific. Equivalent functions exist in other SQL environments.

---

*Reed Slack is a commercial truck driver, safety analyst, and founder of Tanjentz LLC (tanjentz.com), which provides FMCSA carrier safety analytics to freight brokers.*
