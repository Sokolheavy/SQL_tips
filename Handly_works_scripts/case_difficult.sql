SELECT
  ID,Name,Salary
FROM Employees
ORDER BY
  CASE WHEN Salary>=2500 THEN 1 ELSE 0 END, 
  Name 

SELECT
  ID,Name,Salary,

  CASE
    WHEN DepartmentID IN(1,2) THEN 'A'
    WHEN DepartmentID=3 THEN
                          CASE PositionID 
                            WHEN 3 THEN 'B-1'
                            WHEN 4 THEN 'B-2'
                          END
    ELSE 'C'
  END Demo1,

  IIF(DepartmentID IN(1,2),'A',
    IIF(DepartmentID=3,CASE PositionID WHEN 3 THEN 'B-1' WHEN 4 THEN 'B-2' END,'C')) Demo2

FROM Employees
