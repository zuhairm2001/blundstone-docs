-- ===================================================================================
-- ETL Validation Queries for Stock Level Data Warehouse
-- Purpose: Standalone queries to verify ETL process correctness
-- ===================================================================================

-- ===================================================================================
-- QUERY 1: Source vs Target Reconciliation
-- Purpose: Compare source transaction counts with target fact table
-- ===================================================================================

PRINT 'QUERY 1: Source vs Target Reconciliation';
PRINT '==========================================';

SELECT
    'Source Records (InventTrans)' as [Data Source],
    COUNT(*) as [Total Records]
FROM [ax7].[InventTrans]
WHERE (
    STATUSISSUE IN (
        SELECT [Value Id] FROM [ax7].[EnumValues]
        WHERE [Enum Name] = N'StatusIssue'
        AND [Value Name] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical', 'ReservOrdered', 'OnOrder')
    )
    OR STATUSRECEIPT IN (
        SELECT [Value Id] FROM [ax7].[EnumValues]
        WHERE [Enum Name] = N'StatusReceipt'
        AND [Value Name] IN ('Purchased', 'Received', 'Registered', 'Arrived', 'Ordered')
    )
)
AND ISNULL([ReferenceCategory], 0) <> 26

UNION ALL

SELECT
    'Target Records (FactStockLevel)' as [Data Source],
    COUNT(*) as [Total Records]
FROM [dbo].[FactStockLevel];

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 2: Data Freshness Check
-- Purpose: Verify when data was last loaded and check for staleness
-- ===================================================================================

PRINT 'QUERY 2: Data Freshness Check';
PRINT '==============================';

SELECT
    'Most Recent Load' as [Metric],
    MAX([ea_Process_DateTime]) as [DateTime],
    DATEDIFF(HOUR, MAX([ea_Process_DateTime]), GETDATE()) as [Hours Since Load],
    CASE
        WHEN DATEDIFF(HOUR, MAX([ea_Process_DateTime]), GETDATE()) > 24
        THEN '⚠ WARNING: Data is stale (>24 hours)'
        ELSE '✓ Data is fresh'
    END as [Status]
FROM [dbo].[FactStockLevel]

UNION ALL

SELECT
    'Oldest Record' as [Metric],
    MIN([ea_Process_DateTime]) as [DateTime],
    DATEDIFF(DAY, MIN([ea_Process_DateTime]), GETDATE()) as [Days Since First Load],
    '✓' as [Status]
FROM [dbo].[FactStockLevel];

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 3: Dimension Integrity Check
-- Purpose: Verify all foreign key relationships are valid
-- ===================================================================================

PRINT 'QUERY 3: Dimension Integrity Check';
PRINT '===================================';

-- Check Company dimension
SELECT
    'Company Dimension' as [Dimension],
    COUNT(DISTINCT f.[Company Key]) as [Unique Keys in Fact],
    COUNT(DISTINCT CASE WHEN c.[Company Key] IS NULL THEN f.[Company Key] END) as [Orphaned Keys],
    CASE
        WHEN COUNT(DISTINCT CASE WHEN c.[Company Key] IS NULL THEN f.[Company Key] END) = 0
        THEN '✓ All valid'
        ELSE '⚠ Has orphans'
    END as [Status]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimCompany] c ON f.[Company Key] = c.[Company Key]
WHERE f.[Company Key] > 0

UNION ALL

-- Check Product dimension
SELECT
    'Product Dimension' as [Dimension],
    COUNT(DISTINCT f.[Product Key]) as [Unique Keys in Fact],
    COUNT(DISTINCT CASE WHEN p.[Product Key] IS NULL THEN f.[Product Key] END) as [Orphaned Keys],
    CASE
        WHEN COUNT(DISTINCT CASE WHEN p.[Product Key] IS NULL THEN f.[Product Key] END) = 0
        THEN '✓ All valid'
        ELSE '⚠ Has orphans'
    END as [Status]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimProduct] p ON f.[Product Key] = p.[Product Key]
WHERE f.[Product Key] > 0

UNION ALL

