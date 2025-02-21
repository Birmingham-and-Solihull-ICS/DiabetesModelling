USE EAT_Reporting_BSOL;

DROP TABLE IF EXISTS [Development].[DKA_SUS_IP_NEL_OPCS]

CREATE TABLE	[Development].[DKA_SUS_IP_NEL_OPCS]
(
				[EpisodeId]				BIGINT NOT NULL
,				[ProcedureOrder]		SMALLINT
,				[ProcedureCode]			VARCHAR(4)
,				[ProcedureName]			VARCHAR(255)

)
CREATE CLUSTERED INDEX CLIDX_EPID ON [Development].[DKA_SUS_IP_NEL_OPCS]([EpisodeId] ASC)	
CREATE NONCLUSTERED INDEX NCLIDX_OPCSCODE ON [Development].[DKA_SUS_IP_NEL_OPCS]([ProcedureCode] ASC)
CREATE NONCLUSTERED INDEX NCLIDX_OPCSNAME ON [Development].[DKA_SUS_IP_NEL_OPCS]([ProcedureName] ASC)

TRUNCATE TABLE [Development].[DKA_SUS_IP_NEL_OPCS];

INSERT INTO [Development].[DKA_SUS_IP_NEL_OPCS](
				[EpisodeId]				
,				[ProcedureOrder]		
,				[ProcedureCode]			
,				[ProcedureName]			
)

(
SELECT			[EpisodeId]							
,				[ProcedureOrder]		
,				[ProcedureCode]			
,				[ProcedureName]			
FROM			[EAT_Reporting].[dbo].[tbIPProceduresRelational] 
WHERE			[EpisodeId] IN (select episodeid from [Eat_reporting_BSOL].[Development].[DKA_SUS_IP_NEL])
group by		[EpisodeId]							
,				[ProcedureOrder]		
,				[ProcedureCode]			
,				[ProcedureName]

)

SELECT * FROM [Development].[DKA_SUS_IP_NEL_OPCS]

/******************************************************************************************************************************
ICD10's now...
******************************************************************************************************************************/

DROP TABLE IF EXISTS [Development].[DKA_SUS_IP_NEL_ICD10]

CREATE TABLE	[Development].[DKA_SUS_IP_NEL_ICD10]
(
				[EpisodeId]				BIGINT NOT NULL
,				[DiagnosisOrder]		SMALLINT
,				[DiagnosisCode]			VARCHAR(5)
,				[DiagnosisDescription]	VARCHAR(255)

)
CREATE CLUSTERED INDEX CLIDX_EPID ON [Development].[DKA_SUS_IP_NEL_ICD10]([EpisodeId] ASC)	
CREATE NONCLUSTERED INDEX NCLIDX_ICDCODE ON [Development].[DKA_SUS_IP_NEL_ICD10]([DiagnosisCode] ASC)
CREATE NONCLUSTERED INDEX NCLIDX_ICDSNAME ON [Development].[DKA_SUS_IP_NEL_ICD10]([DiagnosisDescription] ASC)

TRUNCATE TABLE [Development].[DKA_SUS_IP_NEL_ICD10];

INSERT INTO [Development].[DKA_SUS_IP_NEL_ICD10](

				[EpisodeId]				
,				[DiagnosisOrder]		
,				[DiagnosisCode]			
,				[DiagnosisDescription]	
)

(
SELECT			[EpisodeId]
,				[DiagnosisOrder]
,				[DiagnosisCode]
,				[DiagnosisDescription]
FROM			[EAT_Reporting].[dbo].[tbIPDiagnosisRelational]

WHERE			[EpisodeId] IN (select episodeid from [Eat_reporting_BSOL].[Development].[DKA_SUS_IP_NEL])
)


SELECT * FROM [Development].[DKA_SUS_IP_NEL_ICD10]