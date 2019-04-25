SELECT QUOTENAME(name)
FROM sys.objects
WHERE type='P' AND OBJECT_DEFINITION([object_id]) LIKE N'%i_vintage%';

SELECT QUOTENAME(name)
FROM sys.objects
WHERE type='P' AND OBJECT_DEFINITION([object_id]) LIKE N'%Link_IS_AC%';

SELECT DISTINCT
       o.name AS Object_Name,
       o.type_desc
  FROM sys.sql_modules m
       INNER JOIN
       sys.objects o
         ON m.object_id = o.object_id
 WHERE m.definition Like '%y_products%';

--table
 SELECT * FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE '%neg%'
