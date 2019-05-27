USE BigDB
go
-- This procedures demonstrates a general batching. By using TOP +
-- MAX, we can move @batchsize rows ahead. The beauty of it is that
-- it works with any data type, and there is no problems with gaps.
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

   CREATE NONCLUSTERED INDEX IX_ProdID_TrnDate
     ON NewTrans(ProdID, TrnDate) INCLUDE (Qty, Amount)

   ALTER TABLE NewTrans ADD CONSTRAINT fk_NewTrans_Product
      FOREIGN KEY (ProdID) REFERENCES Product (ProductID)
go
-- This is a more specialised version that gives better performance
-- than the above (except at small batch sizes according to my tests)
-- in the scenario where you have a numeric key which is largely
-- contiguous. It will not work well with a table where the id
-- column has longer gaps.
CREATE OR ALTER PROCEDURE insert_plain_plain @batchsize int AS
   DECLARE @minID  int,
           @maxID  int,
           @stopID int

   SELECT @minID = MIN(TrnID) FROM BigTrans
   SELECT @stopID = MAX(TrnID) FROM BigTrans

   WHILE @minID <= @stopID
   BEGIN
      SELECT @maxID = @minID + @batchsize - 1

      INSERT NewTrans(TrnID, ProdID, TrnDate, Qty, Amount)
        SELECT TrnID, ProdID, TrnDate, Qty, Amount
        FROM   BigTrans
        WHERE  TrnID BETWEEN @minID AND @maxID

      SELECT @minID = @maxID + 1
   END

   CREATE NONCLUSTERED INDEX IX_ProdID_TrnDate
     ON NewTrans(ProdID, TrnDate) INCLUDE (Qty, Amount)

   ALTER TABLE NewTrans ADD CONSTRAINT fk_NewTrans_Product
      FOREIGN KEY (ProdID) REFERENCES Product (ProductID)
go
-- This procedure includes OPTION (RECOMPILE). In this particular
-- example it decreases the performance even at bigger batch sizes.
-- But as a principle, you should always have one of this or the
-- dynamic SQL below.
CREATE OR ALTER PROCEDURE insert_top_recompile @batchsize int AS
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
      OPTION (RECOMPILE)

      SELECT @minID = MIN(TrnID)
      FROM   BigTrans
      WHERE  TrnID > @maxID
   END

   CREATE NONCLUSTERED INDEX IX_ProdID_TrnDate
     ON NewTrans(ProdID, TrnDate) INCLUDE (Qty, Amount)

   ALTER TABLE NewTrans ADD CONSTRAINT fk_NewTrans_Product
      FOREIGN KEY (ProdID) REFERENCES Product (ProductID)
go
-- Rather than using OPTION (RECOMPILE), I wrap the statement
-- with the interval in dynamic SQL, so that @minID and @maxID
-- can be sniffed by the optimizer, which permits for a better
-- plan.
CREATE OR ALTER PROCEDURE insert_top_dynsql @batchsize int AS
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

      EXEC sp_executesql
         N'INSERT NewTrans(TrnID, ProdID, TrnDate, Qty, Amount)
           SELECT TrnID, ProdID, TrnDate, Qty, Amount
           FROM   dbo.BigTrans
           WHERE  TrnID BETWEEN @minID AND @maxID',
        N'@minID int, @maxID int', @minID, @maxID

      SELECT @minID = MIN(TrnID)
      FROM   BigTrans
      WHERE  TrnID > @maxID
   END

   CREATE NONCLUSTERED INDEX IX_ProdID_TrnDate
     ON NewTrans(ProdID, TrnDate) INCLUDE (Qty, Amount)

   ALTER TABLE NewTrans ADD CONSTRAINT fk_NewTrans_Product
      FOREIGN KEY (ProdID) REFERENCES Product (ProductID)
go