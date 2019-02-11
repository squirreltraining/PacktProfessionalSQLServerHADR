-- Backup and Restore

USE Chinook_BR;
GO

CREATE TABLE ToBeDeleted(ID int primary key identity, Text varchar(100));

INSERT INTO ToBeDeleted VALUES ('First row');
INSERT INTO ToBeDeleted VALUES ('Second row');
INSERT INTO ToBeDeleted VALUES ('Third row');
INSERT INTO ToBeDeleted VALUES ('Fourth row');

SELECT *
FROM ToBeDeleted;

-- Full backup, that overwrites previous backups (WITH INIT)
BACKUP DATABASE Chinook_BR
TO DISK = 'C:\Backups\Chinook_BR_FULL.bak'
WITH INIT
;

-- Simulate a user error, e.g. DROP TABLE

DROP TABLE ToBeDeleted;

SELECT *
FROM ToBeDeleted;

-- Now restore the full backup

USE master; -- make sure the Chinook_BR database is not in use
GO

RESTORE DATABASE Chinook_BR
FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
WITH REPLACE
;

USE Chinook_BR;
GO

SELECT *
FROM ToBeDeleted;

-- Let's make some changes:

INSERT INTO ToBeDeleted 
VALUES ('Fifth row')
;
INSERT INTO ToBeDeleted 
VALUES ('Sixth row')
;

-- Differential backup: database changes since the latest full backup are being backed up (WITH DIFFERENTIAL)  
BACKUP DATABASE Chinook_BR
TO DISK = 'C:\Backups\Chinook_BR_DIFF.bak'
WITH DIFFERENTIAL
;

-- Some updates

UPDATE ToBeDeleted
SET Text = 'Third row amended3'
WHERE ID = 3
;

UPDATE ToBeDeleted
SET Text = 'Fourth row amended4'
WHERE ID = 4
;

DELETE FROM ToBeDeleted;

SELECT *
FROM ToBeDeleted
;

-- Restore from Differential backup

USE master;
GO

-- First we take a tail log backup
-- this will include the two inserts (5th and 6th row) we did before
BACKUP LOG Chinook_BR
	TO DISK = 'C:\Backups\Chinook_BR_TailLog.bak'
	WITH NORECOVERY
;
-- Then we perform a full backup restore
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
	WITH NORECOVERY -- this will leave the database in a recovery pending state, more restores to follow
;
-- Then we perform our differential backup restore
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_DIFF.bak'
	WITH NORECOVERY
;
-- With this 'empty' recovery, then we make the database available to the users
RESTORE DATABASE Chinook_BR
	WITH RECOVERY
;

USE Chinook_BR;
GO
SELECT *
FROM ToBeDeleted
;

-- We make some more changes for a transaction log backup and restore

DELETE FROM ToBeDeleted WHERE id > 2;
INSERT INTO ToBeDeleted VALUES('Before log backup');

SELECT *
FROM ToBeDeleted;

-- Log backup: only transaction logs are backed up
BACKUP LOG Chinook_BR
TO DISK = 'C:\Backups\Chinook_BR_LOG.bak'
;

-- Some more changes

INSERT INTO ToBeDeleted
VALUES ('After log backup');

SELECT *
FROM ToBeDeleted;

-- Make a 'mistake'

DELETE FROM ToBeDeleted 
WHERE ID < 3
;

SELECT *
FROM ToBeDeleted
;

-- Restoring the database from our Log Backup

USE master;
GO

BACKUP LOG Chinook_BR
	TO DISK = 'C:\Backups\Chinook_BR_TailLog.bak'
	WITH NORECOVERY
;
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
	WITH NORECOVERY
;
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_DIFF.bak'
	WITH NORECOVERY
;
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_LOG.bak'
	WITH NORECOVERY
;
RESTORE DATABASE Chinook_BR
	WITH RECOVERY
;

GO

USE Chinook_BR;
GO

SELECT *
FROM ToBeDeleted;


-- Orphaned log experiment


-- Create table
USE Chinook_BR
DROP TABLE MyTable;

GO
CREATE TABLE MyTable (Payload VARCHAR(1000))
;
GO

-- Insert first record
INSERT MyTable VALUES ('Before full backup')
;
GO

-- Perform full backup
BACKUP DATABASE Chinook_BR TO DISK = 'C:\Backups\Chinook_BR_FULL2.bak' 
	WITH INIT
;
GO

