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

						
------------ diff variance of letters -------------------
						
		declare @subje_1 as varchar(50)
		declare @body_text_1 as varchar(100)
		set @subje_1 = 'variant1' 
		set @body_text_1 = 'variant1'
                                                                                                                                            
		EXECUTE msdb.dbo.sp_send_dbmail
			@profile_name = 'Fin_Class_Calculation'
			,@recipients = ''  
			,@copy_recipients = 'Elena.Sokol@alfabank.kiev.ua; '
			,@blind_copy_recipients = ''
			,@subject = @subje_1
			,@body= @body_text_1

	END

else 

	begin
		
		if (select convert(date, max(realdate)) from provodki where month(realdate)= (month(getdate())-1)) <> (select eomonth(dateadd(m, -1,getdate())))
       
	   begin 
			declare @subje_2 as varchar(50)
			declare @body_text_2 as varchar(500)
			set @subje_2 = 'variant2' 
			set @body_text_2 = 'no data in table'
                                                                                                                                            
			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name = 'Fin_Class_Calculation'
				,@recipients = 'Elena.Sokol@alfabank.kiev.ua'  
				,@copy_recipients = ''
				,@blind_copy_recipients = ''
				,@subject = @subje_2
				,@body= @body_text_2
		end


	else 
																	      

																	      
	begin
		
		if (select top 1 RDATE from
	      openquery(Bbbb,'select * from dbo.v_tmp'))  <> (select eomonth(dateadd(m, -1,getdate())))
       
	   begin 
			declare @subje_3 as varchar(50)
			declare @body_text_3 as varchar(100)
			set @subje_3 = 'variant3' 
			set @body_text_3 = 'no data in table 'dbo.v_tmp'.'
                                                                                                                                            
			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name = 'Fin_Class_Calculation'
				,@recipients = 'Elena.Sokol@alfabank.kiev.ua'  
				,@copy_recipients = ''
				,@blind_copy_recipients = ''
				,@subject = @subje_3
				,@body= @body_text_3
		end
