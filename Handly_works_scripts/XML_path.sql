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
 
 
-----------------------------------------------------------------------------------------------------
 DECLARE @rows nvarchar(max) = '[A],[B],[C]';
DECLARE @cols nvarchar(max);

SELECT LTRIM(RTRIM(j.value)) FROM STRING_SPLIT(@rows, ',') j

SET @cols = STUFF((SELECT ', ' + (col) 
                   FROM (SELECT LTRIM(RTRIM(j.value)) col FROM STRING_SPLIT(@rows, ',') j) Foo
            FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(MAX)') 
           ,1,2,'');

SELECT @cols;

SET @cols = STUFF((SELECT ', ' + ('SUM(' + col + ')') 
                   FROM (SELECT LTRIM(RTRIM(j.value)) col FROM STRING_SPLIT(@rows, ',') j) Foo
            FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(MAX)') 
           ,1,2,'');

SELECT @cols;

SET @cols = STUFF((SELECT ', ' + ('SUM(' + col + ') ' + col) 
                   FROM (SELECT LTRIM(RTRIM(j.value)) col FROM STRING_SPLIT(@rows, ',') j) Foo
            FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(MAX)') 
           ,1,2,'');

SELECT @cols;
GO

		   
		   
		   
| (No column name) |
| :--------------- |
| [A]              |
| [B]              |
| [C]              |

| (No column name) |
| :--------------- |
| [A], [B], [C]    |

| (No column name)             |
| :--------------------------- |
| SUM([A]), SUM([B]), SUM([C]) |

| (No column name)                         |
| :--------------------------------------- |
| SUM([A]) [A], SUM([B]) [B], SUM([C]) [C] |		   
