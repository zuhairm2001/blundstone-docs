-- ===================================================================================
-- Test Script for SL_EAStockLevels Stored Procedure
-- Purpose: Comprehensive testing and validation of the ETL process
-- ===================================================================================

-- ===================================================================================
-- SECTION 1: PRE-EXECUTION CHECKS
-- ===================================================================================

PRINT '========================================';
PRINT 'PRE-EXECUTION VALIDATION CHECKS';
PRINT '========================================';
PRINT '';

-- 1.1 Check if stored procedure exists
PRINT '1. Checking if stored procedure exists...';
IF OBJECT_ID('[dbo].[SL_EAStockLevels]', 'P') IS NOT NULL
    PRINT '   ✓ Stored procedure exists';
ELSE
BEGIN
    PRINT '   ✗ ERROR: Stored procedure does not exist!';
    PRINT '   Please run the creation script first.';
    RETURN;
END
PRINT '';

-- 1.2 Check if target table exists
PRINT '2. Checking if target table exists...';
IF OBJECT_ID('[dbo].[FactStockLevel]', 'U') IS NOT NULL
    PRINT '   ✓ FactStockLevel table exists';
ELSE
BEGIN
    PRINT '   ✗ ERROR: FactStockLevel table does not exist!';
    RETURN;
END
PRINT '';

-- 1.3 Check source data availability
PRINT '3. Checking source data availability...';
DECLARE @SourceCount INT;
SELECT @SourceCount = COUNT(*) FROM [ax7].[InventTrans];
IF @SourceCount > 0
    PRINT '   ✓ Source table has ' + CAST(@SourceCount AS VARCHAR) + ' records';
ELSE
    PRINT '   ⚠ WARNING: No records in source table [ax7].[InventTrans]';
PRINT '';

-- 1.4 Check ETL configuration
PRINT '4. Checking ETL configuration...';
IF EXISTS (SELECT 1 FROM [edw].[EtlParams])
    PRINT '   ✓ ETL parameters configured';
ELSE
BEGIN
    PRINT '   ✗ ERROR: No ETL parameters configured!';
    RETURN;
END
PRINT '';

-- 1.5 Check enum values
PRINT '5. Checking enum values...';
DECLARE @EnumCount INT;
SELECT @EnumCount = COUNT(*) FROM [ax7].[EnumValues]
WHERE [Enum Name] IN ('StatusIssue', 'StatusReceipt');
IF @EnumCount >= 15
    PRINT '   ✓ Enum values configured (' + CAST(@EnumCount AS VARCHAR) + ' found)';
ELSE
    PRINT '   ⚠ WARNING: Some enum values may be missing (' + CAST(@EnumCount AS VARCHAR) + ' found)';
PRINT '';

-- 1.6 Record baseline counts
PRINT '6. Recording baseline counts...';
DECLARE @BeforeCount INT;
SELECT @BeforeCount = COUNT(*) FROM [dbo].[FactStockLevel];
PRINT '   Current FactStockLevel records: ' + CAST(@BeforeCount AS VARCHAR);
PRINT '';

-- ===================================================================================
-- SECTION 2: TEST EXECUTION
-- ===================================================================================

PRINT '========================================';
PRINT 'EXECUTING STORED PROCEDURE';
PRINT '========================================';
PRINT '';

-- 2.1 Generate execution ID
DECLARE @ExecutionId NVARCHAR(90);
DECLARE @ProcessRows BIGINT;
SET @ExecutionId = 'TEST_' + CONVERT(VARCHAR, GETDATE(), 112) + '_' + REPLACE(CONVERT(VARCHAR, GETDATE(), 108), ':', '');

PRINT 'Execution ID: ' + @ExecutionId;
PRINT 'Start Time: ' + CONVERT(VARCHAR, GETDATE(), 121);
PRINT '';

