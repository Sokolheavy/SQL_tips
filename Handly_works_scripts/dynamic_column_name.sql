declare @j varchar(max)
declare @text varchar(max) set @text=''
declare @query varchar(max) set @query=''
declare @k int 
set @k=2
set @text='select f.id
			,f.subproduct	
			,f.clim	
			,f.firstlimit	
			,coalesce(f.BIL_limit_clim,f1.BIL_limit_clim) BIL_limit_clim'
      
--declare @j varchar(max)
   while (@k <=36)
   begin
   set @j=convert(varchar(max),@k) 
   set @query = ',f.B'+@j+'OpDate	
				,f.FPDMob'+@j+'Date
        ,coalesce(f.Mob'+@j+'_limit_clim ,f1.Mob'+@j+'_limit_clim) Mob'+@j+'_limit_clim
				,coalesce(f.Mob'+@j+'_Limit,f1.Mob'+@j+'_Limit) Mob'+@j+'_Limit'
        
   set @k=@k+1
   set @text= @text+ @query
   end
   set @text =@text + '
 f.Decision_Limit	,f.group_new	,f.subgroup_new	,f.Сведение	,f.Value_NBSM_Parameter	,f.Point_of_sale
    into Trash.dbo.test_fpd_rest
    from Trash.dbo.tfpd12_rest f '


	exec( @text) 

	--select * from  Trash.dbo.test_fpd_rest
