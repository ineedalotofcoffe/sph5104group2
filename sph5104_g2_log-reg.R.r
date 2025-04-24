

# 0. Install / load needed packages
# install.packages(c("dplyr","gtsummary","broom"))
library(dplyr)
library(gtsummary)
library(broom)


data1 <- raw_sph5104

# 1. Prepare data and recode

data1 <- data1 %>%
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


df <- data1 %>%
  mutate(
    gender       = factor(gender),
    hypertension = factor(hypertension, levels = c(0,1), labels = c("No","Yes")),
    chronic_renal_failure = factor(chronic_renal_failure, levels = c(0,1), labels = c("No","Yes")),
    heart_failure = factor(heart_failure, levels = c(0,1), labels = c("No","Yes")),
    anchor_age = as.numeric(anchor_age),# … add any other recodings here …
  )

# 2. Fit the adjusted logistic model
logistic_inhosp <- glm(
  died_in_hosp ~ hba1c_cat
  + anchor_age
  + gender
  + race_grouped
  + insurance
  + mi_severity
  + hypertension
  + chronic_renal_failure
  + heart_failure
  + Hemoglobin,
  data   = df,
  family = binomial(link = "logit")
)

# 3. Tabulate adjusted ORs
tbl_inhosp <- tbl_regression(
  logistic_inhosp,
  exponentiate = TRUE,
  label = list(
    hba1c_cat    ~ "HbA1c category",
    anchor_age   ~ "Age (years)",
    gender       ~ "Gender",
    race_grouped     ~ "Race/ethnicity",
    insurance    ~ "Insurance status",
    mi_severity        ~ "MI Severity",
    hypertension ~ "Hypertension",
    chronic_renal_failure          ~ "Chronic kidney disease",
    heart_failure           ~ "Prior heart failure",
    Hemoglobin   ~ "Hemoglobin (g/dL)"
  ),
  missing = "no"
) %>%
  add_global_p()  # overall p for HbA1c_cat

# 4. Display
tbl_inhosp

# 5. (Optional) Export results to CSV
tbl_inhosp %>%
  as_tibble() %>%
  write.csv("logistic_inhospital_results.csv", row.names = FALSE)