-- 2.2 Execute the stored procedure (INCREMENTAL LOAD TEST)
PRINT 'Executing stored procedure (Incremental Load)...';
BEGIN TRY
    BEGIN TRANSACTION;

    EXEC [dbo].[SL_EAStockLevels]
        @ExecutionId = @ExecutionId,
        @IncrementalLoad = 1,  -- Set to 1 for incremental, 0 for full load
        @ProcessRows = @ProcessRows OUTPUT;

    COMMIT TRANSACTION;

    PRINT '   ✓ Execution completed successfully';
    PRINT '   Rows processed: ' + CAST(@ProcessRows AS VARCHAR);
    PRINT '   End Time: ' + CONVERT(VARCHAR, GETDATE(), 121);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT '   ✗ ERROR during execution:';
    PRINT '   Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR);
    PRINT '   Error Message: ' + ERROR_MESSAGE();
    PRINT '   Error Line: ' + CAST(ERROR_LINE() AS VARCHAR);
    RETURN;
END CATCH
PRINT '';

-- ===================================================================================
-- SECTION 3: POST-EXECUTION VALIDATION
-- ===================================================================================

PRINT '========================================';
PRINT 'POST-EXECUTION VALIDATION';
PRINT '========================================';
PRINT '';

-- 3.1 Verify row count changes
PRINT '1. Verifying row count changes...';
DECLARE @AfterCount INT;
DECLARE @NewRecords INT;
SELECT @AfterCount = COUNT(*) FROM [dbo].[FactStockLevel];
SET @NewRecords = @AfterCount - @BeforeCount;
PRINT '   Before: ' + CAST(@BeforeCount AS VARCHAR) + ' records';
PRINT '   After:  ' + CAST(@AfterCount AS VARCHAR) + ' records';
PRINT '   Change: ' + CAST(@NewRecords AS VARCHAR) + ' records';
IF @NewRecords > 0
    PRINT '   ✓ New records inserted';
ELSE IF @NewRecords = 0
    PRINT '   ⚠ No new records (may be expected for incremental load)';
ELSE
    PRINT '   ⚠ Records deleted: ' + CAST(ABS(@NewRecords) AS VARCHAR);
PRINT '';

-- 3.2 Check for NULL key values
PRINT '2. Checking for NULL or invalid key values...';
DECLARE @NullKeys INT;
SELECT @NullKeys = COUNT(*)
FROM [dbo].[FactStockLevel]
WHERE [Company Key] IS NULL
   OR [Product Key] IS NULL
   OR [Inventory Dimension Key] IS NULL;
IF @NullKeys = 0
    PRINT '   ✓ No NULL key values found';
ELSE
    PRINT '   ⚠ WARNING: ' + CAST(@NullKeys AS VARCHAR) + ' records have NULL keys';
PRINT '';

-- 3.3 Verify data quality
PRINT '3. Checking data quality...';

-- Check for duplicate records
DECLARE @DuplicateCount INT;
SELECT @DuplicateCount = COUNT(*) FROM (
    SELECT [Record Id], COUNT(*) as cnt
    FROM [dbo].[FactStockLevel]
    WHERE [Stock Level Key] > 0
    GROUP BY [Record Id]
    HAVING COUNT(*) > 1
) dups;
IF @DuplicateCount = 0
    PRINT '   ✓ No duplicate Record IDs';
ELSE
    PRINT '   ⚠ WARNING: ' + CAST(@DuplicateCount AS VARCHAR) + ' duplicate Record IDs found';

-- Check for orphaned dimension references
PRINT '   Checking dimension references...';
DECLARE @OrphanedCompany INT, @OrphanedProduct INT, @OrphanedWarehouse INT;
SELECT @OrphanedCompany = COUNT(*)
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimCompany] c ON f.[Company Key] = c.[Company Key]
WHERE c.[Company Key] IS NULL AND f.[Company Key] > 0;

SELECT @OrphanedProduct = COUNT(*)
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimProduct] p ON f.[Product Key] = p.[Product Key]
WHERE p.[Product Key] IS NULL AND f.[Product Key] > 0;

