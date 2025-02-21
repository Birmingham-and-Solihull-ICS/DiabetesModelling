library(tidyverse)
library(DBI)
library(ModelMetrics)
library(glmnet)
library(doParallel)

# Database connection
con <- dbConnect(odbc::odbc(), .connection_string = "Driver={SQL Server};server=MLCSU-BI-SQL;database=EAT_Reporting_BSOL", 
                 timeout = 10)

# Pull in the dataset from SQL server:

sql_3 <-" "

DKA_adm_dt <- dbGetQuery(con, sql_3)


# Code factors




# Look at somedistributional stuff



# Model with everything
model1 <- glm(admission ~ ., data = DKA_adm_dt, family="binomial")

summary(model1_step)

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



y <- DKA_adm_dt$admission
x <- model.matrix(admission ~ ., DKA_adm_dt)


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