-- Check Warehouse dimension
SELECT
    'Warehouse Dimension' as [Dimension],
    COUNT(DISTINCT f.[Warehouse Key]) as [Unique Keys in Fact],
    COUNT(DISTINCT CASE WHEN w.[Warehouse Key] IS NULL THEN f.[Warehouse Key] END) as [Orphaned Keys],
    CASE
        WHEN COUNT(DISTINCT CASE WHEN w.[Warehouse Key] IS NULL THEN f.[Warehouse Key] END) = 0
        THEN '✓ All valid'
        ELSE '⚠ Has orphans'
    END as [Status]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimWarehouse] w ON f.[Warehouse Key] = w.[Warehouse Key]
WHERE f.[Warehouse Key] > 0

UNION ALL

-- Check Inventory Dimension
SELECT
    'Inventory Dimension' as [Dimension],
    COUNT(DISTINCT f.[Inventory Dimension Key]) as [Unique Keys in Fact],
    COUNT(DISTINCT CASE WHEN id.[Inventory Dimension Key] IS NULL THEN f.[Inventory Dimension Key] END) as [Orphaned Keys],
    CASE
        WHEN COUNT(DISTINCT CASE WHEN id.[Inventory Dimension Key] IS NULL THEN f.[Inventory Dimension Key] END) = 0
        THEN '✓ All valid'
        ELSE '⚠ Has orphans'
    END as [Status]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimInventoryDimension] id ON f.[Inventory Dimension Key] = id.[Inventory Dimension Key]
WHERE f.[Inventory Dimension Key] > 0;

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 4: Stock Balance Verification
-- Purpose: Verify stock calculations make logical sense
-- ===================================================================================

PRINT 'QUERY 4: Stock Balance Verification';
PRINT '====================================';

SELECT
    c.[Company Code],
    COUNT(*) as [Transaction Count],
    SUM([Physical Stock Quantity]) as [Total Physical Stock],
    SUM([Available Stock Quantity]) as [Total Available Stock],
    SUM([Reserved Stock Quantity]) as [Total Reserved Stock],
    SUM([Ordered Stock Quantity]) as [Total Ordered Stock],
    SUM([On Order Stock Quantity]) as [Total On Order Stock],
    -- Logical checks
    CASE
        WHEN SUM([Physical Stock Quantity]) < 0 THEN '⚠ Negative physical stock'
        WHEN SUM([Reserved Stock Quantity]) > ABS(SUM([Physical Stock Quantity])) THEN '⚠ Reserved > Physical'
        ELSE '✓ Balances OK'
    END as [Balance Check]
FROM [dbo].[FactStockLevel] f
LEFT JOIN [dbo].[DimCompany] c ON f.[Company Key] = c.[Company Key]
GROUP BY c.[Company Code]
ORDER BY c.[Company Code];

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 5: Transaction Type Distribution
-- Purpose: Verify all transaction types are being captured correctly
-- ===================================================================================

PRINT 'QUERY 5: Transaction Type Distribution';
PRINT '=======================================';

SELECT
    [Transaction Type],
    [Transaction Status],
    [Movement Type],
    COUNT(*) as [Count],
    SUM([Physical Stock Quantity]) as [Total Physical Qty],
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as [Percentage]
FROM [dbo].[FactStockLevel]
WHERE [Transaction Type] IS NOT NULL
GROUP BY [Transaction Type], [Transaction Status], [Movement Type]
ORDER BY [Count] DESC;

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 6: Duplicate Detection
-- Purpose: Check for any duplicate records that shouldn't exist
-- ===================================================================================

PRINT 'QUERY 6: Duplicate Detection';
PRINT '=============================';

WITH Duplicates AS (
    SELECT
        [Record Id],
        COUNT(*) as [Duplicate Count]
    FROM [dbo].[FactStockLevel]
    WHERE [Stock Level Key] > 0
    GROUP BY [Record Id]
    HAVING COUNT(*) > 1
)
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ No duplicates found'
        ELSE '⚠ WARNING: Duplicates detected'
    END as [Status],
    COUNT(*) as [Duplicate Record IDs],
    SUM([Duplicate Count]) as [Total Duplicate Records]
FROM Duplicates;