SELECT @OrphanedWarehouse = COUNT(*)
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimWarehouse] w ON f.[Warehouse Key] = w.[Warehouse Key]
WHERE w.[Warehouse Key] IS NULL AND f.[Warehouse Key] > 0;

IF @OrphanedCompany = 0 AND @OrphanedProduct = 0 AND @OrphanedWarehouse = 0
    PRINT '   ✓ All dimension references valid';
ELSE
BEGIN
    IF @OrphanedCompany > 0
        PRINT '   ⚠ WARNING: ' + CAST(@OrphanedCompany AS VARCHAR) + ' orphaned Company references';
    IF @OrphanedProduct > 0
        PRINT '   ⚠ WARNING: ' + CAST(@OrphanedProduct AS VARCHAR) + ' orphaned Product references';
    IF @OrphanedWarehouse > 0
        PRINT '   ⚠ WARNING: ' + CAST(@OrphanedWarehouse AS VARCHAR) + ' orphaned Warehouse references';
END
PRINT '';

-- ===================================================================================
-- SECTION 4: BUSINESS LOGIC VALIDATION
-- ===================================================================================

PRINT '========================================';
PRINT 'BUSINESS LOGIC VALIDATION';
PRINT '========================================';
PRINT '';

-- 4.1 Verify stock calculations
PRINT '1. Validating stock quantity calculations...';
SELECT
    'Physical Stock' as [Metric],
    COUNT(*) as [Records],
    SUM([Physical Stock Quantity]) as [Total Quantity],
    AVG([Physical Stock Quantity]) as [Avg Quantity],
    MIN([Physical Stock Quantity]) as [Min Quantity],
    MAX([Physical Stock Quantity]) as [Max Quantity]
FROM [dbo].[FactStockLevel]
WHERE [Physical Stock Quantity] <> 0

UNION ALL

SELECT
    'Available Stock' as [Metric],
    COUNT(*) as [Records],
    SUM([Available Stock Quantity]) as [Total Quantity],
    AVG([Available Stock Quantity]) as [Avg Quantity],
    MIN([Available Stock Quantity]) as [Min Quantity],
    MAX([Available Stock Quantity]) as [Max Quantity]
FROM [dbo].[FactStockLevel]
WHERE [Available Stock Quantity] <> 0

UNION ALL

SELECT
    'Reserved Stock' as [Metric],
    COUNT(*) as [Records],
    SUM([Reserved Stock Quantity]) as [Total Quantity],
    AVG([Reserved Stock Quantity]) as [Avg Quantity],
    MIN([Reserved Stock Quantity]) as [Min Quantity],
    MAX([Reserved Stock Quantity]) as [Max Quantity]
FROM [dbo].[FactStockLevel]
WHERE [Reserved Stock Quantity] <> 0;
PRINT '';

-- 4.2 Check transaction types distribution
PRINT '2. Transaction type distribution...';
SELECT
    [Transaction Type],
    [Transaction Status],
    [Movement Type],
    COUNT(*) as [Record Count],
    SUM([Physical Stock Quantity]) as [Total Physical Quantity]
FROM [dbo].[FactStockLevel]
WHERE [Transaction Type] IS NOT NULL
GROUP BY [Transaction Type], [Transaction Status], [Movement Type]
ORDER BY [Record Count] DESC;
PRINT '';

-- 4.3 Verify date ranges
PRINT '3. Checking date ranges...';
SELECT
    'Transaction Date' as [Date Type],
    MIN([Transaction Date]) as [Earliest Date],
    MAX([Transaction Date]) as [Latest Date],
    DATEDIFF(DAY, MIN([Transaction Date]), MAX([Transaction Date])) as [Date Range Days]
FROM [dbo].[FactStockLevel]
WHERE [Transaction Date] IS NOT NULL

UNION ALL

