#— Load packages
library(dplyr)
library(MatchIt)
library(cobalt)       # balance diagnostics
library(survival)     # for clogit
library(sandwich)     # for robust SEs
library(lmtest)

# Check for missing values in the dataset
colSums(is.na(df))  # Count missing values for each column

# Specifically check Hemoglobin
sum(is.na(df$Hemoglobin))  # Check how many Hemoglobin values are missing (should be only 1)

# Remove rows with missing values in Hemoglobin or other covariates
df_clean <- df %>%
  filter(!is.na(Hemoglobin) & !is.na(anchor_age) & !is.na(gender) & !is.na(hba1c) & !is.na(hypertension))

# Verify that there are no missing values in the cleaned dataset
colSums(is.na(df_clean))  # Confirm that there are no missing values

# Propensity score matching on cleaned dataset
psm <- matchit(
  cut(hba1c, breaks = c(0, 6.5, Inf), labels = c("<6.5%", "≥6.5%")) ~ anchor_age + gender + hypertension + Hemoglobin,
  data = df_clean,  # Use cleaned dataset
  method = "nearest"  # Nearest neighbor matching
)

# Check summary of matched data
summary(psm)  # Summary of the matching process

# Extract matched dataset
matched_data <- match.data(psm)  # Get the matched dataset

# Check balance after matching
bal.tab(psm)  # Check balance of covariates after matching

# Summarize matched data
summary(matched_data)  # Summary statistics of the matched dataset



matched_data <- matched_data %>%
  mutate(
    hba1c_group = ifelse(hba1c < 6.5, "<6.5%", "≥6.5%"),
    hba1c_group = factor(hba1c_group, levels = c("<6.5%", "≥6.5%"))
  )



logistic_inhosp_psm <- glm(
  died_in_hosp ~ hba1c_group
  + anchor_age
  + gender
  + race_grouped
  + insurance
  + mi_severity
  + hypertension
  + chronic_renal_failure
  + heart_failure
  + Hemoglobin,
  data   = matched_data,
  family = binomial(link = "logit")
)



# 1. Inspect the model
summary(logistic_inhosp_psm)

# 2. Odds‑ratios and Wald CIs
#    (uses the model’s estimated coefficients and their CIs)
or_ci <- exp(
  cbind(
    Estimate = coef(logistic_inhosp_psm),
    confint(logistic_inhosp_psm)
  )
)
print(or_ci)

# 3. Cluster‐robust SEs by matched pair (subclass)
#    so inference accounts for the 1:1 matching
library(sandwich)
library(lmtest)

# vcovCL needs a clustering variable in your data; MatchIt adds `subclass`
cluster_vcov <- vcovCL(logistic_inhosp_psm, cluster = matched_data$subclass)
robust_results <- coeftest(logistic_inhosp_psm, vcov = cluster_vcov)
print(robust_results)

# 4. Create a publication‑ready table with gtsummary
library(gtsummary)

tbl_psm <- tbl_regression(
  logistic_inhosp_psm,
  exponentiate = TRUE,
  label = list(
    hba1c_group             ~ "HbA1c ≥6.5% vs <6.5%",
    anchor_age              ~ "Age (years)",
    gender                  ~ "Gender",
    race_grouped            ~ "Race/ethnicity",
    insurance               ~ "Insurance status",
    mi_severity             ~ "MI severity",
    hypertension            ~ "Hypertension",
    chronic_renal_failure   ~ "Chronic renal failure",
    heart_failure           ~ "Prior heart failure",
    Hemoglobin              ~ "Hemoglobin (g/dL)"
  ),
  missing = "no"
) %>%
  add_global_p()  # overall p for HbA1c_cat

tbl_psm




# 5a. Export the OR/CIs from the model
write.csv(
  as.data.frame(or_ci),
  file = "psm_logistic_OR_CI.csv",
  row.names = TRUE
)

# 5b. Export the gtsummary table to CSV
tbl_psm %>%
  as_tibble() %>%
  write.csv("psm_logistic_inhosp.csv", row.names = FALSE)


# Logistic regression for 1-year mortality after PSM
logistic_1yr_psm <- glm(
  died_1year ~ hba1c_group
  + anchor_age
  + gender
  + race_grouped
  + insurance
  + mi_severity
  + hypertension
  + chronic_renal_failure
  + heart_failure
  + Hemoglobin,
  data   = matched_data,
  family = binomial(link = "logit")
)

# Summary of the model
summary(logistic_1yr_psm)

# Odds ratios and confidence intervals
or_ci_1yr <- exp(
  cbind(
    Estimate = coef(logistic_1yr_psm),
    confint(logistic_1yr_psm)
  )
)
print(or_ci_1yr)

# Cluster-robust standard errors for 1-year model
cluster_vcov_1yr <- vcovCL(logistic_1yr_psm, cluster = matched_data$subclass)
robust_results_1yr <- coeftest(logistic_1yr_psm, vcov = cluster_vcov_1yr)
print(robust_results_1yr)

# Create publication-ready table
tbl_psm_1yr <- tbl_regression(
  logistic_1yr_psm,
  exponentiate = TRUE,
  label = list(
    hba1c_group             ~ "HbA1c ≥6.5% vs <6.5%",
    anchor_age              ~ "Age (years)",
    gender                  ~ "Gender",
    race_grouped            ~ "Race/ethnicity",
    insurance               ~ "Insurance status",
    mi_severity             ~ "MI severity",
    hypertension            ~ "Hypertension",
    chronic_renal_failure   ~ "Chronic renal failure",
    heart_failure           ~ "Prior heart failure",
    Hemoglobin              ~ "Hemoglobin (g/dL)"
  ),
  missing = "no"
) %>%
  add_global_p()

# Display table
tbl_psm_1yr

# Export OR/CIs to CSV
write.csv(
  as.data.frame(or_ci_1yr),
  file = "psm_logistic_OR_CI_1year.csv",
  row.names = TRUE
)

# Export gtsummary table to CSV
tbl_psm_1yr %>%
  as_tibble() %>%
  write.csv("psm_logistic_1yr.csv", row.names = FALSE)

