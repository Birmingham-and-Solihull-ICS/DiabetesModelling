library(DBI)
con <- dbConnect(odbc::odbc(), .connection_string = "Driver={SQL Server};server=MLCSU-BI-SQL;database=EAT_Reporting_BSOL", 
                 timeout = 10)

sql1  <- "
select NHS_Number,date, [VALUE], 1 as thecount
from [Development].[DEV_PT360_HBA1C_NDA] 
where 
DATE between '01-Apr-2022' and '31-Mar-2023'
and AUDIT_YEAR = '202324E4'
and VALUE is not null
group by NHS_Number,date, [VALUE]"

my_dt <- dbGetQuery(con, sql1)

my_dt_md <- median(my_dt$VALUE)
my_dt_mn <- mean(my_dt$VALUE)

library(tidyverse)
library(scales)
library(BSOLTheme)

ggplot(my_dt, aes(x=VALUE))+
  geom_histogram(bins = 50, fill = "#3C36C9", alpha = 0.7, col = "grey")+
  geom_vline(xintercept = 48, linewidth = 1.2, col = "#36C986")+
  annotate("label", x = 48-4, y = 500, label = "NICE\n target", col = "#36C986"
           , size = 3)+
  geom_vline(xintercept = my_dt_md, linewidth = 1.2, col = "#C3C936")+
  annotate("label", x = my_dt_md, y = 500, label = "Median", col = "#C3C936"
           , size = 3 )+
  geom_vline(xintercept = my_dt_mn, linewidth = 1.2, col = "#C93679")+
  annotate("label", x = my_dt_mn+4, y = 500, label = "Mean", col = "#C93679"
           , size = 3 )+
  labs(title = "NDA HbA1c test values in BSOL, 2022/23",
       subtitle = "Data represent tests, not patients. Some patients have multiple tests")+
  scale_y_continuous("Count of HbA1C tests", labels = comma)+
  theme_bsol()
