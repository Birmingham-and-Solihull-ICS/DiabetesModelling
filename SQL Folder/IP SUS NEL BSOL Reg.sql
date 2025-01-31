/********************************************************************************************************
Creates the table and  applies indexes
********************************************************************************************************/
/*
drop table			if exists eat_reporting_BSOL.Development.DKA_SUS_IP_NEL;

create table		eat_reporting_BSOL.Development.DKA_SUS_IP_NEL(
					NHSNumber				varchar(10)
,					EpisodeId				bigint
,					ProviderSpellIdentifier varchar(30)
,					GPPracticeCode			varchar(10)
,					LSOA					VARCHAR(9)
,					AgeOnAdmission			int
,					EthnicCode				varchar(2)
,					GenderCode				varchar(3)
,					GenderDescription		varchar(15)
,					IMDQuintile				smallint
,					ReconciliationPoint		int
,					AdmissionDate			date
,					DischargeDate			date
,					LengthOfStay			int				
,					DKADiagnosisCode		varchar(5)
,					DKADiagnosisOrder		smallint
--,					DiabetesDiagnosisCode	varchar(5)
,					DiabetesType			varchar(6)
,					EpisodeNumber			smallint
,					AdmittingEpisode		bit
,					DischargingEpisode		bit
,					IsPatientsFirstSpell	bit
,					IsPatientsLatestSpell	bit
,					IsInNDADataset			bit

)

create clustered index cl_idx_epid on eat_reporting_BSOL.Development.DKA_SUS_IP_NEL (episodeid asc)
create nonclustered index cl_idx_spellId on eat_reporting_BSOL.Development.DKA_SUS_IP_NEL (ProviderSpellIdentifier asc)
create nonclustered index cl_idx_NHSNo on eat_reporting_BSOL.Development.DKA_SUS_IP_NEL (NHSNumber asc)
*/

/********************************************************************************************************
Truncates the table
********************************************************************************************************/
truncate table	eat_reporting_BSOL.Development.DKA_SUS_IP_NEL


/********************************************************************************************************
Initial insert of BSOL Registered patients with a DKA in any position, any part of the spell
BSOL reg per the BSOL 1252 Patient Cohort table.
********************************************************************************************************/
--WITH (TABLOCK)
insert into		eat_reporting_BSOL.Development.DKA_SUS_IP_NEL  (
				NHSNumber				
,				EpisodeId				
,				ProviderSpellIdentifier 
,				GPPracticeCode			
,				LSOA					
,				AgeOnAdmission			
,				EthnicCode				
,				GenderCode				
,				IMDQuintile	
,				ReconciliationPoint
,				AdmissionDate	
,				DischargeDate	
,				LengthOfStay	
,				DKADiagnosisCode		
,				DKADiagnosisOrder		
--,				DiabetesDiagnosisCode	
,				DiabetesType			
,				EpisodeNumber			
,				AdmittingEpisode		
,				DischargingEpisode	
,				IsPatientsFirstSpell	
,				IsPatientsLatestSpell	
,				IsInNDADataset			
)
(
select			ep.NHSNumber				
,				ep.EpisodeId				
,				ep.ProviderSpellIdentifier 
,				ep.GMPOrganisationCode
,				null as LSOA				
,				ep.AgeOnAdmission			
,				ep.EthnicCategoryCode
,				ep.GenderCode
,				null			as IMDQuintile				
,				ep.ReconciliationPoint
,				ep.AdmissionDate
,				ep.DischargeDate	
,				ep.LengthOfStay	
,				null			as DKADiagnosisCode		
,				null			as DKADiagnosisOrder		
--,				null			as DiabetesDiagnosisCode	
,				'NSP'			AS DiabetesType			
,				ep.OrderInSpell as EpisodeNumber			
,				0				as AdmittingEpisode		
,				0				as DischargingEpisode
,				0				as IsPatientsFirstSpell	
,				0				as IsPatientsLatestSpell	
,				0				as IsInNDADataset			
from			EAT_Reporting.dbo.tbinpatientepisodes ep
where			ep.[AdmissionMethodCode] in ('21','22','23','24','25','2A','2B','2C','2D','28')
and				ep.EpisodeId in (	select	EpisodeId 
									from	EAT_Reporting.dbo.tbIpDiagnosisRelational
									where	DiagnosisCode in('E101'	--Type 1 diabetes mellitus - With ketoacidosis
,														     'E111'	--Type 2 diabetes mellitus - With ketoacidosis
,														     'E121'	--Malnutrition-related diabetes mellitus - With ketoacidosis
,														     'E131'	--Other specified diabetes mellitus - With ketoacidosis
,														     'E141'	--Unspecified diabetes mellitus - With ketoacidosis
															)
								)
and				ep.NHSNumber in (select	Pseudo_NHS_Number from EAT_Reporting_BSOL.Development.BSOL_1252_Patient_Cohort)
)

/********************************************************************************************************
Makes #temp table to use for first and last spell for each patient to flag....
********************************************************************************************************/
drop table		if exists #tmpminmax;
select			nhsnumber
,				min(admissiondate) as themin
,				max(admissiondate) as themax 
into			#tmpminmax
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
group by		NHSNumber


