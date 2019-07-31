USE [Portfolio]
GO
/****** Object:  StoredProcedure [dbo].[NBU_class_calculation]    Script Date: 31.07.2019 14:29:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Olena Sokol
-- Create date: 2018-10-02
-- =============================================
ALTER PROCEDURE  [dbo].[NBU_class_calculation] 
	
AS
BEGIN

	SET NOCOUNT ON;

	--1. проверяем наличие всех данных по зарплатам;
	--2. проверяем наличие свежих данных;
	--3. наличие залитых данных в B2;
	--4. наличие всех рассчитанных данных в B2.

	if  (select convert(date, max(realdate)) from rpa.dbo.doc_provodki where month(realdate)= (month(getdate())-1)) = 
		  (select eomonth(dateadd(m, -1,getdate())))   
	      and (select top 1 RDATE from
	      openquery(BIPROD,'select * from dwhstaging.v_guarantee_class_tmp'))  = (select eomonth(dateadd(m, -1,getdate())))
          and (select top 1 eomonth(iputdate)  from openquery(B2ORACLE, 'select * from NBU_Class_from_SAS'))<>(select eomonth(getdate()))
		  and (select *  from openquery(B2ORACLE, 'select count(*) from NBU_Class_from_SAS')) = 
		  (select count(*) from Portfolio.dbo.NBU_class where ReportDate = (select max(convert(date, ReportDate)) from Portfolio.dbo.NBU_class))

	BEGIN

		-----------відправка попередження на пошту------------------------------------------------------------------------------------
		declare @subje as varchar(50)
		declare @body_text as varchar(100)
		set @subje = 'Расчет финансовых классов' 
		set @body_text = 'Внимание!
	Процедура была запущена и начат расчет фин классов.'
                                                                                                                                            
		EXECUTE msdb.dbo.sp_send_dbmail
			@profile_name = 'Fin_Class_Calculation'
			,@recipients = 'Nataliya.Nachos@alfabank.kiev.ua; Aleksandr.Yaroschuk@alfabank.kiev.ua; Nikolay.Dekhtievskiy@alfabank.kiev.ua'  
			,@copy_recipients = ''
			,@blind_copy_recipients = ''
			,@subject = @subje
			,@body= @body_text

		-- забираем данные из Б2
		truncate table Portfolio.dbo.NBU_portfolio_from_B2

		insert into Portfolio.dbo.NBU_portfolio_from_B2
		select * 
		from openquery(BIPROD,'select * from dwhstaging.v_guarantee_class_tmp') 

		--select count(*) from Portfolio.dbo.NBU_portfolio_from_B2
		--select top 100 * from Portfolio.dbo.NBU_portfolio_from_B2

		--проверяем наличие свежих данных, если их нет провоцируем ошибку
		if (select distinct Rdate from Portfolio.dbo.NBU_portfolio_from_B2) <> (select eomonth(dateadd(m, -1,getdate())))
			drop table Portfolio.dbo.NBU_no_data_on_end_of_month
		
		--группируем данные по сделке и маркируем сделки на карты и не карты
		--drop table #NBU_portfolio_2
		select contragentid, 
			identifycode INN, 
			loandealid, 
			dealno as dealno_b2,
			dpd as dpd_b2,
			sum(amounteq_loan) as sum_dolg
		into #NBU_portfolio_2
		from Portfolio.dbo.NBU_portfolio_from_B2
		group by contragentid, 
			identifycode, 
			loandealid,
			dealno,
			dpd
		--select * from #NBU_portfolio_2 where sum_dolg=0

		--собираем данные по кредитам
		declare @LA_reportdate as date
		declare @CC_reportdate as date

		set @LA_reportdate= (select max(reportdate) from Archives.dbo.dwh_BalanceByDeals where reportdate < dateadd(d,1,eomonth(dateadd(m, -1,getdate()))))
		set @CC_reportdate= (select max(reportdate) from rpa.dbo.pqr_daily where reportdate < dateadd(d,1,eomonth(dateadd(m, -1,getdate()))))

		--select  @LA_reportdate,@CC_reportdate
	
		---НЕКАРТКОВІ КРЕДИТИ-----------------------------------
		--drop table #pqr_la 
		SELECT dealid, 
			dpd, 
			bucket
		into #pqr_la
		FROM [Archives ].[dbo].[dwh_BalanceByDeals]
		where reportdate = @LA_reportdate

		---drop table #NBU_portfolio_3_la
		select s.*, 
			f.dealno, 
			f.dealid, 
			f.PortfolioType
		into #NBU_portfolio_3_la
		from #NBU_portfolio_2 s
			left join b2.dbo.dwh_la as f on s.LOANDEALID=f.DEALID

		--drop table #NBU_portfolio_4_la
		select s.*, 
			f.dpd, 
			f.bucket, 
			credit_source = 'LA'
		into #NBU_portfolio_4_la
		from #NBU_portfolio_3_la s
			left join #pqr_la as f on s.LOANDEALID=f.DEALID
		--select * from #NBU_portfolio_4_la

		--КАРТКОВІ КРЕДИТИ------------------------------------------------

		--drop table #NBU_portfolio_3_CC
		select s.*, 
			f.LEGALCONTRACTNUM, 
			f.contractid, 
			f.CLIM, 
			f.ACCSTATUSID, 
			f.addparamvaluename
		into #NBU_portfolio_3_CC
		from #NBU_portfolio_2 s
			left join rpa.dbo.v_contracts as f on f.IDENTCODE=s.inn

		--drop table #NBU_portfolio_3_2_CC
		select s.*
		into #NBU_portfolio_3_2_CC
		from #NBU_portfolio_3_CC s
		where rtrim(s.LEGALCONTRACTNUM) <> '' and charindex(rtrim(s.LEGALCONTRACTNUM),dealno_b2)>0
		--select * from #NBU_portfolio_3_2_CC

		--drop table #pqr_сс --select * from #pqr_сс
		SELECT b.legalcontractnum, 
			a.dpd, 
			a.bucket
		into #pqr_сс
		FROM RPA.dbo.PQR_DAILY as a
			join RPA.dbo.V_Contracts as b on a.contractid=b.contractid
		where reportdate =@CC_reportdate

		--drop table  #NBU_portfolio_4_CC
		select s.*,
			p.dpd,
			p.bucket, 
			credit_source = 'CC'
		into #NBU_portfolio_4_CC
		from #NBU_portfolio_3_2_CC s
			 left join #pqr_сс p on s.LEGALCONTRACTNUM=p.LEGALCONTRACTNUM
		--select * from #NBU_portfolio_4_CC

		----формуємо єдину таблицю по всім продуктам-------------------------------------------------------------------------		
		--drop table #NBU_portfolio_4
		select contragentid, 
			INN,
			loandealid,
			dealno_b2,
			dpd_b2,	
			sum_dolg,
			dpd, 
			contractid as dealid,
			LEGALCONTRACTNUM as dealno,
			credit_source
		into #NBU_portfolio_4
		from #NBU_portfolio_4_CC
					union all
		select contragentid, 
			INN,
			loandealid,
			dealno_b2,
			dpd_b2,	
			sum_dolg,
			dpd, 
			dealid,
			dealno,
			credit_source
		from #NBU_portfolio_4_la
		--select top 10000 * from #NBU_portfolio_4 where credit_source = 'CC' order by 3,9 desc

		--drop table #Dolg
		select distinct  
			n.contragentid, 
			n.INN, 
			sum(n.sum_dolg) sum_dolg
		into #Dolg
		from #NBU_portfolio_2 n 
		group by n.contragentid, n.INN  

		--drop table #Dolg_dpd
		select distinct  
			n.contragentid, 
			n.INN, 
			n.sum_dolg,
			m.dpd dpd
		into #Dolg_dpd
		from #Dolg n 
		left join 
			(select t.contragentid contragentid,
				max(t.dpd) dpd
			from #NBU_portfolio_4 t
			group by t.contragentid
			)m on n.CONTRAGENTID=m.contragentid      

 --ормуємо ZP для кожного ИНН-------------------------------------------------

declare @Max_zp_date as date
declare @Min_zp_date as date

set @Max_zp_date = (select eomonth(max(realdate)) from rpa.dbo.doc_provodki where month(realdate)= (month(getdate())-1))
set @Min_zp_date = (select eomonth(dateadd(m, -6, @Max_zp_date)))

--select @Min_zp_date, @Max_zp_date

	 --drop table #ABU_salary1
		select distinct c.IDENTCODE inn, sum(tc.rate*p.tramt) as salary
		into #ABU_salary1
		from rpa.dbo.doc_provodki p
					join rpa.dbo.V_Contracts c on c.CONTRACTID=p.contractid
					left join rpa.dbo.TCCYRATES tc on tc.OPERDATE=p.operdate and tc.CCYFROM=p.trccy and tc.CCYTO like 'UAH'
				where p.realdate > @Min_zp_date
					and p.realdate <= @Max_zp_date
					and transid in (9035,9029,4391,30003)
					and c.IDENTCODE not in ('9999999999','0000000000', '')
			        and c.IDENTCODE is not null
					and p.description ='Приход' 
         group by c.IDENTCODE
		 having sum(tc.rate*p.tramt)>0


		 --drop table #ABU_salary2
		select distinct c.IDENTCODE inn, 
		                sum(tc.rate*p.tramt) as salary
		into #ABU_salary2
		from Cards_admin.dbo.cc_provodki p
					join rpa.dbo.V_Contracts c on c.CONTRACTID=p.contractid
					left join rpa.dbo.TCCYRATES tc on tc.OPERDATE=p.operdate and tc.CCYFROM=p.trccy and tc.CCYTO like 'UAH'
				where p.realdate >= @Min_zp_date
					and p.realdate < @Max_zp_date
					and transid in (9035,9029,4391,30003)
					and c.IDENTCODE not in ('9999999999','0000000000', '')
			        and c.IDENTCODE is not null
					and p.description ='Приход' 
         group by c.IDENTCODE
		 having sum(tc.rate*p.tramt)>0

		--drop table #ABU_salary
		select * 
		into #ABU_salary
		from #ABU_salary2
		union 	
		select * from #ABU_salary1


	  --UCB_salary--------------------------------------------
	  --drop table #UCB_salary
--drop table #USB_salary1
	select inn,
			        case when eomonth(dateadd(m, -1, reportdate)) >= @Min_zp_date then isnull(ZP_last_1M, 0) else 0 end ZP_last_1M,
					case when eomonth(dateadd(m, -2, reportdate)) >= @Min_zp_date then isnull(ZP_last_2M, 0) else 0 end ZP_last_2M,
					case when eomonth(dateadd(m, -3, reportdate)) >= @Min_zp_date then isnull(ZP_last_3M, 0) else 0 end ZP_last_3M,
					case when eomonth(dateadd(m, -4, reportdate)) >= @Min_zp_date then isnull(ZP_last_4M, 0) else 0 end ZP_last_4M,
					case when eomonth(dateadd(m, -5, reportdate)) >= @Min_zp_date then isnull(ZP_last_5M, 0) else 0 end ZP_last_5M,
					case when eomonth(dateadd(m, -6, reportdate)) >= @Min_zp_date then isnull(ZP_last_6M, 0) else 0 end ZP_last_6M
    into #USB_salary1
			from  [dhazardbp01\hazard].predata.[dbo].[UCB_PI_Customers_predate]
			where  inn not in ('9999999999','0000000000')
			and (isnull(case when eomonth(dateadd(m, -1, reportdate)) >= @Min_zp_date then isnull(ZP_last_1M, 0) else 0 end, 0)!=0 or
			     isnull(case when eomonth(dateadd(m, -2, reportdate)) >= @Min_zp_date then isnull(ZP_last_2M, 0) else 0 end, 0)!=0 or
				 isnull(case when eomonth(dateadd(m, -3, reportdate)) >= @Min_zp_date then isnull(ZP_last_3M, 0) else 0 end, 0)!=0 or
				 isnull(case when eomonth(dateadd(m, -4, reportdate)) >= @Min_zp_date then isnull(ZP_last_4M, 0) else 0 end, 0)!=0 or
				 isnull(case when eomonth(dateadd(m, -5, reportdate)) >= @Min_zp_date then isnull(ZP_last_5M, 0) else 0 end, 0)!=0 or
				 isnull(case when eomonth(dateadd(m, -6, reportdate)) >= @Min_zp_date then isnull(ZP_last_6M, 0) else 0 end, 0)!=0)
	
--drop table #UCB_salary
		select t.inn,
			round(sum(t.val),2) salary 
		into #UCB_salary
		from 
			(select inn,
				val 
			from #USB_salary1
			unpivot (val for col in ( ZP_last_1M
									  , ZP_last_2M
									  , ZP_last_3M
									  , ZP_last_4M
									  , ZP_last_5M 
									  , ZP_last_6M)) up)t
	   group by t.inn


		--Cумуємо зарплатню по UCB та ABU по кожному INN
		--drop table #income
		select t.INN,
			sum(t.salary)/6 avg_salary
		into #income
		from
			(select inn, salary from #UCB_salary
				union all
				select inn, salary from #ABU_salary)t
		group by t.INN


		------шукаємо платежі по кожному inn-----------------------------------------------------------------------------------------------------------
		--drop table #Deal_pay
		select 
			ROW_NUMBER() over(partition by dealno order by arcdate asc) rn
			,*
			,(telo+proce+comis) as pay 
		into #Deal_pay
		from openquery(b2oracle, 'select c.IDENTIFYCODE as inn
											, d.dealno
											, cr.CURRENCYID
											, sch.ARCDATE
											, sch.STATUS
											, sch.PRINCIPALAMOUNT/100 as telo
											, sch.INTERESTAMOUNT/100 as proce
											, sch.FEEAMOUNT/100 as comis
											, sch.RESTPRINCIPALAMOUNT/100 as rest	
										from creator.contragent c
											join creator.Deal d on c.id=d.CONTRAGENTID
											left join creator.Dealannuityschedule sch on d.id=sch.dealid and sch.arcdate>TRUNC(SYSDATE-31) and sch.arcdate<TRUNC(SYSDATE+31)
											left join 
												(select d.dealno, dc.CURRENCYID
												from creator.Deal d
												join creator.DEALCOMMERCIALLOAN dc on d.id=dc.DEALID
												where dc.CURRENCYID is not null
												/*and d.dealno = ''800000007''*/
												) cr on d.dealno = cr.dealno
					where
					/*c.iDENTIFYCODE=''2217802161''
					and */
					sch.DEALID is not null
					') 
		where STATUS = 0
		--select * from #Deal_pay

		--drop table #Deal_pay_uah 
		select p.inn
			,p.dealno 
			,l.dealid
			,case 
				when p.currencyid is null then pay 
				else round(convert(money,pay)*c.CrossRateUAH,2) 
			end PayUAH
		into #Deal_pay_uah 
		from #Deal_pay p
			left join [B2].[dbo].[CrossRates] c on p.CURRENCYID=c.CurrencyCode and c.DateRate=(select max(daterate) from [B2].[dbo].[CrossRates])
			left join b2.dbo.dwh_La l on p.dealno=l.dealno

		--drop table #Deal_pay_uah_2
		select inn
			,dealno 
			,dealid
			,max(PayUAH) as PayUAH 
		into #Deal_pay_uah_2 
		from #Deal_pay_uah  
		group by Inn, dealno, dealid
		having max(PayUAH) > 0 
		--select * from #Deal_pay_uah_2 where inn='3044100659'
		--select dealid, count(*) from #Deal_pay_uah_2 group by dealid having count(*)>2

		--declare @LA_reportdate as date set @LA_reportdate= (select max(reportdate) from Archives.dbo.dwh_BalanceByDeals where reportdate < dateadd(d,1,eomonth(dateadd(m, -1,getdate()))))

		--drop table #add_deals
		select v.IDENTIFYCODE as inn,
			v.dealno,
			v.dealid,
			b.principalUAH,
			coalesce(w.interestrate,0) as interestrate,
			case when datediff(month, b.reportdate, v.EXPECTEDCLOSEDATE) <= 0 then 1 else datediff(month, b.reportdate, v.EXPECTEDCLOSEDATE) end as term
		into #add_deals
		from b2.dbo.i_vintage as v 
			left join b2.dbo.dwh_la as w on v.dealid = w.dealid
			left join #Deal_pay_uah_2 as d on v.dealno = d.dealno
			left join archives.dbo.dwh_balancebydeals b on v.dealid = b.dealid and b.reportdate = @LA_reportdate
		where d.dealno is null 
			and coalesce(b.outstandingUah, 0) > 0
			and v.CLOSEDATE is null
			and (b.principalUAH + b.past_principalUAH + b.InterestUah + b.past_interestUAH)>0
		
		--drop table #Deal_pay_uah_add
		select inn,
			dealno,
			dealid,
			--term,
			--interestrate,
			--principalUAH,
			payUAH = case when interestrate = 0 then principalUAH/term
				else principalUAH*(interestrate*1.0/1200) * power(1+interestrate*1.0/1200, term)/(power(1+interestrate*1.0/1200, term)-1)  
				end
		into #Deal_pay_uah_add
		from #add_deals
		--select * from #Deal_pay_uah_add where inn  ='3044100659'

		/* --drop table #kv_nbu_dti
		select convert(char(10),inn) as identifycode
				 ,round(Total_Income*dti,2) as Payment
		into  #kv_nbu_dti		
		from [dhazardbp01\hazard].sppr.dbo.InfoBasic_from_NBSM_OUT 
			where id_iteration in (select max(id_iteration) from [dhazardbp01\hazard].sppr.dbo.InfoBasic_from_NBSM_OUT where id_order>0 and dti is not null group by inn)
					   and inn not in (0,9999999999) 
	
		select * from b2.dbo.i_vintage as v 
				left join b2.dbo.dcl_woff as w on v.dealid = w.dealid
				left join #p1 as p on p.dealid = v.dealid
			where closedate is null and w.dealid is null
			and p.dealid is null
			and outyest is not null*/

		--drop table #CC_pay_uah
		select v.identcode inn
			,v.legalcontractnum dealno 
			,v.contractid dealid
			,PayUAH = case 
				when coalesce(v.clim,0) = 0 and subgroup_new = 'CC_A_Club' then coalesce(t.yest_outstending,0)*0.1 
				when coalesce(v.clim,0) = 0 then coalesce(t.yest_outstending,0)*0.05 
				when subgroup_new = 'CC_A_Club' then v.clim*0.1 
				else v.clim*0.05 end  
		into #CC_pay_uah 
		from rpa.dbo.v_contracts as v
			left join cards.dbo.FPD_MOB2_MOB3_MOB6 as t on v.contractid = t.contractid  
		where (coalesce(v.clim, 0 )+coalesce(t.yest_outstending,0))>0
			and v.identcode is not null
		--select * from #CC_pay_uah 

		--drop table #payment_by_deals
		select * 
		into #payment_by_deals
		from #Deal_pay_uah_2
			union all
		select * from #Deal_pay_uah_add
			union all
		select * from #CC_pay_uah
	
		--select * from #payment_by_deals where dealno is null

		--drop table #payment
		select t.inn, 
			sum(t.PayUAH) as Payment 
		into #payment						
		from #payment_by_deals t
		group by t.inn
		--select * from #payment	where inn  ='3044100659'

		-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		-----до таблиці #Sum_dolg (об'єднуємо дані по клієнтам) додаємо ще payment та income-------
		--select * from #Inc_pay
		--drop table #Inc_pay
		select u.*,
			i.avg_salary inc,
			p.Payment Payment 
		into #Inc_pay
		from #Dolg_dpd u
			left join #income i on u.inn=i.inn
			left join #payment p on u.inn=p.inn

		-----вигружаємо дані для звіту---------------------------
		--drop table #Class_score
		select distinct t.CONTRAGENTID CONTRAGENTID
			,t.inn 
			,class = case 
				when t.inc2=0 then 5
				when t.dpd1<=7 and t.dti<0.5 then 1
				when t.dpd1<=30 and t.dti<0.6 then 2
				when t.dpd1<=60 and t.dti<0.7 then 3
				when t.dpd1<=90 and t.dti<0.8 then 4
				else 5 end 
			,t.dti dti
			,t.inc2 inc
			,t.Payment
			,t.dpd1 dpd
			,t.sum_dolg
			,DPD_DTI_Score = case 
				when t.inc2=0 then 0
				when t.dpd1<=7 and t.dti<0.5 then 2648
				when t.dpd1<=30 and t.dti<0.6 then 1986
				when t.dpd1<=60 and t.dti<0.7 then 1324
				when t.dpd1<=90 and t.dti<0.8 then 662
				else 0 end 
		into #Class_score
		from
			(select *,
				case when inc is not null and inc<>0 and Payment is not null and Payment<>0 then Payment/inc 
					 else 0 end dti
				,case when inc is null then 0 else inc end inc2
				,case when dpd is null then 0 else dpd end dpd1
			from #Inc_pay) t
		--select * from #Class_score

		--drop table Portfolio.dbo.NBU_class
		--select * into Portfolio.dbo.NBU_class_prev from Portfolio.dbo.NBU_class
		insert into Portfolio.dbo.NBU_class
		select convert(varchar,getdate(),106) ReportDate
			 ,CONTRAGENTID
			,INN 
			,Class
			,[Parameters] = 'Income='+convert(varchar(100), format(inc,'G'))+
							';Payment='+ convert(varchar(100), round(isnull(payment,0),2))+
							';DTI='+convert(varchar(100),round(dti,2))+
							';DPD='+convert(varchar(10),dpd)+
							';Sum_dolg='+convert(varchar(100),format(sum_dolg,'G'))+';'
			,Score = 'DTI_DPD='+convert(varchar(10),DPD_DTI_Score)+';'
		--into Portfolio.dbo.NBU_class
		from #Class_score
	
		--select * from Portfolio.dbo.NBU_class where class <> 5 and convert(float,substring([Parameters], charindex('Sum_dolg=',[Parameters])+len('Sum_dolg='), charindex(';',[Parameters], charindex('Sum_dolg=',[Parameters]))-charindex('Sum_dolg=',[Parameters])-len('Sum_dolg='))) <- 300000
		--select * from Portfolio.dbo.NBU_class where inn = '3044100659'
		--select Parameters, convert(float,substring([Parameters], charindex('Sum_dolg=',[Parameters])+len('Sum_dolg='), charindex(';',[Parameters], charindex('Sum_dolg=',[Parameters]))-charindex('Sum_dolg=',[Parameters])-len('Sum_dolg='))) from Portfolio.dbo.NBU_class
	
	--select count(*) from Portfolio.dbo.NBU_class where reportdate='08 Jan 2019'
	--select reportdate, class, count(*) from Portfolio.dbo.NBU_class where class=1 group by reportdate, class


		--створюємо таблицю із класами за останній місяць (для заливки в Б2)
		--drop table #NBU_clas_to_B2
	   		select 
			CONTRAGENTID
			, class
			,'' note
			,ReportDate 
			, '1' as calctype
			,ROW_NUMBER() over(order by contragentid desc) rn
		into #NBU_clas_to_B2
		from Portfolio.dbo.NBU_class
		where ReportDate = (select max(convert(date, ReportDate)) from Portfolio.dbo.NBU_class)


		while (select *  from openquery(B2ORACLE, 'select count(*) from NBU_Class_from_SAS' )) >0
		begin 
		   delete openquery(B2ORACLE,
				'select * from NBU_Class_from_SAS where rownum<=1000' )
		end

		declare @i int
		set @i = 0

		while (select *  from openquery(B2ORACLE, 'select count(*) from NBU_Class_from_SAS' )) < (select count(*) from #NBU_clas_to_B2)
		begin 
			insert openquery(B2ORACLE, 'select * from NBU_Class_from_SAS where rownum<1')
				select CONTRAGENTID,	
					class,
					note,	
					reportdate,	
					calctype
				from #NBU_clas_to_B2 t
				where rn >= 1000*@i
					and rn < 1000*(@i+1)

			set @i = @i+1
		end
	
		--select ct, 100*ct/1697558.0  from openquery(B2ORACLE, 'select count(*) as ct from NBU_Class_from_SAS' )
		--select distinct contragentid from Portfolio.dbo.NBU_clas_from_SAS_08 where class<>5
		/*
		select *  from openquery(B2ORACLE,
				'select * from NBU_Class_from_SAS where rownum<=100' )


		delete from openquery(B2ORACLE,
				'select * from NBU_Class_from_SAS' )

		--where month(inputdate)=dateadd(mm,-1,getdate())	
	
		insert into openquery(B2ORACLE,
				'select * from NBU_Class_from_SAS where rownum<1')
				select * from Portfolio.dbo.NBU_clas_from_SAS_08
		 
		*/

		-----------відправка на пошту------------------------------------------------------------------------------------
		declare @subje_1 as varchar(50)
		declare @body_text_1 as varchar(100)
		set @subje_1 = 'Расчет финансовых классов' 
		set @body_text_1 = 'Добрый день!
	Расчет и заливка финансовых классов прошли успешно.'
                                                                                                                                            
		EXECUTE msdb.dbo.sp_send_dbmail
			@profile_name = 'Fin_Class_Calculation'
			,@recipients = 'Alena.Shkolnaya@alfabank.kiev.ua;Elena.Kovalevskaya@alfabank.kiev.ua'  
			,@copy_recipients = 'Aleksandr.Moskalets@alfabank.kiev.ua;Nataliya.Nachos@alfabank.kiev.ua;  Aleksandr.Yaroschuk@alfabank.kiev.ua; Nikolay.Dekhtievskiy@alfabank.kiev.ua'
			,@blind_copy_recipients = ''
			,@subject = @subje_1
			,@body= @body_text_1

	END

    else 

	begin
		
		if (select convert(date, max(realdate)) from rpa.dbo.doc_provodki where month(realdate)= (month(getdate())-1)) <> (select eomonth(dateadd(m, -1,getdate())))
       
	   begin 
			-----------відправка попередження на пошту------------------------------------------------------------------------------------
			declare @subje_2 as varchar(50)
			declare @body_text_2 as varchar(500)
			set @subje_2 = 'Расчет финансовых классов' 
			set @body_text_2 = 'Внимание!
Процедура была запущена, но завершена по причине отсутствия всех данных для расчета.
(в таблицу [rpa.dbo.doc_provodki] залиты не все данные за последний месяц)'
                                                                                                                                            
			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name = 'Fin_Class_Calculation'
				,@recipients = 'Nataliya.Nachos@alfabank.kiev.ua; Aleksandr.Yaroschuk@alfabank.kiev.ua; Nikolay.Dekhtievskiy@alfabank.kiev.ua'  
				,@copy_recipients = ''
				,@blind_copy_recipients = ''
				,@subject = @subje_2
				,@body= @body_text_2
		end




	else 

	begin
		
		if (select top 1 RDATE from
	      openquery(BIPROD,'select * from dwhstaging.v_guarantee_class_tmp'))  <> (select eomonth(dateadd(m, -1,getdate())))
       
	   begin 
			-----------відправка попередження на пошту------------------------------------------------------------------------------------
			declare @subje_3 as varchar(50)
			declare @body_text_3 as varchar(100)
			set @subje_3 = 'Расчет финансовых классов' 
			set @body_text_3 = 'Внимание!
Процедура была запущена, но завершена по причине отсутствия данных в исходной таблице.'
                                                                                                                                            
			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name = 'Fin_Class_Calculation'
				,@recipients = 'Nataliya.Nachos@alfabank.kiev.ua; Aleksandr.Yaroschuk@alfabank.kiev.ua; Nikolay.Dekhtievskiy@alfabank.kiev.ua'  
				,@copy_recipients = ''
				,@blind_copy_recipients = ''
				,@subject = @subje_3
				,@body= @body_text_3
		end


		else

		begin
			-----------відправка попередження на пошту------------------------------------------------------------------------------------
			declare @subje_4 as varchar(50)
			declare @body_text_4 as varchar(100)
			set @subje_4 = 'Расчет финансовых классов' 
			set @body_text_4 = 'Внимание!
Процедура была запущена, но завершена по причине уже проведенного ранее расчета.'
                                                                                                                                            
			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name = 'Fin_Class_Calculation'
				,@recipients = 'Nataliya.Nachos@alfabank.kiev.ua; Aleksandr.Yaroschuk@alfabank.kiev.ua; Nikolay.Dekhtievskiy@alfabank.kiev.ua'  
				,@copy_recipients = ''
				,@blind_copy_recipients = ''
				,@subject = @subje_4
				,@body= @body_text_4
		end

	end

END
end

