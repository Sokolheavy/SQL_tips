-- This scripts shows how to do the schema change on BigTrans with ALTER TABLE.
-- It runs for a long time and the t-log grew with 20 GB when I tested.
CREATE PROCEDURE alter_all AS
   DROP INDEX IX_ProdID_TrnDate ON BigTrans 
   ALTER TABLE BigTrans DROP CONSTRAINT pk_BigTrans
   ALTER TABLE BigTrans ALTER COLUMN TrnID bigint NOT NULL
   ALTER TABLE BigTrans ALTER COLUMN TrnDate date NOT NULL
   ALTER TABLE BigTrans ALTER COLUMN Amount decimal(10,2) NOT NULL
   ALTER TABLE BigTrans ALTER COLUMN Qty smallint NOT NULL
   ALTER TABLE BigTrans ADD                CONSTRAINT pk_BigTrans PRIMARY KEY(TrnID)
   CREATE NONCLUSTERED INDEX IX_ProdID_TrnDate
       ON BigTrans(ProdID, TrnDate) INCLUDE (Qty, Amount)
