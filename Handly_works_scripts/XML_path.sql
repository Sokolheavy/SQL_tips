--drop table #reject_rules
SELECT t1.id ,
		reject_rule = STUFF((SELECT ',' + code
		FROM #All_rejects_union As T2
		WHERE T2.ID = T1.id 
		ORDER BY code
		FOR XML PATH ('')), 1, 1, '')  

		into #reject_rules
from #All_rejects_union t1 
 group by t1.id
