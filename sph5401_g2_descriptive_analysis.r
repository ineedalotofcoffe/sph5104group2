# --------------------------------------------------
# 1. Load necessary libraries
# --------------------------------------------------
library(dplyr)
library(readxl)
library(gtsummary)
library(gt)
library(glue)
library(stringr) # Ensure stringr is loaded for str_detect

# --------------------------------------------------
# 2. Read the data
# --------------------------------------------------
raw_sph5104 <- read_excel("Downloads/rawdata_sph5104.xlsm")
data <- raw_sph5104

# --------------------------------------------------
# 3. Data Cleaning
# --------------------------------------------------
data <- data %>%
  mutate(antip = if_else(
    clopidogrel_use == 1 | prasugrel_use == 1 | ticagrelor_use == 1,
    1, 0
  )) %>%
  mutate(race_grouped = case_when(
    str_detect(race, regex("ASIAN", ignore_case = TRUE)) ~ "Asian",
    str_detect(race, regex("HISPANIC|SOUTH AMERICAN", ignore_case = TRUE)) ~ "Hispanic",
    str_detect(race, regex("BLACK|AFRICAN", ignore_case = TRUE)) ~ "Black",
    str_detect(race, regex("WHITE|PORTUGUESE", ignore_case = TRUE)) ~ "White",
    str_detect(race, regex("OTHER|NATIVE HAWAIIAN|DECLINED|UNABLE|UNKNOWN", ignore_case = TRUE)) ~ "Other",
    TRUE ~ "Other" # catch-all for anything unmatched
  )) %>%
  mutate(gender = as.factor(gender)) %>%
  mutate(admission_type = as.factor(admission_type)) %>%
  mutate(insurance = as.factor(insurance)) %>%
  mutate(hba1c_cat = case_when(
    hba1c < 6.5 ~ "<6.5",
    hba1c >= 6.5 & hba1c <= 8 ~ "6.5 - 8",
    hba1c > 8 ~ ">8",
    TRUE ~ NA_character_ # catch any NA or unexpected cases
  )) %>%
  mutate(hba1c_cat = factor(hba1c_cat, levels = c("<6.5", "6.5 - 8", ">8"))) %>%
  mutate(age = as.numeric(anchor_age)) %>%
  mutate(admission_type = case_when(
    str_detect(admission_type, regex("ELECTIVE", ignore_case = TRUE)) ~ "Elective",
    TRUE ~ "Non-Elective" # catch-all
  ))

# --------------------------------------------------
# 4. Create groups
# --------------------------------------------------
mi_patients <- data
mi_with_cs <- data %>% filter(shock == 1)

# --------------------------------------------------
# 5. Define variable groups and labels
# --------------------------------------------------

continuous_vars <- c("anchor_age")

categorical_vars <- c("race_grouped", "gender", "admission_type", "insurance",
                      "died_in_hosp", "died_30day", "died_1year",
                      "mi_severity", "hypertension", "heart_failure",
                      "chronic_renal_failure", "shock", "diabetes_mellitus",
                      "aspirin_use", "clopidogrel_use", "prasugrel_use",
                      "ticagrelor_use", "statin_use", "insulin_use", "antip")

var_labels <- list(
  anchor_age             ~ "Age",
  gender                  ~ "Sex",
  race_grouped            ~ "Race",
  admission_type          ~ "Admission Type",
  insurance               ~ "Insurance",
  died_in_hosp            ~ "Died in Hospital",
  died_30day              ~ "Died at 30 Days",
  died_1year              ~ "Died at 1 Year",
  mi_severity             ~ "MI Severity",
  hypertension            ~ "Hypertension",
  heart_failure           ~ "Heart Failure",
  chronic_renal_failure   ~ "Chronic Renal Failure",
  shock                   ~ "Cardiogenic Shock",
  diabetes_mellitus       ~ "Diabetes Mellitus",
  aspirin_use             ~ "Aspirin Use",
  clopidogrel_use         ~ "Clopidogrel Use",
  prasugrel_use           ~ "Prasugrel Use",
  ticagrelor_use          ~ "Ticagrelor Use",
  statin_use              ~ "Statin Use",
  insulin_use             ~ "Insulin Use",
  antip                   ~ "Clopidogrel / Prasugrel / Ticagrelor Use"
)

# --------------------------------------------------
# 6. Create tbl_summary for MI Patients stratified by hba1c
# --------------------------------------------------
tbl_mi <- mi_patients %>%
  tbl_summary(
    by = hba1c_cat,
    include = intersect(names(mi_patients), c(categorical_vars, continuous_vars)),
    label = var_labels,
    missing = "no",
    statistic = list(
      anchor_age ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(anchor_age ~ 1) # Specify 1 decimal place for anchor_age
  ) %>%
  add_overall("**All MI Patients**", last = TRUE) %>%
  add_p(test = list(
    anchor_age ~ "aov",
    all_categorical() ~ "chisq.test"
  )) %>%
  modify_header(p.value ~ "**p-value**")

# --------------------------------------------------
# 7. Create tbl_summary for MI Patients with CS stratified by hba1c
# --------------------------------------------------
tbl_mi_cs <- mi_with_cs %>%
  tbl_summary(
    by = hba1c_cat,
    include = intersect(names(mi_with_cs), c(categorical_vars, continuous_vars)),
    label = var_labels,
    missing = "no",
    statistic = list(
      anchor_age ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(anchor_age ~ 1) # Specify 1 decimal place for anchor_age
  ) %>%
  add_overall("**All MI Patients**", last = TRUE) %>%
  add_p(test = list(
    anchor_age ~ "aov",
    all_categorical() ~ "chisq.test"
  )) %>%
  modify_header(p.value ~ "**p-value**")
# --------------------------------------------------
# 8. Combine the tables side-by-side
# --------------------------------------------------
combined_tbl <- tbl_merge(
  list(tbl_mi, tbl_mi_cs),
  tab_spanner = c("**All MI Patients (by HbA1c)**", "**MI with CS (by HbA1c)**")
)

# --------------------------------------------------
# 9. Display the combined summary table
# --------------------------------------------------
print(combined_tbl)

# --------------------------------------------------
# 10. Export the combined summary table
# --------------------------------------------------

combined_tbl %>%
  as_gt() %>%
  gt::gtsave("combined_summary_table.html")

