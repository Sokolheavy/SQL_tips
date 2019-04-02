select t.CONTRAGENTID CONTRAGENTID
       ,t.inn IDENTCODE
	   ,t.LOANDEALID LOANDEALID
	   ,t.inc inc
	   ,t.dti dti
	   ,case when t.inc<2500 then 4
	         when t.inc<3000 then (iif(t.dti<0.4,3,4))
			 when t.inc<3500 then (iif(t.dti<0.3,2,iif(t.dti<0.5,3,4)))
			 when t.inc<5000 then (iif(t.dti<0.5,2,iif(t.dti<0.6,3,4)))
			 when t.inc<10000 then (iif(t.dti<0.6,2,iif(t.dti<0.7,3,4)))
			 when t.inc<18000 then (iif(t.dti<0.7,2,iif(t.dti<0.8,3,4)))
			 when t.inc>18000 then (iif(t.dti<0.8,2,3))
			 else 4 end class
        ,'0' as fromdate
		,'0' as inputdate
		,'0' as Class2
		,'0' as Class3
		,'1' as notisgroup
into #Union_class_High
from
(select CONTRAGENTID
       ,inn
	   ,LOANDEALID
	   ,inc
       ,case when inc is not null and inc<>0 and Payment is not null and Payment<>0 then Payment/inc 
		     else 0 end dti
from #Union
where AmountType='High')t