-- Insert second record
INSERT MyTable VALUES ('Before log backup')
;
GO

-- Perform log backup
BACKUP LOG Chinook_BR TO DISK = 'C:\Backups\Chinook_BR_LOG2.bak'
	WITH INIT
;
GO

-- Insert third record
INSERT MyTable VALUES ('After log backup')
;
GO

-- Simulate disaster
SHUTDOWN;

/*
Perform the following actions:
    1. Use Windows Explorer to delete Chinook_BR.mdf
    2. Start SQL Server
	The Chinook_BR database should now be damaged as you deleted the primary data file
*/

-- At this stage, we don't have third record, so we you need to back up the orphaned transaction log.


-- Attempted log backup

USE master;
GO

SELECT name, state_desc 
FROM sys.databases 
WHERE name = 'Chinook_BR'
;
GO

-- Try to back up the orphaned tail-log
BACKUP LOG Chinook_BR TO DISK = 'C:\Backups\Chinook_BR_OrphanedLog.bak' 
WITH INIT
;

/*
	We get an error message, because SQL Server can't find the database’s MDF file, 
	which contains the location of the database’s LDF files in the system tables. 
	To correctly back up the orphaned transaction log, we need the NO_TRUNCATE option.
*/

-- Orphaned log backup with NO_TRUNCATE option

USE master;
GO

BACKUP LOG Chinook_BR TO DISK = 'C:\Backups\Chinook_BR_OrphanedLog.bak' 
	WITH NO_TRUNCATE
;

-- Restore full backup
RESTORE DATABASE Chinook_BR
    FROM DISK = 'C:\Backups\Chinook_BR_FULL2.bak'
	WITH NORECOVERY
    , MOVE 'Chinook_BR' TO 'C:\DatabaseFiles\Chinook_BR_Data.mdf'
    , MOVE 'Chinook_BR_Log' TO 'C:\DatabaseFiles\Chinook_BR_Log.ldf'
;
GO

-- Restore log backup
RESTORE DATABASE Chinook_BR
	FROM DISK = 'C:\Backups\Chinook_BR_LOG2.bak'
	WITH NORECOVERY
;
-- Restore tail log backup
RESTORE DATABASE Chinook_BR
	FROM DISK = 'C:\Backups\Chinook_BR_OrphanedLog.bak'
	WITH RECOVERY
;


USE Chinook_BR;
GO

SELECT *
FROM MyTable
;


-- Configure Backup Automation
-- Scheduling a backup through SQL Server Agent (demo via SSMS)


-- Verifying a backup set

RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
;
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\Chinook_BR_DIFF.bak'
;
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\Chinook_BR_LOG.bak'
;
RESTORE FILELISTONLY
FROM DISK = 'C:\Backups\Chinook_BR_TailLog.bak'
;

RESTORE HEADERONLY
FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
;
RESTORE LABELONLY
FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
;

RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
;
RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\Chinook_BR_DIFF.bak'
;
RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\Chinook_BR_LOG.bak'
;
RESTORE VERIFYONLY
FROM DISK = 'C:\Backups\Chinook_BR_TailLog.bak'
;



-- Piecemeal Restores

/*
	We'll create a database named OnlineStore (to simulate the data from an online shopping website) 
	with the following Filegroups:
		Primary (contains no user tables)
		Orders (has all the critical tables like Customers, Products, Orders, and OrderDetails) 
		CompletedOrders (contains historical tables)
		Data (default filegroup, contains the remainder of the operational tables)
		Archive (holds data that is older than two years)
*/

-- OnlineStore database definition

CREATE DATABASE OnlineStore
 ON  PRIMARY ( NAME = N'OnlineStore_Primary', FILENAME = N'C:\DatabaseFiles\OnlineStore_Primary.mdf', SIZE = 10MB)
	 , FILEGROUP Data
			( NAME = N'OnlineStore_Data', FILENAME = N'C:\DatabaseFiles\OnlineStore_Data.ndf' , SIZE = 50MB)
	 , FILEGROUP Orders
			( NAME = N'OnlineStore_Orders', FILENAME = N'C:\DatabaseFiles\OnlineStore_Orders.ndf' , SIZE = 100MB)
	 , FILEGROUP CompletedOrders
			( NAME = N'OnlineStore_CompletedOrders', FILENAME = N'C:\DatabaseFiles\OnlineStore_CompletedOrders.ndf' , SIZE = 200MB)
	 , FILEGROUP Archive
			( NAME = N'OnlineStore_Archive', FILENAME = N'C:\DatabaseFiles\OnlineStore_Archive.ndf', SIZE = 500MB)
	 LOG ON ( NAME = N'OnlineStore_Log', FILENAME = N'C:\DatabaseFiles\OnlineStore_Log.ldf' , SIZE = 100MB)
