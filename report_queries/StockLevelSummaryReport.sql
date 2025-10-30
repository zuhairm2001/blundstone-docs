-- ===================================================================================
-- Report Query: Stock Level Summary Report
-- Purpose: Monthly stock levels and KPI summary for management reporting
-- Author: Generated for Blundstone warehouse stock reporting
-- Date: 2025-10-28
-- ===================================================================================

-- EXAMPLE 1: Monthly Stock Summary by Warehouse (Last 6 Months)
-- Shows aggregated stock levels, movements, and turnover metrics by warehouse
-- ===================================================================================

SELECT
	dc.[Company Code] AS [Company],
	dw.[Warehouse Code] AS [Warehouse],
	CONCAT(sls.[Year], '-', RIGHT('0' + CAST(sls.[Month] AS VARCHAR(2)), 2)) AS [Period],
	sls.[Period Start Date],
	sls.[Period End Date],
	COUNT(DISTINCT sls.[Product Key]) AS [Total Products],
	ROUND(SUM(sls.[BOM Physical Stock Quantity]), 0) AS [BOM Stock Value],
	ROUND(SUM(sls.[EOM Physical Stock Quantity]), 0) AS [EOM Stock Value],
	ROUND(SUM(sls.[Total Inbound Quantity]), 0) AS [Total Inbound Qty],
	ROUND(SUM(sls.[Total Outbound Quantity]), 0) AS [Total Outbound Qty],
	ROUND(SUM(sls.[Total Transaction Count]), 0) AS [Total Transactions],
	ROUND(AVG(sls.[Stock Turnover Ratio]), 4) AS [Avg Turnover Ratio],
	ROUND(AVG(sls.[Days Inventory Outstanding]), 2) AS [Avg DIO (Days)],
	CASE 
		WHEN SUM(sls.[EOM Physical Stock Quantity]) > SUM(sls.[BOM Physical Stock Quantity]) THEN 'Increase'
		WHEN SUM(sls.[EOM Physical Stock Quantity]) < SUM(sls.[BOM Physical Stock Quantity]) THEN 'Decrease'
		ELSE 'Flat'
	END AS [Trend]
FROM [dbo].[StockLevelSummary] sls
LEFT JOIN [dbo].[DimCompany] dc ON dc.[Company Key] = sls.[Company Key]
LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
WHERE sls.[Year] = YEAR(GETDATE())
AND sls.[Month] >= MONTH(GETDATE()) - 6
GROUP BY 
	dc.[Company Code],
	dw.[Warehouse Code],
	sls.[Year],
	sls.[Month],
	sls.[Period Start Date],
	sls.[Period End Date]
ORDER BY sls.[Year] DESC, sls.[Month] DESC, [Warehouse];

-- ===================================================================================
-- EXAMPLE 2: Top SKUs by Stock Value (Current Month)
-- Shows which products are holding the most inventory value
-- ===================================================================================

DECLARE @CurrentYear INT = YEAR(GETDATE());
DECLARE @CurrentMonth INT = MONTH(GETDATE());

SELECT TOP 20
	dp.[Item Number] AS [Product],
	dp.[Product Name],
	dw.[Warehouse Code] AS [Warehouse],
	sls.[EOM Physical Stock Quantity] AS [Stock Quantity],
	ROUND(sls.[EOM Physical Stock Quantity] * dp.[Unit Cost], 2) AS [Estimated Stock Value],
	sls.[Total Inbound Quantity] AS [Month Inbound],
	sls.[Total Outbound Quantity] AS [Month Outbound],
	ROUND(sls.[Stock Turnover Ratio], 4) AS [Turnover Ratio],
	ROUND(sls.[Days Inventory Outstanding], 2) AS [DIO],
	CASE 
		WHEN sls.[Stock Turnover Ratio] > 5 THEN 'High Velocity'
		WHEN sls.[Stock Turnover Ratio] > 1 THEN 'Normal'
		ELSE 'Slow Moving'
	END AS [Movement Category]
FROM [dbo].[StockLevelSummary] sls
LEFT JOIN [dbo].[DimProduct] dp ON dp.[Product Key] = sls.[Product Key]
LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
WHERE sls.[Year] = @CurrentYear
AND sls.[Month] = @CurrentMonth
AND sls.[EOM Physical Stock Quantity] > 0
ORDER BY [Estimated Stock Value] DESC;

-- ===================================================================================
-- EXAMPLE 3: Stock Health Dashboard (Last 3 Months Comparison)
-- Compares stock metrics across the last 3 months to identify trends
-- ===================================================================================

