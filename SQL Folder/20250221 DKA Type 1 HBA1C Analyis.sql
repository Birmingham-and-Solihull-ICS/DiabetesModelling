use EAT_Reporting_BSOL

/*
DENOMINATOR
===========
ALL BSOL REGISTERED PATIENTS WITH A CODED TYPE 1 DIABETES IN THE NATIONAL DIABETES AUDIT (NDA)
IN THE FINAL QUARTER'S NDA DATA FOR 2022-23 

NUMERATOR
==========
OF THOSE IN THE DENOMINATOR, YOU WILL BE FLAGGED AS 1 ([AdmittedFlag]) AS BEING ADMITTED WITH 
DIABETIC KETOACIDOSIS - ADMITTING EPISODE ONLY, AND MAIN DIAGNOSIS IS DKA AS A NON-ELECTIVE
ADMISSION ADMITTED DATE BETWEEN 01-APR-2023 AND 31-MAR-2024


THE NDA CARE PROCESSES DATA 
===========================
*	IF NOT ADMITTED - MUST HAVE BEEN CODED (THE LATEST CHRONOLOGICAL WITH A VALUE) FOR EACH CARE PROCESS BETWEEN 01-APR-2023 AND 31-MAR-2024
*	IF ADMITTED - MUST HAVE BEEN CODED (THE LATEST CHRONOLOGICAL WITH A VALUE) NEAREST TO THE ADMISSION DATE OF THE ADMISSION
*/
 
--CREATES THE TEMP TABLE...
 DROP TABLE IF EXISTS ##TMP_DKA_MODEL;
 
 select		[PatientId]
,			try_convert(int,[AGE]) AS AGE
,			[CLEAN_SEX] 
,			[CLEAN_ETHNICITY]
,			try_convert(int,[IMD_QUINTILE]) as [IMD_QUINTILE]
,			cast(null as date)			as [HBA1C_Date]
,			cast(null as decimal(19,4)) as HBA1C_VALUE
,			cast(null as decimal(19,4)) as HBA1C_PERCENTAGE
,			cast(null as date)			as [ALBUMIN_Date]
,			cast(null as decimal(19,4)) as ALBUMIN_VALUE
,			cast(null as date)			as [CHOLESTEROL_Date]
,			cast(null as decimal(19,4)) as CHOLESTEROL_VALUE
,			cast(null as date)			as [CREATININE_Date]
,			cast(null as decimal(19,4)) as CREATININE_VALUE
,			cast(null as date)			as [BLOODPRESSURE_Date]
,			cast(null as decimal(19,0)) as [SYSTOLIC_VALUE]
,			cast(null as decimal(19,0)) as [DIASTOLIC_VALUE]
,			cast(null as date)			as [BMI_Date]
,			cast(null as decimal(19,4)) as BMI_VALUE
,			cast(null as date)			as [SMOKING_Date]
,			cast(null as varchar(2))	as SMOKING_VALUE
,			cast(null as date)			as [FOOTEXAM_Date]
,			cast(null as BIT)			as FOOTEXAM_VALUE
,			cast(null as date)			as [EYEEXAM_Date]
,			cast(null as BIT)			as EYEEXAM_VALUE
,			cast(null as varchar(8))	as [3TT_AUDIT_YR]
,			cast(null as BIT)			as [3TT_VALUE]
,			cast(null as varchar(8))	as [8CP_AUDIT_YR]
,			cast(null as BIT)			as [8CP_VALUE]
,			cast(null as varchar(8))	as [9CP_AUDIT_YR]
,			cast(null as BIT)			as [9CP_VALUE]
,			cast(0 as bit )				as AdmittedFlag 
,			CAST(null as date)			as ADMISSIONDATE


 INTO		##TMP_DKA_MODEL
 FROM		[Localfeeds].[Reporting].[NationalDiabetesAudit_NDA_Core_Data]  --SOURCE OF DATA FOR NDA 
where		audit_year='202223E4'   --FINAL AUDIT FILE FOR 2022-2023
and			clean_diabetes_type='01' --HAS TO BE TYPE 1 ONLY
AND			PatientId IN (SELECT [Pseudo_NHS_Number] FROM EAT_Reporting_BSOL.[Demographic].[BSOL_Registered_Population])

GROUP BY	[PatientId]
 ,			try_convert(int,[AGE]) 
 ,			[CLEAN_SEX] 
 ,			[CLEAN_ETHNICITY]
 ,			try_convert(int,[IMD_QUINTILE]) 
 
 --JUST TO HELP WITH UPDATES... INDEX APPLIED
  CREATE CLUSTERED INDEX CL_IDX_NHS ON ##TMP_DKA_MODEL ([PatientId] ASC);

 
 --UPDATES ADMITTED FLAG
 update				##TMP_DKA_MODEL
 set				AdmittedFlag=1
 where				PatientId in (select  nhsnumber from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
 where				AdmittingEpisode=1 --MUST BE FIRST (ADMITTING) EPISODE ONLY
 and				IsInNDADataset=1 --MUST BE IN THE NDA DATASET
 and				DKADiagnosisOrder=1 --DKA MUST BE CODED AS MAIN DIAGNOSIS
 and				AdmissionDate between '01-Apr-2023'and '31-Mar-2024') --ADMISSION DATE BETWEEN THESE DATES.

 --now using this flag - selects the latest admission (for those with more than one in this year) AND PUTS THE DATE OF THAT ADMISSION IN
 UPDATE			T1
 SET			T1.ADMISSIONDATE=TMP.THEMAX
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(ADMISSIONDATE) AS THEMAX
 ,							NHSNUMBER  
				from		eat_reporting_BSOL.Development.DKA_SUS_IP_NEL 
				WHERE		AdmittingEpisode=1
				and			IsInNDADataset=1
				and			DKADiagnosisOrder=1
				and			AdmissionDate between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHSNUMBER
				)TMP
