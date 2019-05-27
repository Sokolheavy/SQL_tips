SET NOCOUNT ON
USE BigDB
go
--================================================================================
-- In this script the rules change: When you have earned yourself a
-- Christmas present, you cannot start earning for a new one within
-- the next ten days. In practice, this means we only have to consider
-- the end-of-day standing, and therefore we can loop over the days
-- of the year.

-- Some constants (and debug variables).
DECLARE @year        char(4)       = '2018',
        @xmaslimit   decimal(14,2) = 1000000,
        @maxpresents tinyint       = 10,
        @waitperiod  tinyint       = 10,
        @orderdate   date,
        @starttime   datetime2(3) = sysdatetime(),
        @tookms      int

-- We use this table to compute the number of presents.
CREATE TABLE #presents 
             (CustomerID    int           NOT NULL PRIMARY KEY,
              AccumSum      decimal(14,2) NOT NULL,
              NoOfPresents  tinyint       NOT NULL,
              LatestPresent date          NOT NULL
)

-- Loop over the days in the year.
SELECT @orderdate = @year + '0101'
WHILE year(@orderdate) = @year
BEGIN
   -- Compute the totals for today and merge it with #presents.
   MERGE #presents p
   USING (SELECT CustomerID, SUM(TotalAmount) AS DayAmount
          FROM   dbo.BigOrders
          WHERE  OrderDate = @orderdate
          GROUP  BY CustomerID) AS B ON p.CustomerID = B.CustomerID
   WHEN NOT MATCHED BY TARGET THEN
      INSERT (CustomerID, AccumSum, NoOfPresents, LatestPresent)
         VALUES (B.CustomerID,
                 IIF(B.DayAmount < @xmaslimit, B.DayAmount, 0),
                 IIF(B.DayAmount < @xmaslimit, 0, 1),
                 IIF(B.DayAmount < @xmaslimit, '19000101', @orderdate))
   WHEN MATCHED AND 
        p.NoOfPresents < @maxpresents AND 
        datediff(DAY, p.LatestPresent, @orderdate) > @waitperiod THEN
      UPDATE SET
      AccumSum      = CASE WHEN p.AccumSum + B.DayAmount < @xmaslimit
                           THEN p.AccumSum + B.DayAmount
                           ELSE 0
                      END,
      NoOfPresents  = CASE WHEN p.AccumSum + B.DayAmount < @xmaslimit
                           THEN p.NoOfPresents
                           ELSE p.NoOfPresents + 1
                      END, 
      LatestPresent = CASE WHEN p.AccumSum + B.DayAmount < @xmaslimit
                           THEN p.LatestPresent
                           ELSE @orderdate
                      END
   ;

   -- Move to the next date.
   SELECT @orderdate = dateadd(DAY, 1, @orderdate)
END

SELECT @tookms = datediff(ms, @starttime, sysdatetime())

-- Return the total number of presents.
SELECT totalnoofpresents = SUM(NoOfPresents), tookms = @tookms
FROM   #presents

-- A query to return the result, together with some general 
-- statistics about the orders.
; WITH OrderData AS (
    SELECT CustomerID, COUNT(*) AS NoOfOrders, 
           SUM(TotalAmount) AS TotalYearAmount, 
           AVG(TotalAmount) AS AvgOrderAmount
    FROM   dbo.BigOrders
    WHERE  OrderDate >= @year + '0101'
      AND  OrderDate <= @year + '1231'
    GROUP  BY CustomerID
)
SELECT C.CustomerName, p.CustomerID, p.NoOfPresents, OD.NoOfOrders, 
       OD.TotalYearAmount, OD.AvgOrderAmount, p.AccumSum, p.LatestPresent
FROM   #presents p
JOIN   OrderData OD ON p.CustomerID = OD.CustomerID
JOIN   Customers C ON p.CustomerID = C.CustomerID
ORDER BY OD.TotalYearAmount DESC, p.CustomerID
go
-- Drop temp tables.
DROP TABLE #presents

