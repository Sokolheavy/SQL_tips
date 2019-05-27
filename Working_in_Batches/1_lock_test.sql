USE BigDB
go
-- This script demonstrates how you can test what type of locks
-- you get.
BEGIN TRANSACTION

DELETE BigTrans
WHERE TrnID BETWEEN 1 AND 2500  -- Increase to 3000 to see what happens. 

SELECT resource_type, request_mode, resource_associated_entity_id,
       object_name(try_convert(int, resource_associated_entity_id)), 
       COUNT(*) AS [Count]
FROM   sys.dm_tran_locks
WHERE  request_session_id = @@spid
GROUP  BY resource_type, request_mode, resource_associated_entity_id,
          object_name(try_convert(int, resource_associated_entity_id)) 
go
ROLLBACK TRANSACTION
