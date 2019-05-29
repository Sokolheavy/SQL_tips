USE [RISK_Test]
GO
/****** Object:  StoredProcedure [dbo].[Scoring_DataMart_CC_create_p2]    Script Date: 29.05.2019 18:14:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		NNachos, DMoiseenkova, DButenko, ESokol
-- Create date: 2018-10-24
-- Description:	Вторая часть сборки витрины данных для скоринга
-- =============================================
ALTER PROCEDURE [dbo].[Scoring_DataMart_CC_create_p2]
AS
BEGIN

	SET NOCOUNT ON;

    if OBJECT_ID('risk_test.dbo.Scoring_DataMart_CC_base') is not null drop table risk_test.dbo.Scoring_DataMart_CC_base
	select * 
	into risk_test.dbo.Scoring_DataMart_CC_base
	from [khazardbp02\hazard].risk_test.dbo.Scoring_DataMart_CC_base

	-------------------------------------------собираем аппликационные данные------------------------------------------

	----------- Формируем таблицы с максимальным значением id_iteration --------------------

	if object_id ('#max_id_NBSM') is not null
	drop table #max_id_NBSM

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_NBSM
	from sppr.dbo.InfoBasic_from_NBSM_OUT
	group by id_order

	if object_id ('#max_id_CSENSE') is not null
	drop table #max_id_CSENSE

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_CSENSE
	from sppr.dbo.InfoBasic_from_CSENSE
	group by id_order

	if object_id ('#max_id_SLOLP') is not null
	drop table #max_id_SLOLP

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_SLOLP
	from sppr.dbo.InfoBasic_from_Slolp
	group by id_order

	if object_id ('#max_id_Front') is not null
	drop table #max_id_Front

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_Front
	from sppr.dbo.InfoBasic_from_Front
	group by id_order

	if object_id ('#max_id_CORESYS') is not null
	drop table #max_id_CORESYS

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_CORESYS
	from sppr.dbo.InfoBasic_from_CORESYS
	group by id_order

	if object_id ('#max_id_UW') is not null
	drop table #max_id_UW

	select id_order, max(id_iteration) as max_id_iter 
	into #max_id_UW
	from sppr.dbo.InfoChangeData_from_UNDERWRITER
	group by id_order

	--------------------------------------------------------------------------

	if object_id ('risk_test.dbo.Scoring_DataMart_CC_appl_1') is not null
	drop table risk_test.dbo.Scoring_DataMart_CC_appl_1

	select 
		t.id_order,
	
		Application_date = coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]),
	
		--ABU_client_from_appl = s2.[Information_Basic_information_Client_AB], 
	
	------------------ Социально-демографические данные клиентов -----------------------

		Passport_Age_y = DATEDIFF(year, coalesce(f2.Documents_Passport_issue_date, s2.Documents_Passport_issue_date), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])) 
		- case when Dateadd(year, DATEDIFF(year, coalesce(f2.Documents_Passport_issue_date, s2.Documents_Passport_issue_date), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])),  coalesce(f2.Documents_Passport_issue_date, s2.Documents_Passport_issue_date)) > coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]) then 1 else 0 end,

		Age_y = DATEDIFF(year, coalesce(f2.[Information_Basic_information_Birth_date], s2.[Information_Basic_information_Birth_date]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])) 
		- case when Dateadd(year, DATEDIFF(year, coalesce(f2.[Information_Basic_information_Birth_date], s2.[Information_Basic_information_Birth_date]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])), coalesce(f2.[Information_Basic_information_Birth_date], s2.[Information_Basic_information_Birth_date])) > coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]) then 1 else 0 end,

		Gender = coalesce(f2.[Information_Basic_information_Gender], s2.[Information_Basic_information_Gender]),

		Education = coalesce(f2.[Information_Basic_information_Education_type], s2.[Information_Basic_information_Education_type]),

		Family_status = coalesce(f2.[Information_Family_status_Family_status], s2.[Information_Family_status_Family_status]),

		Family_status_UW = w2.[Family_status],

		Spouse_social_status = coalesce(f2.[Information_Family_status_Spouse_social_status], s2.[Information_Family_status_Spouse_social_status]),

		Spouse_social_status_UW = w2.[Spouse_social_status],

		Number_of_children = s2.[Information_Family_status_Number_of_children],

		Number_of_dependants = coalesce(f2.[Family_status_Number_of_minor], s2.[Information_Family_status_Number_of_dependants]),

		Number_of_dependants_UW = w2.[Number_of_dependants],

		Time_in_marriage_y = DATEDIFF(year, coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])) 
		- case when Dateadd(year, DATEDIFF(year, coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])), coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration])) > coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]) then 1 else 0 end,

		Time_in_marriage_m = DATEDIFF(month, coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])) 
		- case when Dateadd(month, DATEDIFF(month, coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])), coalesce(f2.[Information_Family_status_Date_of_marriage_registration], s2.[Information_Family_status_Date_of_marriage_registration])) > coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]) then 1 else 0 end,


		Relationship_with_contact_person = coalesce(f2.[Information_Contact_person_Relationship_with_contact_person], s2.[Information_Contact_person_Relationship_with_contact_person]),

------------------ Данные о месте проживания -------------------------------------------------------------------------------

	Registration_term_in_months = DATEDIFF(month, coalesce(f2.[Contact_Registration_address_Registration_date], s2.[Contact_Registration_address_Registration_date]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])) 
	- case when Dateadd(month, DATEDIFF(month, coalesce(f2.[Contact_Registration_address_Registration_date], s2.[Contact_Registration_address_Registration_date]), coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date])), coalesce(f2.[Contact_Registration_address_Registration_date], s2.[Contact_Registration_address_Registration_date])) > coalesce(f2.[Product_Application_Application_date], s2.[Product_Application_Application_date]) then 1 else 0 end,

	Residing_term_in_months = coalesce(f2.Residing_address_Residing_term_in_months, DATEDIFF(month, s2.[Contact_Residing_address_Date_of_started_residing], s2.[Product_Application_Application_date]) 
	- case when Dateadd(month, DATEDIFF(month, s2.[Contact_Residing_address_Date_of_started_residing], s2.[Product_Application_Application_date]), s2.[Contact_Residing_address_Date_of_started_residing]) > s2.[Product_Application_Application_date] then 1 else 0 end),

	Way_of_purchase_of_habitation = s2.[Contact_Registration_address_add_Way_of_purchase_of_habitation],

	--Type_of_habitation = s2.[Contact_Registration_address_add_Type_of_habitation_no_ownership],

	Permanent_residence_data_full_ownership = coalesce(f2.[Contact_Residing_address_Permanent_residence_data_full_ownership], s2.[Contact_Residing_address_Permanent_residence_data_full_ownership]),

------------------ Данные о работе -----------------------------------------------------------------------------------------

	Position = coalesce(f2.[Employer_Current_workplace_Position], s2.[Employer_Current_workplace_Position]),

	Scope_of_activity = coalesce(f2.[Employer_Current_workplace_Scope_of_activity], s2.[Employer_Current_workplace_Scope_of_activity]),
	
	Number_of_employees = coalesce(f2.[Employer_Current_workplace_Number_of_employees_in_organization], s2.[Employer_Current_workplace_Number_of_employees_in_organization]),

	--Number_of_subordinates = s2.[Employer_Current_workplace_Number_of_subordinates],

	Current_work_experience_in_months = coalesce(f2.[Current_workplace_Work_term_in_months], DATEDIFF(month, s2.[Employer_Current_workplace_Start_working_date_in_organization], s2.[Product_Application_Application_date]) 
	- case when Dateadd(month, DATEDIFF(month, s2.[Employer_Current_workplace_Start_working_date_in_organization], s2.[Product_Application_Application_date]), s2.[Employer_Current_workplace_Start_working_date_in_organization]) > s2.[Product_Application_Application_date] then 1 else 0 end),

	Current_work_experience_in_years = coalesce(floor(f2.[Current_workplace_Work_term_in_months]/12), DATEDIFF(year, s2.[Employer_Current_workplace_Start_working_date_in_organization], s2.[Product_Application_Application_date]) 
	- case when Dateadd(year, DATEDIFF(year, s2.[Employer_Current_workplace_Start_working_date_in_organization], s2.[Product_Application_Application_date]), s2.[Employer_Current_workplace_Start_working_date_in_organization]) > s2.[Product_Application_Application_date] then 1 else 0 end),

	Total_work_experience_in_months = coalesce(f2.[Current_workplace_Total_work_experience_in_months], 12*s2.[Employer_Current_workplace_Total_work_experience_in_years]),

	Total_work_experience_in_years = coalesce(floor(f2.[Current_workplace_Total_work_experience_in_months]/12), s2.[Employer_Current_workplace_Total_work_experience_in_years]),

	Type_of_organization = s2.[Employer_Current_workplace_Type_of_organization],

	Work_type = coalesce(f2.[Employer_Current_workplace_Work_type], s2.[Employer_Current_workplace_Work_type]),

------------------ Данные о материальном состоянии клиента ------------------------------------------------------------------

	Main_Income_from_client = coalesce(f2.[Finance_Income_Main_income_amount1], s2.[Finance_Income_Main_income_amount1], 0) + coalesce(f2.[Finance_Income_Main_income_amount2], s2.[Finance_Income_Main_income_amount2], 0) + coalesce(f2.[Finance_Income_Main_income_amount3], s2.[Finance_Income_Main_income_amount3], 0),

	Main_Income_from_UW = isnull(w2.[Main_income_amount1],0)+isnull(w2.[Main_income_amount2],0)+isnull(w2.[Main_income_amount3],0),

	Main_income_type = coalesce(f2.Finance_Income_Main_income_type1, s2.Finance_Income_Main_income_type1),

	Add_Income_from_client = coalesce(f2.[Finance_Income_Additional_income_amount], s2.[Finance_Income_Additional_income_amount]),

	Add_Income_from_UW= w2.[Additional_income],

	Total_Income = n2.Total_Income,

	Monthly_charges = coalesce(f2.[Finance_Income_Monthly_charges], s2.[Finance_Income_Monthly_charges]),

	Has_a_car = coalesce(f2.Finance_Car_ownership_Has_a_car, s2.Finance_Car_ownership_Has_a_car),

------------------ Данные о кредитной нагрузке и кредитной истории ----------------------------------------------------------

	Payments_in_banks_from_client = coalesce(f2.[Finance_Active_loans_Total_payments_in_other_banks], s2.[Finance_Active_loans_Total_payments_in_other_banks]),

	Payments_in_banks_UW = w2.[Total_payments_in_banks],

	Payments_in_banks_total = n2.Total_payments_in_other_banks,

	Payments_in_alfa = r2.MonthlyPay,

	Loan_amount_in_banks_from_client = coalesce(f2.[Finance_Active_loans_Total_loans_amount_in_other_banks], s2.[Finance_Active_loans_Total_loans_amount_in_other_banks]),

	Use_of_credits_last_5_years = s2.[Finance_Loans_Use_of_credits_last_5_years],

	Requested_monthly_payment = c2.Requested_loan_Monthly_payment,
	
	Requested_loan_Initial_cash_payment = s2.Product_Requested_loan_Initial_cash_payment,

	Requested_loan_amount = coalesce(f2.Product_Requested_loan_Loan_amount_requested, s2.Product_Requested_loan_Loan_amount_requested),

	Requested_contract_amount = coalesce(f2.[Product_Requested_loan_Contract_amount], s2.[Product_Requested_loan_Contract_amount]),

	Requested_loan_term = coalesce(f2.[Product_Requested_loan_Loan_term], s2.[Product_Requested_loan_Loan_term]),

	di = n2.di,

	dti = n2.dti
	
	into risk_test.dbo.Scoring_DataMart_CC_appl_1
	from risk_test.dbo.Scoring_DataMart_CC_base as t
		left join #max_id_Front as f1 on t.id_order = f1.id_order
		left join sppr.dbo.InfoBasic_from_Front as f2 on f1.max_id_iter=f2.id_iteration
		left join #max_id_SLOLP as s1 on t.id_order= s1.id_order
		left join sppr.dbo.InfoBasic_from_SLOLP as s2 on s1.max_id_iter=s2.id_iteration
		left join #max_id_UW as w1 on t.id_order= w1.id_order
		left join sppr.dbo.InfoChangeData_from_UNDERWRITER as w2 on w1.max_id_iter=w2.id_iteration
		left join #max_id_NBSM as n1 on t.id_order= n1.id_order
		left join sppr.dbo.InfoBasic_from_NBSM_OUT as n2 on n1.max_id_iter=n2.id_iteration
		left join #max_id_CSENSE as c1 on t.id_order= c1.id_order
		left join sppr.dbo.InfoBasic_from_CSENSE as c2 on c1.max_id_iter=c2.id_iteration 
		left join #max_id_Coresys as r1 on t.id_order= r1.id_order
		left join sppr.dbo.InfoBasic_from_Coresys as r2 on r1.max_id_iter=r2.id_iteration
	--where group_new <> 'CC_PreEmbossed' and subgroup_new <> 'CC_A_Club'


	if object_id ('risk_test.dbo.Scoring_DataMart_CC_appl_2') is not null
	drop table risk_test.dbo.Scoring_DataMart_CC_appl_2

	select
		t.*,
		Education_ukr = sd1.SLOLP_LISTVALUE_RU,
		Family_status_ukr = sd2.SLOLP_LISTVALUE_RU,
		Family_status_UW_ukr = sd3.SLOLP_LISTVALUE_RU,
		Spouse_social_status_ukr = sd4.SLOLP_LISTVALUE_RU,
		Spouse_social_status_UW_ukr = sd5.SLOLP_LISTVALUE_RU,
		Relationship_with_contact_person_ukr = sd6.SLOLP_LISTVALUE_RU,
		Way_of_purchase_of_habitation_ukr = sd7.SLOLP_LISTVALUE_RU,
		Main_income_type_ukr = sd8.SLOLP_LISTVALUE_RU,
		Permanent_residence_data_full_ownership_ukr = sd9.SLOLP_LISTVALUE_RU,
		Position_ukr = sd10.SLOLP_LISTVALUE_RU,
		Scope_of_activity_ukr = sd11.SLOLP_LISTVALUE_RU,
		Work_type_ukr = sd12.SLOLP_LISTVALUE_RU
	into risk_test.dbo.Scoring_DataMart_CC_appl_2
	from risk_test.dbo.Scoring_DataMart_CC_appl_1 as t 
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd1 on t.Education = sd1.SLOLP_LISTVALUE and sd1.SLOLP_LISTNAME = 'EducationTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd2 on t.Family_status = sd2.SLOLP_LISTVALUE and sd2.SLOLP_LISTNAME = 'FamilyStatusTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd3 on t.Family_status_UW = sd3.SLOLP_LISTVALUE and sd3.SLOLP_LISTNAME = 'FamilyStatusTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd4 on t.Spouse_social_status = sd4.SLOLP_LISTVALUE and sd4.SLOLP_LISTNAME = 'EmploymantTypes' and sd4.SLOLP_VALIDTO is null
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd5 on t.Spouse_social_status_UW = sd5.SLOLP_LISTVALUE and sd5.SLOLP_LISTNAME = 'EmploymantTypes' and sd5.SLOLP_VALIDTO is null
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd6 on t.Relationship_with_contact_person = sd6.SLOLP_LISTVALUE and sd6.SLOLP_LISTNAME = 'CustomerRelationshipTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd7 on t.Way_of_purchase_of_habitation = sd7.SLOLP_LISTVALUE and sd7.SLOLP_LISTNAME = 'HabitationPurchaseTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd8 on t.Main_income_type = sd8.SLOLP_LISTVALUE and sd8.SLOLP_LISTNAME = 'BasicIncomes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd9 on t.Permanent_residence_data_full_ownership = sd9.SLOLP_LISTVALUE and sd9.SLOLP_LISTNAME = 'HabitationRelationTypes'
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd10 on t.Position = sd10.SLOLP_LISTVALUE and sd10.SLOLP_LISTNAME = 'PositionTypes'
		left join (select slolp_listvalue, max(SLOLP_VALIDFROM) as svf from alfacheck.[SLOLP_AC].[SLOLP_List_Data] where SLOLP_LISTNAME = 'SectorClasifications' group by slolp_listvalue) as sd_dop11 on t.Scope_of_activity = sd_dop11.SLOLP_LISTVALUE
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd11 on t.Scope_of_activity = sd11.SLOLP_LISTVALUE and sd11.SLOLP_LISTNAME = 'SectorClasifications' and sd11.SLOLP_VALIDFROM = sd_dop11.svf
		left join (select slolp_listvalue, max(SLOLP_VALIDFROM) as svf from alfacheck.[SLOLP_AC].[SLOLP_List_Data] where SLOLP_LISTNAME = 'WorkTypes' group by slolp_listvalue) as sd_dop12 on t.Work_type = sd_dop12.SLOLP_LISTVALUE
		left join alfacheck.[SLOLP_AC].[SLOLP_List_Data] as sd12 on t.Work_type = sd12.SLOLP_LISTVALUE and sd12.SLOLP_LISTNAME = 'WorkTypes' and sd12.SLOLP_VALIDFROM = sd_dop12.svf
	--where group_new <> 'CC_PreEmbossed' and subgroup_new <> 'CC_A_Club'

	drop table #max_id_NBSM
	drop table #max_id_FRONT
	drop table #max_id_SLOLP
	drop table #max_id_CSENSE
	drop table #max_id_CORESYS
	drop table #max_id_UW


	if object_id ('risk_test.dbo.Scoring_DataMart_CC_appl') is not null
	drop table risk_test.dbo.Scoring_DataMart_CC_appl

	select distinct
		id_order,
		/*dealdate,
		decisiondate,
		inn,
		productgroup,
		subgroup,
		subgroupdetail,
		[status],
		decision,
		fl_auto,
		Channel,
		Initial_Channel,
		DecisionSegment,
		scoringsegment,
		CC6J,
		CP6J,
		CF6J,
		PL7J,
		CC6A,
		CP6A,
		CF6A,
		PL7A,
		CC6b,
		CF6B,
		PL6B,
		contractid,
		LEGALCONTRACTNUM,
		inn_from_iscard,
		enrolled,
		firstlimit,
		clim,
		group_new,
		subgroup_new,
		projectname,
		channel2,
		CCsegm,
		ac_id,
		id_cc,
		ID_CoBrand,
		restr_flag,
		restr_dealid,
		restr_date,
		woff_flag,
		woff_date,
		mob3date,
		mob6date,
		mob9date,
		mob12date,
		Mob3Date_12m,
		Mob6Date_12m,
		Mob9Date_12m,
		Mob12Date_12m,
		yest_date,
		[30+3MOB_flag],
		[30+6MOB_flag],
		[60+6MOB_flag],
		[90+6MOB_flag],
		[60+9MOB_flag],
		[90+9MOB_flag],
		[90+12MOB_flag],
		[180+12MOB_flag],
		max_dpd_6m,
		max_dpd_9m,
		max_dpd_12m,
		max_dpd_3m12,
		max_dpd_6m12,
		max_dpd_9m12,
		max_dpd_12m12,
		max_usage_3m_orig,
		max_usage_6m_orig,
		max_usage_9m_orig,
		max_usage_12m_orig,
		max_usage_3m12_orig,
		max_usage_6m12_orig,
		max_usage_9m12_orig,
		max_usage_12m12_orig,
		[target_30+3MOB],
		[target_30+6MOB],
		[target_60+6MOB],
		[target_90+6MOB],
		[target_60+9MOB],
		[target_90+9MOB],
		[target_90+12MOB],
		[target_180+12MOB],
		target_30max6m,
		target_60max6m,
		target_90max6m,
		target_60max9m,
		target_90max9m,
		target_60max12m,
		target_90max12m,
		target_180max12m,*/

		Application_date,
		Passport_Age_y,
		Age_y,
		Gender,

		case 
			when Education='ACADEMIC_DEGREE' or Education_ukr='Вчена ступінь' then 'ACADEMIC_DEGREE'
			when Education in ('AVERAGE', 'AVERAGE_SPECIAL') or Education_ukr='Середнє/середнє спеціальне' then 'AVERAGE'
			when Education='AVERAGE_NOT_FULL' or Education_ukr='Неповне середнє' then 'AVERAGE_NOT_FULL'
			when Education='HIGH' or Education_ukr='Вище' then 'HIGH'
			when Education='HIGH_INCOMPLETE' or Education_ukr='Неповне вище' then 'HIGH_INCOMPLETE'
			when (Education is null or Education='') and Education_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Education,
	
		case 
			when Family_status='CIVIL_MARIAGE' or Family_status_ukr='Громадянський шлюб' then 'CIVIL_MARRIAGE'
			when Family_status='DIVORCED' or Family_status_ukr='Розведений / розведена' then 'DIVORCED'
			when Family_status='MARIED' or Family_status_ukr='Одружений / одружена' then 'MARRIED'
			when Family_status='NEVER_MARIAGED' or Family_status_ukr='Ніколи у шлюбі не перебували' then 'NEVER_MARRIED'
			when Family_status='REPEAT_MARIED' then 'REPEAT_MARRIAGE'
			when Family_status='WIDOWED' or Family_status_ukr='Вдовець / вдова' then 'WIDOWED'
			when (Family_status is null or Family_status='') and Family_status_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Family_status,

		case 
			when Family_status_UW='CIVIL_MARIAGE' or Family_status_UW_ukr='Громадянський шлюб' then 'CIVIL_MARRIAGE'
			when Family_status_UW='DIVORCED' or Family_status_UW_ukr='Розведений / розведена' then 'DIVORCED'
			when Family_status_UW='MARIED' or Family_status_UW_ukr='Одружений / одружена' then 'MARRIED'
			when Family_status_UW='NEVER_MARIAGED' or Family_status_UW_ukr='Ніколи у шлюбі не перебували' then 'NEVER_MARRIED'
			when Family_status_UW='REPEAT_MARIED' then 'REPEAT_MARRIAGE'
			when Family_status_UW='WIDOWED' or Family_status_UW_ukr='Вдовець / вдова' then 'WIDOWED'
			when (Family_status_UW is null or Family_status_UW='') and Family_status_UW_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Family_status_UW,
	
		case 
			when Spouse_social_status in ('NOT_WORK', 'STATUS_DOES_NOT_WORK') or Spouse_social_status_ukr='Не працює по іншим причинам' then 'DOES_NOT_WORK'
			when Spouse_social_status in ('OWN_BUSINESS', 'STATUS_OWN_BUSSINESS') or Spouse_social_status_ukr='Власна справа' then 'OWN_BUSINESS'
			when Spouse_social_status in ('WORKS', 'STATUS_WORK') or Spouse_social_status_ukr='Працює по найму/служить' then 'WORKS'
			when Spouse_social_status='STUDENT' or Spouse_social_status_ukr='Студент і не працює' then 'STUDENT'
			when Spouse_social_status='PENSIONER' or Spouse_social_status_ukr='Пенсіонер і не працює' then 'PENSIONER'
			when (Spouse_social_status is null or Spouse_social_status='') and Spouse_social_status_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Spouse_social_status,
	
		case 
			when Spouse_social_status_UW in ('NOT_WORK', 'STATUS_DOES_NOT_WORK') or Spouse_social_status_UW_ukr='Не працює по іншим причинам' then 'DOES_NOT_WORK'
			when Spouse_social_status_UW in ('OWN_BUSINESS', 'STATUS_OWN_BUSSINESS') or Spouse_social_status_UW_ukr='Власна справа' then 'OWN_BUSINESS'
			when Spouse_social_status_UW in ('WORKS', 'STATUS_WORK') or Spouse_social_status_UW_ukr='Працює по найму/служить' then 'WORKS'
			when Spouse_social_status_UW='STUDENT' or Spouse_social_status_UW_ukr='Студент і не працює' then 'STUDENT'
			when Spouse_social_status_UW='PENSIONER' or Spouse_social_status_UW_ukr='Пенсіонер і не працює' then 'PENSIONER'
			when (Spouse_social_status_UW is null or Spouse_social_status_UW='') and Spouse_social_status_UW_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Spouse_social_status_UW,

		Number_of_children, --CoBrands only
		Number_of_dependants,
		Number_of_dependants_UW,
		Time_in_marriage_y,
		Time_in_marriage_m,

		case 
			when Relationship_with_contact_person='SON' or Relationship_with_contact_person_ukr='Син' then 'SON'
			when Relationship_with_contact_person='DAUGHTER' or Relationship_with_contact_person_ukr='Дочка' then 'DAUGHTER'
			when Relationship_with_contact_person='FATHER' or Relationship_with_contact_person_ukr='Батько' then 'FATHER'
			when Relationship_with_contact_person='MOTHER' or Relationship_with_contact_person_ukr='Мати' then 'MOTHER'
			when Relationship_with_contact_person='HUSBAND' or Relationship_with_contact_person_ukr='Чоловік' then 'HUSBAND'
			when Relationship_with_contact_person='WIFE' or Relationship_with_contact_person_ukr='Дружина' then 'WIFE'
			when Relationship_with_contact_person='BROTHER' or Relationship_with_contact_person_ukr='Брат' then 'BROTHER'
			when Relationship_with_contact_person='SISTER' or Relationship_with_contact_person_ukr='Сестра' then 'SISTER'
			when Relationship_with_contact_person='CLOSE_RELATIVE' or Relationship_with_contact_person_ukr='Близький родич' then 'CLOSE_RELATIVE'		
			when Relationship_with_contact_person='RELATIVE' then 'RELATIVE'
			when Relationship_with_contact_person='DISTANT_RELATIVE' or Relationship_with_contact_person_ukr='Далекий родич' then 'DISTANT_RELATIVE'
			when Relationship_with_contact_person='FRIEND' or Relationship_with_contact_person_ukr='Друг' then 'FRIEND'
			when Relationship_with_contact_person='NEIGHBOR' then 'NEIGHBOUR'		
			when Relationship_with_contact_person='EMPLOYEE' then 'EMPLOYEE'
			when (Relationship_with_contact_person is null or Relationship_with_contact_person='') and Relationship_with_contact_person_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Relationship_with_contact_person,

		Registration_term_in_months, --CoBrands only
		Residing_term_in_months,

		case 
			when Way_of_purchase_of_habitation='EXCHANGE' or Way_of_purchase_of_habitation_ukr='Обмін' then 'EXCHANGE'
			when Way_of_purchase_of_habitation='GIFT' or Way_of_purchase_of_habitation_ukr='Спадок/дар' then 'GIFT'
			when Way_of_purchase_of_habitation='PRIVATIZATION' or Way_of_purchase_of_habitation_ukr='Приватизація' then 'PRIVATIZATION'
			when Way_of_purchase_of_habitation='PURCHASE' or Way_of_purchase_of_habitation_ukr='Купівля' then 'PURCHASE'
			when (Way_of_purchase_of_habitation is null or Way_of_purchase_of_habitation='') and Way_of_purchase_of_habitation_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Way_of_purchase_of_habitation,
			
		case 
			when Permanent_residence_data_full_ownership='ENTIRELY_PROPERTY' or Permanent_residence_data_full_ownership_ukr='Цілком є Вашою власністю' then 'ENTIRELY_PROPERTY'
			when Permanent_residence_data_full_ownership='NO_INFORMATION' or Permanent_residence_data_full_ownership_ukr='Не володію інформацією щодо власності' then 'NO_INFORMATION'
			when Permanent_residence_data_full_ownership='NOT_YOUR_PROPERTY' or Permanent_residence_data_full_ownership_ukr='Не є власником. Проживаю/ зареєстрований:' then 'NOT_YOUR_PROPERTY'
			when Permanent_residence_data_full_ownership='PARTIAL_PROPERTY' or Permanent_residence_data_full_ownership_ukr='Є вашою власністю спільно з іншими особами' then 'PARTIAL_PROPERTY'
			when Permanent_residence_data_full_ownership='HOSTEL' then 'HOSTEL'
			when Permanent_residence_data_full_ownership='LIVING_WITH_FRIENDS' then 'LIVING_WITH_FRIENDS'
			when Permanent_residence_data_full_ownership='RENT' then 'RENT'
			when (Permanent_residence_data_full_ownership is null or Permanent_residence_data_full_ownership='') and Permanent_residence_data_full_ownership_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Permanent_residence_data_full_ownership,

		case 
			when Position='PHYSICAL_WORK' or Position_ukr='Робітник (фізичний труд, що не потребує додаткових знань)' then 'PHYSICAL_WORK'
			when Position='DRIVER' or Position_ukr='Водій, експедитор' then 'DRIVER'
			when Position='QUALIFIED_PHYSICAL_WORK' or Position_ukr='Кваліфіковані робітники фізичного труда (зварювальник, муляр, токар, слюсар, сантехнік…)' then 'QUALIFIED_PHYSICAL_WORK'
			when Position='HIGH_EMPLOYEE' or Position_ukr='Спеціаліст (професії, що потребують вищої освіти та не пов''язані з фізичною працею)' then 'HIGH_EMPLOYEE'
			when Position='SALE' or Position_ukr='Продавець (касир, мерчендайзер, супервайзер, консультант, менеджер з продажу…)' then 'SALE'
			when Position='MILITARY' or Position_ukr='Охоронець/ Міліціонер/ Військовослужбовець/ Працівник митниці' then 'MILITARY'
			when Position='LOW_EMPLOYEE' or Position_ukr='Кваліфікований працівник (профессії, що потребують середньої освіти і не пов''язані з фізичною працею)' then 'LOW_EMPLOYEE'
			when Position='DOP_PERSONAL' or Position_ukr='Допоміжний персонал (прибиральниця, офіціант, диспетчер, пакувальник, кур''єр, провідник…)' then 'DOP_PERSONAL'
			when Position='LOW_BOSS' or Position_ukr='Керівник нижчої ланки (відділу, сектору, дільниці, бригади, зміни…)' then 'LOW_BOSS'
			when Position='HIGH_BOSS' or Position_ukr='Керівник вищої ланки (директор, начальник управління, власник, ПП, головний бухгалтер)' then 'HIGH_BOSS'
			when Position_ukr='Пенсіонер' then 'PENSIONER'
			when (Position is null or Position='') and Position_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Position,

		case 
			when Scope_of_activity = 'AGRICULTURE' then 'AGRICULTURE'
			when Scope_of_activity_ukr = 'Сільське госп-во/ Садівництво/ Тваринництво' then 'AGRICULTURE'
			when Scope_of_activity in ('BUILD', 'REPAIR') then 'CONSTRUCTION'
			when Scope_of_activity_ukr in ('Будівництво', 'Ремонт житла') then 'CONSTRUCTION'
			when Scope_of_activity = 'CLOTHE' then 'LIGHT_INDUSTRY'
			when Scope_of_activity_ukr = 'Виробництво товарів нар. споживання (одягу, взуття, побутової техніки і т. д) та продуктів харчування' then 'LIGHT_INDUSTRY'
			when Scope_of_activity = 'EAT' then 'RESTAURANT'
			when Scope_of_activity_ukr = 'Громадське харчування (кафе, їдальні, ресторани)' then 'RESTAURANT'
			when Scope_of_activity = 'ENTERTAINMENT' then 'CULTURE_ENTERTAINMENT'
			when Scope_of_activity_ukr = 'Розваги/ Культура/ Мистецтво/ ЗМІ/ Телебачення/ Радіо/ Преса/ Гральний бізнес' then 'CULTURE_ENTERTAINMENT'
			when Scope_of_activity in ('FARM', 'OIL') then 'HEAVY_INDUSTRY'
			when Scope_of_activity_ukr in ('Виробництво (фабрики, заводи) / Промисловість / Видобуток/ Металургія/ Машинобудування', 'Видобуток та переробка нафти та газу/ Електроенергетика') then 'HEAVY_INDUSTRY'
			when Scope_of_activity = 'FINANCE' then 'FINANCE_MARKETING_IT_LAW'
			when Scope_of_activity_ukr = 'Фінанси/ Страхування/ Консалтінг/ Реклама/ Аудит/ Юридичні послуги/ Нерухомість' then 'FINANCE_MARKETING_IT_LAW'
			when Scope_of_activity = 'HELTH' then 'HEALTHCARE_SPORT'
			when Scope_of_activity_ukr = 'Охорона здоров''я/ Спорт' then 'HEALTHCARE_SPORT'
			when Scope_of_activity = 'HOTEL' then 'SERVICES'
			when Scope_of_activity_ukr = 'Сфера послуг та обслуговування/ Готельний бізнес/ Туризм' then 'SERVICES'
			when Scope_of_activity in ('MILITARY', 'POLICY', 'PROTECTION') then 'MILITARY_POLICE'
			when Scope_of_activity_ukr in ('Митниці/  МВС/ СБУ/ Поліція', 'Охоронна діяльність', 'Збройні сили') then 'MILITARY_POLICE'
			when Scope_of_activity in ('PENSIONER', 'PENSION') then 'PENSIONER'
			when Scope_of_activity_ukr = 'Пенсіонер' then 'PENSIONER'
			when Work_type = 'PENSIONER' then 'PENSIONER'
			when Work_type_ukr = 'Пенсіонер' then 'PENSIONER'
			when Scope_of_activity = 'POWER' then 'AUTHORITY'
			when Scope_of_activity_ukr = 'Органи влади/ Адміністративні органи/ Органи місцевого самоврядування/ Комунальні госп-ва' then 'AUTHORITY'
			when Scope_of_activity = 'RETAIL' then 'RETAIL'
			when Scope_of_activity_ukr = 'Роздрібна торгівля (магазини, супермаркети, автосалони...)' then 'RETAIL'
			when Scope_of_activity = 'STUDY' then 'STUDY_SCIENCE'
			when Scope_of_activity_ukr = 'Наука/ Освіта' then 'STUDY_SCIENCE'
			when Scope_of_activity in ('TRANSPORT', 'TRANSFER') then 'TRANSPORT'
			when Scope_of_activity_ukr in ('Приватні перевезення (таксі)', 'Транспорт/ Експедиторські роботи та послуги/ Зв''язок (поштовий, кур''єрський, інтернет, телефон...)') then 'TRANSPORT'
			when Scope_of_activity = 'WHOLESALE' then 'WHOLESALE'
			when Scope_of_activity_ukr = 'Оптова торгівля' then 'WHOLESALE'
			when (Scope_of_activity is null or Scope_of_activity in ('null', '')) and Scope_of_activity_ukr is null then 'EMPTY'
			else 'OTHER'
		end as Scope_of_activity,

		Number_of_employees,

		case
			when Work_type = 'PENSIONER' then 'PENSIONER'
			when Work_type_ukr = 'Пенсіонер' then 'PENSIONER'
			when Work_type = 'NOT_WORK' then 'UNEMPLOYED'
			when Work_type_ukr = 'Безробітний' then 'UNEMPLOYED'
			when Work_type = 'NOT_OFFICIAL_WORK' then 'NOT_OFFICIAL'
			when Work_type_ukr = 'Працює неофіційно' then 'NOT_OFFICIAL'
			when Work_type in ('OWN_BUSINESS', 'INDEPENDENT_ACTIVITY') then 'OWN_BUSINESS'
			when Work_type_ukr in ('Приватний підприєиець', 'Здійснюю незалежну професійну діяльність') then 'OWN_BUSINESS'
			when (Work_type is null or Work_type = '') and (Work_type_ukr is null or Work_type_ukr = '') then 'EMPTY'
			when Work_type in ('COLLECTIVE', 'PRIVATE', 'SME', 'STATE') then 'HIRED_EMPLOYEE'
			when Work_type_ukr in ('Працює у приватного підприємця', 'Працює за домовленістю', 'Найманий працівник на юр. особу') then 'HIRED_EMPLOYEE'
			else 'OTHER'
		end as Work_type,

		case
			when Work_type = 'NOT_WORK' then 'UNEMPLOYED'
			when Work_type_ukr = 'Безробітний' then 'UNEMPLOYED'
			when Type_of_organization = 'PRIVATE_BUSINESSMAN' then 'PRIVATE_BUSINESSMAN'
			when Type_of_organization = 'PRIVATE_ENTERPRISE' then 'PRIVATE_ENTERPRISE'
			when Type_of_organization = 'COLLECTIVE_ENTERPRISE' then 'COLLECTIVE_ENTERPRISE'
			when Type_of_organization = 'STATE_MUNICIPAL' then 'STATE_MUNICIPAL'
			when Work_type = 'PENSIONER' then 'PENSIONER'
			when Work_type_ukr = 'Пенсіонер' then 'PENSIONER'
			when Work_type in ('OWN_BUSINESS', 'INDEPENDENT_ACTIVITY') then 'PRIVATE_BUSINESSMAN'		
			when Work_type = 'PRIVATE' then 'PRIVATE_ENTERPRISE'		
			when Work_type in ('COLLECTIVE', 'SME') then 'COLLECTIVE_ENTERPRISE'		
			when Work_type = 'STATE' then 'STATE_MUNICIPAL'		
			when (Work_type is null or Work_type = '') and (Type_of_organization is null or Type_of_organization = '') then 'EMPTY'
			when Work_type = 'NOT_OFFICIAL_WORK' then 'NOT_OFFICIAL'
			when Work_type_ukr = 'Працює неофіційно' then 'NOT_OFFICIAL'
			else 'OTHER'
		end as Type_of_organization,

		Current_work_experience_in_months,
		Current_work_experience_in_years,
		Total_work_experience_in_months,
		Total_work_experience_in_years,

		Main_Income_from_client,
		Main_Income_from_UW,

		case
			when Main_income_type in ('CREDIT', 'LOAN') or Main_income_type_ukr = 'Отримання кредиту' then 'LOAN'
			when Main_income_type = 'HIRING' or 
				 Main_income_type_ukr in ('Официальный доход «по совместительству» (найм)', 'Официальный доход «по совместительству» (ЧП)',
										  'Официальный доход по работе «по совместительству»', 'Офіційний дохід за сумісництвом (найм)',
										  'Офіційний дохід за сумісництвом (ПП)') then 'HIRING'
			when Main_income_type = 'NONOFFICIAL_INCOME' or
				 Main_income_type_ukr in ('Неофициальный доход по основному месту работы',
										  'Неофіційний дохід за основним місцем роботи') then 'NONOFFICIAL'
			when Main_income_type = 'OFFICIAL_INCOME' or Main_income_type_ukr in ('Официальный доход', 'Офіційний дохід') then 'OFFICIAL'
			when Main_income_type = 'PENSION' or Main_income_type_ukr in ('Пенсия',	'Пенсія') then 'PENSIONER'
			else 'OTHER'
		end as Main_income_type,

		Add_Income_from_client,
		Add_Income_from_UW,
		Total_Income,
		Monthly_charges, -- расходы клиента в месяц
		Has_a_car,

		Payments_in_banks_from_client,
		Payments_in_banks_UW,
		Payments_in_banks_total,
		Payments_in_alfa,

		Loan_amount_in_banks_from_client, --CoBrands only
		Use_of_credits_last_5_years, --CoBrands only

		Requested_monthly_Payment, --CoBrands only
		Requested_loan_amount, --CoBrands only
		Requested_contract_amount, --CoBrands only
		Requested_loan_Initial_cash_payment, --CoBrands only
		Requested_loan_term, --CoBrands only

		di,
		dti
	into risk_test.dbo.Scoring_DataMart_CC_appl -- финальная таблица с аппликационными данными
	from risk_test.dbo.Scoring_DataMart_CC_appl_2

	drop table risk_test.dbo.Scoring_DataMart_CC_appl_1
	drop table risk_test.dbo.Scoring_DataMart_CC_appl_2

	--select top 100 * from risk_test.dbo.Scoring_DataMart_CC_appl

	-------------------------------------------собираем данные бюро------------------------------------------
	-- select * from risk_test.dbo.Scoring_DataMart_CC_base 

	 if object_id ('tempdb..#list') is not null
	 drop table #list

	 select distinct
		i.decisiondate
		, sc.id_order
		, Source_Application_ID
		, i.decisiondate as date_insert
		, null dealid
		, null as client_type_2
		, null as target_60max12m
		, null as [target_30+3MOB]
		, convert(varchar(10), null) client_type
		, null sample_type
		, AmountBeginUAH
	into #list
	from risk_test.dbo.Scoring_DataMart_CC_base sc
		join rpa.dbo.i_und_main i on i.id=sc.ID_Order
		left join ALFACHECK.dbo.AC_Order_Application a on i.id=a.ID_Order

	 if object_id ('tempdb..#id') is not null
	drop table #id

	select l.id_order as id_last, client_type_2 as client_type,  isnull(c.id_order,l.id_order) as id_order
		, l.DecisionDate
		, convert(int, null) Buro_error
		, convert(int, null) Buro_stop
		, convert(int, null) Buro_NO_KI
		, convert(int, null) Buro_KI
		, convert(int, null) InUse
		, convert(int, null) KI
		, convert(int, null) KI_no
		, target_60max12m
		, [target_30+3MOB] as target_30MOB3
		, sample_type
	into #id
	from #list l 
		left join rpa.dbo.y_ordersChain c on l.id_order = c.lastID
		join rpa.dbo.i_und_main i on i.id=l.id_order
	order by l.id_order

	insert into #id
	select l.id_order as id_last, client_type_2 as client_type
		,  isnull(a.ID,l.id_order) as id_order
		, l.DecisionDate
		, convert(int, null) Buro_error
		, convert(int, null) Buro_stop
		, convert(int, null) Buro_NO_KI
		, convert(int, null) Buro_KI
		, convert(int, null) InUse
		, convert(int, null) KI
		, convert(int, null) KI_no
		, target_60max12m
		, [target_30+3MOB] as target_30MOB3
		, sample_type
	from #list l 
	 join alfacheck.dbo.AC_PreOrder a on l.Source_Application_ID=a.Source_Application_ID
	order by l.id_order

	update #id
	set Buro_error = 1
	where id_order in (select ordergoBKI FROM [SPPR].[dbo].[BureauStatistics_Reports] where error in (-1,-2,-3))

	update #id
	set Buro_stop = 1
	where id_order in (select ordergoBKI FROM [SPPR].[dbo].[BureauStatistics_Reports] where error in (-4))

	update #id
	set Buro_NO_KI = 1
	where id_order in (select ordergoBKI FROM [SPPR].[dbo].[BureauStatistics_Reports] where error in (0))

	update #id
	set Buro_KI = 1
	where id_order in (select ordergoBKI FROM [SPPR].[dbo].[BureauStatistics_Reports] where error in (1))

	update #id
	set InUse = 1 
	where id_last in ( select id_last 
						from (  select id_last, max(Buro_error) er , max(Buro_stop) st, max(Buro_NO_KI) no_ki, max(Buro_KI) ki
								 from #id i
								 group by id_last) c 
						where case 
								when isnull(er,0)=0 and isnull(st,0)=0 and isnull(no_ki,0)=0 and isnull(ki,0)=0 then 1
								when isnull(er,0)=0 and isnull(st,0)=0 and isnull(no_ki,0)=0 and isnull(ki,0)=1 then 1  
								when isnull(er,0)=0 and isnull(st,0)=0 and isnull(no_ki,0)=1 and isnull(ki,0)=0 then 1 
								when isnull(er,0)=0 and isnull(st,0)=0 and isnull(no_ki,0)=1 and isnull(ki,0)=1 then 1 
								when isnull(er,0)=0 and isnull(st,0)=1 and isnull(no_ki,0)=0 and isnull(ki,0)=1 then 1
								when isnull(er,0)=1 and isnull(st,0)=0 and isnull(no_ki,0)=0 and isnull(ki,0)=1 then 1
								else 0 end =1) 
	-- select * from #id
	-- drop table risk_test.[dbo].[InfoBureauData_from_NBSM_OUT]
	truncate table  risk_test.[dbo].[InfoBureauData_from_NBSM_OUT]
	insert into risk_test.[dbo].[InfoBureauData_from_NBSM_OUT]
	select distinct id_last, DecisionDate
		  ,[INN]      ,[Creditor]      ,[Days180]      ,[Days180TrashHold]      ,[Days30]      ,[Days30LastDate]      ,[Days30TrashHold]
		  ,[Days30TrashHoldLastDate]      ,[Days90]      ,[Days90TrashHold]      ,[DealBureau]      ,[DealCurrencyKoef]      ,[DealCurrencyTag]
		  ,[DealDateBegin]      ,[DealDateEnd]      ,[DealIndex]      ,[DealIsBorrower]      ,[DealIsNull]      ,[DealMaxHistoryDate]
		  ,[DealMonthlyPayment]      ,[DealOpen]      ,[DealOverdueAmount]      ,[DealOverdueDays]      ,[DealSubType]      ,[DealType]
		  ,[DealSumBegin]      ,[DealUnique]      ,[EC180]      ,[EC180TrashHold]      ,[EC30]      ,[EC30TrashHold]      ,[EC90]
		  ,[EC90TrashHold]      ,[FlagEC]      ,[LoanBurden]      ,[LoanBurdenType]      ,[NHNF]      ,[OutstandingAmount]      ,[PH12m]
		  ,[PH6_12m]      ,[PHless6m]      ,[UbkiCardRule1]      ,[UbkiCardRule2]      ,[UbkiCardRule3]      ,[ContractStatus]
		  ,[MaxOutstandingLast3Month]      ,[MaxOverdueAmountEver]      ,[MaxOverdueDaysEver]
	--into risk_test.[dbo].[InfoBureauData_from_NBSM_OUT]
	from  #id i
		join [SPPR].[dbo].[InfoBureauData_from_NBSM_OUT] ou on i.id_order = ou.id_order

	-- select * from risk_test.[dbo].[InfoBureauData_from_NBSM_OUT] where id_last=9328265 order by DealSumBegin


	-- drop table risk_test.[dbo].[InfoContracts_from_bureau]
	truncate table risk_test.[dbo].[InfoContracts_from_bureau]
	insert into risk_test.[dbo].[InfoContracts_from_bureau]
	select distinct id_last, DecisionDate
		  ,[INN]      ,[CodeOfContract]      ,[Index]
	--into risk_test.[dbo].[InfoContracts_from_bureau]
	from  #id i
 		join [SPPR].[dbo].[InfoContracts_from_bureau] ind on i.id_order = ind.id_order 

	-- drop table risk_test.[dbo].[InfoDeal_from_bureau]
	truncate table  risk_test.[dbo].[InfoDeal_from_bureau]
	insert into risk_test.[dbo].[InfoDeal_from_bureau]
	select distinct id_last, DecisionDate
		  ,[INN]      ,[Bureau]      ,[TypeReport]      ,[ContractType]      ,[ContractRole]      ,[CodeOfContract]      ,[ContractPosition]
		  ,[TypeOfFounding]      ,[PurposeOfCredit]      ,[CurrencyCode]      ,[ContractStatus]      ,[NegativeStatus]      ,[SubjectRole]
		  ,[DateOfApplication]      ,[CreditStartDate]      ,[FactualRepaymentDate]      ,[CurrencyTotalAmount]      ,[ValueTotalAmount]
		  ,[ContractEndDate]      ,[NumberOfInstalments]      ,[NumberOfOutstandingInstalments]      ,[PereodicityOfPayments]
		  ,[OutstandingAmount]      ,[MethodOfPayments]      ,[NumberOfOverdueInstalments]      ,[OverdueAmount]      ,[ResidualAmount]
		  ,[UsedAmount]      ,[MonthlyInstalmentAmount]      ,[RolesSubjectRole]      ,[Creditor]      ,[ContractPhase]
		  ,[NumberOfDaysOfPayingPercents]      ,[FactualPaymentDate]      ,[NumberOfInstalmentsNotPaidAccordingToInterestRate]
		  ,[OverdraftCurrency]      ,[OverdraftValue]      ,[DueInterestAmountValue]      ,[DueInterestCurrency]      ,[InteresRate]
		  ,[AccountingDate]      ,[DateOfSignature]      ,[LastUpdateContract]      ,[FactualEndDate]
	-- into risk_test.[dbo].[InfoDeal_from_bureau]
	from  #id i
		join [SPPR].[dbo].[InfoDeal_from_bureau]  ib on ib.id_order = i.id_order


	-- drop table risk_test.[dbo].[InfoDealHistory_from_bureau]
	truncate table  risk_test.[dbo].[InfoDealHistory_from_bureau]
	insert into risk_test.[dbo].[InfoDealHistory_from_bureau]
	select distinct id_last
		  ,[INN]      
		  ,[Bureau]
		  ,[CodeOfContract]
		  ,[MonthIndex]
		  ,[MonthIndex01]
		  ,[HCResidualAmount]
		  ,[HCUsedAmount]
		  ,[HCOverdraft]
		  ,[HCCreditUsedInMonth]
		  ,[HCTotalNumberOfOverdueInstalments]
		  ,[HCTotalOverdueAmount]
		  ,[HCCreditCardUsedInMonth]
		  ,[DealClosing]
		  ,[OverdueDuration]
		  , convert(int, null) dpd
	--into select * from risk_test.[dbo].[InfoDealHistory_from_bureau] where id_last=9160169
	--into risk_test.[dbo].[InfoDealHistory_from_bureau]
	from  #id i
		join [SPPR].[dbo].[InfoDealHistory_from_bureau]  ib on ib.id_order = i.id_order
	-- select * from risk_test.[dbo].[InfoDealHistory_from_bureau]
	update risk_test.[dbo].[InfoDealHistory_from_bureau]
	set dpd = OverdueDuration

	update risk_test.[dbo].[InfoDealHistory_from_bureau]
	set dpd = HCTotalNumberOfOverdueInstalments*-1
	where HCTotalNumberOfOverdueInstalments<0
	and Bureau='PVBKI'

	update risk_test.[dbo].[InfoDealHistory_from_bureau]
	set dpd = HCTotalNumberOfOverdueInstalments*30
	where HCTotalNumberOfOverdueInstalments>=0
	and Bureau in ('PVBKI','MBKI')

	update risk_test.[dbo].[InfoDealHistory_from_bureau]
	set dpd = 0
	where dpd is null

	-- select * from risk_test.[dbo].[InfoDealHistory_from_bureau] where id_last= 9328265 order by MonthIndex01


	-- drop table [risk_test].[dbo].InfoInquiryDate_from_bureau
	truncate table  [risk_test].[dbo].InfoInquiryDate_from_bureau
	insert into [risk_test].[dbo].InfoInquiryDate_from_bureau
	select distinct id_last, DecisionDate
		  , [INN]      
		  , Bureau
		  , reqId
		  , reqDateTime
		  , reqType
		  , partnerType
	--into [risk_test].[dbo].InfoInquiryDate_from_bureau
	from  #id i
		join [SPPR].[dbo].InfoInquiryDate_from_bureau ib on ib.id_order = i.id_order


	-- drop table [risk_test].[dbo].InfoInquiryDate_from_bureau
	truncate table  [risk_test].[dbo].[InfoContact_from_bureau]
	insert into [risk_test].[dbo].[InfoContact_from_bureau]
	select distinct id_last, DecisionDate
		 , INN
		 , Bureau
		 , Name
		 , Value as phone
	--into [risk_test].[dbo].[InfoContact_from_bureau]
	from  #id i
		join [SPPR].[dbo].[InfoContact_from_bureau] ib on ib.id_order = i.id_order


	drop table risk_test.[dbo].[ScoreBuro_InfoDeal]
	select ic.id_last,ic.DecisionDate, ic.inn, ic.CodeOfContract, ic.[Index] dealindex
		 , ou.Creditor
		, ou.DealDateBegin
		, ou.DealDateEnd
		, ib.FactualEndDate
		, ib.LastUpdateContract
		, ou.DealSumBegin
		, ou.DealCurrencyTag
		, [DealCurrencyKoef]
		, ou.DealType
		, ou.DealSubType	
		, ou.DealUnique
		, ou.DealMonthlyPayment
		, ou.OutstandingAmount
		, ou.DealOverdueAmount
		, ou.DealOverdueDays
		, ou.DealOpen
		, Bureau
		, convert(int, 0) main
	--	, *
	into risk_test.[dbo].[ScoreBuro_InfoDeal]
	 from risk_test.[dbo].[InfoContracts_from_bureau] ic
	 join   risk_test.[dbo].[InfoBureauData_from_NBSM_OUT] ou on ic.id_last=ou.id_last and ic.[index]=ou.DealIndex
	 join  risk_test.[dbo].[InfoDeal_from_bureau] ib on ic.id_last=ib.id_last and ic.CodeOfContract=ib.CodeOfContract and left(ib.bureau,4)=left(ic.[Index],4)
	where ou.Creditor<>'ALFA'
	and ContractType<>'Rejected'
	and ContractType<>'Requested'
	and DealIsBorrower=1
	and Bureau in ('PVBKI','UBKI','MBKI')


	delete -- select * 
	from risk_test.[dbo].[ScoreBuro_InfoDeal] 
	where DealDateBegin='1900-01-01'

	delete --select*
	from risk_test.[dbo].[ScoreBuro_InfoDeal] 
	where DealDateEnd<DealDateBegin

	create index i1 on risk_test.[dbo].[ScoreBuro_InfoDeal](id_last, CodeOfContract,Bureau)
	create index i2 on risk_test.[dbo].[InfoDealHistory_from_bureau](id_last, CodeOfContract,Bureau)

	--delete from risk_test.[dbo].[ScoreBuro_InfoDeal] where ContractType='Rejected'
	 if object_id ('tempdb..#buro_hist_prep') is not null
	drop table #buro_hist_prep

	select h.*, i.DealDateBegin, i.DealDateEnd,i.DealSumBegin, i.DealCurrencyTag,i.[DealCurrencyKoef] 
	into #buro_hist_prep
		from risk_test.[dbo].[ScoreBuro_InfoDeal] i
			join risk_test.[dbo].[InfoDealHistory_from_bureau] h on i.id_last=h.id_last and i.CodeOfContract=h.CodeOfContract and h.Bureau=i.Bureau
	where DealOpen>-1
	order by 1,4

	 if object_id ('tempdb..#buro_deal') is not null
	 drop table #buro_deal

	select d.id_last, d.DecisionDate, d.DealDateBegin, d.DealSumBegin,ValueTotalAmount, d.DealCurrencyTag, d.[DealCurrencyKoef]	
		, convert(varchar(20), null) product
		, count(distinct d.Bureau) bur
		, max(d.LastUpdateContract) LUC
		, max(d.DealMonthlyPayment) pay
		, max(d.DealOpen) Op
		, max(d.OutstandingAmount) OutSt
		, min(d.FactualEndDate) FactualEndDate
		, max(d.DealOverdueAmount) dpd_amnt
		, max(d.DealOverdueDays) dpd
		, max(case when d.dealindex like 'PVBKI%' then d.DealDateEnd else null end) enddate_PVBKI
		, max(case when d.dealindex like 'MBKI%' then d.DealDateEnd else null end) enddate_MBKI
		, max(case when d.dealindex like 'UBKI%' then d.DealDateEnd else null end) enddate_UBKI
		, max(d.LastUpdateContract) Last_date
	into #buro_deal
	from risk_test.[dbo].[ScoreBuro_InfoDeal] d
		join risk_test.[dbo].[InfoDeal_from_bureau] b 
			on d.id_last=b.id_last 
				and d.Bureau=b.Bureau 
				and d.CodeOfContract=b.CodeOfContract 
				and ((b.CodeOfContract='UAH' and d.DealSumBegin=ValueTotalAmount) OR (b.CodeOfContract<>'UAH' and d.DealSumBegin/DealCurrencyKoef-ValueTotalAmount between -1 and 1))
	where DealOpen>-1
	 group by d.id_last, d.DecisionDate, d.DealDateBegin, d.DealSumBegin,ValueTotalAmount, d.DealCurrencyTag, d.[DealCurrencyKoef]	
	 order by 1,2,3,4

	create index i1 on #buro_deal(id_last, dealdatebegin,DealSumBegin, DealCurrencyTag)
	create index i2 on #buro_hist_prep(id_last, dealdatebegin,DealSumBegin, DealCurrencyTag)

	 -- select top 10 * from sppr.[dbo].[ScoreBuro_InfoDeal]
	 -- select count(*) from #buro_deal  
	 -- select 1519106-1515604

	  update #buro_deal  
	 set product=null


	  update b
	 set product = 'Credit card' -- select *--distinct PurposeOfCredit
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where  PurposeOfCredit in ('Кредитная карта','Кредитна картка','Кредитна карта')
	--and Bureau='UBKI'
	and product is null

	 update b
	 set product = 'Mortage/Car' -- select *
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where  PurposeOfCredit in ('Автокредит','Придбання автомобіля','Кредитний договір на придбання автомобіля','Іпотечний кредит','Ипотечный кредит', 'Придбання житлової нерухомості','Обеспеченная ссуда','Придбання житлової нерухомості (квартира, будинок)','Договір лізингу')
	and product is null

	 update b
	 set product = 'PIL/CSF' -- select  *
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where PurposeOfCredit in ('Договір займу','Кредит готівкою КВІТ','Споживчий кредит','Товары в кредит','Необеспеченная ссуда','Споживчий кредит (товари в кредит)','СПОЖИВЧИЙ','Персональний кредит без забезпечення','Кредитний договір на інші споживчі цілі','Договір товарного кредиту','Он-лайн кредит','Кредитний договір на освіту','Інші споживчі цілі','Кредит на карту','Поповнення поточних активів','Придбання меблів або обладнання','Кредитний договір на поповнення оборотних засобів') 
	and product is null

	  update b
	 set product = 'Credit card' -- select *--distinct TypeOfFounding, PurposeOfCredit
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where  product is null
	and Bureau='PVBKI'
	and TypeOfFounding='credit'


	  update b
	 set product = 'Credit card' -- select *--distinct TypeOfFounding, PurposeOfCredit
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where  product is null
	and Bureau='MBKI'
	and TypeOfFounding='Contract.Type.Financial.Credit_Card_or_renewable_credit'


	update b
	 set product = 'PIL/CSF' -- select *
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where  product is null
	and Bureau='MBKI'
	and TypeOfFounding in ('Contract.Type.Financial.Credit_by_installments')


	 update b
	 set product = 'PIL/CSF' -- select *
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where Bureau='PVBKI'
	and product is null
	and  TypeOfFounding in ('instalment')



	 update b
	 set product = 'PIL/CSF' -- select  *
	 from #buro_deal b
		join risk_test.[dbo].[InfoDeal_from_bureau] d
		on b.id_last=d.id_last and b.dealdatebegin = d.CreditStartDate  and b.ValueTotalAmount=d.ValueTotalAmount and b.DealCurrencyTag=d.CurrencyTotalAmount
	where PurposeOfCredit in ('Інше') 
	and Bureau='UBKI'
	and product is null


	 update #buro_deal
	 set product = 'NotStandart' -- select * from #buro_deal
	where product is null



	 if object_id ('tempdb..#buro_hist') is not null
	 drop table #buro_hist

	 select b.id_last
			, b.DealDateBegin
			, b.DealSumBegin
			, b.DealCurrencyTag
			, b.[DealCurrencyKoef] 
			, MonthIndex01
			, max(isnull(HCResidualAmount,0)) outstanding
			, max(case 
					when isnull(HCUsedAmount,0)<0 then HCUsedAmount*-1 
					else HCUsedAmount end) HCUsedAmount
			, max(case 
					when isnull(HCOverdraft,0)<0 then HCOverdraft*-1 
					else HCOverdraft end) HCOverdraft	
			, max(case 
					when isnull(HCTotalNumberOfOverdueInstalments,0)<0 then HCTotalNumberOfOverdueInstalments*-1 
					else HCTotalNumberOfOverdueInstalments end ) HCTotalNumberOfOverdueInstalments
			, max(case 
					when isnull(HCTotalOverdueAmount,0)<0 then HCTotalOverdueAmount*-1 
					else HCTotalOverdueAmount end )	HCTotalOverdueAmount
			--, max(case 
			--		when isnull(DealClosing,0)<0 then DealClosing*-1 
			--		else DealClosing end)							DealClosing
			, max(h.dpd)	OverdueDuration
	into #buro_hist -- select * 
	  from #buro_deal b
			join #buro_hist_prep h on h.id_last=b.id_last and b.dealdatebegin = h.dealdatebegin  and b.DealSumBegin=h.DealSumBegin and b.DealCurrencyTag=h.DealCurrencyTag
	group by b.id_last
			, b.DealDateBegin
			, b.DealSumBegin
			, b.DealCurrencyTag
			, b.[DealCurrencyKoef] 
			, MonthIndex01
	order by 1,2,3,4,5,6


	 update #buro_deal
	 set  last_date=null

	--- 124112
	 update #buro_deal
	 set  last_date= dat
	from (select h.id_last id
				, h.DealDateBegin dealbegin
				, h.DealSumBegin dealsum
				, h.DealCurrencyTag currency
				, max(MonthIndex01) dat
			from #buro_deal  d
					join #buro_hist h 
					on		d.id_last = h.id_last
						and d.DealDateBegin=h.DealDateBegin 
						and d.DealSumBegin=h.DealSumBegin 
						and d.DealCurrencyTag = h.DealCurrencyTag
			group by h.id_last
				, h.DealDateBegin
				, h.DealSumBegin
				, h.DealCurrencyTag ) c
	where id_last = id
		and DealDateBegin=DealBegin 
		and DealSumBegin=DealSum
		and DealCurrencyTag = Currency

	 if object_id ('tempdb..#req') is not null
	drop table #req

	select id_last
		 , max(cnt_12mnth) cnt_12mnth
		 , max(cnt_9mnth) cnt_9mnth
		 , max(cnt_6mnth) cnt_6mnth
		 , max(cnt_3mnth) cnt_3mnth
		 , max(cnt_1mnth) cnt_1mnth
		 , max(cnt_12mnth_wo_today) cnt_12mnth_wo_today
		 , max(cnt_9mnth_wo_today) cnt_9mnth_wo_today
		 , max(cnt_6mnth_wo_today) cnt_6mnth_wo_today
		 , max(cnt_3mnth_wo_today) cnt_3mnth_wo_today
		 , max(cnt_1mnth_wo_today) cnt_1mnth_wo_today
		 , max(max_req) last_req
	into #req
	from (	select  id_last
				, Bureau--, case when reqDateTime>dateadd(m,-3,convert(date,decisiondate)) then 1 end, *
				, count(case when reqDateTime>(dateadd(m,-12,convert(date,decisiondate))) then 1 end ) cnt_12mnth
				, count(case when reqDateTime>dateadd(m,-9,convert(date,decisiondate)) then 1 end) cnt_9mnth 
				, count(case when reqDateTime>dateadd(m,-6,convert(date,decisiondate)) then 1 end) cnt_6mnth 
				, count(case when reqDateTime>dateadd(m,-3,convert(date,decisiondate)) then 1 end) cnt_3mnth 
				, count(case when reqDateTime>dateadd(m,-1,convert(date,decisiondate)) then 1 end) cnt_1mnth 
				, count(case when reqDateTime>dateadd(m,-12,convert(date,decisiondate)) and reqDateTime<convert(date,decisiondate) then 1 end) cnt_12mnth_wo_today
				, count(case when reqDateTime>dateadd(m,-9,convert(date,decisiondate)) and reqDateTime<convert(date,decisiondate) then 1 end) cnt_9mnth_wo_today
				, count(case when reqDateTime>dateadd(m,-6,convert(date,decisiondate)) and reqDateTime<convert(date,decisiondate) then 1 end) cnt_6mnth_wo_today
				, count(case when reqDateTime>dateadd(m,-3,convert(date,decisiondate)) and reqDateTime<convert(date,decisiondate) then 1 end) cnt_3mnth_wo_today
				, count(case when reqDateTime>dateadd(m,-1,convert(date,decisiondate)) and reqDateTime<convert(date,decisiondate) then 1 end) cnt_1mnth_wo_today
				, max(reqDateTime) max_req
			from [risk_test].[dbo].InfoInquiryDate_from_bureau
			where case 
					when Bureau in ('UBKI','MBKI') then 1 
					when Bureau in ('PVBKI') and reqType='request' then 1 
					else 0 end=1
			group by id_last
				, Bureau) c
		group by id_last
	order by 1
	-- select * from #req

	 if object_id ('tempdb..#phone_list') is not null
	 drop table #phone_list

	select distinct l.id_order
		 , isnull(s.Information_Contact_Information_Mobile_phone_number, f.Information_Contact_Information_Mobile_phone_number) Information_Contact_Information_Mobile_phone_number
		 , isnull(s.Information_Permanent_Address_Phone_number, f.Registration_address_Phone_number) Information_Permanent_Address_Phone_number
		 , isnull(s.Information_Contact_Address_Phone_number, f.Residing_address_Phone_number) Information_Contact_Address_Phone_number
		-- , convert(int, null) reg
		-- , convert(int, null) mob
	into #phone_list -- select top 100 *
	from #list l
		left join sppr.dbo.InfoBasic_from_SLOLP s on l.id_order=s.id_order
		left join sppr.dbo.InfoBasic_from_front f on l.id_order=f.id_order

	-- select * from [risk_test].[dbo].[InfoContact_from_bureau] where id_last=9164146 
	 if object_id ('tempdb..#prep_phone') is not null
		drop table #prep_phone

	select id_order, Information_Contact_Information_Mobile_phone_number
		, Information_Permanent_Address_Phone_number
		, Information_Contact_Address_Phone_number
		, pre_phone
		, case 
			when len(pre_phone)=10 and substring(pre_phone,1,1)='0' then pre_phone
			when len(pre_phone)=11 and substring(pre_phone,1,1)='8' then substring(pre_phone,2,10)
			when len(pre_phone)=12 and substring(pre_phone,1,2)='38' then substring(pre_phone,3,10)
			when len(pre_phone)=14 and substring(pre_phone,1,2)='00' then substring(pre_phone,5,10)
			else null end fin_phone
		, Bureau
		, Name
	into #prep_phone
	from (
		select  *, replace(replace(replace(replace(replace(phone,'+',''),'-',''),')',''),'(',''),' ','') as pre_phone
		from #phone_list p
			left join [risk_test].[dbo].[InfoContact_from_bureau] c on p.id_order = c.id_last and Name<>'Електронна адреса' and Name<>'Електрона адреса') c
	order by 1

	update p
	set fin_phone=NULL -- select *
	from #prep_phone p
	where substring(fin_phone,1,1)<>'0'


	update #prep_phone
	set fin_phone=NULL
	where  fin_phone like '%1111111%' 
		or fin_phone like '%2222222%' 
		or fin_phone like '%0000000%' 
		or fin_phone like '%3333333%' 
		or fin_phone like '%4444444%' 
		or fin_phone like '%5555555%' 
		or fin_phone like '%6666666%' 
		or fin_phone like '%7777777%' 
		or fin_phone like '%8888888%' 
		or fin_phone like '%9999999%' 
		or fin_phone like '%123456789%' 
		or fin_phone like '%987654321%'
	-- select distinct name from #prep_phone where fin_phone like '%1111111%'
	-- select * from #prep_phone where id_order=6679391

	 if object_id ('tempdb..#phone') is not null
	 drop table #phone
	select id_order
		 , mob
		 , case when home1>home2 then home1 else home2 end home
		 , mob_wo_UBKI
		 , case when home1_wo_UBKI>home2_wo_UBKI then home1_wo_UBKI else home2_wo_UBKI end home_wo_UBKI
		 , mob_buro
		 ,  mob_buro_wo_UBKI
	into #phone
	from (
	select id_order
		, max(case when Information_Contact_Information_Mobile_phone_number=fin_phone and name in ('Телефонний номер - мобільний','Мобільний телефон') then 1 else 0 end) mob
		, max(case when Information_Contact_Information_Mobile_phone_number=fin_phone and name in ('Телефонний номер - мобільний','Мобільний телефон') and Bureau<>'UBKI' then 1 else 0 end) mob_wo_UBKI
		, max(case 
				when Information_Permanent_Address_Phone_number='' then -1
				when fin_phone is null then -1
				when Information_Permanent_Address_Phone_number=fin_phone and name in ('Інший','Домашній телефон','Телефонний номер - домашній') then 1 else 0 end) home1
		, max(case 
				when Information_Permanent_Address_Phone_number='' then -1
				when fin_phone is null then -1
				when Information_Permanent_Address_Phone_number=fin_phone and Bureau<>'UBKI' and name in ('Інший','Домашній телефон','Телефонний номер - домашній') then 1 else 0 end) home1_wo_UBKI
		, max(case 
				when Information_Contact_Address_Phone_number='' then -1
				when fin_phone is null then -1
				when Information_Contact_Address_Phone_number=fin_phone and name in ('Інший','Домашній телефон','Телефонний номер - домашній') then 1 else 0 end) home2
		, max(case 
				when Information_Contact_Address_Phone_number='' then -1
				when fin_phone is null then -1
				when Information_Contact_Address_Phone_number=fin_phone and Bureau<>'UBKI' and name in ('Інший','Домашній телефон','Телефонний номер - домашній') then 1 else 0 end) home2_wo_UBKI
		, count( distinct case when name in ('Телефонний номер - мобільний','Мобільний телефон') then fin_phone end) mob_buro
		, count( distinct case when name in ('Телефонний номер - мобільний','Мобільний телефон') and Bureau<>'UBKI' then fin_phone end) mob_buro_wo_UBKI
	from #prep_phone
	group by id_order) c
	order by 1


	 if object_id ('tempdb..#buro_hist_max') is not null
	drop table #buro_hist_max

	select h.id_last
		 , h.DealDateBegin
		 , h.DealSumBegin
		 , h.DealCurrencyTag
		 , product
		 , max(isnull(OverdueDuration,0)) max_dpd_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(OverdueDuration,0) end) max_dpd_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(OverdueDuration,0) end) max_dpd_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(OverdueDuration,0) end) max_dpd_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(OverdueDuration,0) end) max_dpd_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(OverdueDuration,0) end) max_dpd_current

		 , max(isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) ) max_dpd_amnt_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_dpd_amnt_current
	into #buro_hist_max
	from #buro_deal  d
		join #buro_hist h 
			on		d.id_last = h.id_last
				and d.DealDateBegin=h.DealDateBegin 
				and d.DealSumBegin=h.DealSumBegin 
				and d.DealCurrencyTag = h.DealCurrencyTag
	--where d.id_last=10899180
	group by h.id_last
		 , h.DealDateBegin
		 , h.DealSumBegin
		 , h.DealCurrencyTag
		 , product

	 if object_id ('tempdb..#id_hist') is not null
	 drop table #id_hist

	select d.id_last
		 , max(isnull(OverdueDuration,0)) max_dpd_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(OverdueDuration,0) end) max_dpd_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(OverdueDuration,0) end) max_dpd_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(OverdueDuration,0) end) max_dpd_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(OverdueDuration,0) end) max_dpd_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(OverdueDuration,0) end) max_dpd_current

		 , max(isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) ) max_dpd_amnt_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_dpd_amnt_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_dpd_amnt_current

		 , sum(case when datediff(m, MonthIndex01, DecisionDate)<=1 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) sum_dpd_amnt_current

		 , max(case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end) max_dpd_amnt_x_beginamnt_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 then case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end   end) max_dpd_amnt_x_beginamnt_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 then case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end   end) max_dpd_amnt_x_beginamnt_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 then case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end   end) max_dpd_amnt_x_beginamnt_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 then case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end   end) max_dpd_amnt_x_beginamnt_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then case when isnull(HCTotalOverdueAmount,0) =0 then 0 when isnull(d.DealSumBegin,0) =0 then -2  else (isnull(HCTotalOverdueAmount,0)/isnull(d.DealSumBegin,0))*100 end   end) max_dpd_amnt_x_beginamnt_current

		 , max(case when isnull(OverdueDuration,0)=max_dpd_ever then HCTotalOverdueAmount end) max_out_on_max_dpd_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(OverdueDuration,0)=max_dpd_12mnth  then HCTotalOverdueAmount end) max_out_on_max_dpd_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(OverdueDuration,0)=max_dpd_9mnth  then HCTotalOverdueAmount end) max_out_on_max_dpd_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(OverdueDuration,0)=max_dpd_6mnth  then HCTotalOverdueAmount end) max_out_on_max_dpd_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(OverdueDuration,0)=max_dpd_3mnth  then HCTotalOverdueAmount end) max_out_on_max_dpd_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(OverdueDuration,0)=max_dpd_current  then HCTotalOverdueAmount end) max_out_on_max_dpd_current

		 , max(case when isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_ever then isnull(OverdueDuration,0) end) max_dpd_on_max_out_ever 
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_12mnth  then isnull(OverdueDuration,0) end) max_dpd_on_max_out_12mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_9mnth  then isnull(OverdueDuration,0) end) max_dpd_on_max_out_9mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_6mnth  then isnull(OverdueDuration,0) end) max_dpd_on_max_out_6mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_3mnth then isnull(OverdueDuration,0) end) max_dpd_on_max_out_3mnth
		 , max(case when datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_current then isnull(OverdueDuration,0) end) max_dpd_on_max_out_current

		 -- CC
		 , max(case when d.product='Credit card' then OverdueDuration end) max_cc_dpd_ever 
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(OverdueDuration,0) end) max_cc_dpd_12mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(OverdueDuration,0) end) max_cc_dpd_9mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(OverdueDuration,0) end) max_cc_dpd_6mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(OverdueDuration,0) end) max_cc_dpd_3mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(OverdueDuration,0) end) max_cc_dpd_current

		 , max(case when d.product='Credit card' then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_cc_dpd_amnt_ever 
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0)  end) max_cc_dpd_amnt_12mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_cc_dpd_amnt_9mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_cc_dpd_amnt_6mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_cc_dpd_amnt_3mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_cc_dpd_amnt_current

		 , sum(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) sum_cc_dpd_amnt_current

		 , max(case when d.product='Credit card' then case 
														when outstanding is null then -3 
														when outstanding=0 then 0 
														when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
														else isnull(outstanding,0)/isnull(d.DealSumBegin,0)*100 end  end) max_cc_usage_ever 
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12
						 then case 
									when outstanding is null then -3 
									when outstanding=0 then 0 
									when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
									else (outstanding /isnull(d.DealSumBegin,0))*100 end   end) max_cc_usage_12mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9
						 then case 
									when outstanding is null then -3 
									when outstanding=0 then 0 
									when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
									else (outstanding/isnull(d.DealSumBegin,0))*100 end   end) max_cc_usage_9mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 
						 then case 
									when outstanding is null then -3 
									when outstanding=0 then 0 
									when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
									else (outstanding/isnull(d.DealSumBegin,0))*100 end   end) max_cc_usage_6mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 
						then case 
									when outstanding is null then -3 
									when outstanding=0 then 0 
									when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
									else (outstanding/isnull(d.DealSumBegin,0))*100 end   end) max_cc_usage_3mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date 
						then case 
									when outstanding is null then -3 
									when outstanding=0 then 0 
									when isnull(d.DealSumBegin,0) =0 and isnull(outstanding,0) <>0 then -2 
									else (outstanding/isnull(d.DealSumBegin,0))*100 end   end) max_cc_uase_current

		 , max(case when d.product='Credit card' and isnull(OverdueDuration,0)=max_dpd_ever then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_ever 
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(OverdueDuration,0)=max_dpd_12mnth  then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_12mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(OverdueDuration,0)=max_dpd_9mnth  then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_9mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(OverdueDuration,0)=max_dpd_6mnth  then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_6mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(OverdueDuration,0)=max_dpd_3mnth  then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_3mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(OverdueDuration,0)=max_dpd_current  then HCTotalOverdueAmount end) max_CC_out_on_max_dpd_current

		 , max(case when d.product='Credit card' and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_ever then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_ever 
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_12mnth  then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_12mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_9mnth  then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_9mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_6mnth  then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_6mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_3mnth then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_3mnth
		 , max(case when d.product='Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_current then isnull(OverdueDuration,0) end) max_CC_dpd_on_max_out_current


		 ---PIL/CSF
		 , max(case when d.product='PIL/CSF' then OverdueDuration end) max_inst_dpd_ever 
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(OverdueDuration,0) end) max_inst_dpd_12mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(OverdueDuration,0) end) max_inst_dpd_9mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(OverdueDuration,0) end) max_inst_dpd_6mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(OverdueDuration,0) end) max_inst_dpd_3mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(OverdueDuration,0) end) max_inst_dpd_current

		 , max(case when d.product='PIL/CSF' then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_ever 
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_12mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_9mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_6mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_3mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_current

		 , sum(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) sum_inst_dpd_amnt_current

		 , max(case when d.product='PIL/CSF' and isnull(OverdueDuration,0)=max_dpd_ever then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_ever 
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(OverdueDuration,0)=max_dpd_12mnth  then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_12mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(OverdueDuration,0)=max_dpd_9mnth  then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_9mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(OverdueDuration,0)=max_dpd_6mnth  then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_6mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(OverdueDuration,0)=max_dpd_3mnth  then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_3mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(OverdueDuration,0)=max_dpd_current  then HCTotalOverdueAmount end) max_inst_out_on_max_dpd_current

		 , max(case when d.product='PIL/CSF' and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_ever then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_ever 
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=12 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_12mnth  then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_12mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=9 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_9mnth  then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_9mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=6 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_6mnth  then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_6mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=3 and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_3mnth then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_3mnth
		 , max(case when d.product='PIL/CSF' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date and isnull(HCTotalOverdueAmount,0)=max_dpd_amnt_current then isnull(OverdueDuration,0) end) max_inst_dpd_on_max_out_current

	 		 --wo CC
		 , max(case when d.product<>'Credit card' then OverdueDuration end) max_dpd_ever_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(OverdueDuration,0) end) max_inst_dpd_12mnth_wo_CC 	 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(OverdueDuration,0) end) max_inst_dpd_9mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(OverdueDuration,0) end) max_inst_dpd_6mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(OverdueDuration,0) end) max_inst_dpd_3mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(OverdueDuration,0) end) max_inst_dpd_current_wo_CC 
	
		 , max(case when d.product<>'Credit card' then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_ever_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=12 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_12mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=9 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_9mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=6 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_6mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=3 then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_3mnth_wo_CC 
		 , max(case when d.product<>'Credit card' and datediff(m, MonthIndex01, DecisionDate)<=1 and MonthIndex01=Last_date then isnull(HCTotalOverdueAmount,0)* isnull(h.DealCurrencyKoef,0) end) max_inst_dpd_amnt_current_wo_CC 

	into #id_hist --select *
	from #buro_deal  d
		join #buro_hist h 
			on		d.id_last = h.id_last
				and d.DealDateBegin=h.DealDateBegin 
				and d.DealSumBegin=h.DealSumBegin 
				and d.DealCurrencyTag = h.DealCurrencyTag
		left join #buro_hist_max m 
			on		d.id_last = m.id_last
				and d.DealDateBegin=m.DealDateBegin 
				and d.DealSumBegin=m.DealSumBegin 
				and d.DealCurrencyTag = m.DealCurrencyTag

	--where d.id_last=10899180
	group by d.id_last 

	 if object_id ('tempdb..#pre_param') is not null
	drop table #pre_param

	select l.id_order
		 , l.target_60max12m
		 , l.[target_30+3MOB] target_30MOB30
		 , l.sample_type
		 , client_type
		 , isnull(InUse,0) InUse 
		 , l.date_insert appl_date
		 , l.AmountBeginUAH
	--	 , c.Requested_loan_Monthly_payment
		 , min(DealDateBegin) fdeal
		 , max(DealDateBegin) ldeal
		 , min(case when product='Credit card' then DealDateBegin end) fdeal_CC
		 , max(case when product='Credit card' then DealDateBegin end) ldeal_CC
		 , min(case when product='PIL/CSF' then DealDateBegin end) fdeal_PIL
		 , max(case when product='PIL/CSF' then DealDateBegin end) ldeal_PIL
		 , count(b.id_last) cnt
		 , count(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 then b.id_last end) cnt_12mnth
		 , sum(isnull(b.op,0)) cnt_open
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 then isnull(b.op,0) end) cnt_open_12mnth
		 , max(case when op=0 then DealSumBegin else 0 end) max_closedamount
		 , max(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and op=0 then DealSumBegin else 0 end) max_closedamount_12mnth
		 , sum(case when op=0 then DealSumBegin else 0 end) sum_closedamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and op=0 then DealSumBegin else 0 end) sum_closedamount_12mnth
		 , sum(case when op=1 then DealSumBegin else 0 end) sum_openbeginamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and op=1 then DealSumBegin else 0 end) sum_openbeginamount_12mnth
		 , sum(case when op=1 then outst else 0 end) Sum_OpenOutAmount
		 , sum(case when op=1 then pay else 0 end) Sum_OpenPay
		 , sum(case when op=1 then dpd_amnt else 0 end) SUM_dpd_amnt
		 --- CC
		 , max(case when product='Credit card' and op=0 then DealSumBegin else 0 end) max_CC_closedamount
		 , max(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='Credit card' and op=0 then DealSumBegin else 0 end) max_CC_closedamount_12mnth
		 , sum(case when product='Credit card' and op=0 then DealSumBegin else 0 end) sum_CC_closedamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='Credit card' and op=0 then DealSumBegin else 0 end) sum_CC_closedamount_12mnth
		 , sum(case when product='Credit card' and op=1 then DealSumBegin else 0 end) sum_CC_openbeginamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='Credit card' and op=1 then DealSumBegin else 0 end) sum_CC_openbeginamount_12mnth
		 , sum(case when product='Credit card' and op=1 then outst else 0 end) Sum_CC_OpenOutAmount
		 , sum(case when product='Credit card' and op=1 then pay else 0 end) Sum_CC_OpenPay
		 , sum(case when product='Credit card' and op=1 then dpd_amnt else 0 end) SUM_CC_dpd_amnt
		 --- PIL/CSF
		 , max(case when product='PIL/CSF' and op=0 then DealSumBegin else 0 end) max_PIL_CSF_closedamount
		 , max(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='PIL/CSF' and op=0 then DealSumBegin else 0 end) max_PIL_CSF_closedamount_12mnth
		 , sum(case when product='PIL/CSF' and op=0 then DealSumBegin else 0 end) sum_PIL_CSF_closedamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='PIL/CSF' and op=0 then DealSumBegin else 0 end) sum_PIL_CSF_closedamount_12mnth
		 , sum(case when product='PIL/CSF' and op=1 then DealSumBegin else 0 end) sum_PIL_CSF_openbeginamount
		 , sum(case when datediff(m, DealDateBegin, b.DecisionDate)<=12 and product='PIL/CSF' and op=1 then DealSumBegin else 0 end) sum_PIL_CSF_openbeginamount_12mnth
		 , sum(case when product='PIL/CSF' and op=1 then outst else 0 end) Sum_PIL_CSF_OpenOutAmount
		 , sum(case when product='PIL/CSF' and op=1 then pay else 0 end) Sum_PIL_CSF_OpenPay
		 , sum(case when product='PIL/CSF' and op=1 then dpd_amnt else 0 end) SUM_PIL_CSF_dpd_amnt
		 , max(dpd) max_dpd_current
		 , sum(dpd_amnt) sum_dpd_amnt_current

		 , max(case when product='Mortage/Car' then 1 else 0 end) IsMortage

	into #pre_param -- select *
	from #list l
	--	join [SPPR].[dbo].[InfoBasic_from_CSENSE] c on l.id_order=c.id_order
		left join #buro_deal b on l.id_order = b.id_last
		join (select id_last, max(InUse) InUse from #id group by id_last)  i on l.id_order = i.id_last
	--	join #phone p on l.id_order=p.id_order
	--	left join #id_hist h on l.id_order=h.id_last
	--where b.id_last=6459948
	group by l.id_order
		 , client_type
		 , l.date_insert
		 , l.AmountBeginUAH
		 , l.[target_30+3MOB]
	--	 , c.Requested_loan_Monthly_payment
		 , l.target_60max12m
		 , l.sample_type 
		 , isnull(InUse,0)
		 order by 1


	update #pre_param
	set inuse=2 
	where fdeal is null
	and inuse=1

	 if object_id ('tempdb..#buro_hist_cnt') is not null
	 drop table #buro_hist_cnt

	select id_last
		, max(cnt_overdueamount) cnt_overdueamount
		, max(cnt_overdueamount_12mnth) cnt_overdueamount_12mnth
		, max(cnt_overdueamount_9mnth) cnt_overdueamount_9mnth
		, max(cnt_overdueamount_6mnth) cnt_overdueamount_6mnth
		, max(cnt_overdueamount_3mnth) cnt_overdueamount_3mnth
		, max(case when product='PIL/CSF' then cnt_overdueamount end) cnt_overdueamount_PIL
		, max(case when product='PIL/CSF' then cnt_overdueamount_12mnth end) cnt_overdueamount_12mnth_PIL
		, max(case when product='PIL/CSF' then cnt_overdueamount_9mnth end) cnt_overdueamount_9mnth_PIL
		, max(case when product='PIL/CSF' then cnt_overdueamount_6mnth end) cnt_overdueamount_6mnth_PIL
		, max(case when product='PIL/CSF' then cnt_overdueamount_3mnth end) cnt_overdueamount_3mnth_PIL
		, max(case when product='Credit card' then cnt_overdueamount end) cnt_overdueamount_CC
		, max(case when product='Credit card' then cnt_overdueamount_12mnth end) cnt_overdueamount_12mnth_CC
		, max(case when product='Credit card' then cnt_overdueamount_9mnth end) cnt_overdueamount_9mnth_CC
		, max(case when product='Credit card' then cnt_overdueamount_6mnth end) cnt_overdueamount_6mnth_CC
		, max(case when product='Credit card' then cnt_overdueamount_3mnth end) cnt_overdueamount_3mnth_CC
	into #buro_hist_cnt
	from (
			select h.id_last
				,  h.DealDateBegin
				,  h.DealSumBegin
				,  h.DealCurrencyTag
				,  h.DealCurrencyKoef
				,  product
				,  count(case when HCTotalOverdueAmount>0 then 1 end) cnt_overdueamount
				,  count(case when HCTotalOverdueAmount>0 and datediff(m, MonthIndex01, DecisionDate)<=12 then 1 end) cnt_overdueamount_12mnth
				,  count(case when HCTotalOverdueAmount>0 and datediff(m, MonthIndex01, DecisionDate)<=9 then 1 end) cnt_overdueamount_9mnth
				,  count(case when HCTotalOverdueAmount>0 and datediff(m, MonthIndex01, DecisionDate)<=6 then 1 end) cnt_overdueamount_6mnth
				,  count(case when HCTotalOverdueAmount>0 and datediff(m, MonthIndex01, DecisionDate)<=3 then 1 end) cnt_overdueamount_3mnth
			from #buro_deal  d
				join #buro_hist h 
					on		d.id_last = h.id_last
						and d.DealDateBegin=h.DealDateBegin 
						and d.DealSumBegin=h.DealSumBegin 
						and d.DealCurrencyTag = h.DealCurrencyTag
			--where d.id_last=6459948
			group by  h.id_last
				,  h.DealDateBegin
				,  h.DealSumBegin
				,  h.DealCurrencyTag
				,  h.DealCurrencyKoef
				,  product) c
	group by id_last


	-- по выдачам
	drop table Risk_test.dbo.Scoring_DataMart_CC_bureau
	select	distinct
			p.id_order
			/*, client_type
			, target_60max12m target_BG1
			, null--case when target_30MOB30 = 'good' then 1 else 0 end 
			target_BG2
			, sample_type*/
	--		, InUse
			, case when p.fdeal is NULL then -1 else convert(int,datediff(d, p.fdeal, appl_date)) end days_from_first_loan
			, case when p.ldeal is NULL then -1 else convert(int,datediff(d, p.ldeal, appl_date)) end days_from_last_loan
			, case when isnull(p.fdeal,p.ldeal) is NULL then -1 else convert(int,datediff(d, p.fdeal, p.ldeal)) end days_from_first_to_last_loan
			, case when p.fdeal_CC is NULL then -1 else convert(int,datediff(d, p.fdeal_CC, appl_date)) end days_from_first_CC
			, case when p.ldeal_CC is NULL then -1 else convert(int,datediff(d, p.ldeal_CC, appl_date)) end days_from_last_CC
			, case when isnull(p.fdeal_CC,p.ldeal_CC) is NULL then -1 else convert(int,datediff(d, p.fdeal_CC, p.ldeal_CC)) end days_from_first_to_last_CC
			, case when p.fdeal_PIL is NULL then -1 else convert(int,datediff(d, p.fdeal_PIL, appl_date)) end days_from_first_PIL
			, case when p.ldeal_PIL is NULL then -1 else convert(int,datediff(d, p.ldeal_PIL, appl_date)) end days_from_last_PIL
			, case when isnull(p.fdeal_PIL,p.ldeal_PIL) is NULL then -1 else convert(int,datediff(d, p.fdeal_PIL, p.ldeal_PIL)) end days_from_first_to_last_PIL

			-- количество обращений
			, case when r.cnt_12mnth is NULL then -1 else convert(int,r.cnt_12mnth) end cnt_12mnth
			, case when r.cnt_9mnth is NULL then -1 else convert(int,r.cnt_9mnth) end cnt_9mnth
			, case when r.cnt_6mnth is NULL then -1 else convert(int,r.cnt_6mnth) end cnt_6mnth
			, case when r.cnt_3mnth is NULL then -1 else convert(int,r.cnt_3mnth) end cnt_3mnth
			, case when r.cnt_1mnth is NULL then -1 else convert(int,r.cnt_1mnth) end cnt_1mnth
			, case when r.cnt_12mnth_wo_today is NULL then -1 else convert(int,r.cnt_12mnth_wo_today) end cnt_12mnth_wo_today
			, case when r.cnt_9mnth_wo_today is NULL then -1 else convert(int,r.cnt_9mnth_wo_today) end cnt_9mnth_wo_today
			, case when r.cnt_6mnth_wo_today is NULL then -1 else convert(int,r.cnt_6mnth_wo_today) end cnt_6mnth_wo_today
			, case when r.cnt_3mnth_wo_today is NULL then -1 else convert(int,r.cnt_3mnth_wo_today) end cnt_3mnth_wo_today
			, case when r.cnt_1mnth_wo_today is NULL then -1 else convert(int,r.cnt_1mnth_wo_today) end cnt_1mnth_wo_today

			-- маркер успешности
			, case when cnt_3mnth>0 and datediff(d, p.ldeal, appl_date)<90 then 1 else 0 end champ

			, isnull(convert(int,p.cnt),-1) cnt_loans
			, isnull(convert(int,p.cnt_12mnth),-1) cnt_loans_last_12mnth
			, isnull(convert(int,p.cnt_open),-1) cnt_open_loans
			, isnull(convert(int,p.cnt_open_12mnth),-1) cnt_open_loans_last_12mnth
			, isnull(convert(numeric(18,0),p.max_closedamount),-1) max_closedamount
			, isnull(convert(numeric(18,0),p.max_closedamount_12mnth),-1) max_closedamount_last_12mnth
			, isnull(convert(numeric(18,0),p.sum_closedamount),-1) sum_closedamount
			, isnull(convert(numeric(18,0),p.sum_closedamount_12mnth),-1) sum_closedamount_last_12mnth
		
			, isnull(convert(numeric(18,0),p.sum_openbeginamount),-1) sum_openbeginamount
			, isnull(convert(numeric(18,0),p.sum_openbeginamount_12mnth),-1) sum_openbeginamount_last_12mnth
			, isnull(convert(numeric(18,0),p.Sum_OpenOutAmount),-1) Sum_OpenOutAmount

			, convert(numeric(18,2),case 
				when p.sum_openbeginamount = 0 then -1 
				else (p.Sum_OpenOutAmount/p.sum_openbeginamount)*100 end) Sum_OpenOutAmount_x_sum_openbeginamount

			, isnull(convert(numeric(18,0), p.max_CC_closedamount),-1) max_CC_closedamount
			, isnull(convert(numeric(18,0),p.max_CC_closedamount_12mnth),-1) max_CC_closedamount_last_12mnth
			, isnull(convert(numeric(18,0),p.sum_CC_openbeginamount),-1) sum_CC_openbeginamount
			, isnull(convert(numeric(18,0),p.sum_CC_openbeginamount_12mnth),-1) sum_CC_openbeginamount_last_12mnth
			, isnull(convert(numeric(18,0),p.Sum_CC_OpenOutAmount),-1) Sum_CC_OpenOutAmount

			, convert(numeric(18,2),case 
				when p.sum_CC_openbeginamount = 0 then -1 
				else (p.Sum_CC_OpenOutAmount/p.sum_CC_openbeginamount)*100 end) Sum_CC_OpenOutAmount_x_sum_CC_openbeginamount

			, isnull(convert(numeric(18,0),p.max_PIL_CSF_closedamount),-1) max_PIL_CSF_closedamount
			, isnull(convert(numeric(18,0),p.max_PIL_CSF_closedamount_12mnth),-1) max_PIL_CSF_closedamount_last_12mnth
			, isnull(convert(numeric(18,0),p.sum_PIL_CSF_closedamount),-1) sum_PIL_CSF_closedamount
			, isnull(convert(numeric(18,0),p.sum_PIL_CSF_closedamount_12mnth),-1) sum_PIL_CSF_closedamount_last_12mnth

			, isnull(convert(numeric(18,0),p.sum_PIL_CSF_openbeginamount),-1) sum_PIL_CSF_openbeginamount	
			, isnull(convert(numeric(18,0),p.sum_PIL_CSF_openbeginamount_12mnth),-1) sum_PIL_CSF_openbeginamount_last_12mnth
			, isnull(convert(numeric(18,0),p.Sum_PIL_CSF_OpenOutAmount),-1) Sum_PIL_CSF_OpenOutAmount

			, convert(numeric(18,2),case 
				when p.sum_PIL_CSF_openbeginamount = 0 then -1 
				else (p.Sum_PIL_CSF_OpenOutAmount/p.sum_PIL_CSF_openbeginamount)*100 end) Sum_PIL_CSF_OpenOutAmount_x_sum_PIL_CSF_openbeginamount
			--
			, case when p.max_dpd_current is NULL then -1 else convert(numeric(18,0),p.max_dpd_current) end max_current_dpd_total

			--, case when sum_dpd_amnt_current is NULL then -1 else sum_dpd_amnt_current end max_current_dpd_amnt_total	
			-- Historical payments	
			, case when h.max_dpd_ever is NULL then -1 else convert(numeric(18,0),h.max_dpd_ever) end max_dpd_ever
			, case when h.max_dpd_12mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_12mnth) end max_dpd_12mnth
			, case when h.max_dpd_9mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_9mnth) end max_dpd_9mnth
			, case when h.max_dpd_6mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_6mnth) end max_dpd_6mnth
			, case when h.max_dpd_3mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_3mnth) end max_dpd_3mnth	
			, case when h.max_dpd_current is NULL then -1 else convert(numeric(18,0),h.max_dpd_current) end max_dpd_current	

			, case when h.max_dpd_amnt_ever is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_ever) end max_dpd_amnt_ever	
			, case when h.max_dpd_amnt_12mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_12mnth) end max_dpd_amnt_12mnth
			, case when h.max_dpd_amnt_9mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_9mnth) end max_dpd_amnt_9mnth		
			, case when h.max_dpd_amnt_6mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_6mnth) end max_dpd_amnt_6mnth	
			, case when h.max_dpd_amnt_3mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_3mnth) end max_dpd_amnt_3mnth	
			, case when h.max_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_current) end max_dpd_amnt_current
			
			, case when h.sum_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.max_dpd_amnt_current) end sum_dpd_amnt_current	

			, case when h.max_dpd_amnt_x_beginamnt_ever is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_ever) end max_dpd_amnt_x_beginamnt_ever	
			, case when h.max_dpd_amnt_x_beginamnt_12mnth is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_12mnth) end max_dpd_amnt_x_beginamnt_12mnth	
			, case when h.max_dpd_amnt_x_beginamnt_9mnth is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_9mnth) end max_dpd_amnt_x_beginamnt_9mnth
			, case when h.max_dpd_amnt_x_beginamnt_6mnth is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_6mnth) end max_dpd_amnt_x_beginamnt_6mnth	
			, case when h.max_dpd_amnt_x_beginamnt_3mnth is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_3mnth) end max_dpd_amnt_x_beginamnt_3mnth	
			, case when h.max_dpd_amnt_x_beginamnt_current is NULL then -1 else convert(numeric(18,2),h.max_dpd_amnt_x_beginamnt_current) end max_dpd_amnt_x_beginamnt_current	

			, case when h.max_out_on_max_dpd_ever is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_ever) end max_out_on_max_dpd_ever	
			, case when h.max_out_on_max_dpd_12mnth is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_12mnth) end max_out_on_max_dpd_12mnth	
			, case when h.max_out_on_max_dpd_9mnth is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_9mnth) end max_out_on_max_dpd_9mnth
			, case when h.max_out_on_max_dpd_6mnth is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_6mnth) end max_out_on_max_dpd_6mnth	
			, case when h.max_out_on_max_dpd_3mnth is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_3mnth) end max_out_on_max_dpd_3mnth	
			, case when h.max_out_on_max_dpd_current is NULL then -1 else convert(numeric(18,0),h.max_out_on_max_dpd_current) end max_out_on_max_dpd_current	

			, case when h.max_dpd_on_max_out_ever is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_ever) end max_dpd_on_max_out_ever	
			, case when h.max_dpd_on_max_out_12mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_12mnth) end max_dpd_on_max_out_12mnth	
			, case when h.max_dpd_on_max_out_9mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_9mnth) end max_dpd_on_max_out_9mnth
			, case when h.max_dpd_on_max_out_6mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_6mnth) end max_dpd_on_max_out_6mnth	
			, case when h.max_dpd_on_max_out_3mnth is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_3mnth) end max_dpd_on_max_out_3mnth	
			, case when h.max_dpd_on_max_out_current is NULL then -1 else convert(numeric(18,0),h.max_dpd_on_max_out_current) end max_dpd_on_max_out_current

			, case when h.max_cc_dpd_ever is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_ever) end max_cc_dpd_ever	
			, case when h.max_cc_dpd_12mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_12mnth) end max_cc_dpd_12mnth	
			, case when h.max_cc_dpd_9mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_9mnth) end max_cc_dpd_9mnth
			, case when h.max_cc_dpd_6mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_6mnth) end max_cc_dpd_6mnth	
			, case when h.max_cc_dpd_3mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_3mnth) end max_cc_dpd_3mnth	
			, case when h.max_cc_dpd_current is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_current) end max_cc_dpd_current	

			, case when h.max_cc_dpd_amnt_ever is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_ever) end max_cc_dpd_amnt_ever	
			, case when h.max_cc_dpd_amnt_12mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_12mnth) end max_cc_dpd_amnt_12mnth
			, case when h.max_cc_dpd_amnt_9mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_9mnth) end max_cc_dpd_amnt_9mnth		
			, case when h.max_cc_dpd_amnt_6mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_6mnth) end max_cc_dpd_amnt_6mnth	
			, case when h.max_cc_dpd_amnt_3mnth is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_3mnth) end max_cc_dpd_amnt_3mnth	
			, case when h.max_cc_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.max_cc_dpd_amnt_current) end max_cc_dpd_amnt_current
			
			, case when h.sum_cc_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.sum_cc_dpd_amnt_current) end sum_cc_dpd_amnt_current	

			, case when h.max_cc_usage_ever is NULL then -1 else convert(numeric(18,2),h.max_cc_usage_ever) end max_cc_usage_ever	
			, case when h.max_cc_usage_12mnth is NULL then -1 else convert(numeric(18,2),h.max_cc_usage_12mnth) end max_cc_usage_12mnth
			, case when h.max_cc_usage_9mnth is NULL then -1 else convert(numeric(18,2),h.max_cc_usage_9mnth) end max_cc_usage_9mnth	
			, case when h.max_cc_usage_6mnth is NULL then -1 else convert(numeric(18,2),h.max_cc_usage_6mnth) end max_cc_usage_6mnth	
			, case when h.max_cc_usage_3mnth is NULL then -1 else convert(numeric(18,2),h.max_cc_usage_3mnth) end max_cc_usage_3mnth	
			, case when h.max_cc_uase_current is NULL then -1 else convert(numeric(18,2),h.max_cc_uase_current) end max_cc_uase_current	

			, case when h.max_CC_out_on_max_dpd_ever is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_ever) end max_CC_out_on_max_dpd_ever	
			, case when h.max_CC_out_on_max_dpd_12mnth is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_12mnth) end max_CC_out_on_max_dpd_12mnth
			, case when h.max_CC_out_on_max_dpd_9mnth is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_9mnth) end max_CC_out_on_max_dpd_9mnth	
			, case when h.max_CC_out_on_max_dpd_6mnth is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_6mnth) end max_CC_out_on_max_dpd_6mnth	
			, case when h.max_CC_out_on_max_dpd_3mnth is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_3mnth) end max_CC_out_on_max_dpd_3mnth	
			, case when h.max_CC_out_on_max_dpd_current is NULL then -1 else convert(numeric(18,2),h.max_CC_out_on_max_dpd_current) end max_CC_out_on_max_dpd_current	

			, case when h.max_CC_dpd_on_max_out_ever is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_ever) end max_CC_dpd_on_max_out_ever	
			, case when h.max_CC_dpd_on_max_out_12mnth is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_12mnth) end max_CC_dpd_on_max_out_12mnth
			, case when h.max_CC_dpd_on_max_out_9mnth is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_9mnth) end max_CC_dpd_on_max_out_9mnth	
			, case when h.max_CC_dpd_on_max_out_6mnth is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_6mnth) end max_CC_dpd_on_max_out_6mnth	
			, case when h.max_CC_dpd_on_max_out_3mnth is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_3mnth) end max_CC_dpd_on_max_out_3mnth	
			, case when h.max_CC_dpd_on_max_out_current is NULL then -1 else convert(numeric(18,0),h.max_CC_dpd_on_max_out_current) end max_CC_dpd_on_max_out_current	

			, case when h.max_inst_dpd_ever is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_ever) end max_inst_dpd_ever	
			, case when h.max_inst_dpd_12mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_12mnth) end max_inst_dpd_12mnth
			, case when h.max_inst_dpd_9mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_9mnth) end max_inst_dpd_9mnth	
			, case when h.max_inst_dpd_6mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_6mnth) end max_inst_dpd_6mnth	
			, case when h.max_inst_dpd_3mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_3mnth) end max_inst_dpd_3mnth	
			, case when h.max_inst_dpd_current is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_current) end max_inst_dpd_current	

			, case when h.max_inst_dpd_amnt_ever is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_ever) end max_inst_dpd_amnt_ever	
			, case when h.max_inst_dpd_amnt_12mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_12mnth) end max_inst_dpd_amnt_12mnth	
			, case when h.max_inst_dpd_amnt_9mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_9mnth) end max_inst_dpd_amnt_9mnth
			, case when h.max_inst_dpd_amnt_6mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_6mnth) end max_inst_dpd_amnt_6mnth	
			, case when h.max_inst_dpd_amnt_3mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_3mnth) end max_inst_dpd_amnt_3mnth	
			, case when h.max_inst_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_current) end max_inst_dpd_amnt_current

			, case when h.sum_inst_dpd_amnt_current is NULL then -1 else convert(numeric(18,0),h.sum_inst_dpd_amnt_current) end sum_inst_dpd_amnt_current

			, case when h.max_inst_out_on_max_dpd_ever is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_ever) end max_inst_out_on_max_dpd_ever	
			, case when h.max_inst_out_on_max_dpd_12mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_12mnth) end max_inst_out_on_max_dpd_12mnth	
			, case when h.max_inst_out_on_max_dpd_9mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_9mnth) end max_inst_out_on_max_dpd_9mnth
			, case when h.max_inst_out_on_max_dpd_6mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_6mnth) end max_inst_out_on_max_dpd_6mnth	
			, case when h.max_inst_out_on_max_dpd_3mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_3mnth) end max_inst_out_on_max_dpd_3mnth	
			, case when h.max_inst_out_on_max_dpd_current is NULL then -1 else convert(numeric(18,0),h.max_inst_out_on_max_dpd_current) end max_inst_out_on_max_dpd_current

			, case when h.max_inst_dpd_on_max_out_ever is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_ever) end max_inst_dpd_on_max_out_ever	
			, case when h.max_inst_dpd_on_max_out_12mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_12mnth) end max_inst_dpd_on_max_out_12mnth	
			, case when h.max_inst_dpd_on_max_out_9mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_9mnth) end max_inst_dpd_on_max_out_9mnth
			, case when h.max_inst_dpd_on_max_out_6mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_6mnth) end max_inst_dpd_on_max_out_6mnth	
			, case when h.max_inst_dpd_on_max_out_3mnth is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_3mnth) end max_inst_dpd_on_max_out_3mnth	
			, case when h.max_inst_dpd_on_max_out_current is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_on_max_out_current) end max_inst_dpd_on_max_out_current

			, case when h.max_dpd_ever_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_dpd_ever_wo_CC) end max_dpd_ever_wo_CC
			, case when h.max_inst_dpd_12mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_12mnth_wo_CC) end max_inst_dpd_12mnth_wo_CC
			, case when h.max_inst_dpd_9mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_9mnth_wo_CC) end max_inst_dpd_9mnth_wo_CC		
			, case when h.max_inst_dpd_6mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_6mnth_wo_CC) end max_inst_dpd_6mnth_wo_CC	
			, case when h.max_inst_dpd_3mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_3mnth_wo_CC) end max_inst_dpd_3mnth_wo_CC	
			, case when h.max_inst_dpd_current_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_current_wo_CC) end max_inst_dpd_current_wo_CC	

			, case when h.max_inst_dpd_amnt_ever_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_ever_wo_CC) end max_inst_dpd_amnt_ever_wo_CC	
			, case when h.max_inst_dpd_amnt_12mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_12mnth_wo_CC) end max_inst_dpd_amnt_12mnth_wo_CC
			, case when h.max_inst_dpd_amnt_9mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_9mnth_wo_CC) end max_inst_dpd_amnt_9mnth_wo_CC	
			, case when h.max_inst_dpd_amnt_6mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_6mnth_wo_CC) end max_inst_dpd_amnt_6mnth_wo_CC	
			, case when h.max_inst_dpd_amnt_3mnth_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_3mnth_wo_CC) end max_inst_dpd_amnt_3mnth_wo_CC	
			, case when h.max_inst_dpd_amnt_current_wo_CC is NULL then -1 else convert(numeric(18,0),h.max_inst_dpd_amnt_current_wo_CC) end max_inst_dpd_amnt_current_wo_CC
			, isnull(p.IsMortage,-1) has_mortage
			-- мобильный

			, isnull(c.cnt_overdueamount,-1) cnt_overdueamount
			, isnull(c.cnt_overdueamount_12mnth,-1) cnt_overdueamount_12mnth
			, isnull(c.cnt_overdueamount_9mnth,-1) cnt_overdueamount_9mnth
			, isnull(c.cnt_overdueamount_6mnth,-1) cnt_overdueamount_6mnth
			, isnull(c.cnt_overdueamount_3mnth,-1) cnt_overdueamount_3mnth
			, isnull(c.cnt_overdueamount_PIL,-1) cnt_overdueamount_PIL
			, isnull(c.cnt_overdueamount_12mnth_PIL,-1) cnt_overdueamount_12mnth_PIL
			, isnull(c.cnt_overdueamount_9mnth_PIL,-1) cnt_overdueamount_9mnth_PIL
			, isnull(c.cnt_overdueamount_6mnth_PIL,-1) cnt_overdueamount_6mnth_PIL
			, isnull(c.cnt_overdueamount_3mnth_PIL,-1) cnt_overdueamount_3mnth_PIL
			, isnull(c.cnt_overdueamount_CC,-1) cnt_overdueamount_CC
			, isnull(c.cnt_overdueamount_12mnth_CC,-1) cnt_overdueamount_12mnth_CC
			, isnull(c.cnt_overdueamount_9mnth_CC,-1) cnt_overdueamount_9mnth_CC
			, isnull(c.cnt_overdueamount_6mnth_CC,-1) cnt_overdueamount_6mnth_CC
			, isnull(c.cnt_overdueamount_3mnth_CC,-1) cnt_overdueamount_3mnth_CC
			, isnull(ph.mob_buro,-1) mob_buro
			, isnull(ph.mob_buro_wo_UBKI,-1) mob_buro_wo_UBKI
			, isnull(ph.mob,-1) mob
			, isnull(ph.mob_wo_UBKI,-1) mob_wo_UBKI
	into Risk_test.dbo.Scoring_DataMart_CC_bureau -- финальная таблица с данными по бюро -- select top 100 *
	from #pre_param p
		left join #phone ph on p.id_order = ph.id_order
		left join #id_hist h on h.id_last = p.id_order
		left join #req r on r.id_last = p.id_order
		left join #buro_hist_cnt c on c.id_last=p.id_order

-- select top 100 * from Risk_test.dbo.Scoring_DataMart_CC_bureau

END