ON				T1.PatientId=TMP.NHSNumber
WHERE			T1.AdmittedFlag=1

--------------------------------------------------------------------------------------------
--HBA1c values admitted patients first
 UPDATE			T1
 SET			T1.HBA1C_Date=TMP.THEMAX
 ,				t1.HBA1C_PERCENTAGE=tmp.PERCENTAGE
 ,				t1.HBA1C_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							[PERCENTAGE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_HBA1C_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
,							[PERCENTAGE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				COALESCE(tmp.PERCENTAGE,TMP.[VALUE]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--HBA1c values admitted patients first
 UPDATE			T1
 SET			T1.HBA1C_Date=TMP.THEMAX
 ,				t1.HBA1C_PERCENTAGE=tmp.PERCENTAGE
 ,				t1.HBA1C_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							[PERCENTAGE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_HBA1C_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]
,							[PERCENTAGE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				COALESCE(tmp.PERCENTAGE,TMP.[VALUE]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--ALBUMIN values admitted patients first
 UPDATE			T1
 SET			T1.ALBUMIN_Date=TMP.THEMAX
 ,				t1.ALBUMIN_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_ALBUMIN_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--ALBUMIN values admitted patients first
 UPDATE			T1
 SET			T1.ALBUMIN_Date=TMP.THEMAX
 ,				t1.ALBUMIN_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_ALBUMIN_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 
--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
--CHOLESTEROL values admitted patients first
 UPDATE			T1
 SET			T1.CHOLESTEROL_Date=TMP.THEMAX
 ,				t1.CHOLESTEROL_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_CHOLESTEROL_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--CHOLESTEROL values admitted patients first
 UPDATE			T1
 SET			T1.CHOLESTEROL_Date=TMP.THEMAX
 ,				t1.CHOLESTEROL_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_CHOLESTEROL_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
--CREATININE values admitted patients first
 UPDATE			T1
 SET			T1.CREATININE_Date=TMP.THEMAX
 ,				t1.CREATININE_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_CREATININE_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--CREATININE values admitted patients first
 UPDATE			T1
 SET			T1.CHOLESTEROL_Date=TMP.THEMAX
 ,				t1.CHOLESTEROL_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_CREATININE_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--BMI values admitted patients first
 UPDATE			T1
 SET			T1.BMI_Date=TMP.THEMAX
 ,				t1.BMI_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_BMI_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--BMI values admitted patients first
 UPDATE			T1
 SET			T1.BMI_Date=TMP.THEMAX
 ,				t1.BMI_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_BMI_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--BP values admitted patients first
 UPDATE			T1
 SET			T1.BLOODPRESSURE_Date=TMP.THEMAX
 ,				t1.SYSTOLIC_VALUE=TMP.[SYSTOLIC_VALUE]
 ,				T1.DIASTOLIC_VALUE=TMP.[DIASTOLIC_VALUE]

 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[SYSTOLIC_VALUE]
 ,							[DIASTOLIC_VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_BP_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
 ,							[SYSTOLIC_VALUE]
 ,							[DIASTOLIC_VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				COALESCE(TMP.[SYSTOLIC_VALUE],TMP.[DIASTOLIC_VALUE]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 



--now non admitted just the latest...
--BMI values admitted patients first
 UPDATE			T1
 SET			T1.BLOODPRESSURE_Date=TMP.THEMAX
 ,				t1.SYSTOLIC_VALUE=TMP.[SYSTOLIC_VALUE]
 ,				T1.DIASTOLIC_VALUE=TMP.[DIASTOLIC_VALUE]
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[SYSTOLIC_VALUE]
 ,							[DIASTOLIC_VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_BP_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
 ,							[SYSTOLIC_VALUE]
 ,							[DIASTOLIC_VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				COALESCE(TMP.[SYSTOLIC_VALUE],TMP.[DIASTOLIC_VALUE]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--SMOKING values admitted patients first
/*
Guide from Chris M...   if 1 then smoker - all else is 0
NATIONAL guidance: 
https://digital.nhs.uk/data-and-information/data-collections-and-data-sets/data-collections/tobacco-dependence/guidance/data-guidance#:~:text=Current%20Smokers%20are%20coded%20as,where%20smoking%20status%20is%20unknown
Please input the patient's smoking status at the time of admission, or booking (for maternity), or attendance (for outpatients/community/primary care). Options are:
1	Current smoker 
2	Ex-smoker
3	Non-smoker - history unknown
4	Never smoked
Z   Not Stated (patient asked but declined to provide a response)
9	Unknown (not recorded)
For the national Digital Tobacco Treatment Service this will be recorded by the referral hub at the point of referral into the service
*/


 UPDATE			T1
 SET			T1.SMOKING_Date=TMP.THEMAX
 ,				t1.SMOKING_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_SMOKING_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--SMOKING values admitted patients first
 UPDATE			T1
 SET			T1.smoking_Date=TMP.THEMAX
 ,				t1.smoking_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_SMOKING_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--FOOT EXAM values admitted patients first

 UPDATE			T1
 SET			T1.FOOTEXAM_Date=TMP.THEMAX
 ,				t1.FOOTEXAM_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_FOOT_EXAM_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--FOOT EXAM values admitted patients first
 UPDATE			T1
 SET			T1.FOOTEXAM_Date=TMP.THEMAX
 ,				t1.FOOTEXAM_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_FOOT_EXAM_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--EYE EXAM values admitted patients first

 UPDATE			T1
 SET			T1.EYEEXAM_Date=TMP.THEMAX
 ,				t1.EYEEXAM_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_EYE_EXAM_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
			--	
				GROUP BY	NHS_NUMBER
,							[VALUE]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
and				TMP.THEMAX<=T1.ADMISSIONDATE
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--now non admitted just the latest...
--EYE EXAM values admitted patients first
 UPDATE			T1
 SET			T1.EYEEXAM_Date=TMP.THEMAX
 ,				t1.EYEEXAM_VALUE=TMP.VALUE
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		MAX(DATE) AS THEMAX
 ,							[VALUE]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_EYE_EXAM_NDA]
				where		[Date] between '01-Apr-2023'and '31-Mar-2024'
				GROUP BY	NHS_NUMBER
,							[VALUE]

				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				TMP.[VALUE] IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--3,8&9 values now - admitted patients first

 UPDATE			T1
 SET			T1.[3TT_AUDIT_YR]=TMP.THEMAX
 ,				T1.[3TT_VALUE]=[ALL_3_TREATMENT_TARGETS]
 ,				T1.[8CP_AUDIT_YR]=TMP.THEMAX
 ,				T1.[8CP_VALUE]=TMP.ALL_8_CARE_PROCESSES
  ,				T1.[9CP_AUDIT_YR]=TMP.THEMAX
 ,				t1.[9CP_VALUE]=TMP.[All_9_CARE_PROCESSES]
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		[Audit_Year] AS THEMAX
 ,							[ALL_3_TREATMENT_TARGETS]
 ,							[ALL_8_CARE_PROCESSES]
 ,							[All_9_CARE_PROCESSES]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_PROCESSES_AND_TARGETS_NDA]
				where		[Audit_Year]='202223E4'
			--	
				GROUP BY	NHS_NUMBER
,							[Audit_Year] 
 ,							[ALL_3_TREATMENT_TARGETS]
 ,							[ALL_8_CARE_PROCESSES]
 ,							[All_9_CARE_PROCESSES]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=1
AND				COALESCE(TMP.[ALL_3_TREATMENT_TARGETS],TMP.[ALL_8_CARE_PROCESSES],TMP.[All_9_CARE_PROCESSES]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 


--3,8&9 values now -non admitted......

 UPDATE			T1
 SET			T1.[3TT_AUDIT_YR]=TMP.THEMAX
 ,				T1.[3TT_VALUE]=[ALL_3_TREATMENT_TARGETS]
 ,				T1.[8CP_AUDIT_YR]=TMP.THEMAX
 ,				T1.[8CP_VALUE]=TMP.ALL_8_CARE_PROCESSES
  ,				T1.[9CP_AUDIT_YR]=TMP.THEMAX
 ,				t1.[9CP_VALUE]=TMP.[All_9_CARE_PROCESSES]
 FROM			##TMP_DKA_MODEL T1
 LEFT JOIN	(	SELECT		[Audit_Year] AS THEMAX
 ,							[ALL_3_TREATMENT_TARGETS]
 ,							[ALL_8_CARE_PROCESSES]
 ,							[All_9_CARE_PROCESSES]
 ,							NHS_NUMBER  
				from		[Development].[DEV_PT360_PROCESSES_AND_TARGETS_NDA]
				where		[Audit_Year]='202223E4'
			--	
				GROUP BY	NHS_NUMBER
,							[Audit_Year] 
 ,							[ALL_3_TREATMENT_TARGETS]
 ,							[ALL_8_CARE_PROCESSES]
 ,							[All_9_CARE_PROCESSES]
				)TMP
ON				T1.PatientId=TMP.NHS_NUMBER
WHERE			T1.AdmittedFlag=0
AND				COALESCE(TMP.[ALL_3_TREATMENT_TARGETS],TMP.[ALL_8_CARE_PROCESSES],TMP.[All_9_CARE_PROCESSES]) IS NOT NULL --OCCLUDES ANY WITHOUT A VALUE 

--------------------------------------------------------------------------------------------





