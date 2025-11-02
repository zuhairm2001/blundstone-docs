-- ===================================================================================
-- Validation Script for SL_EAStockLevelSummary Stored Procedure
-- Purpose: Comprehensive testing of stock level summary calculations
-- ===================================================================================

DECLARE @ExecutionId NVARCHAR(90) = 'TEST_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
DECLARE @TestYear INT = YEAR(GETDATE());
DECLARE @TestMonth INT = MONTH(GETDATE());
DECLARE @ProcessRows BIGINT = 0;

PRINT '===================================================================================';
PRINT 'Stock Level Summary Validation Tests';
PRINT '===================================================================================';
PRINT 'Test Year: ' + CAST(@TestYear AS NVARCHAR(4));
PRINT 'Test Month: ' + CAST(@TestMonth AS NVARCHAR(2));
PRINT 'Execution ID: ' + @ExecutionId;
PRINT '';

-- ===================================================================================
-- TEST 1: Execute the Stored Procedure
-- ===================================================================================
PRINT 'TEST 1: Executing SL_EAStockLevelSummary Stored Procedure';
PRINT '=========================================================';

BEGIN TRY
	EXEC [ax7].[SL_EAStockLevelSummary]
		@ExecutionId = @ExecutionId,
		@Year = @TestYear,
		@Month = @TestMonth,
		@ProcessRows = @ProcessRows OUTPUT;
	
	PRINT '✓ Stored procedure executed successfully';
	PRINT 'Rows processed: ' + CAST(@ProcessRows AS NVARCHAR(20));
END TRY
BEGIN CATCH
	PRINT '⚠ ERROR: Stored procedure execution failed';
	PRINT 'Error Message: ' + ERROR_MESSAGE();
	PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
END CATCH

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 2: Validate Data Completeness in FactInventoryMovementSummary
-- ===================================================================================
PRINT 'TEST 2: Data Completeness Validation';
PRINT '=====================================';

SELECT
	CASE
		WHEN COUNT(*) = 0 THEN '⚠ No records found'
		ELSE '✓ Records exist'
	END as [Status],
	COUNT(*) as [Total Records],
	COUNT(DISTINCT [Company Key]) as [Unique Companies],
	COUNT(DISTINCT [Product Key]) as [Unique Products],
	COUNT(DISTINCT [Warehouse Key]) as [Unique Warehouses]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 3: Validate BOM/EOM Stock Level Logic
-- ===================================================================================
PRINT 'TEST 3: Stock Level Reconciliation (BOM vs EOM)';
PRINT '================================================';

SELECT
	[Company Key],
	[Product Key],
	[Warehouse Key],
	[BOM Physical Stock Quantity],
	[EOM Physical Stock Quantity],
	[Total Inbound Quantity],
	[Total Outbound Quantity],
	[Net Movement Quantity],
	[Quantity Change],
	
	-- Calculate expected EOM based on BOM + movements
	(
		[BOM Physical Stock Quantity] 
		+ [Total Inbound Quantity] 
		- [Total Outbound Quantity]
	) as [Expected EOM],
	
	-- Validation check
	CASE
		WHEN ABS([EOM Physical Stock Quantity] - (
			[BOM Physical Stock Quantity] 
			+ [Total Inbound Quantity] 
			- [Total Outbound Quantity]
		)) > 0.01 
		THEN '⚠ MISMATCH'
		ELSE '✓ VALID'
	END as [Balance Status]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
AND (
	ABS([EOM Physical Stock Quantity] - (
		[BOM Physical Stock Quantity] 
		+ [Total Inbound Quantity] 
		- [Total Outbound Quantity]
	)) > 0.01 
)
ORDER BY [Company Key], [Product Key], [Warehouse Key];

PRINT '';
IF NOT EXISTS (
	SELECT 1 FROM [dbo].[FactInventoryMovementSummary]
	WHERE [Year] = @TestYear
	AND [Month] = @TestMonth
	AND ABS([EOM Physical Stock Quantity] - (
		[BOM Physical Stock Quantity] 
		+ [Total Inbound Quantity] 
		- [Total Outbound Quantity]
	)) > 0.01
)
BEGIN
	PRINT '✓ All stock level balances are correct';
END
ELSE
BEGIN
	PRINT '⚠ Found mismatches in stock level calculations';
END

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 4: Validate KPI Calculations (Days Inventory Outstanding)
-- ===================================================================================
PRINT 'TEST 4: KPI Validation - Days Inventory Outstanding (DIO)';
PRINT '===========================================================';

DECLARE @PeriodStartDate DATE = DATEFROMPARTS(@TestYear, @TestMonth, 1);
DECLARE @PeriodEndDate DATE = EOMONTH(@PeriodStartDate);
DECLARE @DaysInMonth INT = DAY(@PeriodEndDate);

