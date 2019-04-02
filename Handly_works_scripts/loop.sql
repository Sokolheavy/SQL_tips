select 
			ROW_NUMBER() over(partition by inputdate order by contragentid asc) rn, 
			* 
		into #NBU_clas_from_SAS
		from risk_test.dbo.NBU_clas_from_SAS_07

		declare @i int
		set @i = 0

		while (select *  from openquery(B2ORACLE, 'select count(*) from NBU_Class_from_SAS' )) < (select count(*) from risk_test.dbo.NBU_clas_from_SAS_07)
		begin 
			insert openquery(B2ORACLE,
			'select * from NBU_Class_from_SAS where rownum<1')
			select CONTRAGENTID,	
				class,
				note,	
				inputdate,	
				calctype
			from #NBU_clas_from_SAS t
			where rn >= 1000*@i
				and rn < 1000*(@i+1)

			set @i = @i+1

		end
