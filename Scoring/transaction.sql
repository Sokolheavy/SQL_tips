select *,
		convert(date, dateadd(d,-1,dateinsert_scoreid)) as date_of_calculation,
		convert(date, dateadd(d,-2,dateinsert_scoreid)) as max_date_in_tables,
		convert(date, dateadd(d,-4,dateinsert_scoreid)) as max_date_in_trans	
	into #prevcredits
	from prevcredits t

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
	from #prevcredits t

	drop table #Scoring_DataMart_CC_prevcredits 

	--select * from #temp1 

	--drop table #temp2
	select distinct
		t.*,
		AmountbeginUAH = f.firstlimit,
		TermOficial = 12,
		TermFact = datediff(mm, t.datebegin, t.closedate),
		FirstDueDate = coalesce(f.FPDDate, dateadd(dd, 1, dateadd(mm, 1, t.datebegin))),
		dateadd(mm, -12, t.date_of_calculation) as reportdate_12m,
		dateadd(mm, -6, t.date_of_calculation) as reportdate_6m,
		dateadd(mm, -3, t.date_of_calculation) as reportdate_3m,
		dateadd(mm, -1, t.date_of_calculation) as reportdate_1m
	into  #temp2
	from temp1 t
		join table_cart_credit as f on isnull(t.dealno, '') = isnull(f.legalcontractnum, '') and t.dealid = f.contractid

	drop table #temp1

	CREATE INDEX idx_dealid
	ON #temp2  (dealid);

	CREATE INDEX idx_max_date_in_tables
	ON #temp2  (max_date_in_tables);

	CREATE INDEX idx_max_date_in_trans
	ON #temp2  (max_date_in_trans);

	CREATE INDEX idx_dealid_max_date_in_trans
	ON #temp2  (dealid, max_date_in_trans);

	CREATE INDEX idx_date_of_calculation
	ON #temp2  (date_of_calculation);

	CREATE INDEX idx_dealid_date_of_calculation
	ON #temp2  (dealid, date_of_calculation);

	
	--drop table #temp2_pqr_join_1
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
	into #temp2_pqr_join_1
	from daily_credit as p
		join #temp2 as t on t.dealid = p.contractid and p.reportdate <= t.max_date_in_trans

	--drop table #temp2_pqr_join
	select distinct * 
	into #temp2_pqr_join
	from #temp2_pqr_join_1

	drop table #temp2_pqr_join_1


	CREATE INDEX idx_dealid
	ON #temp2_pqr_join  (dealid);

	CREATE INDEX idx_id_order
	ON #temp2_pqr_join  (dealid, id_order);

	CREATE INDEX idx_dealid_reportdate
	ON #temp2_pqr_join  (dealid, reportdate);

	--drop table #temp2_provodki_join
	select *
	into #temp2_provodki_join
	  from temp2 t
    left Provodki p on t.dealid=p.contractid and p.operdate < t.date_of_calculation


	CREATE INDEX idx_dealid
	ON #temp2_provodki_join  (dealid);

	CREATE INDEX idx_id_order
	ON #temp2 (dealid, id_order);

	CREATE INDEX idx_operdate
	ON #temp2_provodki_join  (operdate);

	CREATE INDEX idx_dealid_operdate
	ON #temp2_provodki_join  (dealid, operdate);


  --відношення витрат до надходжень
  --відношення покупок до всіх витрат(наскільки часто робляться покупки)
  --відношення покупок до надходжень
  --відношення зняття коштів до всіх витрат
  --відношення зняття коштів до всіх витрат до надходжень
  --середня, максимальна сума покупки 
  --середня, максимальна сума зняття готівки
  --середня, максимальна загальна сума транзакций
  --Количество транзакций 
  --сортування клієнтів по покупці cafe_client, shop_client, taxi_client
  -- транзакції до outstending
  -- покупоки до outstending
  -- зняття кешу до outstending


	--all
	--drop table #usage_ratio_all	
	select dealid,
         id_order,
         case when sum(case when description='Приход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' then tramt else 0 end)*1.0/
		 sum(case when description='Приход' then tramt else 0 end)) end usage_ratio,

		 case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end)*1.0/
		 sum(case when description='Расход' then tramt else 0 end)) end [% Purchase_ratio],

		 case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end)*1.0/
		 sum(case when description='Расход' then tramt else 0 end)) end [% Cash_ratio],

		 avg(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) avg_Purchase_sum,
		 max(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end) max_Purchase_sum,
		 count(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) Purchase_count,

		 avg(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) avg_Cash,
		 max(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end) max_Cash,
		 count(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) Cash_count,

		 avg(case when description='Расход' and tramt is not null then tramt else null end) avg_tramt,
		 max(case when description='Расход' and tramt is not null then tramt else 0 end) max_tramt,
		 count(case when description='Расход' and tramt is not null then tramt else null end) trans_count,

		  sum(case when merchname like '%bar%' or 
		               merchname like '%cafe%' or
					   merchname like '%kafe%' or
					   merchname like '%restaurant%' or
					   merchname like '%vine%' or
					   merchname like '%pub%' then 1 else 0 end) cafe_client,

         sum(case when merchname like '%shop%' or 
		               merchname like '%market%' or
					   merchname like '%aliexpress%' or
					   merchname like '%joom%' or
					   merchname like '%alibaba%' then 1 else 0 end) shop_client,

         sum(case when merchname like '%varus%' or 
		               merchname like '%silpo%' or
					   merchname like '%ashan%' or
					   merchname like '%aushan%' or
					   merchname like '%produkty%' or
					   merchname like '%eko%market%' or
					   merchname like '%supermarket%' or
					   merchname like '%novus%' then 1 else 0 end) supermarket_client,

         sum(case when merchname like '%taxi%' or 
					   merchname like '%uber%' then 1 else 0 end) taxi_client,

        sum(case when comments like'%погашення %% за санкц%' then 1 else 0 end) credit_sanc_count,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then 1 else 0 end) overdraft_sanc_count,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then 1 else 0 end) fine_count,
		sum(case when comments like'%погашення комісії РКО%' then 1 else 0 end) commission_count, --?
		sum(case when comments like'%погашення пені%' then 1 else 0 end) peni_count,
		sum(case when comments like'%погашення %% за санкц%' then tramt else 0 end) credit_sanc_sum,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then tramt else 0 end) overdraft_sanc_sum,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then tramt else 0 end) fine_sum,
		sum(case when comments like'%погашення комісії РКО%' then tramt else 0 end) commission_sum, --?
		sum(case when comments like'%погашення пені%' then tramt else 0 end) peni_sum

    into #usage_ratio_all	 
	from #temp2_provodki_join 
	group by dealid,
          id_order

    --select * from #temp2_provodki_join  where comments like'%погашення штрафів № 1 та 2%' 


	--12m
	--drop table #usage_ratio_12m	
	select dealid,
         id_order,
         case when sum(case when description='Приход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' then tramt else 0 end)*1.0/
		 sum(case when description='Приход' then tramt else 0 end)) end usage_ratio,

		 case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end)*1.0/
		 sum(case when description='Расход' then tramt else 0 end)) end [% Purchase_ratio],

		 case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		 else(sum(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end)*1.0/
		 sum(case when description='Расход' then tramt else 0 end)) end [% Cash_ratio],

		 avg(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) avg_Purchase_sum,
		 max(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end) max_Purchase_sum,
		 count(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) Purchase_count,

		 avg(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) avg_Cash,
		 max(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end) max_Cash,
		 count(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) Cash_count,

		 avg(case when description='Расход' and tramt is not null then tramt else null end) avg_tramt,
		 max(case when description='Расход' and tramt is not null then tramt else 0 end) max_tramt,
		 count(case when description='Расход' and tramt is not null then tramt else null end) trans_count,

		  sum(case when merchname like '%bar%' or 
		               merchname like '%cafe%' or
					   merchname like '%kafe%' or
					   merchname like '%restaurant%' or
					   merchname like '%vine%' or
					   merchname like '%pub%' then 1 else 0 end) cafe_client,

         sum(case when merchname like '%shop%' or 
		               merchname like '%market%' or
					   merchname like '%aliexpress%' or
					   merchname like '%joom%' or
					   merchname like '%alibaba%' then 1 else 0 end) shop_client,

         sum(case when merchname like '%varus%' or 
		               merchname like '%silpo%' or
					   merchname like '%ashan%' or
					   merchname like '%aushan%' or
					   merchname like '%produkty%' or
					   merchname like '%eko%market%' or
					   merchname like '%supermarket%' or
					   merchname like '%novus%' then 1 else 0 end) supermarket_client,

         sum(case when merchname like '%taxi%' or 
					   merchname like '%uber%' then 1 else 0 end) taxi_client,

        sum(case when comments like'%погашення %% за санкц%' then 1 else 0 end) credit_sanc_count,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then 1 else 0 end) overdraft_sanc_count,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then 1 else 0 end) fine_count,
		sum(case when comments like'%погашення комісії РКО%' then 1 else 0 end) commission_count, --?
		sum(case when comments like'%погашення пені%' then 1 else 0 end) peni_count,
		sum(case when comments like'%погашення %% за санкц%' then tramt else 0 end) credit_sanc_sum,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then tramt else 0 end) overdraft_sanc_sum,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then tramt else 0 end) fine_sum,
		sum(case when comments like'%погашення комісії РКО%' then tramt else 0 end) commission_sum, --?
		sum(case when comments like'%погашення пені%' then tramt else 0 end) peni_sum

    into #usage_ratio_12m	 
	from #temp2_provodki_join  t
	where operdate >= reportdate_12m
	group by dealid,
          id_order



	--6m
	--drop table #usage_ratio_6m	
	select dealid,
        id_order,
        case when sum(case when description='Приход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' then tramt else 0 end)*1.0/
		sum(case when description='Приход' then tramt else 0 end)) end usage_ratio,

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Purchase_ratio],

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Cash_ratio],

		avg(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) avg_Purchase_sum,
		max(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end) max_Purchase_sum,
		count(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) Purchase_count,

		avg(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) avg_Cash,
		max(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end) max_Cash,
		count(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) Cash_count,

		avg(case when description='Расход' and tramt is not null then tramt else null end) avg_tramt,
		max(case when description='Расход' and tramt is not null then tramt else 0 end) max_tramt,
		count(case when description='Расход' and tramt is not null then tramt else null end) trans_count,

		sum(case when merchname like '%bar%' or 
		               merchname like '%cafe%' or
					   merchname like '%kafe%' or
					   merchname like '%restaurant%' or
					   merchname like '%vine%' or
					   merchname like '%pub%' then 1 else 0 end) cafe_client,

        sum(case when merchname like '%shop%' or 
		               merchname like '%market%' or
					   merchname like '%aliexpress%' or
					   merchname like '%joom%' or
					   merchname like '%alibaba%' then 1 else 0 end) shop_client,

        sum(case when merchname like '%varus%' or 
		               merchname like '%silpo%' or
					   merchname like '%ashan%' or
					   merchname like '%aushan%' or
					   merchname like '%produkty%' or
					   merchname like '%eko%market%' or
					   merchname like '%supermarket%' or
					   merchname like '%novus%' then 1 else 0 end) supermarket_client,

        sum(case when merchname like '%taxi%' or 
					   merchname like '%uber%' then 1 else 0 end) taxi_client,

        sum(case when comments like'%погашення %% за санкц%' then 1 else 0 end) credit_sanc_count,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then 1 else 0 end) overdraft_sanc_count,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then 1 else 0 end) fine_count,
		sum(case when comments like'%погашення комісії РКО%' then 1 else 0 end) commission_count, --?
		sum(case when comments like'%погашення пені%' then 1 else 0 end) peni_count,
		sum(case when comments like'%погашення %% за санкц%' then tramt else 0 end) credit_sanc_sum,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then tramt else 0 end) overdraft_sanc_sum,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then tramt else 0 end) fine_sum,
		sum(case when comments like'%погашення комісії РКО%' then tramt else 0 end) commission_sum, --?
		sum(case when comments like'%погашення пені%' then tramt else 0 end) peni_sum
    into #usage_ratio_6m	 
	from #temp2_provodki_join 
	where operdate >= reportdate_6m
	group by dealid,
          id_order

	--3m
	--drop table #usage_ratio_3m	
	select dealid,
        id_order,
        case when sum(case when description='Приход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' then tramt else 0 end)*1.0/
		sum(case when description='Приход' then tramt else 0 end)) end usage_ratio,

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Purchase_ratio],

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Cash_ratio],

		avg(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) avg_Purchase_sum,
		max(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end) max_Purchase_sum,
		count(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) Purchase_count,

		avg(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) avg_Cash,
		max(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end) max_Cash,
		count(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) Cash_count,

		avg(case when description='Расход' and tramt is not null then tramt else null end) avg_tramt,
		max(case when description='Расход' and tramt is not null then tramt else 0 end) max_tramt,
		count(case when description='Расход' and tramt is not null then tramt else null end) trans_count,

		sum(case when merchname like '%bar%' or 
		               merchname like '%cafe%' or
					   merchname like '%kafe%' or
					   merchname like '%restaurant%' or
					   merchname like '%vine%' or
					   merchname like '%pub%' then 1 else 0 end) cafe_client,

        sum(case when merchname like '%shop%' or 
		               merchname like '%market%' or
					   merchname like '%aliexpress%' or
					   merchname like '%joom%' or
					   merchname like '%alibaba%' then 1 else 0 end) shop_client,

        sum(case when merchname like '%varus%' or 
		               merchname like '%silpo%' or
					   merchname like '%ashan%' or
					   merchname like '%aushan%' or
					   merchname like '%produkty%' or
					   merchname like '%eko%market%' or
					   merchname like '%supermarket%' or
					   merchname like '%novus%' then 1 else 0 end) supermarket_client,

        sum(case when merchname like '%taxi%' or 
					   merchname like '%uber%' then 1 else 0 end) taxi_client,

        sum(case when comments like'%погашення %% за санкц%' then 1 else 0 end) credit_sanc_count,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then 1 else 0 end) overdraft_sanc_count,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then 1 else 0 end) fine_count,
		sum(case when comments like'%погашення комісії РКО%' then 1 else 0 end) commission_count, --?
		sum(case when comments like'%погашення пені%' then 1 else 0 end) peni_count,
		sum(case when comments like'%погашення %% за санкц%' then tramt else 0 end) credit_sanc_sum,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then tramt else 0 end) overdraft_sanc_sum,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then tramt else 0 end) fine_sum,
		sum(case when comments like'%погашення комісії РКО%' then tramt else 0 end) commission_sum, --?
		sum(case when comments like'%погашення пені%' then tramt else 0 end) peni_sum
    into #usage_ratio_3m	 
	from #temp2_provodki_join 
	where operdate >=  reportdate_3m
	group by dealid,
          id_order



	--1m
	--drop table #usage_ratio_1m	
	select dealid,
        id_order,
        case when sum(case when description='Приход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' then tramt else 0 end)*1.0/
		sum(case when description='Приход' then tramt else 0 end)) end usage_ratio,

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Purchase_ratio],

		case when sum(case when description='Расход' then tramt else 0 end)=0 then 0
		else(sum(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end)*1.0/
		sum(case when description='Расход' then tramt else 0 end)) end [% Cash_ratio],

		avg(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) avg_Purchase_sum,
		max(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else 0 end) max_Purchase_sum,
		count(case when description='Расход' and transinfo like '%Списание за покупку в валюте основного счета%' then tramt else null end) Purchase_count,

		avg(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) avg_Cash,
		max(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else 0 end) max_Cash,
		count(case when description='Расход' and transinfo like '%Списание за снятие наличных в АТМ%' then tramt else null end) Cash_count,

		avg(case when description='Расход' and tramt is not null then tramt else null end) avg_tramt,
		max(case when description='Расход' and tramt is not null then tramt else 0 end) max_tramt,
		count(case when description='Расход' and tramt is not null then tramt else null end) trans_count,

		sum(case when merchname like '%bar%' or 
		               merchname like '%cafe%' or
					   merchname like '%kafe%' or
					   merchname like '%restaurant%' or
					   merchname like '%vine%' or
					   merchname like '%pub%' then 1 else 0 end) cafe_client,

        sum(case when merchname like '%shop%' or 
		               merchname like '%market%' or
					   merchname like '%aliexpress%' or
					   merchname like '%joom%' or
					   merchname like '%alibaba%' then 1 else 0 end) shop_client,

        sum(case when merchname like '%varus%' or 
		               merchname like '%silpo%' or
					   merchname like '%ashan%' or
					   merchname like '%aushan%' or
					   merchname like '%produkty%' or
					   merchname like '%eko%market%' or
					   merchname like '%supermarket%' or
					   merchname like '%novus%' then 1 else 0 end) supermarket_client,

        sum(case when merchname like '%taxi%' or 
					   merchname like '%uber%' then 1 else 0 end) taxi_client,

        sum(case when comments like'%погашення %% за санкц%' then 1 else 0 end) credit_sanc_count,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then 1 else 0 end) overdraft_sanc_count,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then 1 else 0 end) fine_count,
		sum(case when comments like'%погашення комісії РКО%' then 1 else 0 end) commission_count, --?
		sum(case when comments like'%погашення пені%' then 1 else 0 end) peni_count,
		sum(case when comments like'%погашення %% за санкц%' then tramt else 0 end) credit_sanc_sum,
		sum(case when comments like'%погашення %% за несанкц.овердрафт%' then tramt else 0 end) overdraft_sanc_sum,
		sum(case when comments like'%погашення штрафів № 1 та 2%' then tramt else 0 end) fine_sum,
		sum(case when comments like'%погашення комісії РКО%' then tramt else 0 end) commission_sum, --?
		sum(case when comments like'%погашення пені%' then tramt else 0 end) peni_sum

    into #usage_ratio_1m	 
	from #temp2_provodki_join 
   where operdate >= reportdate_1m
	group by dealid,
          id_order

 
	----------------------------- період між транзакціями -----------------------------
	--частота покупок(середня, максимальна кількість днів між покупками та зняття коштів
	--частота знімання готівки (середня, максимальна кількість днів між покупками та зняття коштів

	--створюємо допоміжну таблицю - #date_diff для швидшого виконання наступних звітів( поле rn - порядковий номер рядка відносно operdate, якщо однаковий operdate, то rn також буде однаковий)
	--drop table #date_diff
  	select distinct dealid,
	    id_order,
	    convert(date, operdate) operdate, 
		case when transinfo like '%Списание за покупку в валюте основного счета%' then 'purches'
		    else 'cash' end transinfo,
		reportdate_12m,
		reportdate_6m,
		reportdate_3m,
		reportdate_1m,
  	    DENSE_RANK() over(partition by dealid, id_order,case when transinfo like '%Списание за покупку в валюте основного счета%' then 'purches'
		    else 'cash' end 
			order by convert(date, operdate)) as rn   
	into #date_diff
  	from #temp2_provodki_join 
	where transinfo like '%Списание за покупку в валюте основного счета%' or
		transinfo like '%Списание за снятие наличных в АТМ%'


	--all
	--drop table #date_diff_all	 
	select p1.dealid,
	    p1.id_order, 

      	max(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_purch,

        max(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_cash,

      	min(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_purch,

        min(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_cash

	into #date_diff_all					 			   
    from #date_diff p1  
      	join #date_diff p2 on p1.dealid = p2.dealid  and p1.rn + 1 = p2.rn and p1.id_order = p2.id_order
    group by p1.dealid,
        p1.id_order

	--12m
	--drop table #date_diff_12m	 
    select p1.dealid,
		p1.id_order, 

      	max(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_purch,

        max(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_cash,

      	min(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_purch,

        min(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_cash
	into #date_diff_12m					 			   
    from #date_diff p1  
      	join #date_diff p2 on p1.dealid = p2.dealid  and p1.rn + 1 = p2.rn  and p1.id_order = p2.id_order
	where p1.operdate >= p1.reportdate_12m
    group by p1.dealid,
		p1.id_order

	--6m
	--drop table #date_diff_6m	 
	select p1.dealid,
		p1.id_order, 

      	max(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_purch,

        max(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_cash,

      	min(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_purch,

        min(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_cash
	into #date_diff_6m				 			   
    from #date_diff p1  
      	join #date_diff p2 on p1.dealid = p2.dealid  and p1.rn + 1 = p2.rn  and p1.id_order = p2.id_order
		where p1.operdate >= p1.reportdate_6m
    group by p1.dealid,
		p1.id_order

	 --3m
	--drop table #date_diff_3m	 
    select  p1.dealid,
		p1.id_order, 

      	max(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_purch,

        max(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_cash,

      	min(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_purch,

        min(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_cash
	into #date_diff_3m				 			   
    from #date_diff p1  
      	join #date_diff p2 on p1.dealid = p2.dealid  and p1.rn + 1 = p2.rn  and p1.id_order = p2.id_order
	where p1.operdate >= p1.reportdate_3m
    group by p1.dealid,
		p1.id_order


	 --1m
	--drop table #date_diff_1m
    select p1.dealid,
		p1.id_order, 		 
      	max(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_purch,

        max(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as max_date_diff_cash,

      	min(case when p1.transinfo='purches' and p2.transinfo='purches' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_purch,

        min(case when p1.transinfo='cash' and p2.transinfo='cash' then
		datediff(dd, p1.operdate, p2.operdate) end) as min_date_diff_cash
	into #date_diff_1m				 			   
    from #date_diff p1  
      	join #date_diff p2 on p1.dealid = p2.dealid  and p1.rn + 1 = p2.rn  and p1.id_order = p2.id_order
	where p1.operdate >= p1.reportdate_1m
    group by p1.dealid,
		p1.id_order

	---------------------------- відношення сумми транзакції за місяць до limit_report ----------------------------
	-- транзакції до limit_report
	-- покупоки до limit_report
	-- зняття кешу до limit_report


	--drop table #out_to_all
	select p.dealid,
		p.id_order,
		eomonth(operdate) as opermonth,
        case 
			when isnull(sum(case when p.description='Расход' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99
			else (sum(case when p.description='Расход' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% trans_to_limit_cur],  
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99			
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% Purchase_to_limit_cur], 
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99	
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% cash_to_limit_cur]
    into #out_to_all
	from #temp2_provodki_join p
		left join #temp2_pqr_join pd on p.dealid=pd.dealid and p.operdate = pd.reportdate and p.id_order = pd.id_order
	where description='Расход'
	group by p.dealid,
       p.id_order,
	   eomonth(operdate)


    --12m
    --drop table #out_to_12m
	select p.dealid,
		p.id_order,
		eomonth(operdate) as opermonth,
        case 
			when isnull(sum(case when p.description='Расход' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99
			else (sum(case when p.description='Расход' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% trans_to_limit_cur],  
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99			
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% Purchase_to_limit_cur], 
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99	
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% cash_to_limit_cur]
    into #out_to_12m
	from #temp2_provodki_join p
		left join #temp2_pqr_join pd on p.dealid=pd.dealid and p.operdate = pd.reportdate and p.id_order = pd.id_order
	where description='Расход'
	and operdate >=p.reportdate_12m
	group by p.dealid,
		p.id_order,
		eomonth(operdate)




    --12m
    --drop table #out_to_6m
	select p.dealid,
		p.id_order,
		eomonth(operdate) as opermonth,
        case 
			when isnull(sum(case when p.description='Расход' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99
			else (sum(case when p.description='Расход' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% trans_to_limit_cur],  
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99			
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% Purchase_to_limit_cur], 
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99	
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% cash_to_limit_cur]
    into #out_to_6m
	from #temp2_provodki_join p
		left join #temp2_pqr_join pd on p.dealid=pd.dealid and p.operdate = pd.reportdate and p.id_order = pd.id_order
	where description='Расход'
		and operdate >=p.reportdate_6m
	group by p.dealid,
		p.id_order,
		eomonth(operdate)


    --3m
    --drop table #out_to_3m
	select p.dealid,
		p.id_order,
		eomonth(operdate) as opermonth,
        case 
			when isnull(sum(case when p.description='Расход' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99
			else (sum(case when p.description='Расход' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% trans_to_limit_cur],  
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99			
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% Purchase_to_limit_cur], 
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99	
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% cash_to_limit_cur]
    into #out_to_3m
	from #temp2_provodki_join p
		left join #temp2_pqr_join pd on p.dealid=pd.dealid and p.operdate = pd.reportdate and p.id_order = pd.id_order
	where description='Расход'
		and operdate >=p.reportdate_3m
	group by p.dealid,
		p.id_order,
		eomonth(operdate)



    --1m
    --drop table #out_to_1m
	select p.dealid,
		p.id_order,
		eomonth(operdate) as opermonth,
        case 
			when isnull(sum(case when p.description='Расход' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99
			else (sum(case when p.description='Расход' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% trans_to_limit_cur],  
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99			
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за покупку%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% Purchase_to_limit_cur], 
		case 
			when isnull(sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end),0) = 0 then 0
			when max(pd.Limit_report)=0 or  max(pd.Limit_report) is null then -99	
			else (sum(case when p.description='Расход' and p.transinfo like '%Списание за снятие наличных в АТМ%' then p.tramt else 0 end)*1.0/max(pd.Limit_report)) end [% cash_to_limit_cur]
    into #out_to_1m
	from #temp2_provodki_join p
		left join #temp2_pqr_join pd on p.dealid=pd.dealid and p.operdate = pd.reportdate and p.id_order = pd.id_order
	where description='Расход'
		and operdate >=p.reportdate_1m
	group by p.dealid,
		p.id_order,
		eomonth(operdate)


	CREATE INDEX idx_operdate
	ON #out_to_all  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #out_to_all  (dealid, id_order);

	CREATE INDEX idx_operdate
	ON #out_to_12m  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #out_to_12m  (dealid, id_order);

	CREATE INDEX idx_operdate
	ON #out_to_6m  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #out_to_6m  (dealid, id_order);

	CREATE INDEX idx_operdate
	ON #out_to_3m  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #out_to_3m  (dealid, id_order);

	CREATE INDEX idx_operdate
	ON #out_to_1m  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #out_to_1m  (dealid, id_order);


	--drop table #pre_trans_to_limit_cur
	select 
		t.dealid,
		t.id_order,	
		t.inn,
		[% trans_limit_cur_ever] = max(o1.[% trans_to_limit_cur]),
		[% Purchase_limit_cur_ever] = max(o1.[% Purchase_to_limit_cur]),
		[% cash_limit_cur_ever] = max(o1.[% cash_to_limit_cur]),
		[% trans_limit_cur_12m] = max(o2.[% trans_to_limit_cur]),
		[% Purchase_limit_cur_12m] = max(o2.[% Purchase_to_limit_cur]),
		[% cash_limit_cur_12m] = max(o2.[% cash_to_limit_cur]),
		[% trans_limit_cur_6m] = max(o3.[% trans_to_limit_cur]),
		[% Purchase_limit_cur_6m] = max(o3.[% Purchase_to_limit_cur]),
		[% cash_limit_cur_6m] = max(o3.[% cash_to_limit_cur]),
		[% trans_limit_cur_3m] = max(o4.[% trans_to_limit_cur]),
		[% Purchase_limit_cur_3m] = max(o4.[% Purchase_to_limit_cur]),
		[% cash_limit_cur_3m] = max(o4.[% cash_to_limit_cur]),
		[% trans_limit_cur_1m] = max(o5.[% trans_to_limit_cur]),
		[% Purchase_limit_cur_1m] = max(o5.[% Purchase_to_limit_cur]),
		[% cash_limit_cur_1m] = max(o5.[% cash_to_limit_cur])
	into #pre_trans_to_limit_cur
	from #temp2 as t 
		left join #out_to_all as o1 on t.dealid = o1.dealid and t.id_order = o1.id_order
		left join #out_to_12m as o2 on t.dealid = o2.dealid and t.id_order = o2.id_order
		left join #out_to_6m as o3 on t.dealid = o3.dealid and t.id_order = o3.id_order
		left join #out_to_3m as o4 on t.dealid = o4.dealid and t.id_order = o4.id_order
		left join #out_to_1m as o5 on t.dealid = o5.dealid and t.id_order = o5.id_order
	group by 
		t.dealid,
		t.id_order,
		t.inn

	drop table #out_to_all
	drop table #out_to_12m
	drop table #out_to_6m
	drop table #out_to_3m
	drop table #out_to_1m

	CREATE INDEX idx_operdate
	ON #pre_trans_to_limit_cur  (dealid);

	CREATE INDEX idx_dealid_operdate
	ON #pre_trans_to_limit_cur  (dealid, id_order);

	--select * from #out_to_all

	---------------------------- максимальна к-сть, сума транзакцій за день, тиждень ----------------------------
	--максимальна сума, к-сть транзакцій за день, тиждень протягом усього кредитного періоду 

	--all
	--drop table #max_trans_ever_all
	
	;with p as (  
		select dealid,
			id_order,
			count(tramt) over(partition by dealid, id_order, convert(date, operdate)) trans_day,
			count(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) trans_wk,
			sum(tramt) over(partition by dealid, id_order, convert(date, operdate)) sum_trans_day,
			sum(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) sum_trans_wk
		from #temp2_provodki_join
		where description='Расход') 

	select dealid,
		id_order,
		max(trans_day) [#, max_trans_day],
		max(trans_wk) [#, max_trans_wk],
		max(sum_trans_day) max_trans_day_sum,
		max(sum_trans_day) max_trans_wk_sum
	into #max_trans_ever_all
	from p
	group by dealid,
		id_order


	--12m
	--drop table #max_trans_ever_12m

	;with p as (  
	select dealid,
        id_order,
		count(tramt) over(partition by dealid, id_order, convert(date, operdate)) trans_day,
		count(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) trans_wk,
		sum(tramt) over(partition by dealid, id_order, convert(date, operdate)) sum_trans_day,
		sum(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) sum_trans_wk
	from #temp2_provodki_join 
	where description='Расход'
		and operdate >=reportdate_12m ) 

	select dealid,
		id_order,
		max(trans_day) [#, max_trans_day],
		max(trans_wk) [#, max_trans_wk],
		max(sum_trans_day) max_trans_day_sum,
		max(sum_trans_day) max_trans_wk_sum
	into #max_trans_ever_12m
	from p
	group by dealid,
         id_order

	--6m
	--drop table #max_trans_ever_6m

	;with p as (  
		select dealid,
			id_order,
			count(tramt) over(partition by dealid, id_order, convert(date, operdate)) trans_day,
			count(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) trans_wk,
			sum(tramt) over(partition by dealid, id_order, convert(date, operdate)) sum_trans_day,
			sum(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) sum_trans_wk
		from #temp2_provodki_join 
		where description='Расход'
			and operdate>=reportdate_6m) 

	select dealid,
		id_order,
		max(trans_day) [#, max_trans_day],
		max(trans_wk) [#, max_trans_wk],
		max(sum_trans_day) max_trans_day_sum,
		max(sum_trans_day) max_trans_wk_sum
	into #max_trans_ever_6m
	from p
	group by dealid,
        id_order

	--3m
	--drop table #max_trans_ever_3m

	;with p as (  
		select dealid,
			id_order,
			count(tramt) over(partition by dealid, id_order, convert(date, operdate)) trans_day,
			count(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) trans_wk,
			sum(tramt) over(partition by dealid, id_order, convert(date, operdate)) sum_trans_day,
			sum(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) sum_trans_wk
		from #temp2_provodki_join 
		where description='Расход'
			and operdate >=reportdate_3m) 

	select dealid,
		id_order,
		max(trans_day) [#, max_trans_day],
		max(trans_wk) [#, max_trans_wk],
		max(sum_trans_day) max_trans_day_sum,
		max(sum_trans_day) max_trans_wk_sum
	into #max_trans_ever_3m
	from p
	group by dealid,
         id_order

	--1m
	--drop table #max_trans_ever_1m

	;with p as (  
		select dealid,
			id_order,
			count(tramt) over(partition by dealid, id_order, convert(date, operdate)) trans_day,
			count(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) trans_wk,
			sum(tramt) over(partition by dealid, id_order, convert(date, operdate)) sum_trans_day,
			sum(tramt) over(partition by dealid, id_order, concat(DATEPART(yy,operdate), DATEPART(wk, operdate))) sum_trans_wk
		from #temp2_provodki_join 
		where description='Расход'
			and operdate >=reportdate_1m) 

	select dealid,
		id_order,
		max(trans_day) [#, max_trans_day],
		max(trans_wk) [#, max_trans_wk],
		max(sum_trans_day) max_trans_day_sum,
		max(sum_trans_day) max_trans_wk_sum
	into #max_trans_ever_1m
	from p
	group by dealid,
       id_order

	---------------------------- максимальна к-сть послідовних днів користування карткою ---------------------------- 
		-- 'rn' - порядкова нумерація дат(для однакових дат 'rn' також буде однаковий) ,
		-- 'grp' - різниця між датою та 'rn', якщо дати будуть послідовні, то 'grp' буде однаковий для цих дат

	--All
	--drop table #Max_consecutiveDates_all

	;WITH groups AS (
		SELECT
			distinct convert(date, operdate) operdate,
			dealid,
			id_order,
			DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp2_provodki_join
		where description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_all
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
	        id_order,
	        grp) groups2
	GROUP BY groups2.dealid,
        groups2.id_order

	--12m
	--drop table #Max_consecutiveDates_12m

	;WITH groups AS (
		SELECT
			distinct convert(date, operdate) operdate,
			dealid,
			id_order,
			DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp2_provodki_join
		where operdate >= reportdate_12m
			and description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_12m
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
	        id_order,
	        grp) groups2
	GROUP BY groups2.dealid,
        groups2.id_order

	--6m
	--drop table #Max_consecutiveDates_6m
	;WITH groups AS (
		SELECT
			  distinct convert(date, operdate) operdate,
			  dealid,
			  id_order,
			  DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			  dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp2_provodki_join
		where operdate >= reportdate_6m
			and description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_6m
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
	        id_order,
	        grp) groups2
	GROUP BY groups2.dealid,
        groups2.id_order

	--3m
	--drop table #Max_consecutiveDates_3m
	
	;WITH groups AS (
		SELECT
			distinct convert(date, operdate) operdate,
			dealid,
			id_order,
			DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp2_provodki_join
		where operdate >= reportdate_3m
			and description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_3m
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
	        id_order,
	        grp) groups2
	GROUP BY 
		groups2.dealid,
        groups2.id_order

	--1m
	--drop table #Max_consecutiveDates_1m

	;WITH groups AS (
		SELECT
			distinct convert(date, operdate) operdate,
			dealid,
			id_order,
			DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)) AS rn,
			dateadd(day, -DENSE_RANK() OVER (partition by dealid, id_order ORDER BY convert(date, operdate)), convert(date, operdate)) AS grp
		from #temp2_provodki_join
		where operdate >= reportdate_1m
			and description='Расход')

	select groups2.dealid,
		groups2.id_order,
		max(groups2.consecutiveDates) Max_consecutive_Dates
	into #Max_consecutiveDates_1m
	from(
		select 
			dealid,
			id_order,
			count(*) AS consecutiveDates,
			MIN(operdate) AS minDate,
			MAX(operdate) AS maxDate
		FROM groups
		GROUP BY dealid,
			id_order,
			grp) groups2
	GROUP BY groups2.dealid,
        groups2.id_order


	 ---------------------------- 'найвктивніний' період користування картою ---------------------------- 
	 --ділимо кредитний період на 6 частин і вибираємо найактивніший по к-сті та сумі транзакцій
	 --якщо datebegin < 2014, то починаємо відлік кредитного періоду із 2014-01-01

	--drop table #period_of_payment
	;WITH p1 as
		(select dealid,
			id_order,
			case when operdate < dateadd(dd, DATEDIFF(d,
		                                     IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 1
				 when operdate < dateadd(dd, DATEDIFF(d,
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*2/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 2
				 when operdate < dateadd(dd, DATEDIFF(d, 
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*3/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 3
				 when operdate < dateadd(dd, DATEDIFF(d, 
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*4/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 4
				 when operdate < dateadd(dd, DATEDIFF(d,
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*5/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 5
				 else 6 end credit_period,
			sum(tramt) trans_sum,
			count(tramt) trans_count
		from #temp2_provodki_join
		where description='Расход' and operdate >= '2014-01-01'

		group by dealid,
			id_order,
		    case when operdate < dateadd(dd, DATEDIFF(d,
		                                     IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 1
				when operdate < dateadd(dd, DATEDIFF(d,
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*2/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 2
				when operdate < dateadd(dd, DATEDIFF(d, 
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*3/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 3
				when operdate < dateadd(dd, DATEDIFF(d, 
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*4/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 4
				when operdate < dateadd(dd, DATEDIFF(d,
				                             IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin), date_of_calculation)*5/6 ,IIF(YEAR(datebegin) < 2014, '2014-01-01', datebegin) ) then 5
				else 6 end),
				  
		p2 as (select p1.dealid,
			p1.id_order,
			p1.credit_period,
			p1.trans_sum,
			p1.trans_count,
			max(p1.trans_sum) over(partition by  p1.dealid, p1.id_order) max_trans_sum,
			max(p1.trans_count) over(partition by  p1.dealid, p1.id_order) max_trans_count,
			sum(p1.trans_sum) over(partition by  p1.dealid, p1.id_order) all_trans_sum,
			sum(p1.trans_count) over(partition by  p1.dealid, p1.id_order) all_trans_count,
			max(p1.trans_sum) over(partition by  p1.dealid, p1.id_order)*1.0/sum(p1.trans_sum) over(partition by  p1.dealid, p1.id_order) trans_max_to_all_sum, 
			max(p1.trans_count) over(partition by  p1.dealid, p1.id_order)*1.0/sum(p1.trans_count) over(partition by  p1.dealid, p1.id_order) trans_max_to_all_count
		from p1)

	select p2.dealid,
		p2.id_order,
		max(case when p2.trans_count = max_trans_count then p2.credit_period end) credit_period_max_count,
		max(case when p2.trans_sum = max_trans_sum then p2.credit_period end) credit_period_max_sum,
		trans_max_to_all_sum,
		trans_max_to_all_count

	into #period_of_payment
	from p2
	group by  p2.dealid,
        p2.id_order,
		trans_max_to_all_sum,
	    trans_max_to_all_count

-----------------------------------------------------------------------------------------------------
 ---------------------------- Характеристики користування картою ---------------------------- 

 	--drop table #cc_max_ever
	select p.dealid, 
		p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null then null when p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_ever
	from #temp2_pqr_join p
	group by p.dealid, p.id_order


	--drop table #cc_max_12m
	select p.dealid, 
		p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null then null when p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_12m
	from #temp2_pqr_join p
	where reportdate >= reportdate_12m 
	group by p.dealid, p.id_order


	--drop table #cc_max_6m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_6m
	from #temp2_pqr_join p
	where reportdate >= reportdate_6m
	group by p.id_order, p.dealid


	--drop table #cc_max_3m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_3m
	from #temp2_pqr_join p
	where reportdate >= reportdate_3m
	group by p.id_order, p.dealid


	--drop table #cc_max_1m
	select p.dealid, p.id_order,
		max(p.limit_report) as max_clim,
		max(p.dpd_trash) as max_dpd,
		max(p.outstending) as max_out,
		max(case when p.limit_report is null or p.limit_report = 0 then null else p.outstending/p.limit_report end) as max_usage
	into #CC_max_1m
	from #temp2_pqr_join p
	where reportdate >= reportdate_1m
	group by p.id_order, p.dealid


	--drop table #cc_current
	select p.dealid, p.id_order,
		max(p.outstending) as cur_out
	into #cc_current
	from #temp2_pqr_join p
	where reportdate = convert(date, p.max_date_in_trans)
	group by p.id_order, p.dealid

	--select * from #cc_current


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
	from #temp2_pqr_join t
	group by dealid,
         id_order,
		 date_of_calculation


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
	from #temp2_pqr_join as t
		left join rpa.dbo.pqr_daily p2 on t.dealid=p2.contractid and t.reportdate = DATEADD(d, -1, p2.reportdate)

	
	drop table #temp2_pqr_join

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

	--select * from #cc_preMissed_payment_all_4 where id_order = 10910227
	--select * from #cc_Missed_payment_all where [%, missed_payments] <0

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

	--select * from #cc_Missed_payment_3m

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

	--select * into Risk_test.[dbo].[Scoring_DataMart_CC_trans_old_copy] from Risk_test.[dbo].[Scoring_DataMart_CC_trans]

	if OBJECT_ID('Risk_test.[dbo].[Scoring_DataMart_CC_trans]') is not null drop table Risk_test.[dbo].[Scoring_DataMart_CC_trans]

	--drop table Risk_test.[dbo].[Scoring_DataMart_CC_trans]
	select 
		t.id_order,	
		t.inn,
		#_all_loans = sum(case when t.is_open in (0,1) then 1 else 0 end),
		#_open_loans = sum(case when t.is_open in (1) then 1 else 0 end),
		#_close_loans = sum(case when t.is_open in (0) then 1 else 0 end),
		--сума початкового ліміту
		sum_amountbegin_loans = sum(case when t.is_open in (0,1) then t.AmountbeginUah else 0 end),
		sum_amountbegin_open_loans = sum(case when t.is_open in (1) then t.AmountbeginUah else 0 end),
		sum_amountbegin_close_loans = sum(case when t.is_open in (0) then t.AmountbeginUah else 0 end),
		--сума максимально установленого ліміту(для картки можливий апсел)
		sum_amountmax_all_loans = sum(case when t.is_open in (0,1) then case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end else 0 end),
		sum_amountmax_open_loans = sum(case when t.is_open in (1) then case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end else 0 end),
		sum_amountmax_close_loans = sum(case when t.is_open in (0) then case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end else 0 end),

		max_amountbegin_all_loans = max(t.AmountbeginUah),
		max_amountmax_all_loans =  max(case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end),
		out_to_amountbegin = case when sum(t.AmountbeginUah) is null or sum(t.AmountbeginUah)=0 then 0 else sum(c6.cur_out)*1.0/ sum(t.AmountbeginUah) end,
		out_to_amountmax = case when sum(case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end) is null or sum(case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end)=0 then 0 else sum(c6.cur_out)*1.0/ sum(case when isnull(c1.max_clim,0) > t.AmountbeginUah then isnull(c1.max_clim,0) else t.AmountbeginUah end) end,
		Sum_cur_out = sum(c6.cur_out),
		Max_month_from_date_begin = datediff(month, min(t.DateBegin), date_of_calculation) - case when dateadd(month, datediff(month, min(t.DateBegin), date_of_calculation), min(t.DateBegin)) > date_of_calculation then 1 else 0 end,
		Min_month_from_date_begin = datediff(month, max(t.DateBegin), date_of_calculation) - case when dateadd(month, datediff(month, max(t.DateBegin), date_of_calculation), max(t.DateBegin)) > date_of_calculation then 1 else 0 end,
		From_first_to_last_loan_monthes = datediff(month, min(t.DateBegin),max(t.DateBegin)) - case when dateadd(month, datediff(month, min(t.DateBegin), max(t.DateBegin)), min(t.DateBegin)) > max(t.DateBegin) then 1 else 0 end,
		Max_dpd_ever = max(c1.max_dpd),
		Max_dpd_12m = max(c2.max_dpd),
		Max_dpd_6m = max(c3.max_dpd),
		Max_dpd_3m = max(c4.max_dpd),
		Max_dpd_1m = max(c5.max_dpd),
		MaxCC_out_ever = max(c1.max_out),
		MaxCC_out_12m = max(c2.max_out),
		MaxCC_out_6m = max(c3.max_out),
		MaxCC_out_3m = max(c4.max_out),
		MaxCC_out_1m = max(c5.max_out),
		MaxCC_usage_ever = max(c1.max_usage),
		MaxCC_usage_12m = max(c2.max_usage),
		MaxCC_usage_6m = max(c3.max_usage),
		MaxCC_usage_3m = max(c4.max_usage),
		MaxCC_usage_1m = max(c5.max_usage),
		--avg_number_of_cards = max(s7.avg_number_of_cards),

		Missed_payment_ever = max(s1.all_missed_payments),
		Missed_payment_ever_12m = max(s2.all_missed_payments),
		Missed_payment_ever_6m = max(s3.all_missed_payments),
		Missed_payment_ever_3m = max(s4.all_missed_payments),
		Missed_payment_ever_1m = max(s5.all_missed_payments),
		[Missed_payment_ever,%] = max(s1.[%, missed_payments]),
		[Missed_payment_12m,%] = max(s2.[%, missed_payments]),
		[Missed_payment_6m,%] = max(s3.[%, missed_payments]),
		[Missed_payment_3m,%] = max(s4.[%, missed_payments]),
		[Missed_payment_1m,%] = max(s5.[%, missed_payments]),
		max_dpd_then_pay_all_payment_ever = max(s1.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_12m = max(s2.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_6m = max(s3.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_3m = max(s4.dpd_then_pay_all_payment),
		max_dpd_then_pay_all_payment_1m = max(s5.dpd_then_pay_all_payment),
		max_dpd_then_pay_not_all_payment_ever = max(s1.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_12m = max(s2.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_6m = max(s3.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_3m = max(s4.dpd_then_pay_not_all_payment),
		max_dpd_then_pay_not_all_payment_1m = max(s5.dpd_then_pay_not_all_payment),
		dpd_frequency_ever = max(s1.dpd_frequency),
		dpd_frequency_12m = max(s2.dpd_frequency),
		dpd_frequency_6m = max(s3.dpd_frequency),
		dpd_frequency_3m = max(s4.dpd_frequency),
		dpd_frequency_1m = max(s5.dpd_frequency),

		Month_since_del_more_then_0 =  min(s8.Month_since_del_more_then_0),
		Month_since_del_more_then_7 =  min(s8.Month_since_del_more_then_7),
		Month_since_del_more_then_15 = min(s8.Month_since_del_more_then_15),
		Month_since_del_more_then_30 = min(s8.Month_since_del_more_then_30),
		Month_since_del_more_then_60 = min(s8.Month_since_del_more_then_60),
		Month_since_del_more_then_90 = min(s8.Month_since_del_more_then_90),

		usage_ratio_ever = max(r1.usage_ratio),
		[% Purchase_ratio_ever] = max(r1.[% Purchase_ratio]),
		[% Cash_ratio_ever] = max(r1.[% Cash_ratio]),
		avg_Purchase_sum_ever = max(r1.avg_Purchase_sum),
		max_Purchase_sum_ever = max(r1.max_Purchase_sum),
		Purchase_count_ever = sum(r1.Purchase_count),
		avg_Cash_ever = max(r1.avg_Cash),
		max_Cash_ever = max(r1.max_Cash),
		Cash_count_ever = sum(r1.Cash_count),
		Trans_avg_ever = max(r1.avg_tramt),
		Trans_max_ever = max(r1.max_tramt),
		Trans_count_ever = sum(r1.trans_count),
		cafe_client_ever = sum(r1.cafe_client),
		shop_client_ever = sum(r1.shop_client),
		supermarket_client_ever = sum(r1.supermarket_client),
		taxi_client_ever = sum(r1.taxi_client),
		credit_sanc_count_ever = sum(r1.credit_sanc_count),
		overdraft_sanc_count_ever = sum(r1.overdraft_sanc_count),
		fine_count_ever = sum(r1.fine_count),
		commission_count_ever = sum(r1.commission_count),
		peni_count_ever = sum(r1.peni_count),
		credit_sanc_sum_ever = sum(r1.credit_sanc_sum),
		overdraft_sanc_sum_ever = sum(r1.overdraft_sanc_sum),
		fine_sum_ever = sum(r1.fine_sum),
		commission_sum_ever = sum(r1.commission_sum),
		peni_sum_ever = sum(r1.peni_sum),

		usage_ratio_12m = max(r2.usage_ratio),
		[% Purchase_ratio_12m] = max(r2.[% Purchase_ratio]),
		[% Cash_ratio_12m] = max(r2.[% Cash_ratio]),
		avg_Purchase_sum_12m = max(r2.avg_Purchase_sum),
		max_Purchase_sum_12m = max(r2.max_Purchase_sum),
		Purchase_count_12m = sum(r2.Purchase_count),
		avg_Cash_12m = max(r2.avg_Cash),
		max_Cash_12m = max(r2.max_Cash),
		Cash_count_12m = sum(r2.Cash_count),
		trans_avg_12m = max(r2.avg_tramt),
		trans_max_12m = max(r2.max_tramt),
		trans_count_12m = sum(r2.trans_count),
		cafe_client_12m = sum(r2.cafe_client),
		shop_client_12m = sum(r2.shop_client),
		supermarket_client_12m = sum(r2.supermarket_client),
		taxi_client_12m = sum(r2.taxi_client),
		credit_sanc_count_12m = sum(r2.credit_sanc_count),
		overdraft_sanc_count_12m = sum(r2.overdraft_sanc_count),
		fine_count_12m = sum(r2.fine_count),
		commission_count_12m = sum(r2.commission_count),
		peni_count_12m = sum(r2.peni_count),
		credit_sanc_sum_12m = sum(r2.credit_sanc_sum),
		overdraft_sanc_sum_12m = sum(r2.overdraft_sanc_sum),
		fine_sum_12m = sum(r2.fine_sum),
		commission_sum_12m = sum(r2.commission_sum),
		peni_sum_12m = sum(r2.peni_sum),

		usage_ratio_6m = max(r3.usage_ratio),
		[% Purchase_ratio_6m] = max(r3.[% Purchase_ratio]),
		[% Cash_ratio_6m] = max(r3.[% Cash_ratio]),
		avg_Purchase_sum_6m = max(r3.avg_Purchase_sum),
		max_Purchase_sum_6m = max(r3.max_Purchase_sum),
		Purchase_count_6m = sum(r3.Purchase_count),
		avg_Cash_6m = max(r3.avg_Cash),
		max_Cash_6m = max(r3.max_Cash),
		Cash_count_6m = sum(r3.Cash_count),
		trans_avg_6m = max(r3.avg_tramt),
		trans_max_6m = max(r3.max_tramt),
		trans_count_6m = sum(r3.trans_count),
		cafe_client_6m = sum(r3.cafe_client),
		shop_client_6m = sum(r3.shop_client),
		supermarket_client_6m = sum(r3.supermarket_client),
		taxi_client_6m = sum(r3.taxi_client),
		credit_sanc_count_6m = sum(r3.credit_sanc_count),
		overdraft_sanc_count_6m = sum(r3.overdraft_sanc_count),
		fine_count_6m = sum(r3.fine_count),
		commission_count_6m = sum(r3.commission_count),
		peni_count_6m = sum(r3.peni_count),
		credit_sanc_sum_6m = sum(r3.credit_sanc_sum),
		overdraft_sanc_sum_6m = sum(r3.overdraft_sanc_sum),
		fine_sum_6m = sum(r3.fine_sum),
		commission_sum_6m = sum(r3.commission_sum),
		peni_sum_6m = sum(r3.peni_sum),

		usage_ratio_3m = max(r4.usage_ratio),
		[% Purchase_ratio_3m] = max(r4.[% Purchase_ratio]),
		[% Cash_ratio_3m] = max(r4.[% Cash_ratio]),
		avg_Purchase_sum_3m = max(r4.avg_Purchase_sum),
		max_Purchase_sum_3m = max(r4.max_Purchase_sum),
		Purchase_count_3m = sum(r4.Purchase_count),
		avg_Cash_3m = max(r4.avg_Cash),
		max_Cash_3m = max(r4.max_Cash),
		Cash_count_3m = sum(r4.Cash_count),
		trans_avg_3m = max(r4.avg_tramt),
		trans_max_3m = max(r4.max_tramt),
		trans_count_3m = sum(r4.trans_count),
		cafe_client_3m = sum(r4.cafe_client),
		shop_client_3m = sum(r4.shop_client),
		supermarket_client_3m = sum(r4.supermarket_client),
		taxi_client_3m = sum(r4.taxi_client),
		credit_sanc_count_3m = sum(r4.credit_sanc_count),
		overdraft_sanc_count_3m = sum(r4.overdraft_sanc_count),
		fine_count_3m = sum(r4.fine_count),
		commission_count_3m = sum(r4.commission_count),
		peni_count_3m = sum(r4.peni_count),
		credit_sanc_sum_3m = sum(r4.credit_sanc_sum),
		overdraft_sanc_sum_3m = sum(r4.overdraft_sanc_sum),
		fine_sum_3m = sum(r4.fine_sum),
		commission_sum_3m = sum(r4.commission_sum),
		peni_sum_3m = sum(r4.peni_sum),

		usage_ratio_1m = max(r5.usage_ratio),
		[% Purchase_ratio_1m] = max(r5.[% Purchase_ratio]),
		[% Cash_ratio_1m] = max(r5.[% Cash_ratio]),
		avg_Purchase_sum_1m = max(r5.avg_Purchase_sum),
		max_Purchase_sum_1m = max(r5.max_Purchase_sum),
		Purchase_count_1m = sum(r5.Purchase_count),
		avg_Cash_1m = max(r5.avg_Cash),
		max_Cash_1m = max(r5.max_Cash),
		Cash_count_1m = sum(r5.Cash_count),
		trans_avg_1m = max(r5.avg_tramt),
		trans_max_1m = max(r5.max_tramt),
		trans_count_1m = sum(r5.trans_count),
		cafe_client_1m = sum(r5.cafe_client),
		shop_client_1m = sum(r5.shop_client),
		supermarket_client_1m = sum(r5.supermarket_client),
		taxi_client_1m = sum(r5.taxi_client),
		credit_sanc_count_1m = sum(r5.credit_sanc_count),
		overdraft_sanc_count_1m = sum(r5.overdraft_sanc_count),
		fine_count_1m = sum(r5.fine_count),
		commission_count_1m = sum(r5.commission_count),
		peni_count_1m = sum(r5.peni_count),
		credit_sanc_sum_1m = sum(r5.credit_sanc_sum),
		overdraft_sanc_sum_1m = sum(r5.overdraft_sanc_sum),
		fine_sum_1m = sum(r5.fine_sum),
		commission_sum_1m = sum(r5.commission_sum),
		peni_sum_1m = sum(r5.peni_sum),

		max_date_diff_purch_ever = max(d1.max_date_diff_purch),
		max_date_diff_cash_ever = max(d1.max_date_diff_cash),
		avg_date_diff_purch_ever = max(d1.min_date_diff_purch),
		avg_date_diff_cash_ever = max(d1.min_date_diff_cash),
		max_date_diff_purch_12m = max(d2.max_date_diff_purch),
		max_date_diff_cash_12m = max(d2.max_date_diff_cash),
		avg_date_diff_purch_12m = max(d2.min_date_diff_purch),
		avg_date_diff_cash_12m = max(d2.min_date_diff_cash),
		max_date_diff_purch_6m = max(d3.max_date_diff_purch),
		max_date_diff_cash_6m = max(d3.max_date_diff_cash),
		avg_date_diff_purch_6m = max(d3.min_date_diff_purch),
		avg_date_diff_cash_6m = max(d3.min_date_diff_cash),
		max_date_diff_purch_3m = max(d4.max_date_diff_purch),
		max_date_diff_cash_3m = max(d4.max_date_diff_cash),
		avg_date_diff_purch_3m = max(d4.min_date_diff_purch),
		avg_date_diff_cash_3m = max(d4.min_date_diff_cash),
		max_date_diff_purch_1m = max(d5.max_date_diff_purch),
		max_date_diff_cash_1m = max(d5.max_date_diff_cash),
		avg_date_diff_purch_1m = max(d5.min_date_diff_purch),
		avg_date_diff_cash_1m = max(d5.min_date_diff_cash),

		[% trans_limit_cur_ever] = max(o1.[% trans_limit_cur_ever]),
		[% Purchase_limit_cur_ever] = max(o1.[% Purchase_limit_cur_ever]),
		[% cash_limit_cur_ever] = max(o1.[% cash_limit_cur_ever]),
		[% trans_limit_cur_12m] = max(o1.[% trans_limit_cur_12m]),
		[% Purchase_limit_cur_12m] = max(o1.[% Purchase_limit_cur_12m]),
		[% cash_limit_cur_12m] = max(o1.[% cash_limit_cur_12m]),
		[% trans_limit_cur_6m] = max(o1.[% trans_limit_cur_6m]),
		[% Purchase_limit_cur_6m] = max(o1.[% Purchase_limit_cur_6m]),
		[% cash_limit_cur_6m] = max(o1.[% cash_limit_cur_6m]),
		[% trans_limit_cur_3m] = max(o1.[% trans_limit_cur_3m]),
		[% Purchase_limit_cur_3m] = max(o1.[% Purchase_limit_cur_3m]),
		[% cash_limit_cur_3m] = max(o1.[% cash_limit_cur_3m]),
		[% trans_limit_cur_1m] = max(o1.[% trans_limit_cur_1m]),
		[% Purchase_limit_cur_1m] = max(o1.[% Purchase_limit_cur_1m]),
		[% cash_limit_cur_1m] = max(o1.[% cash_limit_cur_1m]),

		 [#, max_trans_day_ever] = max(m1.[#, max_trans_day]),
		 [#, max_trans_wk_ever] = max(m1.[#, max_trans_wk]),
		 max_trans_day_sum_ever = max(m1.max_trans_day_sum),
		 max_trans_wk_sum_ever = max(m1.max_trans_wk_sum),
		 [#, max_trans_day_12m] = max(m2.[#, max_trans_day]),
		 [#, max_trans_wk_12m] = max(m2.[#, max_trans_wk]),
		 max_trans_day_sum_12m = max(m2.max_trans_day_sum),
		 max_trans_wk_sum_12m = max(m2.max_trans_wk_sum),
		 [#, max_trans_day_6m] = max(m3.[#, max_trans_day]),
		 [#, max_trans_wk_6m] = max(m3.[#, max_trans_wk]),
		 max_trans_day_sum_6m = max(m3.max_trans_day_sum),
		 max_trans_wk_sum_6m = max(m3.max_trans_wk_sum),
		 [#, max_trans_day_3m] = max(m4.[#, max_trans_day]),
		 [#, max_trans_wk_3m] = max(m4.[#, max_trans_wk]),
		 max_trans_day_sum_3m = max(m4.max_trans_day_sum),
		 max_trans_wk_sum_3m = max(m4.max_trans_wk_sum),
		 [#, max_trans_day_1m] = max(m5.[#, max_trans_day]),
		 [#, max_trans_wk_1m] = max(m5.[#, max_trans_wk]),
		 max_trans_day_sum_1m = max(m5.max_trans_day_sum),
		 max_trans_wk_sum_1m = max(m5.max_trans_wk_sum),
		 Max_consecutive_Dates_ever = max(v1.Max_consecutive_Dates),
		 Max_consecutive_Dates_12m = max(v2.Max_consecutive_Dates),
		 Max_consecutive_Dates_6m = max(v3.Max_consecutive_Dates),
		 Max_consecutive_Dates_3m = max(v4.Max_consecutive_Dates),
		 Max_consecutive_Dates_1m = max(v5.Max_consecutive_Dates),
		 credit_period_max_count = max(p.credit_period_max_count),
		 credit_period_max_sum = max(p.credit_period_max_sum)


	into Scoring__trans
	from #temp2 as t 
		left join #CC_max_ever as c1 on t.dealid = c1.dealid and t.id_order = c1.id_order
		left join #CC_max_12m as c2 on t.dealid = c2.dealid	and t.id_order = c2.id_order
		left join #CC_max_6m as c3 on t.dealid = c3.dealid and t.id_order = c3.id_order
		left join #CC_max_3m as c4 on t.dealid = c4.dealid and t.id_order = c4.id_order
		left join #CC_max_1m as c5 on t.dealid = c5.dealid and t.id_order = c5.id_order
		left join #CC_current as c6 on t.dealid = c6.dealid and t.id_order = c6.id_order
		left join #cc_Missed_payment_all as s1 on t.dealid = s1.contractid and t.id_order = s1.id_order
		left join #cc_Missed_payment_12m as s2 on t.dealid = s2.contractid	and t.id_order = s2.id_order
		left join #cc_Missed_payment_6m as s3 on t.dealid = s3.contractid and t.id_order = s3.id_order
		left join #cc_Missed_payment_3m as s4 on t.dealid = s4.contractid and t.id_order = s4.id_order
		left join #cc_Missed_payment_1m as s5 on t.dealid = s5.contractid and t.id_order = s5.id_order
		--left join #avg_number_of_cards as s7 on t.dealid = s7.dealid and t.id_order = s7.id_order
		left join #cc_Month_since_del_more_then as s8 on t.dealid = s8.dealid and t.id_order = s8.id_order
		left join #usage_ratio_all as r1 on t.dealid = r1.dealid and t.id_order = r1.id_order 
		left join #usage_ratio_12m as r2 on t.dealid = r2.dealid and t.id_order = r2.id_order
		left join #usage_ratio_6m as r3 on t.dealid = r3.dealid and t.id_order = r3.id_order
		left join #usage_ratio_3m as r4 on t.dealid = r4.dealid and t.id_order = r4.id_order
		left join #usage_ratio_1m as r5 on t.dealid = r5.dealid and t.id_order = r5.id_order 
		left join #date_diff_all as d1 on t.dealid = d1.dealid and t.id_order = d1.id_order 
		left join #date_diff_12m as d2 on t.dealid = d2.dealid and t.id_order = d2.id_order 
		left join #date_diff_6m as d3 on t.dealid = d3.dealid and t.id_order = d3.id_order 
		left join #date_diff_3m as d4 on t.dealid = d4.dealid and t.id_order = d4.id_order 
		left join #date_diff_1m as d5 on t.dealid = d5.dealid and t.id_order = d5.id_order 
		left join #pre_trans_to_limit_cur as o1 on t.dealid = o1.dealid and t.id_order = o1.id_order
		left join #max_trans_ever_all m1 on t.dealid = m1.dealid and t.id_order = m1.id_order
		left join #max_trans_ever_12m m2 on t.dealid = m2.dealid and t.id_order = m2.id_order
		left join #max_trans_ever_6m m3 on t.dealid = m3.dealid and t.id_order = m3.id_order
		left join #max_trans_ever_3m m4 on t.dealid = m4.dealid and t.id_order = m4.id_order
		left join #max_trans_ever_1m m5 on t.dealid = m5.dealid and t.id_order = m5.id_order
		left join #Max_consecutiveDates_all v1 on t.dealid = v1.dealid and t.id_order = v1.id_order
		left join #Max_consecutiveDates_12m v2 on t.dealid = v2.dealid and t.id_order = v2.id_order
		left join #Max_consecutiveDates_6m v3 on t.dealid = v3.dealid and t.id_order = v3.id_order
		left join #Max_consecutiveDates_3m v4 on t.dealid = v4.dealid and t.id_order = v4.id_order
		left join #Max_consecutiveDates_1m v5 on t.dealid = v5.dealid and t.id_order = v5.id_order
		left join #period_of_payment p on t.dealid = p.dealid and t.id_order = p.id_order
	group by 
		t.id_order,
		t.inn,
		t.date_of_calculation



