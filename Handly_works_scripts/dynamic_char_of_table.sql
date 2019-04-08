BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
if object_id('tempdb..#t') is not null
drop table #t

SELECT Product as Product
	  into #t
  FROM table_name
  WHERE [portfolioType] ='Not Define'
  and product not like '%8%кл%'
and product not like '%IsCard%'
and product not like '%KI%POT%'
and product not like '%СС_over_UCB%' 
and product not like 'МСБ-КИ%ФЛ 980' 
and product not like '%8%KI%'
and product not like '%2%кл%'
  --drop table ##not,#t
if object_id('tempdb..##not') is not null
drop table ##not


declare @len varchar(60)
set @len = (select max(len(Product)) from #t)
--select @len
 exec('create table ##not
(Product varchar('+@len+'),
Qty TINYINT,
Min_datebegin varchar(13),
Max_datebegin varchar(13))') 

insert into ##not
SELECT Product as Product
      ,count(*) AS 'Qty'
	   ,'   '+format(MIN([datebegin]),'dd-MM-yyyy') AS 'Min_datebegin'
	  ,'   '+format(MAX([datebegin]),'dd-MM-yyyy') AS 'Max_datebegin'
     -- ,'   '+convert(varchar(10),MIN([datebegin])) AS 'Min_datebegin'
	 -- ,'   '+convert(varchar(10),MAX([datebegin])) AS 'Max_datebegin'
  FROM table_name
  WHERE [portfolioType] ='Not Define'
  and product not like '%8%кл%'
and product not like '%IsCard%'
and product not like '%KI%POT%'
and product not like '%СС_over_UCB%' 
and product not like 'МСБ-КИ%ФЛ 980' 
and product not like '%8%KI%'
and product not like '%2%кл%'
  GROUP BY product
  order by 4 desc,1

  -----------send all this dich------------------------------------------------------------------------------------
declare @subje as varchar(50)
declare @body_text as varchar(50)
set @subje = 'Undefined products' 
set @body_text = 'Information about undefined products:  
'
                                                                                                                                            
EXECUTE msdb.dbo.sp_send_dbmail
          @profile_name = 'JobReport'
          ,@recipients = 'Elena.Sokol@alfabank.kiev.ua;'
		  ,@copy_recipients = ' '
		  ,@blind_copy_recipients = ''
          ,@subject = @subje
		  ,@body= @body_text
		  ,@query = 'SELECT * from ##not'
