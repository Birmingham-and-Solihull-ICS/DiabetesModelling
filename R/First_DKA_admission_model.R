# Initial NDA model of simple elements
# Exposure year: 2022/23, 
# Ouctomes year: 2023/24
# Does HbA1C control and/or care processes correlate with DKA admission?

library(DBI)
con <- dbConnect(odbc::odbc(), .connection_string = "Driver={SQL Server};server=MLCSU-BI-SQL;database=EAT_Reporting_BSOL", 
                 timeout = 10)

# First need to run the global temp table in: [SQL Folder] / NDA_DKA_simple_set.sql
# SQL provided by WA:
sql_2 <-
  ";with cte as
(
select 
[NHS_Number]				
,[VALUE_HBA1C]				
,[PERCENTAGE_HBA1C]			
,[DATE_HBA1C]				
--,[AUDIT_YEAR_HBA1c]			
--,[AUDIT_YEAR_PROCESSTARGET]	
,[ALL_3_TREATMENT_TARGETS]	
,[ALL_8_CARE_PROCESSES]		
,[All_9_CARE_PROCESSES]		
,[DKA_NEL]					
, row_number() OVER (partition by NHS_Number order by [DATE_HBA1C] desc) as rn
from ##DKA_MODELLING_ONE
--where --NHS_Number='160566170'
group by [NHS_Number]				
,[VALUE_HBA1C]				
,[PERCENTAGE_HBA1C]			
,[DATE_HBA1C]				
--,[AUDIT_YEAR_HBA1c]			
--,[AUDIT_YEAR_PROCESSTARGET]	
,[ALL_3_TREATMENT_TARGETS]	
,[ALL_8_CARE_PROCESSES]		
,[All_9_CARE_PROCESSES]		
,[DKA_NEL]					
)
--order by [NHS_Number],
Select * from cte
where rn = 1
"

DKA_dt <- dbGetQuery(con, sql_2)

DKA_dt$ALL_3_TREATMENT_TARGETS <- as.numeric(DKA_dt$ALL_3_TREATMENT_TARGETS)
DKA_dt$ALL_8_CARE_PROCESSES <- as.numeric(DKA_dt$ALL_8_CARE_PROCESSES)
DKA_dt$All_9_CARE_PROCESSES <- as.numeric(DKA_dt$All_9_CARE_PROCESSES)
DKA_dt$DKA_NEL <- as.numeric(DKA_dt$DKA_NEL)
DKA_dt$rn <- NULL
gc()

model1 <- glm(DKA_NEL ~ scale(VALUE_HBA1C) + 
                ALL_3_TREATMENT_TARGETS +
                ALL_8_CARE_PROCESSES
              ,data = DKA_dt
              , family = binomial())

summary(model1)

plot(model1)

library(ModelMetrics)

auc(model1)

# Multicolinearity check
car::vif(model1)



model2 <- glm(DKA_NEL ~ scale(VALUE_HBA1C)
                #ALL_3_TREATMENT_TARGETS +
                #ALL_8_CARE_PROCESSES
              ,data = DKA_dt
              , family = binomial())

summary(model2)
auc(model2)


AIC(model1)
AIC(model2)

library(ggplot2)

ggplot(DKA_dt, aes(y=VALUE_HBA1C, x=DKA_NEL, group=DKA_NEL))+
  geom_boxplot()