-- Show details if duplicates exist
IF EXISTS (SELECT 1 FROM [dbo].[FactStockLevel] WHERE [Stock Level Key] > 0 GROUP BY [Record Id] HAVING COUNT(*) > 1)
BEGIN
    PRINT '';
    PRINT 'Duplicate Record Details:';
    SELECT TOP 10
        f.[Record Id],
        COUNT(*) as [Count],
        STRING_AGG(CAST(f.[Stock Level Key] AS VARCHAR), ', ') as [Stock Level Keys]
    FROM [dbo].[FactStockLevel] f
    WHERE f.[Stock Level Key] > 0
    GROUP BY f.[Record Id]
    HAVING COUNT(*) > 1
    ORDER BY [Count] DESC;
END

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 7: Warehouse Coverage Check
-- Purpose: Verify all expected warehouses are represented in the data
-- ===================================================================================

PRINT 'QUERY 7: Warehouse Coverage Check';
PRINT '==================================';

SELECT
    w.[Company Code],
    w.[Warehouse Code],
    w.[Warehouse Name],
    COUNT(f.[Stock Level Key]) as [Transaction Count],
    COUNT(DISTINCT f.[Product Key]) as [Unique Products],
    SUM(f.[Physical Stock Quantity]) as [Total Physical Stock],
    MAX(f.[ea_Process_DateTime]) as [Last Updated],
    CASE
        WHEN COUNT(f.[Stock Level Key]) = 0 THEN '⚠ No transactions'
        WHEN DATEDIFF(DAY, MAX(f.[ea_Process_DateTime]), GETDATE()) > 7 THEN '⚠ Stale data (>7 days)'
        ELSE '✓ Active'
    END as [Status]
FROM [dbo].[DimWarehouse] w
LEFT JOIN [dbo].[FactStockLevel] f ON w.[Warehouse Key] = f.[Warehouse Key]
WHERE w.[Warehouse Code] IS NOT NULL
GROUP BY w.[Company Code], w.[Warehouse Code], w.[Warehouse Name]
ORDER BY w.[Company Code], w.[Warehouse Code];

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 8: Date Range Validation
-- Purpose: Check transaction date ranges for anomalies
-- ===================================================================================

PRINT 'QUERY 8: Date Range Validation';
PRINT '===============================';

SELECT
    'Transaction Date' as [Date Field],
    MIN([Transaction Date]) as [Earliest],
    MAX([Transaction Date]) as [Latest],
    DATEDIFF(DAY, MIN([Transaction Date]), MAX([Transaction Date])) as [Range (Days)],
    COUNT(DISTINCT [Transaction Date]) as [Unique Dates],
    CASE
        WHEN MAX([Transaction Date]) > GETDATE() THEN '⚠ Future dates detected'
        WHEN MIN([Transaction Date]) < '2000-01-01' THEN '⚠ Suspiciously old dates'
        ELSE '✓ Date range valid'
    END as [Status]
FROM [dbo].[FactStockLevel]
WHERE [Transaction Date] IS NOT NULL

UNION ALL

SELECT
    'Status Date' as [Date Field],
    MIN([Status Date]) as [Earliest],
    MAX([Status Date]) as [Latest],
    DATEDIFF(DAY, MIN([Status Date]), MAX([Status Date])) as [Range (Days)],
    COUNT(DISTINCT [Status Date]) as [Unique Dates],
    CASE
        WHEN MAX([Status Date]) > GETDATE() THEN '⚠ Future dates detected'
        WHEN MIN([Status Date]) < '2000-01-01' THEN '⚠ Suspiciously old dates'
        ELSE '✓ Date range valid'
    END as [Status]
FROM [dbo].[FactStockLevel]
WHERE [Status Date] IS NOT NULL

UNION ALL

SELECT
    'Inventory Date' as [Date Field],
    MIN([Inventory Date]) as [Earliest],
    MAX([Inventory Date]) as [Latest],
    DATEDIFF(DAY, MIN([Inventory Date]), MAX([Inventory Date])) as [Range (Days)],
    COUNT(DISTINCT [Inventory Date]) as [Unique Dates],
    CASE
        WHEN MAX([Inventory Date]) > GETDATE() THEN '⚠ Future dates detected'
        WHEN MIN([Inventory Date]) < '2000-01-01' THEN '⚠ Suspiciously old dates'
        ELSE '✓ Date range valid'
    END as [Status]
FROM [dbo].[FactStockLevel]
WHERE [Inventory Date] IS NOT NULL;

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 9: Business Report Validation (StockOnHand)
-- Purpose: Test the actual business report query from the stored procedure comments
-- ===================================================================================