SELECT
    'Status Date' as [Date Type],
    MIN([Status Date]) as [Earliest Date],
    MAX([Status Date]) as [Latest Date],
    DATEDIFF(DAY, MIN([Status Date]), MAX([Status Date])) as [Date Range Days]
FROM [dbo].[FactStockLevel]
WHERE [Status Date] IS NOT NULL;
PRINT '';

-- ===================================================================================
-- SECTION 5: SAMPLE DATA REVIEW
-- ===================================================================================

PRINT '========================================';
PRINT 'SAMPLE DATA REVIEW';
PRINT '========================================';
PRINT '';

-- 5.1 Show recent records
PRINT '1. Most recent 10 records:';
SELECT TOP 10
    [Stock Level Key],
    [Company Key],
    [Product Key],
    [Warehouse Key],
    [Transaction Date],
    [Physical Stock Quantity],
    [Available Stock Quantity],
    [Reserved Stock Quantity],
    [Transaction Type],
    [Transaction Status],
    [ea_Process_DateTime]
FROM [dbo].[FactStockLevel]
ORDER BY [ea_Process_DateTime] DESC;
PRINT '';

-- 5.2 Show summary by warehouse
PRINT '2. Stock summary by warehouse:';
SELECT
    w.[Warehouse Code],
    w.[Warehouse Name],
    COUNT(DISTINCT f.[Product Key]) as [Unique Products],
    COUNT(*) as [Total Transactions],
    SUM(f.[Physical Stock Quantity]) as [Total Physical Stock],
    SUM(f.[Available Stock Quantity]) as [Total Available Stock],
    SUM(f.[Reserved Stock Quantity]) as [Total Reserved Stock]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimWarehouse] w ON f.[Warehouse Key] = w.[Warehouse Key]
WHERE f.[Stock Level Key] > 0
GROUP BY w.[Warehouse Code], w.[Warehouse Name]
ORDER BY [Total Physical Stock] DESC;
PRINT '';

-- ===================================================================================
-- SECTION 6: PERFORMANCE METRICS
-- ===================================================================================

PRINT '========================================';
PRINT 'PERFORMANCE METRICS';
PRINT '========================================';
PRINT '';

-- 6.1 Record counts by company
PRINT '1. Records by company:';
SELECT
    c.[Company Code],
    c.[Company Name],
    COUNT(*) as [Record Count],
    COUNT(DISTINCT f.[Product Key]) as [Unique Products]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimCompany] c ON f.[Company Key] = c.[Company Key]
GROUP BY c.[Company Code], c.[Company Name]
ORDER BY [Record Count] DESC;
PRINT '';

-- ===================================================================================
-- SECTION 7: TEST SUMMARY
-- ===================================================================================

PRINT '========================================';
PRINT 'TEST SUMMARY';
PRINT '========================================';
PRINT '';
PRINT 'Execution ID: ' + @ExecutionId;
PRINT 'Rows Processed: ' + CAST(@ProcessRows AS VARCHAR);
PRINT 'Records Before: ' + CAST(@BeforeCount AS VARCHAR);
PRINT 'Records After: ' + CAST(@AfterCount AS VARCHAR);
PRINT 'Net Change: ' + CAST(@NewRecords AS VARCHAR);
PRINT '';
PRINT 'Test completed at: ' + CONVERT(VARCHAR, GETDATE(), 121);
PRINT '========================================';

-- ===================================================================================
-- OPTIONAL: CLEANUP (Uncomment to remove test data)
-- ===================================================================================
/*
PRINT '';
PRINT 'CLEANUP: Removing test records...';
DELETE FROM [dbo].[FactStockLevel]
WHERE [Inventory Transaction Id] IN (
    SELECT CAST([recid] AS NVARCHAR(50)) [InventTransId]
    FROM [ax7].[InventTrans]
    WHERE [ExecutionId] = @ExecutionId
);
PRINT 'Test data removed.';
*/
