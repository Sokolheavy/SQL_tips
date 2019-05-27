USE BigDB
-- This file demonstrates different approaches to implement batching
-- when the clustered index is not a single-column unique key.
-- Performance data is at the end of the script.
go
-- This is the naïve approach: we ignore that the leading column
-- in the clustered index is unique. This means that batches may 
-- be bigger than the intended batchsize, but this is not an issue
-- if the number of excess rows is moderate. This is the method
-- you want to use as much as possible.
CREATE OR ALTER PROCEDURE UpdatePrice_simple @batchsize int AS
   DECLARE @minID int,
           @maxID int

   SELECT @minID = MIN(OrderID) FROM BigDetails

   WHILE @minID IS NOT NULL
   BEGIN
      SELECT @maxID = MAX(OrderID)
      FROM   (SELECT TOP(@batchsize) OrderID
              FROM   BigDetails
              WHERE  OrderID >= @minID
              ORDER  BY OrderID ASC) AS B

      UPDATE BigDetails
      SET    UnitPrice = UnitPrice * 1.2
      WHERE  OrderID BETWEEN @minID AND @maxID
      OPTION (RECOMPILE)

      SELECT @minID = MIN(OrderID) FROM BigDetails WHERE OrderID > @maxID
   END
go
----------------------------------------------------------------
-- Here follows solutions for the case when there are that many
-- products per order (or more generically many second-key values
-- for a single first-key value), that you cannot just ignore them
-- and use the simple method above.
-- This first solution reads all key values into a temp table and
-- divides them into batches and then loops over the temp table,
-- updating the table one batch at a time. Care is taken so that a 
-- batch includes number of adjacent row to make the join efficient.
CREATE OR ALTER PROCEDURE UpdatePrice_temptbl @batchsize int AS
   DECLARE @batchno int

   -- The #batches table. Note the clustered index on BatchNo
   -- followed by the keys in BigDetails. While we could define
   -- (OrderID, ProductID) as a key in itself, that only takes
   -- time to do.
   CREATE TABLE #batches (
       OrderID   int  NOT NULL,
       ProductID int  NOT NULL,
       BatchNo   int  NOT NULL,
       PRIMARY KEY (BatchNo, OrderID, ProductID)
   )

   -- Fill up the temp table. We use row_number to define the batches.
   -- Note that we order by the key values, so that a batch has a number
   -- of adjacent tows.
   INSERT #batches (OrderID, ProductID, BatchNo)
      SELECT OrderID, ProductID, 
             (row_number() OVER(ORDER BY OrderID, ProductID) - 1) / 
                    @batchsize
      FROM  BigDetails

   -- Then loop over all the batches.
   DECLARE @batchcur CURSOR
   SET @batchcur = CURSOR STATIC FOR
      SELECT DISTINCT BatchNo FROM #batches

   OPEN @batchcur

   WHILE 1 = 1
   BEGIN
      FETCH @batchcur INTO @batchno
      IF @@fetch_status <> 0
         BREAK

      -- Update the rows in this batch.
      UPDATE BigDetails
      SET    UnitPrice = UnitPrice * 1.2
      FROM   BigDetails BD
      WHERE  EXISTS (SELECT *
                     FROM   #batches b
                     WHERE  b.OrderID   = BD.OrderID
                       AND  b.ProductID = BD.ProductID
                       AND  b.BatchNo   = @batchno)
      OPTION (RECOMPILE)  -- Added as a principle; may not be needed.
   END
go
---------------------------------------------------------------------
-- Here is a solution that avoids scanning the entire table to get
-- the batches, but instead fills a temp table with one batch at a time
-- as it moves on. When I tested, it was faster than the temptbl
-- solution for some batch sizes, but slower for others.
CREATE OR ALTER PROCEDURE UpdatePrice_smalltemp @batchsize int AS
   DECLARE @CurOrderID    int,
           @LastProductID int,
           @rowcnt        int = @batchsize

   -- No batch number in this table.
   CREATE TABLE #thisbatch (OrderID   int NOT NULL,
                            ProductID int NOT NULL,
                            PRIMARY KEY (OrderID, ProductID)
   )

   SELECT @CurOrderID = MIN(OrderID) - 1
   FROM   BigDetails

   WHILE @rowcnt = @batchsize
   BEGIN
      -- Make sure table is empty. 
      TRUNCATE TABLE #thisbatch

      -- Load the table with @batchsize rows, starting where ended
      -- last time.
      INSERT #thisbatch(OrderID, ProductID)
         SELECT TOP (@batchsize) OrderID, ProductID
         FROM   BigDetails
         WHERE  OrderID = @CurOrderID AND ProductID > @LastProductID OR
                OrderID > @CurOrderID
         ORDER  BY OrderID, ProductID

      -- Track the number of rows found. If get less than @batchsize
      -- rows, this is the last batch.
      SELECT @rowcnt = @@rowcount

      -- Update for this batch.
      UPDATE BigDetails
      SET    UnitPrice = UnitPrice * 1.2
      FROM   BigDetails BD
      WHERE  EXISTS (SELECT *
                     FROM   #thisbatch t
                     WHERE  t.OrderID   = BD.OrderID
                       AND  t.ProductID = BD.ProductID)
      OPTION (RECOMPILE)

      -- Find out which is the last row in this batch, so that 
      -- we know where to start the next.
      SELECT TOP 1 @CurOrderID = OrderID, @LastProductID = ProductID
      FROM   #thisbatch
      ORDER  BY OrderID DESC, ProductID DESC
   END
