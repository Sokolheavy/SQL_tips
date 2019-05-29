select *,
		convert(date, dateadd(d,-1,dateinsert_scoreid)) as date_of_calculation,
		convert(date, dateadd(d,-2,dateinsert_scoreid)) as max_date_in_tables,
		convert(date, dateadd(d,-4,dateinsert_scoreid)) as max_date_in_trans	
	into #Scoring_DataMart_CC_prevcredits
	from risk_test.dbo.Scoring_DataMart_CC_prevcredits t

	--select * from #Scoring_DataMart_CC_prevcredits 

	--drop table #temp1
	select distinct t.*,
		is_open = case 
			when date_of_calculation <= t.datebegin then -1
			when t.closedate is null or t.closedate >= date_of_calculation then 1 
			else 0 end,
		days_from_open = datediff(dd,t.datebegin,date_of_calculation),
		days_from_close = case when t.closedate >= date_of_calculation then null else datediff(dd,t.closedate,date_of_calculation) end
	into #temp1 
	from #Scoring_DataMart_CC_prevcredits t

	drop table #Scoring_DataMart_CC_prevcredits 

	--select * from #temp1 

	--drop table #temp2
	select distinct
		t.*,
		Productgroup = coalesce(v.productgroup, 'CC'),
		AmountbeginUAH = coalesce(v.AmountBeginUAH, f.firstlimit),
		TermOficial = coalesce(datediff(mm, v.datebegin, v.expectedclosedate), 12),
		TermFact = datediff(mm, t.datebegin, t.closedate),
		AmountMaxUAH = v.amountbeginuah,
		FirstDueDate = coalesce(f.FPDDate, dateadd(dd, 1, dateadd(mm, 1, t.datebegin)))
	into #temp2
	from #temp1 t
		left join b2.dbo.i_vintage as v on isnull(t.dealno, '') = isnull(v.dealno, '') and t.dealid = v.dealid 
		left join rpa.dbo.FPD_MOB2_MOB3_MOB6 as f on isnull(t.dealno, '') = isnull(f.legalcontractnum, '') and t.dealid = f.contractid

	drop table #temp1

	--select * from #temp2 where id_order = 5872813

	CREATE INDEX idx_dealid
	ON #temp2  (dealid);

	CREATE INDEX idx_max_date_in_tables
	ON #temp2  (max_date_in_tables);

	CREATE INDEX idx_max_date_in_trans
	ON #temp2  (max_date_in_trans);

	CREATE INDEX idx_date_of_calculation
	ON #temp2  (date_of_calculation);

	CREATE INDEX idx_scoredealid
	ON #temp2  (scoredealid);

	--drop table #CC_temp2
	select distinct id_order,
		dealid,
		datebegin,
		date_of_calculation,
		max_date_in_tables,
		max_date_in_trans,
		FirstDueDate,
		dateadd(mm, -12, t.date_of_calculation) as reportdate_12m,
		dateadd(mm, -6, t.date_of_calculation) as reportdate_6m,
		dateadd(mm, -3, t.date_of_calculation) as reportdate_3m,
		dateadd(mm, -1, t.date_of_calculation) as reportdate_1m
	into #CC_temp2
	from #temp2 t
	where Productgroup = 'CC'

	CREATE INDEX idx_dealid_max_date_in_trans
	ON #CC_temp2  (dealid, max_date_in_trans);

	CREATE INDEX idx_dealid
	ON #CC_temp2  (dealid);

	CREATE INDEX idx_max_date_in_trans
	ON #CC_temp2  (max_date_in_trans);

	CREATE INDEX idx_date_of_calculation
	ON #CC_temp2  (date_of_calculation);

	CREATE INDEX idx_reportdate_12m
	ON #CC_temp2  (reportdate_12m);

	CREATE INDEX idx_reportdate_6m
	ON #CC_temp2  (reportdate_6m);

	CREATE INDEX idx_reportdate_3m
	ON #CC_temp2  (reportdate_3m);

	CREATE INDEX idx_reportdate_1m
	ON #CC_temp2  (reportdate_1m);

	--notcc

	--drop table #notCC_temp2
	select distinct id_order,
		dealid,
		datebegin,
		date_of_calculation,
		max_date_in_tables,
		max_date_in_trans,
		FirstDueDate,
		dateadd(mm, -12, t.date_of_calculation) as reportdate_12m,
		dateadd(mm, -6, t.date_of_calculation) as reportdate_6m,
		dateadd(mm, -3, t.date_of_calculation) as reportdate_3m,
		dateadd(mm, -1, t.date_of_calculation) as reportdate_1m
	into #notCC_temp2
	from #temp2 t
	where Productgroup <> 'CC'

	CREATE INDEX idx_dealid_max_date_in_tables
	ON #notCC_temp2  (dealid, max_date_in_tables);

	CREATE INDEX idx_dealid
	ON #notCC_temp2  (dealid);

	CREATE INDEX idx_max_date_in_tables
	ON #notCC_temp2  (max_date_in_tables);

	CREATE INDEX idx_date_of_calculation
	ON #notCC_temp2  (date_of_calculation);

	CREATE INDEX idx_reportdate_12m
	ON #notCC_temp2  (reportdate_12m);

	CREATE INDEX idx_reportdate_6m
	ON #notCC_temp2  (reportdate_6m);

	CREATE INDEX idx_reportdate_3m
	ON #notCC_temp2  (reportdate_3m);

	CREATE INDEX idx_reportdate_1m
	ON #notCC_temp2  (reportdate_1m);

	--drop table #cc_prev_1
	select t.dealid, 
		t.id_order,
		p.reportdate,
		p.limit_report,
		p.dpd_trash,
		p.outstending,
		max_date_in_trans,
		date_of_calculation,
		reportdate_12m,
		reportdate_6m,
		reportdate_3m,
		reportdate_1m,
		--------
		t.datebegin,
		t.max_date_in_tables,
		t.FirstDueDate,
		p.DatePastDue_new as datepastdue
	into #CC_prev_1
	from rpa.dbo.pqr_daily as p
		join #CC_temp2 as t on t.dealid = p.contractid and p.reportdate <= t.max_date_in_trans

	--drop table #cc_prev
	select distinct * 
	into #cc_prev
	from #CC_prev_1

	drop table #cc_prev_1

	/* select * into risk_test.dbo.NN_cc_prev from #CC_prev*/

	CREATE INDEX idx_dealid
	ON #cc_prev  (dealid);

	CREATE INDEX idx_id_order
	ON #cc_prev  (id_order);

	CREATE INDEX idx_dealid_reportdate
	ON #cc_prev  (dealid, reportdate);

	--select id_order, dealid, count(*) from #cc_temp2 group by id_order, dealid having count(*) >  1
	--select * from #cc_temp2 where id_order = 10856722
	--select * from #cc_prev where id_order = 5872813

	--drop table #cc_max_ever
	select p.dealid, 
		p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null then null when p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_ever
	from #cc_prev p
	group by p.dealid, p.id_order


	--drop table #cc_max_12m
	select p.dealid, 
		p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null then null when p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_12m
	from #cc_prev p
	where reportdate >= reportdate_12m 
	group by p.dealid, p.id_order


	--drop table #cc_max_6m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_6m
	from #cc_prev p
	where reportdate >= reportdate_6m
	group by p.id_order, p.dealid


	--drop table #cc_max_3m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_3m
	from #cc_prev p
	where reportdate >= reportdate_3m
	group by p.id_order, p.dealid


	--drop table #cc_max_1m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_1m
	from #cc_prev p
	where reportdate >= reportdate_1m
	group by p.id_order, p.dealid


	--drop table #cc_current
	select p.dealid, p.id_order,
		max(p.outstending) as cur_out
	into #cc_current
	from #cc_prev p
	where reportdate = convert(date, p.max_date_in_trans)
	group by p.id_order, p.dealid


	--drop table #notcc_prev_1
	select t.dealid, 
		t.id_order,
		p.reportdate,
		p.dpd,
		p.outstandinguah,
		max_date_in_tables,
		date_of_calculation,
		reportdate_12m,
		reportdate_6m,
		reportdate_3m,
		reportdate_1m,
		-----
		t.datebegin,
		FirstDueDate,
		p.DatePastDue
	into #notCC_prev_1
	from archives.dbo.dwh_balancebydeals as p
		join #notCC_temp2 as t on  t.dealid = p.dealid and p.reportdate <= t.max_date_in_tables

	--drop table #notcc_prev
	select distinct * 
	into #notcc_prev
	from #notCC_prev_1

	drop table #notcc_prev_1

	/* select * into risk_test.dbo.NN_notcc_prev from #notCC_prev*/

	CREATE INDEX idx_dealid
	ON #notcc_prev  (dealid);

	CREATE INDEX idx_id_order
	ON #notcc_prev  (id_order);

	CREATE INDEX idx_dealid_reportdate
	ON #notcc_prev  (dealid, reportdate);

	--select * from #notcc_temp2 where id_order = 5872813
	--select * from #notcc_prev_1 where id_order = 5872813
	--select * from #notcc_prev where id_order = 5872813

	--drop table #notcc_max_ever
	select p.dealid, p.id_order,
		max(p.dpd) as max_dpd,
		max(p.outstandinguah) as max_out
	into #notCC_max_ever
	from #notCC_prev p
	group by p.id_order, p.dealid

	--drop table #notcc_max_12m
	select p.dealid, p.id_order,
		max(p.dpd) as max_dpd,
		max(p.outstandinguah) as max_out
	into #notCC_max_12m
	from #notcc_prev p
	where reportdate >= reportdate_12m
	group by p.id_order, p.dealid

	--select * from #notcc_max_12m

	--drop table #notcc_max_6m
	select p.id_order, p.dealid,
		max(p.dpd) as max_dpd,
		max(p.outstandinguah) as max_out
	into #notCC_max_6m
	from #notcc_prev p
	where reportdate >= reportdate_6m
	group by p.id_order, p.dealid

	--drop table #notcc_max_3m
	select p.dealid, p.id_order,
		max(p.dpd) as max_dpd,
		max(p.outstandinguah) as max_out
	into #notCC_max_3m
	from #notcc_prev p
	where reportdate >= reportdate_3m
	group by p.id_order, p.dealid


	--drop table #notcc_max_1m
	select p.dealid, p.id_order,
		max(p.dpd) as max_dpd,
		max(p.outstandinguah) as max_out
	into #notCC_max_1m
	from #notcc_prev p
	where reportdate >= reportdate_1m
	group by p.id_order, p.dealid


	--drop table #notcc_current
	select p.dealid, p.id_order,
		max(p.outstandinguah) as cur_out
	into #notcc_current
	from #notcc_prev p
	where reportdate >= convert(date, p.max_date_in_tables)
	group by p.id_order, p.dealid

	----------------------Month_since_del_more_then----------------------
	--1. знаходимо max reportdate коли dpd>n днів
	--2. знаходимо різницю місяців між reportdate і Checkdate (ф-ія datediff)
       --а). якщо такого reportdate немає, то результат має бути 0. Тобто щоб datediff( reportdate, Checkdate) = 0 треба щоб reportdate=Checkdate, замінимо reportdate на Checkdate за допомогою ф-ії - isnull('case when' повертає 'NULL', якщо не виконується умова).
	   --b). ф-ія datediff 'округлює' значення до більшого, щоб отримати цілу к-сть місяців робимо перевірку 

	--drop table #CC_Month_since_del_more_then
	select t.dealid,
		id_order,
		datediff(m, isnull(max(case when t.dpd_trash>0 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>0 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>0 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_0,

		datediff(m, isnull(max(case when t.dpd_trash>7 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>7 then reportdate end),dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>7 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_7,

		datediff(m, isnull(max(case when t.dpd_trash>15 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>15 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>15 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_15,
	
		datediff(m, isnull(max(case when t.dpd_trash>30 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>30 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>30 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_30,
	
		datediff(m, isnull(max(case when t.dpd_trash>60 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>60 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>60 then reportdate end),dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_60,
	
		datediff(m, isnull(max(case when t.dpd_trash>90 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
			case when dateadd(month, datediff(m, isnull(max(case when t.dpd_trash>90 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd_trash>90 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_90
	into #CC_Month_since_del_more_then
	from #CC_prev t
	group by dealid,
         id_order,
		 date_of_calculation

	--drop table #notcc_Month_since_del_more_then
	select t.dealid,
		id_order,
		datediff(m, isnull(max(case when t.dpd>0 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>0 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>0 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_0,

		datediff(m, isnull(max(case when t.dpd>7 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>7 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>7 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_7,

		datediff(m, isnull(max(case when t.dpd>15 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>15 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>15 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_15,
	
	   datediff(m, isnull(max(case when t.dpd>30 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>30 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>30 then reportdate end),dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_30,
	
	   datediff(m, isnull(max(case when t.dpd>60 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>60 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>60 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_60,
	
	   datediff(m, isnull(max(case when t.dpd>90 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation) - 
		case when dateadd(month, datediff(m, isnull(max(case when t.dpd>90 then reportdate end), dateadd(m, -999, t.date_of_calculation)),  t.date_of_calculation), isnull(max(case when t.dpd>90 then reportdate end), dateadd(m, -999, t.date_of_calculation))) > t.date_of_calculation then 1 else 0 end  Month_since_del_more_then_90

	into #notcc_Month_since_del_more_then
	from #notCC_prev t
	group by t.dealid,
			 id_order,
			 t.date_of_calculation

	--select * from #notcc_temp2 where id_order = 5872813    select * from #notcc_Month_since_del_more_then where id_order = 5872813

	---------------new variable add
	--для знаходження нездійсненого платежу ставимо 2 умови(check_missed_pay):
		   --1. місяць просрочки=місяцю reportdate
		   --2. якщо просрочка "тягнеться" з минулого місяця, тоді DPD більше за кількість днів минулого місяця 
	--ставимо умову, коли було оплачено конкретний платіж, проте просрочка ще залишилася:
		   --1. DPD попереднього дня на дату більше за DPD на дану дату. (у такому випадку ми рахуємо, що платіж здійснено)


	--drop table #cc_preMissed_payment_all
	select t.dealid as contractid, 
			t.id_order,
			t.datebegin,
			t.date_of_calculation,
			max_date_in_tables,
			max_date_in_trans,
			t.FirstDueDate,
			t.reportdate,
			t.datepastdue,
			t.dpd_trash as dpd,
			p2.dpd_trash as dpd_after
	into #cc_preMissed_payment_all
	from #CC_prev as t
		left join rpa.dbo.pqr_daily p2 on t.dealid=p2.contractid and t.reportdate = DATEADD(d, -1, p2.reportdate)

	drop table #CC_prev

	--drop table #cc_preMissed_payment_all_1
	select t.*,
		   case when (dpd > 0) and (dpd is not null) and month(reportdate)=month(DatePastDue) then 1
				when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #cc_preMissed_payment_all_1 
	from #cc_preMissed_payment_all t

	-- select top 100 * from #cc_preMissed_payment_all_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #cc_preMissed_payment_all_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #cc_preMissed_payment_all_5 where contractid = 3906723 and id_order = 10796376  
	select * from #cc_Missed_payment_all where contractid = 3906723 and id_order = 10796376 
	*/

	--drop table #cc_preMissed_payment_all_2
	select contractid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #cc_preMissed_payment_all_2
	from #cc_preMissed_payment_all_1
	group by contractid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #cc_preMissed_payment_all_3
	select contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   max(reportdate) as last_reportdate
    into #cc_preMissed_payment_all_3
	from #cc_preMissed_payment_all_1
	group by contractid,
			 id_order,
			 FirstDueDate,
			 datebegin

	--drop table #cc_preMissed_payment_all_4
	select t.contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   last_reportdate,
		   max(payment_number) as paym_number
    into #cc_preMissed_payment_all_4
	from #cc_preMissed_payment_all_3 as t
		left join Cards.dbo.v_rm_ic_duepayment2 as c on t.last_reportdate >= c.duedate and t.contractid = c.contractid
	group by t.contractid,
			 id_order,
			 datebegin,
			 FirstDueDate,
			last_reportdate

	--drop table #cc_preMissed_payment_all_5
	select contractid,
		   id_order,
		   datebegin,
		   firstduedate,
		   last_reportdate,
		   paym_number,
		   fullpaymentperiods = coalesce(paym_number, datediff(mm, firstduedate, last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #cc_preMissed_payment_all_5
	from #cc_preMissed_payment_all_4 as t


	--drop table #cc_Missed_payment_all
	select t.contractid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #cc_Missed_payment_all
	from #cc_preMissed_payment_all_2 as t 
		left join #cc_preMissed_payment_all_5 as c on t.id_order = c.id_order and t.contractid = c.contractid
	group by  t.contractid,
			 t.id_order,
			 fullpaymentperiods
	
	--select * from #notcc_Missed_payment_all where id_order = 7495817

	-------------------#, %, 12m_Missed_payment
	--drop table #cc_preMissed_payment_12m_1
	select t.*,
			dateadd(mm, -12, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #cc_preMissed_payment_12m_1
	from #cc_preMissed_payment_all t
	where reportdate >= dateadd(mm, -12, t.date_of_calculation)


	--drop table #cc_preMissed_payment_12m_2
	select contractid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #cc_preMissed_payment_12m_2
	from #cc_preMissed_payment_12m_1
	group by contractid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #cc_preMissed_payment_12m_3
	select contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #cc_preMissed_payment_12m_3
	from #cc_preMissed_payment_12m_1
	group by contractid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	--drop table #cc_preMissed_payment_12m_4
	select t.contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   last_reportdate,
		   max(c1.payment_number)-min(c2.payment_number) + 1 as paym_number
    into #cc_preMissed_payment_12m_4
	from #cc_preMissed_payment_12m_3 as t
		left join Cards.dbo.v_rm_ic_duepayment2 as c1 on t.last_reportdate >= c1.duedate and t.contractid = c1.contractid
		left join Cards.dbo.v_rm_ic_duepayment2 as c2 on t.last_reportdate >= c2.duedate and t.contractid = c2.contractid and c2.DUEDATE >= t.from_date
	group by t.contractid,
			 id_order,
			 datebegin,
			 FirstDueDate,
			 from_date,
			last_reportdate

	--drop table #cc_preMissed_payment_12m_5
	select contractid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   paym_number,
		   fullpaymentperiods = coalesce(paym_number, datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #cc_preMissed_payment_12m_5
	from #cc_preMissed_payment_12m_4 as t


	--drop table #cc_Missed_payment_12m
	select t.contractid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #cc_Missed_payment_12m
	from #cc_preMissed_payment_12m_2 as t 
		left join #cc_preMissed_payment_12m_5 as c on t.id_order = c.id_order and t.contractid = c.contractid
	group by  t.contractid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #cc_preMissed_payment_12m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #cc_preMissed_payment_12m_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #cc_preMissed_payment_12m_5 where contractid = 3906723 and id_order = 10796376  
	select * from #cc_Missed_payment_12m where contractid = 3906723 and id_order = 10796376 
	*/

	-------------------#, %, 6m_Missed_payment
	--drop table #cc_preMissed_payment_6m_1
	select t.*,
			dateadd(mm, -6, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #cc_preMissed_payment_6m_1
	from #cc_preMissed_payment_all t
	where reportdate >= dateadd(mm, -6, t.date_of_calculation)


	--drop table #cc_preMissed_payment_6m_2
	select contractid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #cc_preMissed_payment_6m_2
	from #cc_preMissed_payment_6m_1
	group by contractid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #cc_preMissed_payment_6m_3
	select contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #cc_preMissed_payment_6m_3
	from #cc_preMissed_payment_6m_1
	group by contractid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	--drop table #cc_preMissed_payment_6m_4
	select t.contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   last_reportdate,
		   max(c1.payment_number)-min(c2.payment_number) + 1 as paym_number
    into #cc_preMissed_payment_6m_4
	from #cc_preMissed_payment_6m_3 as t
		left join Cards.dbo.v_rm_ic_duepayment2 as c1 on t.last_reportdate >= c1.duedate and t.contractid = c1.contractid
		left join Cards.dbo.v_rm_ic_duepayment2 as c2 on t.last_reportdate >= c2.duedate and t.contractid = c2.contractid and c2.DUEDATE >= t.from_date
	group by t.contractid,
			 id_order,
			 datebegin,
			 FirstDueDate,
			 from_date,
			last_reportdate

	--drop table #cc_preMissed_payment_6m_5
	select contractid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   paym_number,
		   fullpaymentperiods = coalesce(paym_number, datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #cc_preMissed_payment_6m_5
	from #cc_preMissed_payment_6m_4 as t


	--drop table #cc_Missed_payment_6m
	select t.contractid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #cc_Missed_payment_6m
	from #cc_preMissed_payment_6m_2 as t 
		left join #cc_preMissed_payment_6m_5 as c on t.id_order = c.id_order and t.contractid = c.contractid
	group by  t.contractid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #cc_preMissed_payment_6m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #cc_preMissed_payment_6m_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #cc_preMissed_payment_6m_5 where contractid = 3906723 and id_order = 10796376  
	select * from #cc_Missed_payment_6m where contractid = 3906723 and id_order = 10796376 
	*/


	-------------------#, %, 3m_Missed_payment
	--drop table #cc_preMissed_payment_3m_1
	select t.*,
			dateadd(mm, -3, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #cc_preMissed_payment_3m_1
	from #cc_preMissed_payment_all t
	where reportdate >= dateadd(mm, -3, t.date_of_calculation)


	--drop table #cc_preMissed_payment_3m_2
	select contractid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #cc_preMissed_payment_3m_2
	from #cc_preMissed_payment_3m_1
	group by contractid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #cc_preMissed_payment_3m_3
	select contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #cc_preMissed_payment_3m_3
	from #cc_preMissed_payment_3m_1
	group by contractid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	--drop table #cc_preMissed_payment_3m_4
	select t.contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   last_reportdate,
		   max(c1.payment_number)-min(c2.payment_number) + 1 as paym_number
    into #cc_preMissed_payment_3m_4
	from #cc_preMissed_payment_3m_3 as t
		left join Cards.dbo.v_rm_ic_duepayment2 as c1 on t.last_reportdate >= c1.duedate and t.contractid = c1.contractid
		left join Cards.dbo.v_rm_ic_duepayment2 as c2 on t.last_reportdate >= c2.duedate and t.contractid = c2.contractid and c2.DUEDATE >= t.from_date
	group by t.contractid,
			 id_order,
			 datebegin,
			 FirstDueDate,
			 from_date,
			last_reportdate

	--drop table #cc_preMissed_payment_3m_5
	select contractid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   paym_number,
		   fullpaymentperiods = coalesce(paym_number, datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #cc_preMissed_payment_3m_5
	from #cc_preMissed_payment_3m_4 as t


	--drop table #cc_Missed_payment_3m
	select t.contractid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #cc_Missed_payment_3m
	from #cc_preMissed_payment_3m_2 as t 
		left join #cc_preMissed_payment_3m_5 as c on t.id_order = c.id_order and t.contractid = c.contractid
	group by  t.contractid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #cc_preMissed_payment_3m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #cc_preMissed_payment_3m_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #cc_preMissed_payment_3m_5 where contractid = 3906723 and id_order = 10796376  
	select * from #cc_Missed_payment_3m where contractid = 3906723 and id_order = 10796376 
	*/


	-------------------#, %, 1m_Missed_payment
	--drop table #cc_preMissed_payment_1m_1
	select t.*,
			dateadd(mm, -1, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #cc_preMissed_payment_1m_1
	from #cc_preMissed_payment_all t
	where reportdate >= dateadd(mm, -1, t.date_of_calculation)


	--drop table #cc_preMissed_payment_1m_2
	select contractid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #cc_preMissed_payment_1m_2
	from #cc_preMissed_payment_1m_1
	group by contractid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #cc_preMissed_payment_1m_3
	select contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #cc_preMissed_payment_1m_3
	from #cc_preMissed_payment_1m_1
	group by contractid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	--drop table #cc_preMissed_payment_1m_4
	select t.contractid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   last_reportdate,
		   max(c1.payment_number)-min(c2.payment_number) + 1 as paym_number
    into #cc_preMissed_payment_1m_4
	from #cc_preMissed_payment_1m_3 as t
		left join Cards.dbo.v_rm_ic_duepayment2 as c1 on t.last_reportdate >= c1.duedate and t.contractid = c1.contractid
		left join Cards.dbo.v_rm_ic_duepayment2 as c2 on t.last_reportdate >= c2.duedate and t.contractid = c2.contractid and c2.DUEDATE >= t.from_date
	group by t.contractid,
			 id_order,
			 datebegin,
			 FirstDueDate,
			 from_date,
			last_reportdate

	--drop table #cc_preMissed_payment_1m_5
	select contractid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   paym_number,
		   fullpaymentperiods = coalesce(paym_number, datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #cc_preMissed_payment_1m_5
	from #cc_preMissed_payment_1m_4 as t


	--drop table #cc_Missed_payment_1m
	select t.contractid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #cc_Missed_payment_1m
	from #cc_preMissed_payment_1m_2 as t 
		left join #cc_preMissed_payment_1m_5 as c on t.id_order = c.id_order and t.contractid = c.contractid
	group by  t.contractid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #cc_preMissed_payment_1m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #cc_preMissed_payment_1m_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #cc_preMissed_payment_1m_5 where contractid = 3906723 and id_order = 10796376  
	select * from #cc_Missed_payment_1m where contractid = 3906723 and id_order = 10796376 
	*/

	drop table #cc_preMissed_payment_all_1
	drop table #cc_preMissed_payment_all_2
	drop table #cc_preMissed_payment_all_3
	drop table #cc_preMissed_payment_all_4
	drop table #cc_preMissed_payment_all_5

	drop table #cc_preMissed_payment_12m_1
	drop table #cc_preMissed_payment_12m_2
	drop table #cc_preMissed_payment_12m_3
	drop table #cc_preMissed_payment_12m_5

	drop table #cc_preMissed_payment_6m_1
	drop table #cc_preMissed_payment_6m_2
	drop table #cc_preMissed_payment_6m_3
	drop table #cc_preMissed_payment_6m_5

	drop table #cc_preMissed_payment_3m_1
	drop table #cc_preMissed_payment_3m_2
	drop table #cc_preMissed_payment_3m_3
	drop table #cc_preMissed_payment_3m_5

	drop table #cc_preMissed_payment_1m_1
	drop table #cc_preMissed_payment_1m_2
	drop table #cc_preMissed_payment_1m_3
	drop table #cc_preMissed_payment_1m_5

	drop table #cc_preMissed_payment_all

	-----------------------balance_by deals------------


	--drop table #notCC_preMissed_payment_all
	select	t.dealid, 
			t.id_order,
			t.datebegin,
			t.date_of_calculation,
			t.max_date_in_tables,
			t.FirstDueDate,
			t.reportdate,
			t.DatePastDue,
			t.dpd,
			p2.dpd as dpd_after
	into #notCC_preMissed_payment_all
	from #notCC_prev as t 
		left join archives.dbo.dwh_balancebydeals p2 on t.dealid=p2.dealid and t.reportdate = DATEADD(d, -1, p2.reportdate)



	drop table #notCC_prev

	--drop table #notCC_preMissed_payment_all_1
	select t.*,
		   case when (dpd > 0) and (dpd is not null) and month(reportdate)=month(DatePastDue) then 1
				when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #notCC_preMissed_payment_all_1 
	from #notCC_preMissed_payment_all t

	--drop table #notCC_preMissed_payment_all_2
	select dealid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #notCC_preMissed_payment_all_2
	from #notCC_preMissed_payment_all_1
	group by dealid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #notCC_preMissed_payment_all_3
	select dealid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   max(reportdate) as last_reportdate
    into #notCC_preMissed_payment_all_3
	from #notCC_preMissed_payment_all_1
	group by dealid,
			 id_order,
			 FirstDueDate,
			 datebegin


	--drop table #notCC_preMissed_payment_all_5
	select dealid,
		   id_order,
		   datebegin,
		   firstduedate,
		   last_reportdate,
		   fullpaymentperiods = coalesce(datediff(mm, firstduedate, last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #notCC_preMissed_payment_all_5
	from #notCC_preMissed_payment_all_3 as t


	--drop table #notCC_Missed_payment_all
	select t.dealid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #notCC_Missed_payment_all
	from #notCC_preMissed_payment_all_2 as t 
		left join #notCC_preMissed_payment_all_5 as c on t.id_order = c.id_order and t.dealid = c.dealid
	group by  t.dealid,
			 t.id_order,
			 fullpaymentperiods


	-- select top 100 * from #notCC_preMissed_payment_all_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #notCC_preMissed_payment_all_1 where dealid = 3906723 and id_order = 10796376 order by 8
	select  * from #notCC_preMissed_payment_all_5 where dealid = 3906723 and id_order = 10796376  
	select * from #notCC_Missed_payment_all where id_order = 5872813
	*/

	-------------------#, %, 12m_Missed_payment
	--drop table #notCC_preMissed_payment_12m_1
	select t.*,
			dateadd(mm, -12, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #notCC_preMissed_payment_12m_1
	from #notCC_preMissed_payment_all t
	where reportdate >= dateadd(mm, -12, t.date_of_calculation)


	--drop table #notCC_preMissed_payment_12m_2
	select dealid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #notCC_preMissed_payment_12m_2
	from #notCC_preMissed_payment_12m_1
	group by dealid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #notCC_preMissed_payment_12m_3
	select dealid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #notCC_preMissed_payment_12m_3
	from #notCC_preMissed_payment_12m_1
	group by dealid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin


	--drop table #notCC_preMissed_payment_12m_5
	select dealid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   fullpaymentperiods = coalesce(datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #notCC_preMissed_payment_12m_5
	from #notCC_preMissed_payment_12m_3 as t


	--drop table #notCC_Missed_payment_12m
	select t.dealid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #notCC_Missed_payment_12m
	from #notCC_preMissed_payment_12m_2 as t 
		left join #notCC_preMissed_payment_12m_5 as c on t.id_order = c.id_order and t.dealid = c.dealid
	group by  t.dealid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #notCC_preMissed_payment_12m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #notCC_preMissed_payment_12m_1 where dealid = 3906723 and id_order = 10796376 order by 8
	select  * from #notCC_preMissed_payment_12m_5 where dealid = 3906723 and id_order = 10796376  
	select * from #notCC_Missed_payment_12m where dealid = 3906723 and id_order = 10796376 
	*/

	-------------------#, %, 6m_Missed_payment
	--drop table #notCC_preMissed_payment_6m_1
	select t.*,
			dateadd(mm, -6, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #notCC_preMissed_payment_6m_1
	from #notCC_preMissed_payment_all t
	where reportdate >= dateadd(mm, -6, t.date_of_calculation)


	--drop table #notCC_preMissed_payment_6m_2
	select dealid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #notCC_preMissed_payment_6m_2
	from #notCC_preMissed_payment_6m_1
	group by dealid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #notCC_preMissed_payment_6m_3
	select dealid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #notCC_preMissed_payment_6m_3
	from #notCC_preMissed_payment_6m_1
	group by dealid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	
	--drop table #notCC_preMissed_payment_6m_5
	select dealid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   fullpaymentperiods = coalesce(datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #notCC_preMissed_payment_6m_5
	from #notCC_preMissed_payment_6m_3 as t


	--drop table #notCC_Missed_payment_6m
	select t.dealid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #notCC_Missed_payment_6m
	from #notCC_preMissed_payment_6m_2 as t 
		left join #notCC_preMissed_payment_6m_5 as c on t.id_order = c.id_order and t.dealid = c.dealid
	group by  t.dealid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #notCC_preMissed_payment_6m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #notCC_preMissed_payment_6m_1 where dealid = 3906723 and id_order = 10796376 order by 8
	select  * from #notCC_preMissed_payment_6m_5 where dealid = 3906723 and id_order = 10796376  
	select * from #notCC_Missed_payment_6m where dealid = 3906723 and id_order = 10796376 
	*/


	-------------------#, %, 3m_Missed_payment
	--drop table #notCC_preMissed_payment_3m_1
	select t.*,
			dateadd(mm, -3, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #notCC_preMissed_payment_3m_1
	from #notCC_preMissed_payment_all t
	where reportdate >= dateadd(mm, -3, t.date_of_calculation)


	--drop table #notCC_preMissed_payment_3m_2
	select dealid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #notCC_preMissed_payment_3m_2
	from #notCC_preMissed_payment_3m_1
	group by dealid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #notCC_preMissed_payment_3m_3
	select dealid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #notCC_preMissed_payment_3m_3
	from #notCC_preMissed_payment_3m_1
	group by dealid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin


	--drop table #notCC_preMissed_payment_3m_5
	select dealid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   fullpaymentperiods = coalesce( datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #notCC_preMissed_payment_3m_5
	from #notCC_preMissed_payment_3m_3 as t


	--drop table #notCC_Missed_payment_3m
	select t.dealid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #notCC_Missed_payment_3m
	from #notCC_preMissed_payment_3m_2 as t 
		left join #notCC_preMissed_payment_3m_5 as c on t.id_order = c.id_order and t.dealid = c.dealid
	group by  t.dealid,
			 t.id_order,
			 fullpaymentperiods

		-- select count(*) from #notCC_preMissed_payment_3m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #notCC_preMissed_payment_3m_1 where dealid = 3906723 and id_order = 10796376 order by 8
	select  * from #notCC_preMissed_payment_3m_5 where dealid = 3906723 and id_order = 10796376  
	select * from #notCC_Missed_payment_3m where dealid = 3906723 and id_order = 10796376 
	*/


	-------------------#, %, 1m_Missed_payment
	--drop table #notCC_preMissed_payment_1m_1
	select t.*,
			dateadd(mm, -1, t.date_of_calculation) as from_date,
		   case when (dpd > 0) and (dpd is not null) and (day(reportdate) >= day(DatePastDue) or (day(reportdate) >= day(eomonth(reportdate)) and day(DatePastDue) > day(eomonth(reportdate)))) then 1
				else 0 end check_missed_pay,
		   case when (DPD!=0 and DPd_after!=0 and DPD>DPD_after) then 1 else 0 end check_not_all_pay,
		   case when (DPd_after=0 and DPD>DPD_after) then DPD else 0 end dpd_then_pay_all_payment,
		   case when (DPD!=0 and dpd_after!=0 and DPD>dpd_after) then DPD else 0 end dpd_then_pay_not_all_payment,
		   case when (DPD>0) then 1 else 0 end dpd_availability
	into #notCC_preMissed_payment_1m_1
	from #notCC_preMissed_payment_all t
	where reportdate >= dateadd(mm, -1, t.date_of_calculation)


	--drop table #notCC_preMissed_payment_1m_2
	select dealid,
		   id_order,
		   max(reportdate) end_month_date,
		   max(check_missed_pay) check_missed_pay,
		   max(check_not_all_pay) check_not_all_pay,
		   max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		   max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		   max(dpd_availability) dpd_availability_month
    into #notCC_preMissed_payment_1m_2
	from #notCC_preMissed_payment_1m_1
	group by dealid,
			 id_order,
			 year(reportdate),
			 month(reportdate)

	--drop table #notCC_preMissed_payment_1m_3
	select dealid,
		   id_order,
		   datebegin,
		   FirstDueDate,
		   from_date,
		   max(reportdate) as last_reportdate
    into #notCC_preMissed_payment_1m_3
	from #notCC_preMissed_payment_1m_1
	group by dealid,
			 id_order,
			 FirstDueDate,
			 from_date,
			 datebegin

	--drop table #notCC_preMissed_payment_1m_5
	select dealid,
		   id_order,
		   datebegin,
		   firstduedate,
		   from_date,
		   dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)) as firstduedate_new,
		   last_reportdate,
		   fullpaymentperiods = coalesce( datediff(mm, dateadd(mm, case when day(firstduedate) < day(from_date) then 1 else 0 end, dateadd(dd, + day(firstduedate) - day(from_date), from_date)), last_reportdate) - case when day(last_reportdate) < day(firstduedate) then 1 else 0 end -1, 0)
    into #notCC_preMissed_payment_1m_5
	from #notCC_preMissed_payment_1m_3 as t


	--drop table #notCC_Missed_payment_1m
	select t.dealid,
		   t.id_order,
		   fullpaymentperiods,
		   sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end) all_missed_payments,
		   case when fullpaymentperiods =0 then 0
		   else sum(case when check_missed_pay=1 and check_not_all_pay=1 then 0
					when check_missed_pay=1 and check_not_all_pay=0 then 1
					else 0 end)*100/fullpaymentperiods end  [%, missed_payments],
		  sum(check_not_all_pay) check_not_all_pay_qty,
		  max(dpd_then_pay_all_payment) dpd_then_pay_all_payment,
		  max(dpd_then_pay_not_all_payment) dpd_then_pay_not_all_payment,
		  case when fullpaymentperiods = 0 then 0
			   else sum(dpd_availability_month)*1.00/count(*) end dpd_frequency,
		  count(*) month_in_debt_all
	into #notCC_Missed_payment_1m
	from #notCC_preMissed_payment_1m_2 as t 
		left join #notCC_preMissed_payment_1m_5 as c on t.id_order = c.id_order and t.dealid = c.dealid
	group by  t.dealid,
			 t.id_order,
			 fullpaymentperiods

		-- select top 100 * from #notCC_preMissed_payment_1m_1 where check_missed_pay = 1 and dpd > 30 and dpd_then_pay_all_payment >0
	/* select  * from #notCC_preMissed_payment_1m_1 where contractid = 3906723 and id_order = 10796376 order by 8
	select  * from #notCC_preMissed_payment_1m_5 where contractid = 3906723 and id_order = 10796376  
	select * from #notCC_Missed_payment_1m where id_order = 10796376 
	*/

	drop table #notcc_preMissed_payment_all_1
	drop table #notcc_preMissed_payment_all_2
	drop table #notcc_preMissed_payment_all_3
	drop table #notcc_preMissed_payment_all_5

	drop table #notcc_preMissed_payment_12m_1
	drop table #notcc_preMissed_payment_12m_2
	drop table #notcc_preMissed_payment_12m_3
	drop table #notcc_preMissed_payment_12m_5

	drop table #notcc_preMissed_payment_6m_1
	drop table #notcc_preMissed_payment_6m_2
	drop table #notcc_preMissed_payment_6m_3
	drop table #notcc_preMissed_payment_6m_5

	drop table #notcc_preMissed_payment_3m_1
	drop table #notcc_preMissed_payment_3m_2
	drop table #notcc_preMissed_payment_3m_3
	drop table #notcc_preMissed_payment_3m_5

	drop table #notcc_preMissed_payment_1m_1
	drop table #notcc_preMissed_payment_1m_2
	drop table #notcc_preMissed_payment_1m_3
	drop table #notcc_preMissed_payment_1m_5

	drop table #notcc_preMissed_payment_all

	--drop table #scoring_alfacredits_beh
	select distinct 
		t.Inn,
		t.dealid,
		t.dealno,
		t.DateBegin,
		t.id_order,
		t.closedate,
		t.scoredealid,
		t.dateinsert_scoreid,	
		t.client_type,
		t.is_open,	
		t.days_from_open,	
		t.days_from_close,	
		t.Productgroup,	
		t.AmountbeginUah,
		t.TermOficial,	
		t.TermFact,	
		t.date_of_calculation,
		t.max_date_in_trans,
		t.max_date_in_tables,
		AmountMaxUah = coalesce(t.amountmaxuah, c1.max_clim),
		Max_dpd_ever = coalesce(n1.max_dpd, c1.max_dpd),
		Max_dpd_12m = coalesce(n2.max_dpd, c2.max_dpd),
		Max_dpd_6m = coalesce(n3.max_dpd, c3.max_dpd),
		Max_dpd_3m = coalesce(n4.max_dpd, c4.max_dpd),
		Max_dpd_1m = coalesce(n5.max_dpd, c5.max_dpd),
		Max_out_ever = coalesce(n1.max_out, c1.max_out),
		Max_out_12m = coalesce(n2.max_out, c2.max_out),
		Max_out_6m = coalesce(n3.max_out, c3.max_out),
		Max_out_3m = coalesce(n4.max_out, c4.max_out),
		Max_out_1m = coalesce(n5.max_out, c5.max_out),
		Max_CCusage_ever = c1.max_usage,
		Max_CCusage_12m = c2.max_usage,
		Max_CCusage_6m = c3.max_usage,
		Max_CCusage_3m = c4.max_usage,
		Max_CCusage_1m = c5.max_usage,
		out_cur = coalesce(n6.cur_out, c6.cur_out),
		Missed_payment_ever = coalesce(p1.all_missed_payments, s1.all_missed_payments),
		Missed_payment_12m = coalesce(p2.all_missed_payments, s2.all_missed_payments),
		Missed_payment_6m = coalesce(p3.all_missed_payments, s3.all_missed_payments),
		Missed_payment_3m = coalesce(p4.all_missed_payments, s4.all_missed_payments),
		Missed_payment_1m = coalesce(p5.all_missed_payments, s5.all_missed_payments),
		[Missed_payment_ever,%] = coalesce(p1.[%, missed_payments], s1.[%, missed_payments]),
		[Missed_payment_12m,%] = coalesce(p2.[%, missed_payments], s2.[%, missed_payments]),
		[Missed_payment_6m,%] = coalesce(p3.[%, missed_payments], s3.[%, missed_payments]),
		[Missed_payment_3m,%] = coalesce(p4.[%, missed_payments], s4.[%, missed_payments]),
		[Missed_payment_1m,%] = coalesce(p5.[%, missed_payments], s5.[%, missed_payments]),
		not_all_pay_qty_ever = coalesce(p1.check_not_all_pay_qty, s1.check_not_all_pay_qty),
		not_all_pay_qty_12m = coalesce(p2.check_not_all_pay_qty, s2.check_not_all_pay_qty),
		not_all_pay_qty_6m = coalesce(p3.check_not_all_pay_qty, s3.check_not_all_pay_qty),
		not_all_pay_qty_3m = coalesce(p4.check_not_all_pay_qty, s4.check_not_all_pay_qty),
		not_all_pay_qty_1m = coalesce(p5.check_not_all_pay_qty, s5.check_not_all_pay_qty),
		max_dpd_then_pay_all_payment_ever = coalesce(p1.dpd_then_pay_all_payment, s1.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_12m = coalesce(p2.dpd_then_pay_all_payment, s2.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_6m = coalesce(p3.dpd_then_pay_all_payment, s3.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_3m = coalesce(p4.dpd_then_pay_all_payment, s4.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_1m = coalesce(p5.dpd_then_pay_all_payment, s5.dpd_then_pay_all_payment),
		max_dpd_then_pay_not_all_payment_ever = coalesce(p1.dpd_then_pay_not_all_payment, s1.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_12m = coalesce(p2.dpd_then_pay_not_all_payment, s2.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_6m = coalesce(p3.dpd_then_pay_not_all_payment, s3.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_3m = coalesce(p4.dpd_then_pay_not_all_payment, s4.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_1m = coalesce(p5.dpd_then_pay_not_all_payment, s5.dpd_then_pay_not_all_payment),
		dpd_frequency_ever = coalesce(p1.dpd_frequency, s1.dpd_frequency),
		dpd_frequency_12m = coalesce(p2.dpd_frequency, s2.dpd_frequency),
		dpd_frequency_6m = coalesce(p3.dpd_frequency, s3.dpd_frequency),
		dpd_frequency_3m = coalesce(p4.dpd_frequency, s4.dpd_frequency),
		dpd_frequency_1m = coalesce(p5.dpd_frequency, s5.dpd_frequency)
		,
		Month_since_del_more_then_0 = coalesce(p6.Month_since_del_more_then_0, s6.Month_since_del_more_then_0),
		Month_since_del_more_then_7 = coalesce(p6.Month_since_del_more_then_7, s6.Month_since_del_more_then_7),
		Month_since_del_more_then_15 = coalesce(p6.Month_since_del_more_then_15, s6.Month_since_del_more_then_15),
		Month_since_del_more_then_30 = coalesce(p6.Month_since_del_more_then_30, s6.Month_since_del_more_then_30),
		Month_since_del_more_then_60 = coalesce(p6.Month_since_del_more_then_60, s6.Month_since_del_more_then_60),
		Month_since_del_more_then_90 = coalesce(p6.Month_since_del_more_then_90, s6.Month_since_del_more_then_90)

	into #scoring_alfacredits_beh
	from #temp2 as t 
		left join #CC_max_ever as c1 on t.dealid = c1.dealid and t.id_order = c1.id_order
		left join #CC_max_12m as c2 on t.dealid = c2.dealid	and t.id_order = c2.id_order
		left join #CC_max_6m as c3 on t.dealid = c3.dealid and t.id_order = c3.id_order
		left join #CC_max_3m as c4 on t.dealid = c4.dealid and t.id_order = c4.id_order
		left join #CC_max_1m as c5 on t.dealid = c5.dealid and t.id_order = c5.id_order
		left join #CC_current as c6 on t.dealid = c6.dealid and t.id_order = c6.id_order
		left join #notCC_max_ever as n1 on t.dealid = n1.dealid and t.id_order = n1.id_order
		left join #notCC_max_12m as n2 on t.dealid = n2.dealid	and t.id_order = n2.id_order
		left join #notCC_max_6m as n3 on t.dealid = n3.dealid and t.id_order = n3.id_order
		left join #notCC_max_3m as n4 on t.dealid = n4.dealid and t.id_order = n4.id_order
		left join #notCC_max_1m as n5 on t.dealid = n5.dealid and t.id_order = n5.id_order
		left join #notCC_current as n6 on t.dealid = n6.dealid and t.id_order = n6.id_order
		left join #notcc_Missed_payment_all as p1 on t.dealid = p1.dealid and t.id_order = p1.id_order
		left join #notcc_Missed_payment_12m as p2 on t.dealid = p2.dealid	and t.id_order = p2.id_order
		left join #notcc_Missed_payment_6m as p3 on t.dealid = p3.dealid and t.id_order = p3.id_order
		left join #notcc_Missed_payment_3m as p4 on t.dealid = p4.dealid and t.id_order = p4.id_order
		left join #notcc_Missed_payment_1m as p5 on t.dealid = p5.dealid and t.id_order = p5.id_order
		left join #cc_Missed_payment_all as s1 on t.dealid = s1.contractid and t.id_order = s1.id_order
		left join #cc_Missed_payment_12m as s2 on t.dealid = s2.contractid	and t.id_order = s2.id_order
		left join #cc_Missed_payment_6m as s3 on t.dealid = s3.contractid and t.id_order = s3.id_order
		left join #cc_Missed_payment_3m as s4 on t.dealid = s4.contractid and t.id_order = s4.id_order
		left join #cc_Missed_payment_1m as s5 on t.dealid = s5.contractid and t.id_order = s5.id_order
		left join #notcc_Month_since_del_more_then as p6 on t.dealid = p6.dealid and t.id_order = p6.id_order
		left join #cc_Month_since_del_more_then as s6 on t.dealid = s6.dealid and t.id_order = s6.id_order

		--select distinct  *  from  #scoring_alfacredits_beh where  id_order = 6626369
		--select top 10 * from #cc_Month_since_del_more_then where id_order = 7097664
		--select * from #cc_Missed_payment_all where id_order = 10885799
		--select * from #cc_preMissed_payment_all_1 where id_order = 10885799 order by reportdate


	if OBJECT_ID('Risk_test.[dbo].[Scoring_DataMart_CC_beh]') is not null drop table Risk_test.[dbo].[Scoring_DataMart_CC_beh]
	select 
		a.id_order,
		a.inn,
		#_all_loans = sum(case when a.is_open in (0,1) then 1 else 0 end),
		#_open_loans = sum(case when a.is_open in (1) then 1 else 0 end),
		#_close_loans = sum(case when a.is_open in (0) then 1 else 0 end),
		#_CC_loans = sum(case when a.Productgroup = 'CC'  then 1 else 0 end),
		#_Pil_loans = sum(case when a.Productgroup = 'PIL' then 1 else 0 end),
		#_CSF_loans = sum(case when a.Productgroup = 'CSF' then 1 else 0 end),
		#_CC_loans_open = sum(case when a.Productgroup = 'CC' and a.is_open in (1) then 1 else 0 end),
		#_Pil_loans_open = sum(case when a.Productgroup = 'PIL' and a.is_open in (1) then 1 else 0 end),
		#_CSF_loans_open = sum(case when a.Productgroup = 'CSF' and a.is_open in (1) then 1 else 0 end),
		#_CC_loans_close = sum(case when a.Productgroup = 'CC' and a.is_open in (0) then 1 else 0 end),
		#_Pil_loans_close = sum(case when a.Productgroup = 'PIL' and a.is_open in (0) then 1 else 0 end),
		#_CSF_loans_close = sum(case when a.Productgroup = 'CSF' and a.is_open in (0) then 1 else 0 end),	
		--сума початкового ліміту
		sum_amountbegin_all_loans = sum(case when a.is_open in (0,1) then a.AmountbeginUah else 0 end),
		sum_amountbegin_all_loans_CC = sum(case when a.is_open in (0,1) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		sum_amountbegin_all_loans_PIL = sum(case when a.is_open in (0,1) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		sum_amountbegin_all_loans_CSF = sum(case when a.is_open in (0,1) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		sum_amountbegin_open_loans = sum(case when a.is_open in (1) then a.AmountbeginUah else 0 end),
		sum_amountbegin_open_loans_CC = sum(case when a.is_open in (1) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		sum_amountbegin_open_loans_PIL = sum(case when a.is_open in (1) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		sum_amountbegin_open_loans_CSF = sum(case when a.is_open in (1) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		sum_amountbegin_close_loans = sum(case when a.is_open in (0) then a.AmountbeginUah else 0 end),
		sum_amountbegin_close_loans_CC = sum(case when a.is_open in (0) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		sum_amountbegin_close_loans_PIL = sum(case when a.is_open in (0) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		sum_amountbegin_close_loans_CSF = sum(case when a.is_open in (0) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		--сума максимально установленого ліміту(для картки можливий апсел)
		sum_amountmax_all_loans = sum(case when a.is_open in (0,1) then a.AmountmaxUah else 0 end),
		sum_amountmax_all_loans_CC = sum(case when a.is_open in (0,1) and a.Productgroup = 'CC' then a.AmountMaxUah else 0 end),
		sum_amountmax_all_loans_PIL = sum(case when a.is_open in (0,1) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		sum_amountmax_all_loans_CSF = sum(case when a.is_open in (0,1) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),
		sum_amountmax_open_loans = sum(case when a.is_open in (1) then a.AmountmaxUah else 0 end),
		sum_amountmax_open_loans_CC = sum(case when a.is_open in (1) and a.Productgroup = 'CC' then a.AmountmaxUah else 0 end),
		sum_amountmax_open_loans_PIL = sum(case when a.is_open in (1) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		sum_amountmax_open_loans_CSF = sum(case when a.is_open in (1) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),
		sum_amountmax_close_loans = sum(case when a.is_open in (0) then a.AmountmaxUah else 0 end),
		sum_amountmax_close_loans_CC = sum(case when a.is_open in (0) and a.Productgroup = 'CC' then a.AmountmaxUah else 0 end),
		sum_amountmax_close_loans_PIL = sum(case when a.is_open in (0) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		sum_amountmax_close_loans_CSF = sum(case when a.is_open in (0) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),
		--максимальний ліміт серед початкових лімітів
		max_amountbegin_all_loans = max(case when a.is_open in (0,1) then a.AmountbeginUah else 0 end),
		max_amountbegin_all_loans_CC = max(case when a.is_open in (0,1) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		max_amountbegin_all_loans_PIL = max(case when a.is_open in (0,1) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		max_amountbegin_all_loans_CSF = max(case when a.is_open in (0,1) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		max_amountbegin_open_loans = max(case when a.is_open in (1) then a.AmountbeginUah else 0 end),
		max_amountbegin_open_loans_CC = max(case when a.is_open in (1) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		max_amountbegin_open_loans_PIL = max(case when a.is_open in (1) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		max_amountbegin_open_loans_CSF = max(case when a.is_open in (1) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		max_amountbegin_close_loans = max(case when a.is_open in (0) then a.AmountbeginUah else 0 end),
		max_amountbegin_close_loans_CC = max(case when a.is_open in (0) and a.Productgroup = 'CC' then a.AmountbeginUah else 0 end),
		max_amountbegin_close_loans_PIL = max(case when a.is_open in (0) and a.Productgroup = 'PIL' then a.AmountbeginUah else 0 end),
		max_amountbegin_close_loans_CSF = max(case when a.is_open in (0) and a.Productgroup = 'CSF' then a.AmountbeginUah else 0 end),
		--максимальний ліміт по всіх продуктах, по кожному продукту
		max_amountmax_all_loans = max(case when a.is_open in (0,1) then a.AmountmaxUah else 0 end),
		max_amountmax_all_loans_CC = max(case when a.is_open in (0,1) and a.Productgroup = 'CC' then a.AmountmaxUah else 0 end),
		max_amountmax_all_loans_PIL = max(case when a.is_open in (0,1) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		max_amountmax_all_loans_CSF = max(case when a.is_open in (0,1) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),
		max_amountmax_open_loans = max(case when a.is_open in (1) then a.AmountmaxUah else 0 end),
		max_amountmax_open_loans_CC = max(case when a.is_open in (1) and a.Productgroup = 'CC' then a.AmountmaxUah else 0 end),
		max_amountmax_open_loans_PIL = max(case when a.is_open in (1) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		max_amountmax_open_loans_CSF = max(case when a.is_open in (1) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),
		max_amountmax_close_loans = max(case when a.is_open in (0) then a.AmountmaxUah else 0 end),
		max_amountmax_close_loans_CC = max(case when a.is_open in (0) and a.Productgroup = 'CC' then a.AmountmaxUah else 0 end),
		max_amountmax_close_loans_PIL = max(case when a.is_open in (0) and a.Productgroup = 'PIL' then a.AmountmaxUah else 0 end),
		max_amountmax_close_loans_CSF = max(case when a.is_open in (0) and a.Productgroup = 'CSF' then a.AmountmaxUah else 0 end),

		out_to_amountbegin = case when sum(a.AmountbeginUah) is null or sum(a.AmountbeginUah)=0 then 0 else sum(a.out_cur)*1.0/ sum(a.AmountbeginUah) end,
		out_to_amountmax = case when sum(a.AmountMaxUah) is null or sum(a.AmountMaxUah)=0 then 0 else sum(a.out_cur)*1.0/ sum(AmountMaxUah) end,

		Sum_cur_out = sum(a.out_cur),
		Sum_cur_out_CC = sum(case when a.Productgroup = 'CC' then a.out_cur else 0 end),
		Sum_cur_out_PIL = sum(case when a.Productgroup = 'PIL' then a.out_cur else 0 end),
		Sum_cur_out_CSF = sum(case when a.Productgroup = 'CSF' then a.out_cur else 0 end),
		Max_month_from_date_begin = datediff(month, min(a.DateBegin), date_of_calculation) - case when dateadd(month, datediff(month, min(a.DateBegin), date_of_calculation), min(a.DateBegin)) > date_of_calculation then 1 else 0 end,
		Min_month_from_date_begin = datediff(month, max(a.DateBegin), date_of_calculation) - case when dateadd(month, datediff(month, max(a.DateBegin), date_of_calculation), max(a.DateBegin)) > date_of_calculation then 1 else 0 end,
		From_first_to_last_loan_monthes = datediff(month, min(a.DateBegin),max(a.DateBegin)) - case when dateadd(month, datediff(month, min(a.DateBegin), max(a.DateBegin)), min(a.DateBegin)) > max(a.DateBegin) then 1 else 0 end,
		AvgTermOficial_PILCSF = sum(case when a.Productgroup <> 'CC' then a.TermOficial else 0 end)/sum(case when a.Productgroup <> 'CC'  then 1 else 0.0000001 end),
		Max_dpd_ever = max(a.Max_dpd_ever),
		Max_dpd_12m = max(a.Max_dpd_12m),
		Max_dpd_6m = max(a.Max_dpd_6m),
		Max_dpd_3m = max(a.Max_dpd_3m),
		Max_dpd_1m = max(a.Max_dpd_1m),
		MaxCC_out_ever = max(case when a.Productgroup = 'CC' then a.Max_out_ever else 0 end),
		MaxCC_out_12m = max(case when a.Productgroup = 'CC' then a.Max_out_12m else 0 end),
		MaxCC_out_6m = max(case when a.Productgroup = 'CC' then a.Max_out_6m else 0 end),
		MaxCC_out_3m = max(case when a.Productgroup = 'CC' then a.Max_out_3m else 0 end),
		MaxCC_out_1m = max(case when a.Productgroup = 'CC' then a.Max_out_1m else 0 end),
		MaxCC_usage_ever = max(case when a.Productgroup = 'CC' then a.Max_CCusage_ever else 0 end),
		MaxCC_usage_12m = max(case when a.Productgroup = 'CC' then a.Max_CCusage_12m else 0 end),
		MaxCC_usage_6m = max(case when a.Productgroup = 'CC' then a.Max_CCusage_6m else 0 end),
		MaxCC_usage_3m = max(case when a.Productgroup = 'CC' then a.Max_CCusage_3m else 0 end),
		MaxCC_usage_1m = max(case when a.Productgroup = 'CC' then a.Max_CCusage_1m else 0 end),

		Missed_payment_ever_ever = max( a.Missed_payment_ever ),
		Missed_payment_ever_12m = max( a.Missed_payment_12m ),
		Missed_payment_ever_6m = max( a.Missed_payment_6m ),
		Missed_payment_ever_3m = max( a.Missed_payment_3m ),
		Missed_payment_ever_1m = max( a.Missed_payment_1m ),
		[Missed_payment_ever,%] = max( a.[Missed_payment_ever,%] ),
		[Missed_payment_12m,%] = max( a.[Missed_payment_12m,%] ),
		[Missed_payment_6m,%] = max( a.[Missed_payment_6m,%] ),
		[Missed_payment_3m,%] = max( a.[Missed_payment_3m,%] ),
		[Missed_payment_1m,%] = max( a.[Missed_payment_1m,%] ),
		max_dpd_then_pay_all_payment_ever = max( a.max_dpd_then_pay_all_payment_ever ),
		max_dpd_then_pay_all_payment_12m = max( a.max_dpd_then_pay_all_payment_12m ),
		max_dpd_then_pay_all_payment_6m = max( a.max_dpd_then_pay_all_payment_6m ),
		max_dpd_then_pay_all_payment_3m = max( a.max_dpd_then_pay_all_payment_3m ),
		max_dpd_then_pay_all_payment_1m = max( a.max_dpd_then_pay_all_payment_1m ),
		max_dpd_then_pay_not_all_payment_ever = max( a.max_dpd_then_pay_not_all_payment_ever ),
		max_dpd_then_pay_not_all_payment_12m = max( a.max_dpd_then_pay_not_all_payment_12m ),
		max_dpd_then_pay_not_all_payment_6m = max( a.max_dpd_then_pay_not_all_payment_6m ),
		max_dpd_then_pay_not_all_payment_3m = max( a.max_dpd_then_pay_not_all_payment_3m ),
		max_dpd_then_pay_not_all_payment_1m = max( a.max_dpd_then_pay_not_all_payment_1m ),
		dpd_frequency_ever = max( a.dpd_frequency_ever ),
		dpd_frequency_12m = max( a.dpd_frequency_12m ),
		dpd_frequency_6m = max( a.dpd_frequency_6m ),
		dpd_frequency_3m = max( a.dpd_frequency_3m ),
		dpd_frequency_1m = max( a.dpd_frequency_1m ),

		Month_since_del_more_then_0 =  min( a.Month_since_del_more_then_0 ),
		Month_since_del_more_then_7 = min( a.Month_since_del_more_then_7 ),
		Month_since_del_more_then_15 = min( a.Month_since_del_more_then_15 ),
		Month_since_del_more_then_30 = min( a.Month_since_del_more_then_30 ),
		Month_since_del_more_then_60 = min( a.Month_since_del_more_then_60 ),
		Month_since_del_more_then_90 = min( a.Month_since_del_more_then_90 )

	into Risk_test.[dbo].[Scoring_DataMart_CC_beh]
	from  #scoring_alfacredits_beh as a 
	where a.is_open in (0,1)
	group by 
		a.id_order,
		a.inn,
		a.date_of_calculation
