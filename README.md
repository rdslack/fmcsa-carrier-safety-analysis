# FMCSA Carrier Safety Analysis

Public reproducibility repository for two independent analyses of FMCSA fatal crash data, prepared by Reed Slack, Tanjentz LLC.

All analyses use publicly available datasets from the U.S. Department of Transportation. No proprietary data is required to reproduce any result in this repository.

---

## Analyses

### 1. New vs. Established Carrier Fatal Crash Risk
**File:** `new_carrier_fatality_methodology.md`  
**SQL:** `new_carrier_fatality_queries.sql`

Examines whether carriers with fewer than 24 months of operating authority are disproportionately represented in FMCSA fatal crash data. Motivated by the April 2026 CBS News 60 Minutes chameleon carrier investigation.

Key finding: New carriers represent 21% of the active carrier population with known first authority dates but only 5% of fatal crash carriers. Among carriers involved in catastrophic crashes (3+ fatalities), zero new carriers appear among those with verifiable authority dates.

---

### 2. Fleet Size and Fatal Crash Risk
**File:** `fleet_size_fatality_methodology.md`  
**SQL:** `fleet_size_fatality_queries.sql`

Examines whether larger carriers have materially better fatal crash outcomes than smaller carriers on an exposure-adjusted basis. Motivated by freight industry commentary claiming that large carriers are safer due to their access to safety technology.

Key finding: Among interstate carriers with 1 to 500 power units, exposure-adjusted fatal crash rates are essentially identical across all fleet size cohorts. Fatal crash severity (fatalities per crash event) is virtually identical across all cohorts regardless of fleet size.

---

## Data Sources

Both analyses draw from publicly available FMCSA datasets:

| Dataset | URL |
|---|---|
| SMS Input - Crash | https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Crash/4wxs-vbns/about_data |
| SMS Input - Motor Carrier Census Information | https://data.transportation.gov/Trucking-and-Motorcoaches/SMS-Input-Motor-Carrier-Census-Information/kjg3-diqy/about_data |
| AuthHist - All With History | https://data.transportation.gov/Trucking-and-Motorcoaches/AuthHist-All-With-History/9mw4-x3tu/about_data |

The AuthHist dataset is required only for the new carrier analysis. The fleet size analysis uses the Crash and Census datasets only.

---

## SQL Environment

Queries are written in Google BigQuery SQL dialect. `SAFE_CAST`, `SAFE.PARSE_DATE`, and `APPROX_QUANTILES` are BigQuery-specific functions. Equivalent functions exist in other SQL environments. Table name references in the queries reflect the author's BigQuery project naming and must be updated to match your environment after ingesting the public datasets.

---

## Reproducibility

Each methodology document includes the full SQL queries used and the validated results from the March 31, 2026 FMCSA SMS snapshot. Anyone who ingests the public datasets and runs the queries should obtain identical results against the same snapshot.

---

## About

Reed Slack is a commercial truck driver, safety analyst, and founder of Tanjentz LLC ([tanjentz.com](https://tanjentz.com)), which provides FMCSA carrier safety analytics to freight brokers.