go
-------------------------------------------------------------------
-- But must we use a temp table? Can't we do it with variables only?
-- Sure we can, but the solution is complex. And the version that follows
-- is not that much faster than the solutions with the temp table.
CREATE OR ALTER PROCEDURE UpdatePrice_double @batchsize int AS
   DECLARE @FirstOrderID   int,
           @LastOrderID    int,
           @StopOrderID    int,
           @FirstProductID int,
           @LastProductID  int,
           @StopProductID  int,
           @gameover       bit = 0
        
    -- Get start and end points.
    SELECT TOP (1) @FirstOrderID = OrderID, @FirstProductID = ProductID
    FROM   BigDetails
    ORDER  BY OrderID ASC, ProductID ASC

    SELECT TOP (1) @StopOrderID = OrderID, @StopProductID = ProductID
    FROM   BigDetails
    ORDER  BY OrderID DESC, ProductID DESC

    WHILE @gameover = 0
    BEGIN
       -- Init variables before getting the end of the interval.
       SELECT @LastOrderID = NULL, @LastProductID = NULL

       -- Get the end of the interval, but for the last batch
       -- we will not get a hit, since rowno will not reach
       -- @batchno.
       ; WITH numbering AS (
            SELECT TOP(@batchsize) OrderID, ProductID,
                   row_number() OVER (ORDER BY OrderID, ProductID) AS rowno
            FROM   BigDetails
            WHERE  OrderID = @FirstOrderID AND ProductID >= @FirstProductID OR
                   OrderID > @FirstOrderID
            ORDER  BY OrderID, ProductID
       )
       SELECT @LastOrderID = OrderID, @LastProductID = ProductID
       FROM   numbering
       WHERE  rowno = @batchsize

       IF @LastOrderID IS NULL
       BEGIN
          -- Variable was not assigned. This is the last batch.
          SELECT @gameover = 1, 
                 @LastOrderID = @StopOrderID, 
                 @LastProductID = @StopProductID
       END

       -- There are several cases to consider. Normally(?) a batch starts
       -- in the middle of an order and ends in the middle of another 
       -- one with a couple of complete orders in between. But if an
       -- order has many products, the batch may be a single order, which
       -- needs to be handled separately.
       IF @LastOrderID > @FirstOrderID
       BEGIN
          -- Love that WHERE conditon? Yuk!
          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID = @FirstOrderID AND ProductID >= @FirstProductID OR
                 OrderID > @FirstOrderID AND OrderID < @LastOrderID OR
                 OrderID = @LastOrderID AND ProductID <= @LastProductID
          OPTION (RECOMPILE)
       END
       ELSE
       BEGIN
          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID = @FirstOrderID 
            AND  ProductID BETWEEN @FirstProductID AND @LastProductID
          OPTION (RECOMPILE)
       END

       IF @gameover = 0
       BEGIN
          -- Get the starting point for the next batch.
          SELECT @FirstOrderID = NULL, @FirstProductID = NULL

          SELECT TOP (1) @FirstOrderID = OrderID, 
                         @FirstProductID = ProductID
          FROM   BigDetails
          WHERE  OrderID = @LastOrderID AND ProductID > @LastProductID OR
                 OrderID > @LastOrderID
          ORDER  BY OrderID, ProductID
      END
   END