SELECT TOP 20
	[Company Key],
	[Product Key],
	[Warehouse Key],
	[EOM Physical Stock Quantity],
	[Total Outbound Quantity],
	[Days Inventory Outstanding],
	
	-- Recalculate DIO to verify
	CASE
		WHEN [Total Outbound Quantity] > 0
		THEN CAST(([EOM Physical Stock Quantity] * @DaysInMonth) / [Total Outbound Quantity] AS DECIMAL(10, 2))
		ELSE NULL
	END as [Expected DIO],
	
	-- Validation
	CASE
		WHEN [Days Inventory Outstanding] IS NULL AND [Total Outbound Quantity] = 0 THEN '✓ Correct (NULL)'
		WHEN [Days Inventory Outstanding] IS NOT NULL 
			AND ABS([Days Inventory Outstanding] - CAST(([EOM Physical Stock Quantity] * @DaysInMonth) / [Total Outbound Quantity] AS DECIMAL(10, 2))) < 0.01
		THEN '✓ Correct'
		ELSE '⚠ Mismatch'
	END as [DIO Status]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
AND [Total Outbound Quantity] > 0
ORDER BY [EOM Physical Stock Quantity] DESC;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 5: Validate KPI Calculations (Stock Turnover Ratio)
-- ===================================================================================
PRINT 'TEST 5: KPI Validation - Stock Turnover Ratio';
PRINT '==============================================';

SELECT TOP 20
	[Company Key],
	[Product Key],
	[Warehouse Key],
	[Total Outbound Quantity],
	[Average Physical Stock Quantity],
	[Stock Turnover Ratio],
	
	-- Recalculate to verify
	CASE
		WHEN [Average Physical Stock Quantity] > 0
		THEN CAST([Total Outbound Quantity] / [Average Physical Stock Quantity] AS DECIMAL(10, 4))
		ELSE NULL
	END as [Expected Turnover Ratio],
	
	-- Validation
	CASE
		WHEN [Stock Turnover Ratio] IS NULL AND [Average Physical Stock Quantity] = 0 THEN '✓ Correct (NULL)'
		WHEN [Stock Turnover Ratio] IS NOT NULL 
			AND ABS([Stock Turnover Ratio] - CAST([Total Outbound Quantity] / [Average Physical Stock Quantity] AS DECIMAL(10, 4))) < 0.0001
		THEN '✓ Correct'
		ELSE '⚠ Mismatch'
	END as [Turnover Status]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
AND [Average Physical Stock Quantity] > 0
ORDER BY [Stock Turnover Ratio] DESC;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 6: Validate Average Stock Calculation
-- ===================================================================================
PRINT 'TEST 6: Average Stock Calculation Validation';
PRINT '=============================================';

SELECT
	[Company Key],
	[Product Key],
	[Warehouse Key],
	[BOM Physical Stock Quantity],
	[EOM Physical Stock Quantity],
	[Average Physical Stock Quantity],
	
	-- Expected average (BOM + EOM) / 2
	([BOM Physical Stock Quantity] + [EOM Physical Stock Quantity]) / 2.0 as [Expected Average],
	
	CASE
		WHEN ABS([Average Physical Stock Quantity] - (([BOM Physical Stock Quantity] + [EOM Physical Stock Quantity]) / 2.0)) < 0.01
		THEN '✓ Correct'
		ELSE '⚠ Mismatch'
	END as [Status]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
AND (
	ABS([Average Physical Stock Quantity] - (([BOM Physical Stock Quantity] + [EOM Physical Stock Quantity]) / 2.0)) >= 0.01
)
ORDER BY [Company Key], [Product Key], [Warehouse Key];

PRINT '';
IF NOT EXISTS (
	SELECT 1 FROM [dbo].[FactInventoryMovementSummary]
	WHERE [Year] = @TestYear
	AND [Month] = @TestMonth
	AND ABS([Average Physical Stock Quantity] - (([BOM Physical Stock Quantity] + [EOM Physical Stock Quantity]) / 2.0)) >= 0.01
)
BEGIN
	PRINT '✓ All average stock calculations are correct';
END

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 7: Validate Transaction Counts
-- ===================================================================================
PRINT 'TEST 7: Transaction Count Validation';
PRINT '====================================';

SELECT
	[Company Key],
	[Product Key],
	[Warehouse Key],
	[Inbound Transaction Count],
	[Outbound Transaction Count],
	[Total Transaction Count],
	
	CASE
		WHEN [Total Transaction Count] = ([Inbound Transaction Count] + [Outbound Transaction Count])
		THEN '✓ Correct'
		ELSE '⚠ Mismatch'
	END as [Status]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
AND [Total Transaction Count] <> ([Inbound Transaction Count] + [Outbound Transaction Count])
ORDER BY [Company Key], [Product Key], [Warehouse Key];

PRINT '';
IF NOT EXISTS (
	SELECT 1 FROM [dbo].[FactInventoryMovementSummary]
	WHERE [Year] = @TestYear
	AND [Month] = @TestMonth
	AND [Total Transaction Count] <> ([Inbound Transaction Count] + [Outbound Transaction Count])
)
BEGIN
	PRINT '✓ All transaction counts are correctly summed';