PRINT 'QUERY 9: StockOnHand Report Validation';
PRINT '=======================================';
PRINT 'Testing the StockOnHand report query for BLU and NZL companies';

SELECT TOP 20
    dP.[Company Code],
    dP.[Item Number],
    dP.[Product Name],
    dID.[Warehouse Code],
    dID.[Inventory Site Code],
    SUM(ISNULL([Physical Stock Quantity],0)) as [Physical Quantity],
    SUM(ISNULL([Available Stock Quantity],0)) as [Available Physical Quantity],
    SUM(ISNULL([Reserved Stock Quantity],0)) as [Physical Reserved Quantity],
    COUNT(*) as [Transaction Count]
FROM [dbo].[FactStockLevel] fSL
JOIN [dbo].[DimProduct] dP ON dP.[Product Key] = fSL.[Product Key]
JOIN [dbo].[DimInventoryDimension] dID ON dID.[Inventory Dimension Key] = fSL.[Inventory Dimension Key]
WHERE dP.[Company Code] in ('blu', 'nzl')
AND dP.[Commodity] in ('FOOTWEAR', 'ANCILLARY', 'POS')
AND dID.[Warehouse Code] in ('DOMDC', 'AUCK')
GROUP BY
    dP.[Company Code],
    dP.[Item Number],
    dP.[Product Name],
    dID.[Warehouse Code],
    dID.[Inventory Site Code]
ORDER BY [Physical Quantity] DESC;

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 10: Performance Metrics
-- Purpose: Check ETL performance and identify potential bottlenecks
-- ===================================================================================

PRINT 'QUERY 10: Performance Metrics';
PRINT '==============================';

-- Records by load date
SELECT
    CAST([ea_Process_DateTime] AS DATE) as [Load Date],
    COUNT(*) as [Records Loaded],
    COUNT(DISTINCT [Product Key]) as [Unique Products],
    COUNT(DISTINCT [Warehouse Key]) as [Unique Warehouses],
    MIN([ea_Process_DateTime]) as [First Load Time],
    MAX([ea_Process_DateTime]) as [Last Load Time],
    DATEDIFF(SECOND, MIN([ea_Process_DateTime]), MAX([ea_Process_DateTime])) as [Load Duration (Seconds)]
FROM [dbo].[FactStockLevel]
WHERE [ea_Process_DateTime] >= DATEADD(DAY, -7, GETDATE())
GROUP BY CAST([ea_Process_DateTime] AS DATE)
ORDER BY [Load Date] DESC;

PRINT '';
PRINT '';

-- ===================================================================================
-- QUERY 11: Null Value Analysis
-- Purpose: Identify columns with high null rates that may indicate data quality issues
-- ===================================================================================

PRINT 'QUERY 11: Null Value Analysis';
PRINT '==============================';

SELECT
    'Warehouse Key' as [Column],
    COUNT(*) as [Total Records],
    SUM(CASE WHEN [Warehouse Key] IS NULL THEN 1 ELSE 0 END) as [Null Count],
    CAST(SUM(CASE WHEN [Warehouse Key] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null Percentage]
FROM [dbo].[FactStockLevel]

UNION ALL

SELECT
    'Transaction Type' as [Column],
    COUNT(*) as [Total Records],
    SUM(CASE WHEN [Transaction Type] IS NULL THEN 1 ELSE 0 END) as [Null Count],
    CAST(SUM(CASE WHEN [Transaction Type] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null Percentage]
FROM [dbo].[FactStockLevel]

UNION ALL

SELECT
    'Inventory Reference' as [Column],
    COUNT(*) as [Total Records],
    SUM(CASE WHEN [Inventory Reference] IS NULL THEN 1 ELSE 0 END) as [Null Count],
    CAST(SUM(CASE WHEN [Inventory Reference] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null Percentage]
FROM [dbo].[FactStockLevel]

UNION ALL

SELECT
    'Inventory Transaction Id' as [Column],
    COUNT(*) as [Total Records],
    SUM(CASE WHEN [Inventory Transaction Id] IS NULL THEN 1 ELSE 0 END) as [Null Count],
    CAST(SUM(CASE WHEN [Inventory Transaction Id] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null Percentage]
FROM [dbo].[FactStockLevel];

PRINT '';
PRINT 'Validation complete!';
