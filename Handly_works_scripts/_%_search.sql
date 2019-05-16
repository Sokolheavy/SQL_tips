--search with special symbol
select * from #table1 where name like '%10!%%' ESCAPE '!'
select * from #table1 where name like '%10[%]%' 


--table in database
SELECT      c.name  AS 'ColumnName'
            ,t.name AS 'TableName'
FROM        sys.columns c
JOIN        sys.tables  t   ON c.object_id = t.object_id
WHERE       c.name LIKE '%regi%'
ORDER BY    TableName
            ,ColumnName;