go
------------------------------------------------------------------
-- Not only is that WHERE condition for the UPDATE frightening - it's
-- also inefficient, because the optimizer thinks it has to do more
-- work. We need to split it up in three statements (which we wrap in
-- in a transaction to reduce overhead). Performance is now reasonbly
-- close to the naïve solution for bigger batch sizes, but still 40%
-- longer time for 1000 rows - and it is at smaller batch size, you
-- may want to do this in the first place. (However, this is very
-- like to be due to that in the test, no order has more than 600
-- products. In a test case where there commonly are several thousands
-- of rows for a single first-key value, the result is likely to be
-- different.)
CREATE OR ALTER PROCEDURE UpdatePrice_triple @batchsize int AS
   DECLARE @FirstOrderID   int,
           @LastOrderID    int,
           @StopOrderID    int,
           @FirstProductID int,
           @LastProductID  int,
           @StopProductID  int,
           @gameover       bit = 0
        
    SELECT TOP (1) @FirstOrderID = OrderID, @FirstProductID = ProductID
    FROM   BigDetails
    ORDER  BY OrderID ASC, ProductID ASC

    SELECT TOP (1) @StopOrderID = OrderID, @StopProductID = ProductID
    FROM   BigDetails
    ORDER  BY OrderID DESC, ProductID DESC

    WHILE @gameover = 0
    BEGIN
       SELECT @LastOrderID = NULL, @LastProductID = NULL

       ; WITH numbering AS (
            SELECT TOP(@batchsize) OrderID, ProductID,
                   row_number() OVER (ORDER BY OrderID, ProductID) AS rowno
            FROM   BigDetails
            WHERE  OrderID = @FirstOrderID AND ProductID >= @FirstProductID OR
                   OrderID > @FirstOrderID
       )
       SELECT @LastOrderID = OrderID, @LastProductID = ProductID
       FROM   numbering
       WHERE  rowno = @batchsize

       IF @LastOrderID IS NULL
       BEGIN
          SELECT @gameover = 1, 
                 @LastOrderID = @StopOrderID, @LastProductID = @StopProductID
       END

       IF @LastOrderID > @FirstOrderID
       BEGIN
          BEGIN TRANSACTION
       
          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID = @FirstOrderID AND ProductID >= @FirstProductID
          OPTION (RECOMPILE)

          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID > @FirstOrderID AND OrderID < @LastOrderID
          OPTION (RECOMPILE)

          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID = @LastOrderID AND ProductID <= @LastProductID
          OPTION (RECOMPILE)

          COMMIT TRANSACTION
       END
       ELSE
       BEGIN
          UPDATE BigDetails
          SET    UnitPrice = UnitPrice * 1.2
          WHERE  OrderID = @FirstOrderID 
            AND  ProductID BETWEEN @FirstProductID AND @LastProductID
       END

       IF @gameover = 0
       BEGIN
          SELECT @FirstOrderID = NULL, @FirstProductID = NULL

          SELECT TOP (1) @FirstOrderID = OrderID, @FirstProductID = ProductID
          FROM   BigDetails
          WHERE  OrderID = @LastOrderID AND ProductID > @LastProductID OR
                 OrderID > @LastOrderID
          ORDER  BY OrderID, ProductID
      END
   END
go
-------------------------------------------------------------------
-- This solution is almost identical to UpdatePrice_temptbl. The only 
-- difference is how the batch numbers are computed. By not sorting
-- the key values, they can be read from the NC index on ProductID
-- which makes that part faster. But with all batches having key values 
-- scattered all over BigDetails, this solution is seriously slower
-- than the previous one.
CREATE OR ALTER PROCEDURE UpdatePrice_temptbl2 @batchsize int AS
   DECLARE @batchno int

   -- Now only with a clustered index on BatchNo.
   CREATE TABLE #batches (
       OrderID   int  NOT NULL,
       ProductID int  NOT NULL,
       BatchNo   int  NOT NULL,
       INDEX batchno_ix CLUSTERED (BatchNo)
   )

   -- Fill up the temp table. We decline to order the rows in any way.
   INSERT #batches (OrderID, ProductID, BatchNo)
      SELECT OrderID, ProductID, 
             (row_number() OVER(ORDER BY (SELECT 1)) - 1) / @batchsize
      FROM  BigDetails

   -- Then loop over all the batches.
   DECLARE @batchcur CURSOR
   SET @batchcur = CURSOR STATIC FOR
      SELECT DISTINCT BatchNo FROM #batches

   OPEN @batchcur

   WHILE 1 = 1
   BEGIN
      FETCH @batchcur INTO @batchno
      IF @@fetch_status <> 0
         BREAK

      -- Update the rows in this batch. Note that they key values
      -- now are all over the place in the table.
      UPDATE BigDetails
      SET    UnitPrice = UnitPrice * 1.2
      FROM   BigDetails BD
      WHERE  EXISTS (SELECT *
                     FROM   #batches b
                     WHERE  b.OrderID   = BD.OrderID
                       AND  b.ProductID = BD.ProductID
                       AND  b.BatchNo   = @batchno)
      OPTION (RECOMPILE)  -- Added as a principle; may not be needed.
   END
go
------------------------------------------------------------------
-- Performance data:
-- batchsize   simple  temptbl  tempsimple double  triple temptbl2 
-- 1000            67      176         246    233     109      623 
-- 5000            50      147         169    172      67      438 
-- 30000           35      132         116    127      37      324 
-- 200000          34      196         108     98      34      597 
-- 1000000         34       84         123     84      35      211 
