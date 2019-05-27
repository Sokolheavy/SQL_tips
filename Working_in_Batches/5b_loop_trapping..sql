-- This script performs the same thing as 
-- 05_trapping-errors but without bells and whistles. 
-- It is a simple plain cursor loop, updating the rows 
-- one by one.
SET NOCOUNT ON
USE BigDB
go
-- Local variables.
DECLARE @starttime datetime2(3) = sysdatetime(),
        @afterms   int,
        @rowc      int = 0,
        @orderid   int,
        @cur       CURSOR

-- Set up the cursor.
SET @cur = CURSOR STATIC FOR
   SELECT OrderID FROM dbo.NewOrders

OPEN @cur

WHILE 1 = 1
BEGIN 
   FETCH @cur INTO @orderid
   IF @@fetch_status <> 0
      BREAK

   -- Copy the order data to the Big Tables.
   BEGIN TRY
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
                       Amount = SUM(Quantity * UnitPrice)
                FROM   dbo.NewDetails
                GROUP  BY OrderID) AS D 
             ON O.OrderID = D.OrderID
        WHERE  O.OrderID = @orderid

     INSERT BigDetails (OrderID, ProductID, Quantity, 
                        UnitPrice)
        SELECT OrderID, ProductID, Quantity, UnitPrice
        FROM   dbo.NewDetails
        WHERE OrderID = @orderid

     COMMIT TRANSACTION
   END TRY
   BEGIN CATCH
      IF @@trancount > 0 ROLLBACK TRANSACTION
      DECLARE @errmsg  nvarchar(2048) = error_message()

      RAISERROR('Adding order %d failed with error: %s', 16, 1, 
                 @orderid, @errmsg) WITH NOWAIT
   END CATCH

   SELECT @rowc += 1

   -- Diagnostics
   IF @rowc % 1000 = 0
   BEGIN
      SELECT @afterms = datediff(ms, @starttime, sysdatetime())
      RAISERROR('%d rows updated in %d ms.', 0, 1, @rowc, @afterms) 
               WITH NOWAIT
   END
END
SELECT @afterms = datediff(ms, @starttime, sysdatetime())
RAISERROR('All rows processed in %d ms.', 0, 1, @afterms) WITH NOWAIT
go
-- Delete the inserted orders, so that we can re-test.
DELETE BigDetails 
   WHERE OrderID IN (SELECT OrderID FROM NewOrders)
DELETE BigOrders
   WHERE OrderID IN (SELECT OrderID FROM NewOrders)
go
