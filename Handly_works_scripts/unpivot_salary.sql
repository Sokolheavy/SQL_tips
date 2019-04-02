
	select t.inn,
		round(avg(t.val),2) salary 
	into #salary
	from 
		(select inn,
			val 
		from [dhazardbp01\hazard].predata.[dbo].[UCB_PI_Customers_predate]
		unpivot (val for col in ( ZP_last_1M
								  , ZP_last_2M
								  , ZP_last_3M
								  , ZP_last_4M
								  , ZP_last_5M 
								  , ZP_last_6M)) up)t
	join 
		(select inn
		from [dhazardbp01\hazard].predata.[dbo].[UCB_PI_Customers_predate]
		where coalesce(ZP_last_1M, ZP_last_2M, ZP_last_3M, 0) > 0
		and ((case when coalesce(ZP_last_1M,0) = 0 then 0 else 1 end)+
		     (case when coalesce(ZP_last_2M,0) = 0 then 0 else 1 end)+
			 (case when coalesce(ZP_last_3M,0) = 0 then 0 else 1 end)+
			 (case when coalesce(ZP_last_4M,0) = 0 then 0 else 1 end)+
			 (case when coalesce(ZP_last_5M,0) = 0 then 0 else 1 end)+
			 (case when coalesce(ZP_last_6M,0) = 0 then 0 else 1 end)) > 2
		and inn not in ('9999999999','0000000000')
		)t1 on t1.inn=t.inn
	  group by t.inn
