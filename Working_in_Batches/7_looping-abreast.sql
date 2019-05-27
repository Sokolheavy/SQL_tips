SET NOCOUNT ON
USE BigDB
go
--================================================================================
-- This is a second solution to the Christmas-present problem.
-- Rather than looping over the customers one at a time, we will
-- loop over all customers abreast, by first looking at the
-- first order for each customer, then the second order etc.

-- Some constants (and debug variables).
DECLARE @year        char(4)       = '2018',
        @xmaslimit   decimal(14,2) = 1000000,
        @maxpresents tinyint       = 10,
        @starttime   datetime2(3) = sysdatetime(),
        @tookms      int

-- Set up a temp table with batches, so that all customers' first order
-- in is in batch one, their second in batch two etc.
CREATE TABLE #batches
             (BatchNo     int            NOT NULL,
              CustomerID  int            NOT NULL,
              OrderAmount decimal(10, 2) NOT NULL,
              PRIMARY KEY (BatchNo, CustomerID)
)

INSERT #batches (CustomerID, OrderAmount, BatchNo)
   SELECT CustomerID, TotalAmount,
          row_number() OVER(PARTITION BY CustomerID
                            ORDER BY OrderDate, OrderID)
   FROM   dbo.BigOrders
   WHERE  OrderDate >= @year + '0101'
     AND  OrderDate <= @year + '1231'

-- This table will hold the accumulated value for each customer, and
-- the final number of presents.
CREATE TABLE #presents
             (CustomerID   int           NOT NULL PRIMARY KEY,
              AccumSum     decimal(14,2) NOT NULL DEFAULT 0,
              NoOfPresents tinyint       NOT NULL DEFAULT 0
)

-- Load #presents with all customers in the first batch.
INSERT #presents(CustomerID)
   SELECT CustomerID
   FROM   #batches
   WHERE  BatchNo = 1

-- Setup a cursor over the batches. Note that it is important to
-- take them in order.
DECLARE @batchno int
DECLARE batch_cur CURSOR STATIC LOCAL FOR
   SELECT DISTINCT BatchNo FROM #batches ORDER BY BatchNo

OPEN batch_cur

WHILE 1 = 1
BEGIN
   FETCH batch_cur INTO @batchno
   IF @@fetch_status <> 0
      BREAK

   -- Update the #presents table with the amount from the orders in
   -- this batch.
   UPDATE #presents
   SET    AccumSum = CASE WHEN p.AccumSum + b.OrderAmount < @xmaslimit
                          THEN p.AccumSum + b.OrderAmount
                          ELSE 0
                     END,
          NoOfPresents = CASE WHEN p.AccumSum + b.OrderAmount < @xmaslimit
                                 THEN p.NoOfPresents
                              WHEN p.NoOfPresents < @maxpresents
                                 THEN p.NoOfPresents + 1
                              ELSE @maxpresents
                          END
   FROM  #presents p
   JOIN  #batches b ON p.CustomerID = b.CustomerID
   WHERE b.BatchNo = @batchno

   -- A small optimisation: as we proceed through the batches, there
   -- are fewer and fewer customers left. And particularly, no
   -- customer that is not in this batch, will appear in a later
   -- batch. Thus, if all remaining customers have been alotteed
   -- the maximum number of presents, we can stop now.
   IF NOT EXISTS (SELECT *
                  FROM   #batches b
                  JOIN   #presents p ON b.CustomerID = p.CustomerID
                  WHERE  b.BatchNo = @batchno
                    AND  p.NoOfPresents < @maxpresents)
     BREAK
END

DEALLOCATE batch_cur

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
       OD.TotalYearAmount, OD.AvgOrderAmount
FROM   #presents p
JOIN   OrderData OD ON p.CustomerID = OD.CustomerID
JOIN   Customers C ON p.CustomerID = C.CustomerID
ORDER BY OD.TotalYearAmount DESC, p.CustomerID
go
-- You may find that the execution time of this solution is quite close
-- to the plain loop. But see what happens if you add this index, with
-- or without the INCLUDE. (The bottleneck is the loading of the #batches
-- table.
-- CREATE INDEX extra_ix ON BigOrders(CustomerID, OrderDate, OrderID)
-- INCLUDE (TotalAmount) WITH  (DROP_EXISTING = ON)
-- DROP INDEX extra_ix on BigOrders
go
-- Drop temp tables.
DROP TABLE #batches, #presents
