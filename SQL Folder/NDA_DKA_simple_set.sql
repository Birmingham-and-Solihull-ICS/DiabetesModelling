use EAT_Reporting_BSOL;

--creates the table!
DROP TABLE IF EXISTS ##DKA_MODELLING_ONE;

CREATE TABLE ##DKA_MODELLING_ONE(
 [NHS_Number]				varchar(10)
,[VALUE_HBA1C]				DECIMAL(19,4)
,[PERCENTAGE_HBA1C]			DECIMAL(19,4)
,[DATE_HBA1C]				DATE
,[AUDIT_YEAR_HBA1c]			VARCHAR(10)
,[AUDIT_YEAR_PROCESSTARGET]	VARCHAR(10)
,[ALL_3_TREATMENT_TARGETS]	BIT
,[ALL_8_CARE_PROCESSES]		BIT
,[All_9_CARE_PROCESSES]		BIT
,[DKA_NEL]					BIT

)
--season with a nice index
create clustered index cl_idx on ##DKA_MODELLING_ONE (NHS_Number asc)

--insert from hba1c p360 all tests regardless (unless no value)
--in date range....  between '01-APR-2022' and '31-MAR-2023'
insert into ##DKA_MODELLING_ONE

(
 [NHS_Number]				
,[VALUE_HBA1C]				
,[PERCENTAGE_HBA1C]			
,[DATE_HBA1C]				
,[AUDIT_YEAR_HBA1c]			
,[AUDIT_YEAR_PROCESSTARGET]	
,[ALL_3_TREATMENT_TARGETS]	
,[ALL_8_CARE_PROCESSES]		
,[All_9_CARE_PROCESSES]		
,[DKA_NEL]					
)

(select		[NHS_Number]				
,			[VALUE]			as [VALUE_HBA1C]				
,			[PERCENTAGE]	as [PERCENTAGE_HBA1C]			
,			[DATE]			as [DATE_HBA1C]						
,			[Audit_Year]	as [AUDIT_YEAR_HBA1c]			
,			'No Entry'		as [AUDIT_YEAR_PROCESSTARGET]	
,			0				as [ALL_3_TREATMENT_TARGETS]	
,			0				as [ALL_8_CARE_PROCESSES]		
,			0				as [All_9_CARE_PROCESSES]		
,			0				as [DKA_NEL]	
from		[Development].[DEV_PT360_HBA1C_NDA]
where		[DATE] between '01-APR-2022' and '31-MAR-2023'
AND			[VALUE]IS NOT NULL
group by	[NHS_Number]	
,			[VALUE]			
,			[PERCENTAGE]	
,			[DATE]			
,			[Audit_Year]	

)

--updates if patient had all 3 tt done by the SAME audit year
update		nda
set			nda.ALL_3_TREATMENT_TARGETS=1
,			nda.[AUDIT_YEAR_PROCESSTARGET]=tt.Audit_Year
from		##DKA_MODELLING_ONE nda
left join	[Development].[DEV_PT360_PROCESSES_AND_TARGETS_NDA] tt
on			nda.AUDIT_YEAR_HBA1c=tt.Audit_Year
where		nda.NHS_Number=tt.NHS_Number
and			tt.ALL_3_TREATMENT_TARGETS=1

--updates if patient had all 8 care processes done by the SAME audit year
update		nda
set			nda.[ALL_8_CARE_PROCESSES]=1
,			nda.[AUDIT_YEAR_PROCESSTARGET]=tt.Audit_Year
from		##DKA_MODELLING_ONE nda
left join	[Development].[DEV_PT360_PROCESSES_AND_TARGETS_NDA] tt
on			nda.AUDIT_YEAR_HBA1c=tt.Audit_Year
where		nda.NHS_Number=tt.NHS_Number
and			tt.[ALL_8_CARE_PROCESSES]=1

--updates if patient had all 9 care processes done by the SAME audit year
update		nda
set			nda.[All_9_CARE_PROCESSES]=1
,			nda.[AUDIT_YEAR_PROCESSTARGET]=tt.Audit_Year
from		##DKA_MODELLING_ONE nda
left join	[Development].[DEV_PT360_PROCESSES_AND_TARGETS_NDA] tt
on			nda.AUDIT_YEAR_HBA1c=tt.Audit_Year
where		nda.NHS_Number=tt.NHS_Number
and			tt.[ALL_9_CARE_PROCESSES]=1

--checks for NDA pts with DKA NEL post date of test.... 
update		nda
set			DKA_NEL=1
from		##DKA_MODELLING_ONE nda
left join	[Eat_reporting_BSOL].[Development].[DKA_SUS_IP_NEL] dka
on			nda.NHS_Number=dka.NHSNumber
where		dka.AdmissionDate between '01-Apr-2023' and '31-Mar-2024'
