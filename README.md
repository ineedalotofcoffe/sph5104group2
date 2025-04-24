# 📁 SPH5104 Group 2: HbA1c and Mortality in ICU Patients with MI

This repository contains all SQL, R scripts, and outputs used for the analysis of the impact of HbA1c on inpatient and 1-year mortality among ICU patients with myocardial infarction (MI), as part of the coursework for **SPH5104: Health Data Analytics**.

---

## 📄 Contents

| File Name                          | Description |
|-----------------------------------|-------------|
| `sph5104_g2_dataextract.sql`      | SQL script used to extract cohort from the MIMIC-IV database. |
| `sph5401_g2_descriptive_analysis.r` | R script for baseline characteristic summaries and initial exploratory data analysis. |
| `sph5104_g2_log-reg.R.r`          | R script for multivariable logistic regression (unmatched cohort). |
| `sph5104_g2_psm_log-reg.r`        | R script for propensity score matching and post-match logistic regression. |
| `sph5104_g2_survivalanalysis.r`   | R script for Kaplan-Meier and Cox proportional hazards analyses. |
| `sph5104_g2_figure1.r`            | R script for generating survival curve visualizations (KM plots). |

---

## 📊 Outcomes Assessed

1. **In-hospital mortality**: Time from hospital admission to in-hospital death or discharge.
2. **1-year mortality**: Time from hospital admission to all-cause death, with right-censoring at 365 days.

---

## 🧪 Methods Summary

- **Data Source**: MIMIC-IV v3.1  
- **Population**: ICU patients with MI, with HbA1c recorded within ±3 months of ICU admission.  
- **Statistical Methods**:
  - Descriptive statistics (ANOVA, chi-square tests)
  - Logistic regression
  - Propensity score matching (MatchIt)
  - Kaplan-Meier estimation + log-rank test
  - Cox proportional hazards model

---

## 📌 Notes

- 38% of cases were excluded from PSM due to missing covariate data.
- Survival analysis begins from **hospital admission**, not discharge or ICU admission.
- Time-to-event variables are cleaned to ensure non-negative durations.

---

**Group 2 – SPH5104, Semester 2 AY 2024/2025**

- Chang Mei-Ying  
- Goh Jie Lin Claire Marie  
- Heng Chuhua  
- Khoo Xue Ni, Nikita  
- Liu Mao Sheng  
- Tay Kian Wei  *(Project Lead)* 
- Zanaria Binte Husin
