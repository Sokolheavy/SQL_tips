USE BigDB
go
-- This script has some examples of batching operations. The
-- purpose of this script is to demonstrate what you need to
-- think of in case the operation is interrupted and needs to be
-- resumed.

-- A simple purge operation.
CREATE OR ALTER PROCEDURE PurgeOldData @purgedate date,
                                       @batchsize int AS

CREATE TABLE #batches (TrnID   int NOT NULL,
                       BatchNo int NOT NULL,
                       PRIMARY KEY (BatchNo, TrnID)
)

INSERT #batches (TrnID, BatchNo)
   SELECT TrnID, row_number() OVER(ORDER BY TrnID) / @batchsize
   FROM   BigTrans
   WHERE  TrnDate < @purgedate

DECLARE @cur CURSOR, @batchno int
SET @cur = CURSOR STATIC FOR
   SELECT DISTINCT BatchNo FROM #batches

OPEN @cur

WHILE 1 = 1
BEGIN
   FETCH @cur INTO @batchno
   IF @@fetch_status <> 0
      BREAK

   DELETE BigTrans
	WHERE  TrnID IN (SELECT TrnID
                    FROM   #batches
                    WHERE  BatchNo = @batchno)
END
-- Key point: this procedure can be started without problem.
-- What has been deleted, has been deleted.
-- ...however, if you expect to stop and restart this procedure
-- regularly (because it can only run during off-hours), consider
-- making the temp table a permanent table, so it only has to be
-- filled up once.
go



-- Copy data from one big table to another.
CREATE OR ALTER  PROCEDURE insert_top_plain @batchsize int AS
   DECLARE @minID  int,
           @maxID  int

   SELECT @minID = MIN(TrnID) FROM BigTrans

   WHILE @minID IS NOT NULL
   BEGIN
      SELECT @maxID = MAX(TrnID)
      FROM   (SELECT TOP(@batchsize) TrnID
              FROM   BigTrans
              WHERE  TrnID >= @minID
              ORDER  BY TrnID ASC) AS B

      INSERT NewTrans(TrnID, ProdID, TrnDate, Qty, Amount)
        SELECT TrnID, ProdID, TrnDate, Qty, Amount
        FROM   BigTrans
        WHERE  TrnID BETWEEN @minID AND @maxID

      SELECT @minID = MIN(TrnID) FROM BigTrans WHERE TrnID > @maxID
   END
-- Key point: if you restart this procedure, it will fail with
-- PK violation. You can save the show with a simple modification:
go
CREATE OR ALTER  PROCEDURE insert_top_restart @batchsize int AS
   DECLARE @minID  int,
           @maxID  int

   SELECT @minID =
      isnull ((SELECT MAX(TrnID) + 1 FROM NewTrans),
              (SELECT MIN(TrnID) FROM BigTrans))

   WHILE @minID IS NOT NULL
   BEGIN
      SELECT @maxID = MAX(TrnID)
      FROM   (SELECT TOP(@batchsize) TrnID
              FROM   BigTrans
              WHERE  TrnID >= @minID
              ORDER  BY TrnID ASC) AS B

      INSERT NewTrans(TrnID, ProdID, TrnDate, Qty, Amount)
        SELECT TrnID, ProdID, TrnDate, Qty, Amount
        FROM   BigTrans
        WHERE  TrnID BETWEEN @minID AND @maxID

      SELECT @minID = MIN(TrnID)
      FROM   BigTrans
      WHERE  TrnID > @maxID
   END
-- Get the highest ID in NewTrans so that you can start
-- where you left off.
go



-- This procedure updates the filler column for all rows. (In real
-- life, this could be a new column that is initiated in some way.)
CREATE OR ALTER PROCEDURE UpdateAbsolute @batchsize int AS

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

      EXEC sp_executesql
           N'UPDATE dbo.BigDetails
             SET    filler = convert(varchar(200), crypt_gen_random(200))
             WHERE  OrderID BETWEEN @minID AND @maxID
               --   AND filler = ''''',
           N'@minID int, @maxID int', @minID, @maxID

      SELECT @minID = MIN(OrderID) FROM BigDetails WHERE OrderID > @maxID
   END
-- Key point: if you restart the procedure, it will work, but you will
-- redo rows which already have been updated. If you uncomment the
-- condition on Filler, it is marginally better, but you will still
-- trudge through rows already updated. Whence, this is better:
GO
CREATE OR ALTER PROCEDURE UpdateAbsolute2 @batchsize int AS

   DECLARE @minID int,
           @maxID int

   SELECT @minID = MIN(OrderID) FROM BigDetails WHERE filler = ''

   WHILE @minID IS NOT NULL
   BEGIN
      SELECT @maxID = MAX(OrderID)
      FROM   (SELECT TOP(@batchsize) OrderID
              FROM   BigDetails
              WHERE  OrderID >= @minID
              ORDER  BY OrderID ASC) AS B

      EXEC sp_executesql
           N'UPDATE dbo.BigDetails
             SET    filler = convert(varchar(200), crypt_gen_random(200))
             WHERE  OrderID BETWEEN @minID AND @maxID',
           N'@minID int, @maxID int', @minID, @maxID

      SELECT @minID = MIN(OrderID) FROM BigDetails WHERE OrderID > @maxID
   END
-- Key point: we determine the lowest ID which has not been processed,
-- so we can resume where we were interrupted.
go


-- This procedure makes an incremental change throuh UPDATE.
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
-- Key point: if this procedure is interrupted, you have but one
-- choice to resume: restore a backup. If you restart the procedure,
-- some rows will have the change applied twice. To avoid this,
-- you need to persist where you were. For instance:
go
CREATE OR ALTER PROCEDURE UpdatePrice_resumable @batchsize  int AS
   DECLARE @minID  int,
           @maxID  int

   IF object_id('guest.lastid') IS NULL
   BEGIN
      CREATE TABLE guest.lastid (lastid int NOT NULL PRIMARY KEY)
      INSERT guest.lastid(lastid)
         SELECT MIN(OrderID) - 1 FROM BigDetails
   END

   SELECT @minID = lastid + 1 FROM guest.lastid

   WHILE @minID IS NOT NULL
   BEGIN
      SELECT @maxID = MAX(OrderID)
      FROM   (SELECT TOP(@batchsize) OrderID
              FROM   BigDetails
              WHERE  OrderID >= @minID
              ORDER  BY OrderID ASC) AS B

      BEGIN TRANSACTION

      UPDATE BigDetails
      SET    UnitPrice = UnitPrice * 1.2
      WHERE  OrderID BETWEEN @minID AND @maxID
      OPTION (RECOMPILE)

      UPDATE guest.lastid SET lastid = @maxID

      COMMIT TRANSACTION

      SELECT @minID = MIN(OrderID) FROM BigDetails WHERE OrderID > @maxID
   END

   DROP TABLE guest.lastid
-- If you are so inclined, you could also add an extra temporary
-- column. Or you could have a more permanent table than one created
-- in the procedure. The important thing is that it cannot be a temp
-- table or a table in tempdb - the server may have been restarted.
go