/********************************************************************************************************
Inserts at every episode the code, and the diagnosis order for all DKA coding
********************************************************************************************************/
update			t1
set				t1.DKADiagnosisCode=icd.DiagnosisCode
,				t1.DKADiagnosisOrder=icd.DiagnosisOrder
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
left join		EAT_Reporting.dbo.tbIpDiagnosisRelational icd
on				t1.EpisodeId=icd.EpisodeId
and				icd.DiagnosisCode in(					 'E101'	--Type 1 diabetes mellitus - With ketoacidosis
,														 'E111'	--Type 2 diabetes mellitus - With ketoacidosis
,														 'E121'	--Malnutrition-related diabetes mellitus - With ketoacidosis
,														 'E131'	--Other specified diabetes mellitus - With ketoacidosis
,														 'E141'	--Unspecified diabetes mellitus - With ketoacidosis
														)

/********************************************************************************************************
Updates the flag to 1 (TRUE) where the Episode order =1 for Admitting episode
********************************************************************************************************/
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
set				AdmittingEpisode= 1 where EpisodeNumber=1

/********************************************************************************************************
Updates the flag to 1 (TRUE) where the Episode is the final episode in the Spell
********************************************************************************************************/
update			t1
set				t1.Dischargingepisode=1
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
left join		EAT_Reporting.dbo.tbInpatientEpisodes t2
on				t1.EpisodeId=t2.EpisodeId
where			t2.IsLastInSpell=1

/********************************************************************************************************
Checks one of the NDA tables from our PT360 for the presence of an NHS Number.... 
********************************************************************************************************/
update			t1
set				t1.IsInNDADataset=1
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
left join		EAT_Reporting_BSOL.Development.DEV_PT360_HBA1C_NDA t2
on				t1.NHSNumber=t2.NHS_Number
where			t2.NHS_Number is not null

/********************************************************************************************************
Now inserts from SUS the LSOA from 2011 as per episode Id....
********************************************************************************************************/
update			t1
set				t1.lsoa=t2.[LowerlayerSuperOutputArea2011]
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
inner join		EAT_Reporting.[dbo].[tbIPPatientGeography] t2
on				t1.EpisodeId=t2.EpisodeId

/********************************************************************************************************
Using the LSOA, now uses that to put in the IMD_QUINTILE from locally produced table from Archie
********************************************************************************************************/
update			t1
set				t1.IMDQuintile=t2.imd_quintile
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
inner join		EAT_Reporting_BSOL.[Reference].[LSOA_2011_IMD] t2
on				t1.LSOA=t2.lsoa_code

/********************************************************************************************************
Updates Diabetes Type BASED ON the SUS Coding on that episode.... 
*******************************************************************************************************/
--Type 1
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
set				DiabetesType= 'Type 1'
where			DKADiagnosisCode= 'E101'	--Type 1 diabetes mellitus - With ketoacidosis

--Type 2
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
set				DiabetesType= 'Type 2'
where			DKADiagnosisCode= 'E111'	--Type 2 diabetes mellitus - With ketoacidosis

--Other
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
set				DiabetesType= 'Other'
where			DKADiagnosisCode in ('E121'	--Malnutrition-related diabetes mellitus - With ketoacidosis
,						  		     'E131'	--Other specified diabetes mellitus - With ketoacidosis
									)

--Unsp
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
set				DiabetesType= 'Unspec'
where			DKADiagnosisCode in ('E141'	--Unspecified diabetes mellitus - With ketoacidosis
									)
/********************************************************************************************************
Flags the patient's chronologically first spell for DKA NEL
********************************************************************************************************/

update			t1
set				t1.IsPatientsFirstSpell=1
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
left join		#tmpminmax t2
on				t1.AdmissionDate=t2.themin
and				t2.themin is not null
where			t1.NHSNumber=t2.NHSNumber

/********************************************************************************************************
Flags the patient's chronologically latest spell for DKA NEL
********************************************************************************************************/
update			t1
set				t1.IsPatientsLatestSpell=1
from			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL t1
left join		#tmpminmax t2
on				t1.AdmissionDate=t2.themax
and				t2.themax is not null
where			t1.NHSNumber=t2.NHSNumber
				

/********************************************************************************************************
Updates The Gender Description
********************************************************************************************************/
update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL					
set				genderDescription='Male'
where			GenderCode=1

update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL					
set				genderDescription='Female'
where			GenderCode=2

update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL					
set				genderDescription='Other'
where			GenderCode not in (1,2) and GenderCode is not null

update			eat_reporting_BSOL.Development.DKA_SUS_IP_NEL					
set				genderDescription='Not coded'
where			GenderCode is null



/*************************************************
Some checks for specifics or generics...

*************************************************
drop table if exists #tmp;
select NHSNumber, ProviderSpellIdentifier,1 as thecount 
into #tmp
from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL


group by  NHSNumber, ProviderSpellIdentifier


select NHSNumber,SUM(thecount) as totalDKASpells from #tmp
group by NHSNumber
HAVING COUNT(*)>1
order by totalDKASpells desc



select * from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
where NHSNumber in ('')
--and IsPatientsLatestSpell=1
order by NHSNumber,AdmissionDate desc,EpisodeNumber desc

select * from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL where providerspellidentifier in ('')
(select ProviderSpellIdentifier from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
where DKADiagnosisOrder>5
)


select * from EAT_Reporting.dbo.tbIpDiagnosisRelational where episodeid in ()
order by episodeid, diagnosisorder

select * from #tmpminmax
where NHSNumber in ('')

select * from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
where NHSNumber in ('')
order by NHSNumber,AdmissionDate,EpisodeNumber
 
select * from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
where NHSNumber in ('')
and IsPatientsFirstSpell=1
order by NHSNumber,AdmissionDate,EpisodeNumber
 
select * from eat_reporting_BSOL.Development.DKA_SUS_IP_NEL
where NHSNumber in ('')
and IsPatientsLatestSpell=1
order by NHSNumber,AdmissionDate,EpisodeNumber

*/

 