END

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 8: Null Value Analysis
-- ===================================================================================
PRINT 'TEST 8: Null Value Analysis';
PRINT '============================';

SELECT
	'BOM Physical Stock Quantity' as [Column],
	COUNT(*) as [Total Records],
	SUM(CASE WHEN [BOM Physical Stock Quantity] IS NULL THEN 1 ELSE 0 END) as [Null Count],
	CAST(SUM(CASE WHEN [BOM Physical Stock Quantity] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null %]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear AND [Month] = @TestMonth

UNION ALL

SELECT
	'Days Inventory Outstanding' as [Column],
	COUNT(*) as [Total Records],
	SUM(CASE WHEN [Days Inventory Outstanding] IS NULL THEN 1 ELSE 0 END) as [Null Count],
	CAST(SUM(CASE WHEN [Days Inventory Outstanding] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null %]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear AND [Month] = @TestMonth

UNION ALL

SELECT
	'Stock Turnover Ratio' as [Column],
	COUNT(*) as [Total Records],
	SUM(CASE WHEN [Stock Turnover Ratio] IS NULL THEN 1 ELSE 0 END) as [Null Count],
	CAST(SUM(CASE WHEN [Stock Turnover Ratio] IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as [Null %]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear AND [Month] = @TestMonth;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 9: Logical Validations (Stock Balances)
-- ===================================================================================
PRINT 'TEST 9: Logical Validation - Stock Balance Checks';
PRINT '==================================================';

SELECT
	CASE
		WHEN [BOM Physical Stock Quantity] < 0 THEN '⚠ Negative BOM'
		WHEN [EOM Physical Stock Quantity] < 0 THEN '⚠ Negative EOM'
		WHEN [Average Physical Stock Quantity] < 0 THEN '⚠ Negative Average'
		ELSE '✓ Valid'
	END as [Validation],
	COUNT(*) as [Count]

FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth

GROUP BY
	CASE
		WHEN [BOM Physical Stock Quantity] < 0 THEN '⚠ Negative BOM'
		WHEN [EOM Physical Stock Quantity] < 0 THEN '⚠ Negative EOM'
		WHEN [Average Physical Stock Quantity] < 0 THEN '⚠ Negative Average'
		ELSE '✓ Valid'
	END;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 10: Date Field Validation
-- ===================================================================================
PRINT 'TEST 10: Date Field Validation';
PRINT '===============================';

SELECT
	'Period Start Date' as [Date Field],
	MIN([Period Start Date]) as [Min],
	MAX([Period Start Date]) as [Max],
	COUNT(DISTINCT [Period Start Date]) as [Unique Values],
	CASE
		WHEN COUNT(DISTINCT [Period Start Date]) = 1 
			AND MIN([Period Start Date]) = DATEFROMPARTS(@TestYear, @TestMonth, 1)
		THEN '✓ Correct'
		ELSE '⚠ Unexpected'
	END as [Status]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear AND [Month] = @TestMonth

UNION ALL

SELECT
	'Period End Date' as [Date Field],
	MIN([Period End Date]) as [Min],
	MAX([Period End Date]) as [Max],
	COUNT(DISTINCT [Period End Date]) as [Unique Values],
	CASE
		WHEN COUNT(DISTINCT [Period End Date]) = 1 
			AND MIN([Period End Date]) = EOMONTH(DATEFROMPARTS(@TestYear, @TestMonth, 1))
		THEN '✓ Correct'
		ELSE '⚠ Unexpected'
	END as [Status]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear AND [Month] = @TestMonth;

PRINT '';
PRINT '';

-- ===================================================================================
-- TEST 11: Summary Report
-- ===================================================================================
PRINT 'TEST 11: Execution Summary';
PRINT '==========================';

SELECT
	[Year],
	[Month],
	[Period Start Date],
	[Period End Date],
	COUNT(*) as [Total Records],
	COUNT(DISTINCT [Company Key]) as [Companies],
	COUNT(DISTINCT [Product Key]) as [Products],
	COUNT(DISTINCT [Warehouse Key]) as [Warehouses],
	MIN([ea_Process_DateTime]) as [First Processed],
	MAX([ea_Process_DateTime]) as [Last Processed],
	SUM([Total Transaction Count]) as [Total Transactions],
	SUM(CASE WHEN [Is Current Month] = 1 THEN 1 ELSE 0 END) as [Current Month Records]
FROM [dbo].[FactInventoryMovementSummary]
WHERE [Year] = @TestYear
AND [Month] = @TestMonth
GROUP BY [Year], [Month], [Period Start Date], [Period End Date];

PRINT '';
PRINT '===================================================================================';
PRINT 'Validation Tests Complete';
PRINT '===================================================================================';
PRINT '';
