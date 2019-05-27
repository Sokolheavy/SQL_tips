SET NOCOUNT ON
USE BigDB
go
--================================================================================
-- This last demo looks at a different problem: Customers will get
-- Christmas presents depending on how much they have ordered for
-- through the year. The rule is this: every time they have
-- accumulated one million in order sum, they are entitled to a present.
-- Once they reach one million, they start over on zero. Note that it does
-- not matter if they are on 999000 and their next order is for 1000
-- or 100000, they will always restart on zero. There is also a total
-- cap: you cannot get more than ten presents.
--    You might be able to devise a solution that performs this with a
-- single SELECT, but it is not straightforward. Instead we will solve
-- this by looping. This first example loops over all customers, and
-- the over orders for the given year for each customer.

-- Constants.
DECLARE @year         char(4)       = '2018',
        @xmaslimit    decimal(14,2) = 1000000,
        @maxpresents  tinyint       = 10

-- Loop variables.
DECLARE @CustID       int,
        @OrderAmount  decimal(10,2),
        @AccumSum     decimal(10,2),
        @NoOfPresents int

-- Variables for measuring time.
DECLARE @starttime    datetime2(3) = sysdatetime(),
        @tookms       int

-- We accumulate the result in this table.
CREATE TABLE #presents
             (CustomerID   int     NOT NULL PRIMARY KEY,
              NoOfPresents tinyint NOT NULL
)


-- Set up a cursor over all customers with an order this year.
DECLARE custcur CURSOR STATIC LOCAL FOR
   SELECT DISTINCT CustomerID
   FROM   dbo.BigOrders O
   WHERE  O.OrderDate >= @year + '0101'
     AND  O.OrderDate <= @year + '1231'

OPEN custcur

WHILE 1 = 1
BEGIN
   -- Get next customer.
   FETCH custcur INTO @CustID
   IF @@fetch_status <> 0
      BREAK

   -- Initiate for this customer.
   SELECT @AccumSum = 0, @NoOfPresents = 0

   -- Set up cursor over all orders this year for this customer.
   DECLARE ordercur CURSOR STATIC LOCAL FOR
      SELECT TotalAmount
      FROM   BigOrders
      WHERE  CustomerID = @CustID
        AND  OrderDate >= @year + '0101'
        AND  OrderDate <= @year + '1231'
     ORDER  BY OrderDate, OrderID

   OPEN ordercur

   WHILE 1 = 1
   BEGIN
      -- Get next order.
      FETCH ordercur INTO @OrderAmount
      IF @@fetch_status <> 0
         BREAK

      -- Increase total for customer.
      SELECT @AccumSum += @OrderAmount

      -- Did we get above the limit for a present? In such case,
      -- increment present count and clear total for customer.
      IF @AccumSum >= @xmaslimit
         SELECT @NoOfPresents += 1, @AccumSum = 0

      -- If we have reached the max, we can quit this loop.
      IF @NoOfPresents = @maxpresents
         BREAK
   END

   DEALLOCATE ordercur

   -- Add a record, if customer is to get presents.
   IF @NoOfPresents > 0
   BEGIN
      INSERT #presents(CustomerID, NoOfPresents)
         VALUES(@CustID, @NoOfPresents)
   END
END

DEALLOCATE custcur

-- How long time did it take?
SELECT @tookms = datediff(ms, @starttime, sysdatetime())

-- Display total no of present and execution time.
SELECT totalnoofpresents = SUM(NoOfPresents), tookms = @tookms
FROM   #presents

-- Total present alotment + some other diagnostics.
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
       OD.TotalYearAmount, OD.AvgOrderAmount
FROM   #presents p
JOIN   OrderData OD ON p.CustomerID = OD.CustomerID
JOIN   Customers C ON p.CustomerID = C.CustomerID
ORDER BY OD.TotalYearAmount DESC, p.CustomerID
go
DROP TABLE #presents
