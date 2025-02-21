library(tidyverse)
library(DBI)
library(ModelMetrics)
library(glmnet)
library(doParallel)
library(BSOLTheme)
library(scales)

# ethnic grouping file
ethn <- read_csv("data/nhs_ethnic_categories.csv")

# Database connection
con <- dbConnect(odbc::odbc(), .connection_string = "Driver={SQL Server};server=MLCSU-BI-SQL;database=EAT_Reporting_BSOL", 
                 timeout = 10)

# Pull in the dataset from SQL server:

sql_3 <-"SELECT * 
FROM ##TMP_DKA_MODEL 
/* and PatientId in ('24774566','24745991')
#select * from [Development].[DEV_PT360_HBA1C_NDA]
where NHS_Number in ('24774566','24745991')
order by NHS_Number, date */
"

DKA_adm_dt <- dbGetQuery(con, sql_3)

DKA_adm_dt <- 
  DKA_adm_dt |> 
  inner_join(ethn, by= c("CLEAN_ETHNICITY" = "NHSCode"))

DKA_adm_dt$LocalGrouping2 <- ifelse(DKA_adm_dt$LocalGrouping %in% c("Mixed or Multiple ethnic groups",
                                                                   "Not Known", "Other Ethnicity"), "Other or Unknown", DKA_adm_dt$LocalGrouping)




# Look at some distributional stuff

# Age
ggplot(DKA_adm_dt, aes(x=AGE))+
  geom_histogram(binwidth=1)

ggplot(DKA_adm_dt, aes(x=AGE))+
  geom_density()

ggplot(DKA_adm_dt, aes(x=AGE))+
  geom_histogram(binwidth=1)+
  facet_wrap(~AdmittedFlag)

ggplot(DKA_adm_dt, aes(x=AGE))+
  geom_density()+ 
  facet_wrap(~AdmittedFlag)


ggplot(DKA_adm_dt, aes(y=AGE, x = AdmittedFlag))+
  geom_boxplot()


# Ethnicity
DKA_adm_dt |> 
  group_by(LocalGrouping, AdmittedFlag) |> 
  summarise(patients = n()) |> 
  ggplot(aes(x=LocalGrouping, y=patients, fill = AdmittedFlag))+
  geom_col() + 
  scale_x_discrete(labels = function(x) str_wrap(x, width = 10))+
  scale_y_continuous(labels = comma)+
  scale_fill_bsol()+
  theme_bsol()

# Ethnicity
DKA_adm_dt |> 
  group_by(LocalGrouping2, AdmittedFlag) |> 
  summarise(patients = n()) |> 
  ggplot(aes(x=LocalGrouping2, y=patients, fill = AdmittedFlag))+
  geom_col() + 
  scale_x_discrete(labels = function(x) str_wrap(x, width = 10))+
  scale_y_continuous(labels = comma)+
  scale_fill_bsol()+
  theme_bsol()



# Code factors

DKA_adm_dt_mod <-
  DKA_adm_dt |> 
  mutate(
    CLEAN_SEX = ifelse(CLEAN_SEX==1,0, 1),
    #CLEAN_ETHNICITY = factor(CLEAN_ETHNICITY),
    IMD_QUINTILE = factor(IMD_QUINTILE),
    SMOKING_VALUE = factor(SMOKING_VALUE)
  ) |> 
  select(AdmittedFlag, AGE, CLEAN_SEX, LocalGrouping2, IMD_QUINTILE,
         HBA1C_VALUE, 
         #ALBUMIN_VALUE, CHOLESTEROL_VALUE, CREATININE_VALUE,
         #SYSTOLIC_VALUE, DIASTOLIC_VALUE, 
         BMI_VALUE, 
         SMOKING_VALUE,
         #FOOTEXAM_VALUE, EYEEXAM_VALUE,
         #`3TT_VALUE`, `8CP_VALUE`, 
         # `9CP_VALUE` - Exclude 9 for now, as newer and collinear with 8
  ) |> 
  na.omit()


DKA_adm_dt_mod |> 
  group_by(SMOKING_VALUE) |> 
  tally()


#### Models ####

##############################################################################################


# Model with everything
model1 <- glm(AdmittedFlag ~ ., data = DKA_adm_dt_mod, family="binomial")

summary(model1)

auc(model1)


# Stepwise based on AIC.  I know, don't shoot me...
model1_step <- step(model1, direction = "both")

summary(model1_step)

auc(model1_step)



##########################################################################
# LASSO, using glmnet package
# alpha = 1 is LASSO, 0 is Ridge, and between the two is Elastic Net
# glmnet uses a penalty, and is helpful to cross-validate it to select.
##########################################################################



y <- DKA_adm_dt_mod$AdmittedFlag
x <- model.matrix(AdmittedFlag ~ ., DKA_adm_dt_mod)


# Set up parallelism for cross-validation
parallel::detectCores(logical = FALSE)

registerDoParallel(8)
getDoParWorkers()


# Cross-validate LASSO
cv_lasso1 <- cv.glmnet(x,y, family="binomial", alpha = 1, parallel = TRUE)

stopImplicitCluster()

# Pull out and refit final model 
lasso_1se <- glmnet(x,y, family = "binomial", lambda = cv_lasso1$lambda.min)

summary(lasso_1se)

lasso_1se$beta