;

GO

ALTER DATABASE OnlineStore
MODIFY FILEGROUP Data DEFAULT;

USE OnlineStore;
GO

CREATE TABLE OnlineStoreData(ID int primary key identity, Description varchar(100));

INSERT INTO OnlineStoreData VALUES ('Online Store Data 1');

CREATE TABLE Orders(ID int primary key identity, Customer varchar(100), OrderDate datetime, Amount money
					) ON Orders;

INSERT INTO Orders VALUES ('Packt', getdate(), 100);

/*
	Take the following backups:

	Full backup
	Differential backup
	Log backup
*/

BACKUP DATABASE OnlineStore
TO DISK = 'C:\Backups\OnlineStore_FULL.bak'
WITH INIT
;

INSERT INTO OnlineStoreData VALUES ('After Full, before Differential');
INSERT INTO Orders VALUES ('O''Reilly', getdate(), 200);

BACKUP DATABASE OnlineStore
TO DISK = 'C:\Backups\OnlineStore_DIFF.bak'
WITH DIFFERENTIAL
;

INSERT INTO OnlineStoreData VALUES ('After Differential, before Log');
INSERT INTO Orders VALUES ('After Differential', getdate(), 300);

BACKUP LOG OnlineStore
TO DISK = 'C:\Backups\OnlineStore_LOG.bak'
WITH INIT
;

INSERT INTO OnlineStoreData VALUES ('After Log, before Tail Log');
INSERT INTO Orders VALUES ('After Log', getdate(), 400);

SELECT *
FROM OnlineStoreData;
SELECT *
FROM Orders;

GO
SHUTDOWN
GO

/*
	Delete all files, except OnlineStore_Log.ldf.

	Now we need to recover the database, and especially the Orders filegroup ASAP, 
	so that users can place orders.
*/

-- 1. Perform a tail-log backup, restore the primary file group, and bring the database online

-- Partial-restore sequence

-- Back up orphaned transaction log (tail log) to minimize data loss
USE master;
GO
BACKUP LOG OnlineStore TO DISK = 'C:\Backups\OnlineStore_TAIL_LOG.bak' 
WITH NO_TRUNCATE
;

-- Start partial-restore sequence

RESTORE DATABASE OnlineStore
FILEGROUP = 'PRIMARY' FROM DISK = 'C:\Backups\OnlineStore_FULL.bak' 
WITH NORECOVERY, PARTIAL
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'PRIMARY' FROM DISK = 'C:\Backups\OnlineStore_DIFF.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'PRIMARY' FROM DISK = 'C:\Backups\OnlineStore_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'PRIMARY' FROM DISK = 'C:\Backups\OnlineStore_TAIL_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore 
WITH RECOVERY
;

-- 2. Restore and recover the Orders file group and bring it online

-- Orders filegroup-restore sequence


-- Restore Orders filegroup and bring it online
RESTORE DATABASE OnlineStore
FILEGROUP = 'Orders' FROM DISK = 'C:\Backups\OnlineStore_FULL.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Orders' FROM DISK = 'C:\Backups\OnlineStore_DIFF.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Orders' FROM DISK = 'C:\Backups\OnlineStore_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Orders' FROM DISK = 'C:\Backups\OnlineStore_TAIL_LOG.bak' 
WITH RECOVERY
;
GO


-- 3. Check to make sure that the Orders filegroup is online and that users can query the Orders table

-- Check partial availability of database files

USE OnlineStore;
GO

-- Check to see if Orders filegroup is online
SELECT file_id, name, type_desc, state_desc
FROM sys.database_files
;
GO

-- Ensure users can query the critical tables
SELECT * FROM  Orders
;



-- 4. Restore and recover the Data and CompletedOrders filegroups

-- Data and CompletedOrders filegroup-restore sequence

