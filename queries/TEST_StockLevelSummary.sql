-- ===================================================================================
-- Test and Validation Queries for StockLevelSummary
-- Purpose: Validate the summary table after ETL execution
-- Date: 2025-10-28
-- ===================================================================================

-- ===================================================================================
-- TEST 1: Verify table exists and has data
-- ===================================================================================
PRINT '===== TEST 1: Table Existence and Record Count =====';
GO

IF OBJECT_ID('[dbo].[StockLevelSummary]', 'U') IS NOT NULL
BEGIN
	PRINT '✓ Table [dbo].[StockLevelSummary] exists';
	
	SELECT 
		'Total Records' AS [Metric],
		COUNT(*) AS [Value]
	FROM [dbo].[StockLevelSummary];
	
	SELECT 
		'Months Covered' AS [Metric],
		COUNT(DISTINCT CONCAT([Year], '-', [Month])) AS [Value]
	FROM [dbo].[StockLevelSummary];
	
	SELECT 
		'Companies' AS [Metric],
		COUNT(DISTINCT [Company Key]) AS [Value]
	FROM [dbo].[StockLevelSummary]
	WHERE [Company Key] > 0;
	
	SELECT 
		'Warehouses' AS [Metric],
		COUNT(DISTINCT [Warehouse Key]) AS [Value]
	FROM [dbo].[StockLevelSummary]
	WHERE [Warehouse Key] > 0;
END
ELSE
BEGIN
	PRINT '✗ ERROR: Table [dbo].[StockLevelSummary] does not exist';
END

PRINT '';

-- ===================================================================================
-- TEST 2: Check for NULL values in key columns
-- ===================================================================================
PRINT '===== TEST 2: NULL Value Check in Key Columns =====';
GO

SELECT 
	'Period Start Date' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [Period Start Date] IS NULL

UNION ALL

SELECT 
	'Period End Date' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [Period End Date] IS NULL

UNION ALL

SELECT 
	'Company Key' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [Company Key] IS NULL

UNION ALL

SELECT 
	'Product Key' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [Product Key] IS NULL

UNION ALL

SELECT 
	'Warehouse Key' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [Warehouse Key] IS NULL

UNION ALL

SELECT 
	'EOM Physical Stock' AS [Column],
	COUNT(*) AS [NULL Count]
FROM [dbo].[StockLevelSummary]
WHERE [EOM Physical Stock Quantity] IS NULL

ORDER BY [NULL Count] DESC;

PRINT '';

-- ===================================================================================
-- TEST 3: Validate calculations (Stock Change = Inbound - Outbound)
-- ===================================================================================
PRINT '===== TEST 3: Validate Stock Movement Calculations =====';
GO

SELECT 
	[Year],
	[Month],
	COUNT(*) AS [Record Count],
	ROUND(AVG(ABS([Quantity Change])), 2) AS [Avg Quantity Change],
	ROUND(AVG([Total Inbound Quantity]), 2) AS [Avg Inbound],
	ROUND(AVG([Total Outbound Quantity]), 2) AS [Avg Outbound],
	ROUND(AVG([Stock Turnover Ratio]), 4) AS [Avg Turnover Ratio],
	ROUND(AVG([Days Inventory Outstanding]), 2) AS [Avg DIO]
FROM [dbo].[StockLevelSummary]
WHERE [EOM Physical Stock Quantity] > 0
GROUP BY [Year], [Month]
ORDER BY [Year], [Month] DESC;

PRINT '';

-- ===================================================================================
-- TEST 4: Data Quality - Look for anomalies
-- ===================================================================================
PRINT '===== TEST 4: Data Quality Checks =====';
GO

PRINT '-- Negative inventory values (should be rare or non-existent):';
SELECT 
	COUNT(*) AS [Records with Negative EOM Stock]
FROM [dbo].[StockLevelSummary]
WHERE [EOM Physical Stock Quantity] < 0;

PRINT '';
PRINT '-- Missing transaction activity (highest transaction counts):';
SELECT TOP 10
	CONCAT([Year], '-', RIGHT('0' + CAST([Month] AS VARCHAR(2)), 2)) AS [Period],
	COUNT(*) AS [Summary Records],
	ROUND(AVG([Total Transaction Count]), 0) AS [Avg Transactions per Record],
	MAX([Total Transaction Count]) AS [Max Transactions],
	COUNT(CASE WHEN [Total Transaction Count] = 0 THEN 1 END) AS [Zero Activity Records]
FROM [dbo].[StockLevelSummary]
GROUP BY [Year], [Month]
ORDER BY [Year] DESC, [Month] DESC;

PRINT '';

-- ===================================================================================
-- TEST 5: Stock Level Trends (Last 6 months)
-- ===================================================================================
PRINT '===== TEST 5: Stock Level Trends (Last 6 Months) =====';
GO

