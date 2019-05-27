-- This demonstrates how batching can be used to trap 
-- errors in occasional rows, and yet permit the rest to
-- complete. We are importing order data from NewOrders
-- and NewDetails and we want all good orders to be 
-- inserted. You compare this to the script 
-- 05_loop_trapping.sql which has no batching.
SET NOCOUNT ON
USE BigDB
go
-- This sets up the Discounts table.
DECLARE @starttime datetime2(3) = sysdatetime(),
        @afterms   int,
        @batchno   int,
        @rowc      int = 0

-- We create a temp table with the orders to work with 
-- divided into batches.
CREATE TABLE #tmporders 
             (OrderID  int NOT NULL,
              BatchNo  int NOT NULL,
              PRIMARY KEY (BatchNo, OrderID))

INSERT #tmporders(OrderID, BatchNo)
   SELECT OrderID, 
         (row_number() OVER(ORDER BY OrderID) - 1) / 10000
   FROM  dbo.NewOrders

-- Batches are dynamic, so we cannot run a static cursor,
-- but we handle the loop ourselves.
WHILE EXISTS (SELECT * FROM #tmporders)
BEGIN TRY
   -- Get next batch.
   SELECT @batchno = MIN(BatchNo) FROM #tmporders

   -- Try to import this batch.
   BEGIN TRANSACTION

   INSERT BigOrders(OrderID, CustomerID, EmployeeID, 
                    OrderDate, RequiredDate, ShipVia, 
                    Freight, ShipName, ShipAddress, 
                    ShipCity, ShipRegion, ShipPostalCode, 
                    ShipCountry, Discount, 
                    TotalAmount, Status)
     SELECT O.OrderID, O.CustomerID, O.EmployeeID, 
            O.OrderDate, O.RequiredDate, O.ShipVia, 
            O.Freight, O.ShipName, O.ShipAddress, 
            O.ShipCity, O.ShipRegion, O.ShipPostalCode, 
            O.ShipCountry, O.Discount, 
            D.Amount * (1 - O.Discount) + O.Freight, 'N'
     FROM   dbo.NewOrders  O
     JOIN   (SELECT OrderID, 
                    Amount = SUM(isnull(Quantity * 
                                        UnitPrice, 0))
             FROM   dbo.NewDetails
             GROUP  BY OrderID) AS D 
         ON O.OrderID = D.OrderID
     WHERE  EXISTS (SELECT *
                    FROM   #tmporders t
                    WHERE  t.OrderID = O.OrderID
                      AND  t.BatchNo = @batchno) 
     SELECT @rowc = @@rowcount

   INSERT BigDetails (OrderID, ProductID, Quantity, 
                      UnitPrice)
      SELECT D.OrderID, D.ProductID, D.Quantity, 
             D.UnitPrice
      FROM   dbo.NewDetails D
      WHERE  EXISTS (SELECT *
                     FROM   #tmporders t
                     WHERE  t.OrderID = D.OrderID
                       AND  t.BatchNo = @batchno) 

   COMMIT TRANSACTION

   -- Diagnostics
   SELECT @afterms = datediff(ms, @starttime, sysdatetime())
   RAISERROR('%d orders in batch %d inserted in %d ms.', 0, 1, 
             @rowc, @batchno, @afterms) WITH NOWAIT

   -- Delete this batch from the work table.
   DELETE #tmporders WHERE BatchNo = @batchno
END TRY
BEGIN CATCH
   -- This batch failed. Starting with rolling back any
   -- open transaction.
   IF @@trancount > 0 ROLLBACK TRANSACTION

   -- Get current size of batch.
   DECLARE @batchsize    int,
           @newbatchsize int

   SELECT @batchsize = COUNT(*) 
   FROM   #tmporders
   WHERE  BatchNo = @batchno

   -- As long as batch size is > 1, divide into smaller 
   -- for retry.
   IF @batchsize > 1
   BEGIN 
      -- Divide by hundred, but result must be >= 1 and
      -- we want 10000 to yield 100 etc.
      SELECT @newbatchsize = (@batchsize - 1) / 100 + 1

      -- Produce diagnostic message.
      RAISERROR('Redividing batch %d from batchsize %d to new size %d', 0, 1,
                 @batchno, @batchsize, @newbatchsize) WITH NOWAIT

      -- Assign new batch numbers for the orders in the
      -- current batch.
      ; WITH batchCTE AS (
         SELECT BatchNo, 
               (row_number() OVER(ORDER BY OrderID) - 1) / 
                          @newbatchsize AS NewBatchNo
         FROM   #tmporders
         WHERE  BatchNo = @batchno
      )
      UPDATE batchCTE
      SET    BatchNo = NewBatchNo + 
                       (SELECT MAX(BatchNo) 
                        FROM #tmporders) + 1
   END
   ELSE
   BEGIN
      -- In a real-world application, you would log the
      -- error in a table, but not re-raise it, as it 
      -- could be trapped by an upper CATCH handler, 
      -- and most likely you want to continue the loop
      DECLARE @errmsg  nvarchar(2048) = error_message(),
              @orderid int

      SELECT @orderid = OrderID 
      FROM   #tmporders 
      WHERE  BatchNo = @batchno

      RAISERROR('Insering order %d failed with error: %s', 16, 1, 
                 @orderid, @errmsg) WITH NOWAIT

      -- Delete this batch, so we don't retry.
      DELETE #tmporders WHERE BatchNo = @batchno
   END
END CATCH
              

SELECT @afterms = datediff(ms, @starttime, sysdatetime())
RAISERROR('All rows processed in %d ms.', 0, 1, @afterms) WITH NOWAIT
go
DROP TABLE #tmporders
-- Delete the inserted orders, so that we can re-test.
DELETE BigDetails 
   WHERE OrderID IN (SELECT OrderID FROM NewOrders)
DELETE BigOrders
   WHERE OrderID IN (SELECT OrderID FROM NewOrders)
go