USE master;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Data', FILEGROUP = 'CompletedOrders' 
FROM DISK = 'C:\Backups\OnlineStore_FULL.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Data', FILEGROUP = 'CompletedOrders' 
FROM DISK = 'C:\Backups\OnlineStore_DIFF.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Data', FILEGROUP = 'CompletedOrders' 
FROM DISK = 'C:\Backups\OnlineStore_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Data', FILEGROUP = 'CompletedOrders' 
FROM DISK = 'C:\Backups\OnlineStore_TAIL_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore 
WITH RECOVERY
;
GO

-- Check the table in filegroup DATA

USE OnlineStore
GO

SELECT *
FROM OnlineStoreData
;

-- 5. Restore and recover the final Archive filegroup

-- Archive filegroup-restore sequence

USE master;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Archive' FROM DISK = 'C:\Backups\OnlineStore_FULL.bak' 
WITH NORECOVERY
;

GO
RESTORE DATABASE OnlineStore
FILEGROUP = 'Archive' FROM DISK = 'C:\Backups\OnlineStore_DIFF.bak' 
WITH NORECOVERY
;

GO
RESTORE DATABASE OnlineStore
FILEGROUP = 'Archive' FROM DISK = 'C:\Backups\OnlineStore_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore
FILEGROUP = 'Archive' FROM DISK = 'C:\Backups\OnlineStore_TAIL_LOG.bak' 
WITH NORECOVERY
;
GO

RESTORE DATABASE OnlineStore 
WITH RECOVERY
;
GO

-- Check to see if all filegroups online

USE OnlineStore;
GO
SELECT file_id, name, type_desc, state_desc
FROM sys.database_files
;




-- Page restore

USE Chinook_BR; 
INSERT INTO ToBeDeleted 
VALUES ('Before page corruption, before tail log backup');

-- Backup database

BACKUP DATABASE Chinook_BR
	TO DISK = 'C:\Backups\Chinook_BR_Full_for_PageRecovery.bak'
	WITH INIT
;

USE Chinook_BR; 
INSERT INTO ToBeDeleted 
VALUES ('Before page corruption, before tail log backup');

USE master;
GO

BACKUP LOG Chinook_BR TO DISK = 'C:\Backups\Chinook_BR_TailLog_for_PageRecovery.bak' 
WITH INIT
;
GO

SHUTDOWN
GO

-- Corrupt Chinook_BR.mdb

-- Determine corrupted pages
USE msdb;
GO

SELECT database_id, file_id, page_id, event_type, error_count, last_update_date
FROM dbo.suspect_pages
WHERE database_id = DB_ID('Chinook_BR')
;
GO

--  Restore corrupt page

-- Try this first:
USE master;
GO
BACKUP LOG Chinook_BR
TO DISK = 'C:\Bakups\Chinook_BR_Tail_Log_for_PageRecovery.bak'
WITH NO_TRUNCATE
;
RESTORE DATABASE Chinook_BR 
	PAGE='1:2' 
FROM DISK = 'C:\Backups\Chinook_BR_Full_for_PageRecovery.bak'
WITH NORECOVERY
;
RESTORE DATABASE Chinook_BR 
FROM DISK = 'C:\Backups\Chinook_BR_Full_for_LogRecovery.bak'
WITH FILE = 1 -- this file has one or more corrupt pages
	 , RECOVERY
;
GO

-- If one of the above commands (usually the first one), renders an error message,
-- try the next commands:

-- If the database is Suspect:

ALTER DATABASE Chinook_BR SET EMERGENCY;
GO
ALTER DATABASE Chinook_BR SET SINGLE_USER;
GO
DBCC CHECKDB (N'Chinook_BR', REPAIR_ALLOW_DATA_LOSS) WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO

-- and if that doesn't help:

RESTORE DATABASE Chinook_BR 
FROM DISK = 'C:\Backups\Chinook_BR_Full_for_PageRecovery.bak'
WITH FILE = 1 -- this file has one or more corrupt pages
	 , REPLACE
;

USE Chinook_BR;
GO
SELECT *
FROM sys.sysfiles
;



/*
	Exercise: perform the following high-level steps:

	1. Insert three records into a table.
	2. Perform a database backup.
	3. Insert a record into a table.
	4. Examine the transaction log’s operations and their LSNs and --> Record the last LSN
	5. Simulate a mistake by updating all the records in the table.
	6. Drop the database.
	7. Restore the full backup.
	8. Restore the log backup stopping at the LSN recorded at Step 4.
	9. Confirm the database has been restored to before the mistake was simulated.
*/

-- Restoring a database to a LSN

-- Set up experiment