SELECT TOP 6
	CONCAT(CAST([Year] AS VARCHAR(4)), '-', RIGHT('0' + CAST([Month] AS VARCHAR(2)), 2)) AS [Period],
	[Period Start Date],
	[Period End Date],
	COUNT(*) AS [SKU-Warehouse Combinations],
	ROUND(SUM([EOM Physical Stock Quantity]), 0) AS [Total Physical Stock],
	ROUND(SUM([EOM Available Stock Quantity]), 0) AS [Total Available Stock],
	ROUND(SUM([Total Inbound Quantity]), 0) AS [Total Inbound],
	ROUND(SUM([Total Outbound Quantity]), 0) AS [Total Outbound],
	ROUND(SUM([Total Transaction Count]), 0) AS [Total Transactions],
	ROUND(AVG([Stock Turnover Ratio]), 4) AS [Avg Turnover Ratio]
FROM [dbo].[StockLevelSummary]
WHERE [EOM Physical Stock Quantity] > 0
GROUP BY [Year], [Month], [Period Start Date], [Period End Date]
ORDER BY [Year] DESC, [Month] DESC;

PRINT '';

-- ===================================================================================
-- TEST 6: Warehouse-Level Summary (Current Month)
-- ===================================================================================
PRINT '===== TEST 6: Warehouse-Level Summary (Most Recent Month) =====';
GO

DECLARE @MaxYear INT;
DECLARE @MaxMonth INT;

SELECT @MaxYear = MAX([Year]), @MaxMonth = MAX([Month])
FROM [dbo].[StockLevelSummary];

SELECT
	dw.[Warehouse Code] AS [Warehouse],
	COUNT(DISTINCT sls.[Product Key]) AS [Unique Products],
	ROUND(SUM(sls.[EOM Physical Stock Quantity]), 0) AS [Total Physical Stock],
	ROUND(SUM(sls.[Total Inbound Quantity]), 0) AS [Total Inbound],
	ROUND(SUM(sls.[Total Outbound Quantity]), 0) AS [Total Outbound],
	ROUND(AVG(sls.[Stock Turnover Ratio]), 4) AS [Avg Turnover],
	ROUND(AVG(sls.[Days Inventory Outstanding]), 2) AS [Avg DIO]
FROM [dbo].[StockLevelSummary] sls
LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
WHERE sls.[Year] = @MaxYear
AND sls.[Month] = @MaxMonth
GROUP BY dw.[Warehouse Code]
ORDER BY [Total Physical Stock] DESC;

PRINT '';

-- ===================================================================================
-- TEST 7: Compare BOM vs EOM (Period-over-Period Analysis)
-- ===================================================================================
PRINT '===== TEST 7: Period-over-Period Stock Comparison =====';
GO

WITH RankedSummary AS (
	SELECT
		[Year],
		[Month],
		ROUND(SUM([BOM Physical Stock Quantity]), 0) AS [BOM Total],
		ROUND(SUM([EOM Physical Stock Quantity]), 0) AS [EOM Total],
		ROUND(SUM([Total Inbound Quantity]), 0) AS [Inbound Total],
		ROUND(SUM([Total Outbound Quantity]), 0) AS [Outbound Total],
		ROW_NUMBER() OVER (ORDER BY [Year], [Month]) AS [Period Rank]
	FROM [dbo].[StockLevelSummary]
	GROUP BY [Year], [Month]
)
SELECT
	CONCAT(CAST([Year] AS VARCHAR(4)), '-', RIGHT('0' + CAST([Month] AS VARCHAR(2)), 2)) AS [Period],
	[BOM Total] AS [Beginning Stock],
	[EOM Total] AS [Ending Stock],
	[Inbound Total],
	[Outbound Total],
	[EOM Total] - [BOM Total] AS [Net Change],
	CASE 
		WHEN [BOM Total] > 0 
		THEN CAST(([EOM Total] - [BOM Total]) * 100.0 / [BOM Total] AS DECIMAL(10, 2))
		ELSE NULL
	END AS [% Change]
FROM RankedSummary
ORDER BY [Year] DESC, [Month] DESC;

PRINT '';

-- ===================================================================================
-- TEST 8: High-Level Index Usage (Performance Check)
-- ===================================================================================
PRINT '===== TEST 8: Index Usage Statistics =====';
GO

SELECT
	i.name AS [Index Name],
	ISNULL(s.user_seeks, 0) AS [Seeks],
	ISNULL(s.user_scans, 0) AS [Scans],
	ISNULL(s.user_lookups, 0) AS [Lookups],
	ISNULL(s.user_updates, 0) AS [Updates]
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE i.object_id = OBJECT_ID('[dbo].[StockLevelSummary]')
AND i.name IS NOT NULL
ORDER BY (ISNULL(s.user_seeks, 0) + ISNULL(s.user_scans, 0) + ISNULL(s.user_lookups, 0)) DESC;

PRINT '';
PRINT '===== ALL TESTS COMPLETED =====';
GO
