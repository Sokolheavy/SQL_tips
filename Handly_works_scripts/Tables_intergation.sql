----------------------------- tables selecting ----------------------------------------
--drop table #temptable
  SELECT TABLE_NAME ,ROW_NUMBER() over(order by TABLE_NAME asc) rn
  into #temptable
FROM  INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = 'RPA'
and TABLE_NAME like 'temp[0-9][_]%'
AND   COLUMN_NAME LIKE '%enrolled%'

--select * from #temptable
--select * from #new_table


-----------create table with names of tables and their columns----------
--drop table #new_table
create table #new_table(id int IDENTITY(1,1) PRIMARY KEY,
                         tablename varchar(30),
                         max_date varchar(10))

insert into #new_table(tablename) 
select TABLE_NAME from #temptable


----------from loops take value from tables-----------------------------------
		declare @i int
		set @i = 1
		while (select @i ) <= (select count(*) from #temptable)
		begin 

		declare @nametable_temp varchar(60)
			set @nametable_temp = (select TABLE_NAME from #temptable where rn=@i)
			exec('update #new_table
                set max_date= (select max(enrolled) from '+@nametable_temp+')
				where id='+@i)
   
			set @i = @i+1

		end

-----delete tables---------------------
declare @i int
		set @i = 1
		while (select @i ) <= (select count(*) from #temptable)
		begin 

		declare @nametable_temp varchar(60)
			set @nametable_temp = (select TABLE_NAME from #temptable where rn=@i)
			exec('drop table  '+@nametable_temp)
			set @i = @i+1

		end