-- /* You might have to enable xp_cmdshell by running the following:
EXEC sp_configure 'show advanced', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
-- */

USE master;
EXEC xp_cmdshell 'md C:\Backups\';
GO

-- Create database
CREATE DATABASE PointInTimeRecovery
ON  PRIMARY (NAME = N'RestoreToLSNExperiment_data', FILENAME = N'C:\DatabaseFiles\RestoreToLSNExperiment.mdf')
LOG ON (NAME = N'RestoreToLSNExperiment_log', FILENAME = N'C:\DatabaseFiles\RestoreToLSNExperiment.ldf')
;
GO

USE PointInTimeRecovery
GO

-- Create table
CREATE TABLE MyTable (Payload VARCHAR(1000))
;
GO

-- Step 1: Insert 3 records
INSERT MyTable VALUES ('Record 1'), ('Record 2'), ('Record 3')
;
GO

SELECT *
FROM MyTable
;

-- Step 2: Perform full backup
BACKUP DATABASE PointInTimeRecovery
TO DISK = 'C:\Backups\PointInTimeRecovery_FULL.bak'
WITH INIT
;
GO

-- Step 3: Insert 1 record
INSERT MyTable VALUES ('Record 4')
;
GO

SELECT * FROM MyTable
;

-- Step 4: Query the transaction log
SELECT * FROM fn_dblog(NULL, NULL);

-- Record the last LSN: 00000024:00000158:0004
GO

-- Step 5: Accidentally update all 4 records (simulating a mistake)
UPDATE MyTable SET Payload = 'MISTAKE';
GO

SELECT * FROM MyTable;

SELECT * FROM fn_dblog(NULL, NULL);

-- More LSN's have been added to this list, but 
-- this is the LSN we need: 00000024:00000158:0004

-- Perform log backup
BACKUP LOG PointInTimeRecovery
TO DISK = 'C:\Backups\RestoreToLSN_LOG.bak'
WITH INIT
;
GO

-- Step 6: Drop database
USE master;

DROP DATABASE PointInTimeRecovery;

-- Step 7: Restore full backup
RESTORE DATABASE PointInTimeRecovery
FROM DISK = 'C:\Backups\PointInTimeRecovery_FULL.bak'
WITH NORECOVERY
;

-- Step 8: Restore log backup at LSN recorded above
RESTORE LOG PointInTimeRecovery
FROM DISK = 'C:\Backups\RestoreToLSN_LOG.bak'
WITH RECOVERY
, STOPATMARK = 'lsn:0x00000024:00000158:0004' 
;

-- Step 9: Confirm restore doesn't include "mistake"
USE PointInTimeRecovery;
GO
SELECT * FROM MyTable;



-- Point in time recovery

SELECT GETDATE(); -- 2019-01-30 16:30:41.433

INSERT INTO MyTable VALUES ('I don''t want this row');
INSERT INTO MyTable VALUES ('I don''t want this row either');

SELECT GETDATE(); -- 2019-01-30 16:31:07.857

BACKUP LOG PointInTimeRecovery
TO DISK = 'C:\Backups\RestoreToLSN_LOG3.bak'
WITH INIT
;

-- Point-in-time recovery with a date/time

BACKUP LOG PointInTimeRecovery
TO DISK = 'C:\Backups\TailLog.bak'
WITH NORECOVERY
;
RESTORE DATABASE PointInTimeRecovery
FROM DISK = 'C:\Backups\PointInTimeRecovery_FULL.bak'
WITH NORECOVERY
;
RESTORE LOG PointInTimeRecovery
FROM DISK = 'C:\Backups\RestoreToLSN_LOG3.bak'
WITH RECOVERY, STOPAT = '2019-01-30 16:30:42'
;
GO
USE PointInTimeRecovery;
GO
SELECT *
FROM MyTable
;

/* 
	Using the date/time, or LSN as a recovery point can be imprecise, 
	because it requires you to know exactly what happened when. 
	
	We can also recover to a marked transaction: an explicit marker in the transaction log 
*/

-- Create a transaction log mark

BEGIN TRANSACTION TextChange
    WITH MARK 'TextChange'
;
UPDATE MyTable
    SET Payload = Payload + ' with change'
;
COMMIT TRANSACTION TextChange
;
GO

-- We can query the msdb database’s logmarkhistory to see all marked transactions.

-- Query all marked transactions

