# FMCSA Carrier Safety Analysis

Public reproducibility repository for two independent analyses of FMCSA fatal crash data, prepared by Reed Slack, Tanjentz LLC.

All analyses use publicly available datasets from the U.S. Department of Transportation. No proprietary data is required to reproduce any result in this repository.

---

## Archived Data

The analyses in this repository were validated against the **March 31, 2026 FMCSA SMS snapshot**. FMCSA updates its public data files monthly; once a new snapshot is released, prior month data is no longer available from the public portal.

The complete March 2026 snapshot has been archived on Kaggle to support reproducibility:

**https://www.kaggle.com/datasets/reedslack/fmcsa-public-safety-data-march-2026-sms-snapshot**

To reproduce the validated results in this repository, download the March 2026 files from Kaggle rather than from the FMCSA portal, which will reflect a more recent snapshot after April 2026.

---

## Analyses

### 1. New vs. Established Carrier Fatal Crash Risk
**File:** `new_carrier_fatality_methodology.md`

Examines whether carriers with fewer than 24 months of operating authority are disproportionately represented in FMCSA fatal crash data. Motivated by the April 2026 CBS News 60 Minutes chameleon carrier investigation.

Key finding: New carriers represent 21% of the active carrier population with known first authority dates but only 5% of fatal crash carriers. Among carriers involved in catastrophic crashes (3+ fatalities), zero new carriers appear among those with verifiable authority dates.

---

### 2. Fleet Size and Fatal Crash Risk
**File:** `fleet_size_fatality_methodology.md`

Examines whether larger carriers have materially better fatal crash outcomes than smaller carriers on an exposure-adjusted basis. Motivated by freight industry and legal commentary suggesting that large carriers are safer due to their access to safety technology, a premise cited in Supreme Court oral arguments in the C.H. Robinson broker liability case.

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

Each methodology document includes the full SQL queries used and the validated results from the March 31, 2026 FMCSA SMS snapshot. Anyone who ingests the public datasets from the Kaggle archive above and runs the queries should obtain identical results.

---

## About

Reed Slack is a commercial truck driver, safety analyst, and founder of Tanjentz LLC ([tanjentz.com](https://tanjentz.com)), which provides FMCSA carrier safety analytics to freight brokers.