WITH PeriodComparison AS (
	SELECT
		sls.[Year],
		sls.[Month],
		dw.[Warehouse Code],
		dp.[Item Number],
		ROUND(SUM(sls.[EOM Physical Stock Quantity]), 0) AS [EOM Qty],
		ROUND(SUM(sls.[Total Inbound Quantity]), 0) AS [Inbound Qty],
		ROUND(SUM(sls.[Total Outbound Quantity]), 0) AS [Outbound Qty],
		ROUND(AVG(sls.[Stock Turnover Ratio]), 4) AS [Turnover Ratio],
		ROW_NUMBER() OVER (PARTITION BY dw.[Warehouse Code], dp.[Product Key] ORDER BY sls.[Year] DESC, sls.[Month] DESC) AS [Month Rank]
	FROM [dbo].[StockLevelSummary] sls
	LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
	LEFT JOIN [dbo].[DimProduct] dp ON dp.[Product Key] = sls.[Product Key]
	WHERE sls.[Year] = YEAR(GETDATE())
	AND sls.[Month] >= MONTH(GETDATE()) - 3
	GROUP BY sls.[Year], sls.[Month], dw.[Warehouse Code], dp.[Product Key], dp.[Item Number]
)
SELECT
	[Warehouse Code],
	[Item Number] AS [Product],
	MAX(CASE WHEN [Month Rank] = 1 THEN [EOM Qty] END) AS [Current Month Qty],
	MAX(CASE WHEN [Month Rank] = 2 THEN [EOM Qty] END) AS [Prev Month Qty],
	MAX(CASE WHEN [Month Rank] = 3 THEN [EOM Qty] END) AS [2 Months Ago Qty],
	MAX(CASE WHEN [Month Rank] = 1 THEN [Turnover Ratio] END) AS [Current Turnover],
	CASE 
		WHEN MAX(CASE WHEN [Month Rank] = 1 THEN [EOM Qty] END) > MAX(CASE WHEN [Month Rank] = 2 THEN [EOM Qty] END) THEN 'Increasing'
		WHEN MAX(CASE WHEN [Month Rank] = 1 THEN [EOM Qty] END) < MAX(CASE WHEN [Month Rank] = 2 THEN [EOM Qty] END) THEN 'Decreasing'
		ELSE 'Stable'
	END AS [Trend]
FROM PeriodComparison
WHERE [Month Rank] IN (1, 2, 3)
GROUP BY [Warehouse Code], [Item Number]
HAVING COUNT(*) = 3  -- Only products with full 3-month data
ORDER BY [Warehouse Code], [Current Month Qty] DESC;

-- ===================================================================================
-- EXAMPLE 4: Warehouse Capacity Analysis
-- Identifies warehouses approaching stock capacity or with low stock
-- ===================================================================================

SELECT TOP 50
	dw.[Warehouse Code] AS [Warehouse],
	CONCAT(sls.[Year], '-', RIGHT('0' + CAST(sls.[Month] AS VARCHAR(2)), 2)) AS [Period],
	ROUND(SUM(sls.[EOM Physical Stock Quantity]), 0) AS [Total Physical Stock],
	ROUND(SUM(sls.[EOM Available Stock Quantity]), 0) AS [Total Available Stock],
	ROUND(SUM(sls.[EOM Reserved Stock Quantity]), 0) AS [Total Reserved Stock],
	ROUND(SUM(sls.[Total Inbound Quantity]), 0) AS [Month Inbound],
	ROUND(SUM(sls.[Total Outbound Quantity]), 0) AS [Month Outbound],
	COUNT(DISTINCT sls.[Product Key]) AS [Unique SKUs],
	ROUND(AVG(sls.[Stock Turnover Ratio]), 4) AS [Avg Turnover],
	CASE 
		WHEN SUM(sls.[EOM Physical Stock Quantity]) > SUM(sls.[BOM Physical Stock Quantity]) THEN 'Building'
		WHEN SUM(sls.[EOM Physical Stock Quantity]) < SUM(sls.[BOM Physical Stock Quantity]) THEN 'Drawing Down'
		ELSE 'Stable'
	END AS [Inventory Trend]
FROM [dbo].[StockLevelSummary] sls
LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
WHERE sls.[Year] = YEAR(GETDATE())
AND sls.[Month] >= MONTH(GETDATE()) - 1
GROUP BY dw.[Warehouse Code], sls.[Year], sls.[Month]
ORDER BY sls.[Year] DESC, sls.[Month] DESC, [Total Physical Stock] DESC;

-- ===================================================================================
-- EXAMPLE 5: Slow-Moving Inventory Report
-- Identifies products with low turnover that might need attention
-- ===================================================================================

SELECT TOP 30
	dp.[Item Number] AS [Product],
	dp.[Product Name],
	dw.[Warehouse Code] AS [Warehouse],
	ROUND(sls.[EOM Physical Stock Quantity], 0) AS [On-Hand Qty],
	ROUND(sls.[Stock Turnover Ratio], 4) AS [Turnover Ratio],
	ROUND(sls.[Days Inventory Outstanding], 2) AS [Days Held],
	ROUND(sls.[Total Outbound Quantity], 0) AS [Month Sales],
	sls.[Total Transaction Count] AS [Transactions],
	CONCAT(sls.[Year], '-', RIGHT('0' + CAST(sls.[Month] AS VARCHAR(2)), 2)) AS [Period]
FROM [dbo].[StockLevelSummary] sls
LEFT JOIN [dbo].[DimProduct] dp ON dp.[Product Key] = sls.[Product Key]
LEFT JOIN [dbo].[DimWarehouse] dw ON dw.[Warehouse Key] = sls.[Warehouse Key]
WHERE sls.[Year] = YEAR(GETDATE())
AND sls.[Month] = MONTH(GETDATE())
AND sls.[EOM Physical Stock Quantity] > 0
AND (sls.[Stock Turnover Ratio] < 0.5 OR sls.[Days Inventory Outstanding] > 90)
ORDER BY [Days Held] DESC;

GO