SELECT database_name, mark_name, description, user_name, lsn, mark_time
FROM msdb.dbo.logmarkhistory
;

select * from mytable;

update mytable set payload = 'mistake';

BACKUP LOG PointInTimeRecovery
TO DISK = 'C:\Backups\RestoreToLSN_LOG2.bak'
WITH INIT
;

-- Restore database to marked transaction
BACKUP LOG PointInTimeRecovery
TO DISK = 'C:\Backups\TailLog.bak'
WITH NORECOVERY
;
RESTORE DATABASE PointInTimeRecovery
FROM DISK = 'C:\Backups\PointInTimeRecovery_FULL.bak'
WITH NORECOVERY
;
RESTORE LOG PointInTimeRecovery
FROM DISK = 'C:\Backups\RestoreToLSN_LOG2.bak'
WITH RECOVERY, STOPATMARK = 'TextChange'
;
GO
USE PointInTimeRecovery;
GO
SELECT *
FROM MyTable
;



-- Filegroup restore example

USE master;
GO

-- Add a filegroup called Chinook_BR_FG

-- Restore filegroup
RESTORE DATABASE Chinook_BR
   FILEGROUP = 'Chinook_BR_FG' 
   FROM DISK = 'C:\Backups\Chinook_BR_FULL.bak'
   WITH NORECOVERY, REPLACE
;
GO

-- Make two log backups

-- Restore first log backup
RESTORE LOG Chinook_BR FROM 'C:\Backups\Chinook_BR_LOG.bak'
   WITH FILE = 1, NORECOVERY
;
GO

-- Restore second log backup and recover database
RESTORE LOG Chinook_BR FROM 'C:\Backups\Chinook_BR_LOG.bak'
   WITH FILE = 2, RECOVERY
;
GO



-- Database Consistency Checks

-- DBCC operation progress

SELECT session_id, db_name(database_id) as database_name, start_time, command, percent_complete, estimated_completion_time
FROM sys.dm_exec_requests
WHERE command LIKE 'dbcc%'
;

DBCC CHECKALLOC;
-- Checks the consistency of disk space allocation structures with a database
DBCC CHECKCATALOG;
-- Checks the consistency of the system tables with a database
DBCC CHECKFILEGROUP;
-- Checks the allocation and structural integrity of all tables and indexed views in a filegroup
DBCC CHECKTABLE('MyTable') ;
-- Checks the allocation and structural integrity a table

DBCC CHECKDB;
-- Checks the logical and physical integrity of all the objects of a database (except IMOT)

-- DBCC consistency check 
--  that includes the extended logical checks, 
--	uses a table lock, 
--	and does not generate information messages

DBCC CHECKDB (PointInTimeRecovery, NOINDEX)-- no comprehensive checks on nonclustered indexes
	WITH
	  DATA_PURITY -- column values are checked to ensure that they are valid for the domain and not out of range
	, EXTENDED_LOGICAL_CHECKS
	, NO_INFOMSGS -- no information messages are reported, only errors
	, ESTIMATEONLY -- tempdb space estimate, no checks
	, TABLOCK	-- no internal database snapshot is taken and that table lock be used instead -- improves performance in certain cases
				-- Use TABLOCK when you know there is no user activity
				-- TABLOCK causes the DBCC CHECKCATALOG and Service Broker checks not to run
	, MAXDOP = 2	-- controls the degree of parallelism that the DBCC operation uses
					-- The DBCC operation typically dynamically adjusts the degree of parallelism during its execution
--	 PHYSICAL_ONLY -- only checks the allocation consistency, physical structure of the pages, and record headers
					-- and detects checksum and torn pages errors, which indicate a hardware problem with your memory or storage subsystem
					-- cannot be combined with option MAXDOP
;


DBCC CHECKCONSTRAINTS;
GO

-- Repairing a database using the REPAIR_REBUILD operation

USE master;

-- Change database to single user mode
ALTER DATABASE Chinook_BR SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- Perform safe repair
DBCC CHECKDB (Chinook_BR, REPAIR_REBUILD);
GO


-- Repairing a database using the REPAIR_ALLOW_DATA_LOSS operation

USE master;
GO
ALTER DATABASE Chinook_BR SET EMERGENCY;
GO
ALTER DATABASE Chinook_BR SET SINGLE_USER;
GO
DBCC CHECKDB ('Chinook_BR', REPAIR_ALLOW_DATA_LOSS)
WITH NO_INFOMSGS
;
GO

