library(broom)
library(writexl)


##----------------------------## 
# Death 1 year after discharge #
##----------------------------## 

df <- data

#Step 1: Convert dates to proper datetime format
#### Use Hospital Admission
df$admittime <- as.POSIXct(df$admittime, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
df$dod <- as.POSIXct(df$dod, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")

#Step 2: Compute time to event (in days) and create censoring indicator

df$time_to_event <- as.numeric(difftime(df$dod, df$admittime, units = "days"))
df$time_to_event <- ifelse(df$died_1year == 0, 365, df$time_to_event)
df$event_1yr <- df$died_1year
## cap negative/odd values just in case
df$time_to_event <- ifelse(df$time_to_event < 0, 0, df$time_to_event)

# Step 3: Create HbA1c groups

df$hba1c_group <- ifelse(df$hba1c > 8, ">8%", "≤8%")
df$hba1c_group <- factor(df$hba1c_group)

# Step 4: Fit Kaplan-Meier and plot

library(survival)
library(survminer)

surv_obj <- Surv(time = df$time_to_event, event = df$event_1yr)
km_fit <- survfit(surv_obj ~ hba1c_group, data = df)

km_plot_1year_mortality <- ggsurvplot(km_fit, data = df,
                                      pval = TRUE, conf.int = TRUE,
                                      risk.table = TRUE, 
                                      title = "Kaplan-Meier Curve by HbA1c Group",
                                      xlab = "Days from ICU Admission",
                                      ylab = "Survival Probability")


ggsave("km_plot_1year_mortality.png", km_plot_1year_mortality$plot, width = 8, height = 6, dpi = 300)



# Step 5: Cox Proportional Hazards Model
cox_fit_1year <- coxph(surv_obj ~ hba1c_group + anchor_age + gender + 
                   heart_failure + chronic_renal_failure + 
                   diabetes_mellitus + hypertension, data = df)



summary(cox_fit_1year)


# Tidy Cox model summary with exponentiated coefficients (i.e., hazard ratios)
cox_tidy_1year <- tidy(cox_fit_1year, exponentiate = TRUE, conf.int = TRUE)

# Export to Excel
write_xlsx(cox_tidy_1year, "cox_model_summary_1year.xlsx")



##----------------------------## 
# Death In Hospital            #
##----------------------------## 

# Step 1: Calculate time to in-hospital event

df$admittime <- as.POSIXct(df$admittime, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
df$dischtime <- as.POSIXct(df$dischtime, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
df$dod <- as.POSIXct(df$dod, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")

# Use date of death if died in hospital; otherwise censor at discharge
df$event_time <- ifelse(df$died_in_hosp == 1,
                        as.numeric(difftime(df$dod, df$admittime, units = "days")),
                        as.numeric(difftime(df$dischtime, df$admittime, units = "days")))

df$event_time <- ifelse(df$event_time < 0, 0, df$event_time)  # just in case


# Step 2: Create survival object
library(survival)
library(survminer)

surv_obj <- Surv(time = df$event_time, event = df$died_in_hosp)


# Step 3: Kaplan-Meier plot
km_fit <- survfit(surv_obj ~ hba1c_group, data = df)

km_plot_inhosp_mortality <- ggsurvplot(km_fit, data = df,
                                       pval = TRUE, conf.int = TRUE,
                                       risk.table = TRUE,
                                       title = "Survival During Hospital Stay by HbA1c Group",
                                       xlab = "Days from ICU Admission",
                                       ylab = "Probability of In-Hospital Survival")


ggsave("km_plot_inhosp_mortality.png", km_plot_inhosp_mortality$plot, width = 8, height = 6, dpi = 300)

#Step 4: Cox model
cox_fit_inhosp <- coxph(surv_obj ~ hba1c_group + anchor_age + gender +
                   heart_failure + chronic_renal_failure + 
                   diabetes_mellitus + hypertension, data = df)

summary(cox_fit_inhosp)


# Tidy Cox model summary with exponentiated coefficients (i.e., hazard ratios)
cox_fit_inhosp <- tidy(cox_fit_inhosp, exponentiate = TRUE, conf.int = TRUE)

# Export to Excel
write_xlsx(cox_fit_inhosp, "cox_model_summary_inhosp.xlsx")

