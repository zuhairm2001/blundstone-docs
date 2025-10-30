SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [ax7].[SL_EAStockLevelSummary]
(
	@ExecutionId [nvarchar](90),
	@Year [int],
	@Month [int],
	@ProcessRows [bigint] OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @PeriodStartDate DATE;
	DECLARE @PeriodEndDate DATE;
	DECLARE @PeriodPreviousStartDate DATE;
	DECLARE @NA nvarchar(10);
	DECLARE @NANumber int;
	DECLARE @NAKey int;
	DECLARE @NADate datetime;

	-- Calculate period dates
	SET @PeriodStartDate = DATEFROMPARTS(@Year, @Month, 1);
	SET @PeriodEndDate = EOMONTH(@PeriodStartDate);
	SET @PeriodPreviousStartDate = DATEADD(DAY, 1, EOMONTH(DATEADD(MONTH, -1, @PeriodStartDate)));

	-- Get NA values from EtlParams
	SELECT TOP (1) 
		@NA = [NA String], 
		@NAKey = [NA Key], 
		@NANumber = [NA Number], 
		@NADate = [NA DateTime]
	FROM [edw].[EtlParams];

	-- ===================================================================================
	-- STEP 1: Get Beginning of Month Stock Levels (EOM from previous month)
	-- ===================================================================================
	WITH BOMStockLevels AS (
		SELECT 
			co.[Company Key],
			p.[Product Key],
			pinv.[Product Inventory Key],
			id.[Inventory Dimension Key],
			id.[Inventory Size Key],
			w.[Warehouse Key],
			ISNULL(fsl.[Physical Stock Quantity], 0) AS [BOM Physical Stock Quantity],
			ISNULL(fsl.[Available Stock Quantity], 0) AS [BOM Available Stock Quantity],
			ISNULL(fsl.[Reserved Stock Quantity], 0) AS [BOM Reserved Stock Quantity],
			ISNULL(fsl.[On Order Stock Quantity], 0) AS [BOM On Order Stock Quantity]
		FROM (
			SELECT DISTINCT
				[Company Key],
				[Product Key],
				[Product Inventory Key],
				[Inventory Dimension Key],
				[Warehouse Key]
			FROM [dbo].[FactStockLevel]
			WHERE [Transaction Date] >= DATEFROMPARTS(@Year, @Month, 1)
			AND [Transaction Date] <= EOMONTH(DATEFROMPARTS(@Year, @Month, 1))
		) AS base_keys
		LEFT JOIN [dbo].[FactStockLevel] fsl ON 
			fsl.[Company Key] = base_keys.[Company Key]
			AND fsl.[Product Key] = base_keys.[Product Key]
			AND fsl.[Product Inventory Key] = base_keys.[Product Inventory Key]
			AND fsl.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
			AND fsl.[Warehouse Key] = base_keys.[Warehouse Key]
			AND fsl.[Transaction Date] < @PeriodStartDate
			AND fsl.[Transaction Date] = (
				SELECT MAX([Transaction Date])
				FROM [dbo].[FactStockLevel] fsl2
				WHERE fsl2.[Company Key] = base_keys.[Company Key]
				AND fsl2.[Product Key] = base_keys.[Product Key]
				AND fsl2.[Product Inventory Key] = base_keys.[Product Inventory Key]
				AND fsl2.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
				AND fsl2.[Warehouse Key] = base_keys.[Warehouse Key]
				AND fsl2.[Transaction Date] < @PeriodStartDate
			)
		LEFT JOIN [dbo].[DimCompany] co ON co.[Company Key] = base_keys.[Company Key]
		LEFT JOIN [dbo].[DimProduct] p ON p.[Product Key] = base_keys.[Product Key]
		LEFT JOIN [dbo].[DimProductInventory] pinv ON pinv.[Product Inventory Key] = base_keys.[Product Inventory Key]
		LEFT JOIN [dbo].[DimInventoryDimension] id ON id.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
		LEFT JOIN [dbo].[DimWarehouse] w ON w.[Warehouse Key] = base_keys.[Warehouse Key]
	),

	-- ===================================================================================
	-- STEP 2: Get End of Month Stock Levels (latest transaction on or before EOM)
	-- ===================================================================================
	EOMStockLevels AS (
		SELECT 
			co.[Company Key],
			p.[Product Key],
			pinv.[Product Inventory Key],
			id.[Inventory Dimension Key],
			id.[Inventory Size Key],
			w.[Warehouse Key],
			ISNULL(fsl.[Physical Stock Quantity], 0) AS [EOM Physical Stock Quantity],
			ISNULL(fsl.[Available Stock Quantity], 0) AS [EOM Available Stock Quantity],
			ISNULL(fsl.[Reserved Stock Quantity], 0) AS [EOM Reserved Stock Quantity],
			ISNULL(fsl.[On Order Stock Quantity], 0) AS [EOM On Order Stock Quantity]
		FROM (
			SELECT DISTINCT
				[Company Key],
				[Product Key],
				[Product Inventory Key],
				[Inventory Dimension Key],
				[Warehouse Key]
			FROM [dbo].[FactStockLevel]
			WHERE [Transaction Date] >= @PeriodStartDate
			AND [Transaction Date] <= @PeriodEndDate
		) AS base_keys
		LEFT JOIN [dbo].[FactStockLevel] fsl ON 
			fsl.[Company Key] = base_keys.[Company Key]
			AND fsl.[Product Key] = base_keys.[Product Key]
			AND fsl.[Product Inventory Key] = base_keys.[Product Inventory Key]
			AND fsl.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
			AND fsl.[Warehouse Key] = base_keys.[Warehouse Key]
			AND fsl.[Transaction Date] <= @PeriodEndDate
			AND fsl.[Transaction Date] = (
				SELECT MAX([Transaction Date])
				FROM [dbo].[FactStockLevel] fsl2
				WHERE fsl2.[Company Key] = base_keys.[Company Key]
				AND fsl2.[Product Key] = base_keys.[Product Key]
				AND fsl2.[Product Inventory Key] = base_keys.[Product Inventory Key]
				AND fsl2.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
				AND fsl2.[Warehouse Key] = base_keys.[Warehouse Key]
				AND fsl2.[Transaction Date] <= @PeriodEndDate
			)
		LEFT JOIN [dbo].[DimCompany] co ON co.[Company Key] = base_keys.[Company Key]
		LEFT JOIN [dbo].[DimProduct] p ON p.[Product Key] = base_keys.[Product Key]
		LEFT JOIN [dbo].[DimProductInventory] pinv ON pinv.[Product Inventory Key] = base_keys.[Product Inventory Key]
		LEFT JOIN [dbo].[DimInventoryDimension] id ON id.[Inventory Dimension Key] = base_keys.[Inventory Dimension Key]
		LEFT JOIN [dbo].[DimWarehouse] w ON w.[Warehouse Key] = base_keys.[Warehouse Key]
	),

	-- ===================================================================================
	-- STEP 3: Aggregate monthly movements (inbound vs outbound)
	-- ===================================================================================
	MonthlyMovements AS (
		SELECT 
			ISNULL(co.[Company Key], @NAKey) [Company Key],
			ISNULL(p.[Product Key], @NAKey) [Product Key],
			ISNULL(pinv.[Product Inventory Key], @NAKey) [Product Inventory Key],
			ISNULL(id.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key],
			ISNULL(id.[Inventory Size Key], @NAKey) [Inventory Size Key],
			ISNULL(w.[Warehouse Key], @NAKey) [Warehouse Key],
			
			-- Inbound transactions (IN, ON_ORDER)
			SUM(CASE 
				WHEN fsl.[Movement Type] IN ('IN', 'ON_ORDER')
				THEN ISNULL(fsl.[Physical Stock Quantity], 0)
				ELSE 0
			END) AS [Total Inbound Quantity],
			
			-- Outbound transactions (OUT, TRANSFER)
			SUM(CASE 
				WHEN fsl.[Movement Type] IN ('OUT', 'TRANSFER')
				THEN ABS(ISNULL(fsl.[Physical Stock Quantity], 0))
				ELSE 0
			END) AS [Total Outbound Quantity],
			
			-- Count of inbound transactions
			COUNT(DISTINCT CASE 
				WHEN fsl.[Movement Type] IN ('IN', 'ON_ORDER')
				THEN fsl.[Inventory Transaction Id]
				ELSE NULL
			END) AS [Inbound Transaction Count],
			
			-- Count of outbound transactions
			COUNT(DISTINCT CASE 
				WHEN fsl.[Movement Type] IN ('OUT', 'TRANSFER')
				THEN fsl.[Inventory Transaction Id]
				ELSE NULL
			END) AS [Outbound Transaction Count],
			
			-- Total transaction count
			COUNT(DISTINCT fsl.[Inventory Transaction Id]) AS [Total Transaction Count],
			
			-- Collect unique transaction types
			STRING_AGG(fsl.[Transaction Type], ', ') WITHIN GROUP (ORDER BY fsl.[Transaction Type]) AS [Transaction Types]
		
		FROM [dbo].[FactStockLevel] fsl
		LEFT JOIN [dbo].[DimCompany] co ON co.[Company Key] = fsl.[Company Key]
		LEFT JOIN [dbo].[DimProduct] p ON p.[Product Key] = fsl.[Product Key]
		LEFT JOIN [dbo].[DimProductInventory] pinv ON pinv.[Product Inventory Key] = fsl.[Product Inventory Key]
		LEFT JOIN [dbo].[DimInventoryDimension] id ON id.[Inventory Dimension Key] = fsl.[Inventory Dimension Key]
		LEFT JOIN [dbo].[DimWarehouse] w ON w.[Warehouse Key] = fsl.[Warehouse Key]
		
		WHERE fsl.[Transaction Date] >= @PeriodStartDate
		AND fsl.[Transaction Date] <= @PeriodEndDate
		
		GROUP BY 
			ISNULL(co.[Company Key], @NAKey),
			ISNULL(p.[Product Key], @NAKey),
			ISNULL(pinv.[Product Inventory Key], @NAKey),
			ISNULL(id.[Inventory Dimension Key], @NAKey),
			ISNULL(id.[Inventory Size Key], @NAKey),
			ISNULL(w.[Warehouse Key], @NAKey)
	),

	-- ===================================================================================
	-- STEP 4: Calculate average stock and KPIs
	-- ===================================================================================
	AggregatedSummary AS (
		SELECT 
			@Year AS [Year],
			@Month AS [Month],
			@PeriodStartDate AS [Period Start Date],
			@PeriodEndDate AS [Period End Date],
			dd.[Date Key],
			
			ISNULL(bom.[Company Key], @NAKey) [Company Key],
			ISNULL(bom.[Product Key], @NAKey) [Product Key],
			ISNULL(bom.[Product Inventory Key], @NAKey) [Product Inventory Key],
			ISNULL(bom.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key],
			ISNULL(bom.[Inventory Size Key], @NAKey) [Inventory Size Key],
			ISNULL(bom.[Warehouse Key], @NAKey) [Warehouse Key],
			
			-- BOM levels
			ISNULL(bom.[BOM Physical Stock Quantity], 0) [BOM Physical Stock Quantity],
			ISNULL(bom.[BOM Available Stock Quantity], 0) [BOM Available Stock Quantity],
			ISNULL(bom.[BOM Reserved Stock Quantity], 0) [BOM Reserved Stock Quantity],
			ISNULL(bom.[BOM On Order Stock Quantity], 0) [BOM On Order Stock Quantity],
			
			-- EOM levels
			ISNULL(eom.[EOM Physical Stock Quantity], 0) [EOM Physical Stock Quantity],
			ISNULL(eom.[EOM Available Stock Quantity], 0) [EOM Available Stock Quantity],
			ISNULL(eom.[EOM Reserved Stock Quantity], 0) [EOM Reserved Stock Quantity],
			ISNULL(eom.[EOM On Order Stock Quantity], 0) [EOM On Order Stock Quantity],
			
			-- Movements
			ISNULL(mov.[Total Inbound Quantity], 0) [Total Inbound Quantity],
			ISNULL(mov.[Total Outbound Quantity], 0) [Total Outbound Quantity],
			ISNULL(mov.[Total Inbound Quantity], 0) - ISNULL(mov.[Total Outbound Quantity], 0) [Net Movement Quantity],
			ISNULL(eom.[EOM Physical Stock Quantity], 0) - ISNULL(bom.[BOM Physical Stock Quantity], 0) [Quantity Change],
			
			-- Transaction counts
			ISNULL(mov.[Inbound Transaction Count], 0) [Inbound Transaction Count],
			ISNULL(mov.[Outbound Transaction Count], 0) [Outbound Transaction Count],
			ISNULL(mov.[Total Transaction Count], 0) [Total Transaction Count],
			
			-- Average stock (simplified: average of BOM and EOM)
			(ISNULL(bom.[BOM Physical Stock Quantity], 0) + ISNULL(eom.[EOM Physical Stock Quantity], 0)) / 2.0 [Average Physical Stock Quantity],
			(ISNULL(bom.[BOM Available Stock Quantity], 0) + ISNULL(eom.[EOM Available Stock Quantity], 0)) / 2.0 [Average Available Stock Quantity],
			
			-- KPI: Days Inventory Outstanding (DIO)
			CASE 
				WHEN ISNULL(mov.[Total Outbound Quantity], 0) > 0
				THEN CAST((ISNULL(eom.[EOM Physical Stock Quantity], 0) * DAY(EOMONTH(@PeriodStartDate))) / ISNULL(mov.[Total Outbound Quantity], 1) AS DECIMAL(10, 2))
				ELSE NULL
			END [Days Inventory Outstanding],
			
			-- KPI: Stock Turnover Ratio (monthly outbound / average stock)
			CASE 
				WHEN ((ISNULL(bom.[BOM Physical Stock Quantity], 0) + ISNULL(eom.[EOM Physical Stock Quantity], 0)) / 2.0) > 0
				THEN CAST(ISNULL(mov.[Total Outbound Quantity], 0) / ((ISNULL(bom.[BOM Physical Stock Quantity], 0) + ISNULL(eom.[EOM Physical Stock Quantity], 0)) / 2.0) AS DECIMAL(10, 4))
				ELSE NULL
			END [Stock Turnover Ratio],
			
			-- Stockout days (could be enhanced with daily aggregation)
			NULL [Stockout Days],
			
			-- Reference fields
			NULL [Product Count],
			mov.[Transaction Types],
			
			GETDATE() [ea_Process_DateTime],
			NULL [ea_Last_Update_DateTime],
			CASE 
				WHEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) = @PeriodStartDate
				THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
			END [Is Current Month]
		
		FROM BOMStockLevels bom
		FULL OUTER JOIN EOMStockLevels eom ON 
			eom.[Company Key] = bom.[Company Key]
			AND eom.[Product Key] = bom.[Product Key]
			AND eom.[Product Inventory Key] = bom.[Product Inventory Key]
			AND eom.[Inventory Dimension Key] = bom.[Inventory Dimension Key]
			AND eom.[Inventory Size Key] = bom.[Inventory Size Key]
			AND eom.[Warehouse Key] = bom.[Warehouse Key]
		LEFT JOIN MonthlyMovements mov ON 
			mov.[Company Key] = ISNULL(eom.[Company Key], bom.[Company Key])
			AND mov.[Product Key] = ISNULL(eom.[Product Key], bom.[Product Key])
			AND mov.[Product Inventory Key] = ISNULL(eom.[Product Inventory Key], bom.[Product Inventory Key])
			AND mov.[Inventory Dimension Key] = ISNULL(eom.[Inventory Dimension Key], bom.[Inventory Dimension Key])
			AND mov.[Inventory Size Key] = ISNULL(eom.[Inventory Size Key], bom.[Inventory Size Key])
			AND mov.[Warehouse Key] = ISNULL(eom.[Warehouse Key], bom.[Warehouse Key])
		LEFT JOIN [dbo].[DimDate] dd ON dd.[Date] = @PeriodEndDate
	)

	-- ===================================================================================
	-- STEP 5: MERGE into target table (upsert pattern)
	-- ===================================================================================
	MERGE [dbo].[FactInventoryMovementSummary] AS target
	USING AggregatedSummary AS source
	ON (
		target.[Year] = source.[Year]
		AND target.[Month] = source.[Month]
		AND target.[Company Key] = source.[Company Key]
		AND target.[Product Key] = source.[Product Key]
		AND target.[Product Inventory Key] = source.[Product Inventory Key]
		AND target.[Inventory Dimension Key] = source.[Inventory Dimension Key]
		AND target.[Warehouse Key] = source.[Warehouse Key]
	)
	WHEN MATCHED THEN
		UPDATE SET
			target.[Period Start Date] = source.[Period Start Date],
			target.[Period End Date] = source.[Period End Date],
			target.[Date Key] = source.[Date Key],
			target.[BOM Physical Stock Quantity] = source.[BOM Physical Stock Quantity],
			target.[BOM Available Stock Quantity] = source.[BOM Available Stock Quantity],
			target.[BOM Reserved Stock Quantity] = source.[BOM Reserved Stock Quantity],
			target.[BOM On Order Stock Quantity] = source.[BOM On Order Stock Quantity],
			target.[EOM Physical Stock Quantity] = source.[EOM Physical Stock Quantity],
			target.[EOM Available Stock Quantity] = source.[EOM Available Stock Quantity],
			target.[EOM Reserved Stock Quantity] = source.[EOM Reserved Stock Quantity],
			target.[EOM On Order Stock Quantity] = source.[EOM On Order Stock Quantity],
			target.[Total Inbound Quantity] = source.[Total Inbound Quantity],
			target.[Total Outbound Quantity] = source.[Total Outbound Quantity],
			target.[Net Movement Quantity] = source.[Net Movement Quantity],
			target.[Quantity Change] = source.[Quantity Change],
			target.[Inbound Transaction Count] = source.[Inbound Transaction Count],
			target.[Outbound Transaction Count] = source.[Outbound Transaction Count],
			target.[Total Transaction Count] = source.[Total Transaction Count],
			target.[Average Physical Stock Quantity] = source.[Average Physical Stock Quantity],
			target.[Average Available Stock Quantity] = source.[Average Available Stock Quantity],
			target.[Days Inventory Outstanding] = source.[Days Inventory Outstanding],
			target.[Stock Turnover Ratio] = source.[Stock Turnover Ratio],
			target.[Stockout Days] = source.[Stockout Days],
			target.[Product Count] = source.[Product Count],
			target.[Transaction Types] = source.[Transaction Types],
			target.[ea_Last_Update_DateTime] = GETDATE(),
			target.[Is Current Month] = source.[Is Current Month]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[Year],
			[Month],
			[Period Start Date],
			[Period End Date],
			[Date Key],
			[Company Key],
			[Product Key],
			[Product Inventory Key],
			[Inventory Dimension Key],
			[Inventory Size Key],
			[Warehouse Key],
			[BOM Physical Stock Quantity],
			[BOM Available Stock Quantity],
			[BOM Reserved Stock Quantity],
			[BOM On Order Stock Quantity],
			[EOM Physical Stock Quantity],
			[EOM Available Stock Quantity],
			[EOM Reserved Stock Quantity],
			[EOM On Order Stock Quantity],
			[Total Inbound Quantity],
			[Total Outbound Quantity],
			[Net Movement Quantity],
			[Quantity Change],
			[Inbound Transaction Count],
			[Outbound Transaction Count],
			[Total Transaction Count],
			[Average Physical Stock Quantity],
			[Average Available Stock Quantity],
			[Days Inventory Outstanding],
			[Stock Turnover Ratio],
			[Stockout Days],
			[Product Count],
			[Transaction Types],
			[ea_Process_DateTime],
			[ea_Last_Update_DateTime],
			[Is Current Month]
		)
		VALUES (
			source.[Year],
			source.[Month],
			source.[Period Start Date],
			source.[Period End Date],
			source.[Date Key],
			source.[Company Key],
			source.[Product Key],
			source.[Product Inventory Key],
			source.[Inventory Dimension Key],
			source.[Inventory Size Key],
			source.[Warehouse Key],
			source.[BOM Physical Stock Quantity],
			source.[BOM Available Stock Quantity],
			source.[BOM Reserved Stock Quantity],
			source.[BOM On Order Stock Quantity],
			source.[EOM Physical Stock Quantity],
			source.[EOM Available Stock Quantity],
			source.[EOM Reserved Stock Quantity],
			source.[EOM On Order Stock Quantity],
			source.[Total Inbound Quantity],
			source.[Total Outbound Quantity],
			source.[Net Movement Quantity],
			source.[Quantity Change],
			source.[Inbound Transaction Count],
			source.[Outbound Transaction Count],
			source.[Total Transaction Count],
			source.[Average Physical Stock Quantity],
			source.[Average Available Stock Quantity],
			source.[Days Inventory Outstanding],
			source.[Stock Turnover Ratio],
			source.[Stockout Days],
			source.[Product Count],
			source.[Transaction Types],
			source.[ea_Process_DateTime],
			source.[ea_Last_Update_DateTime],
			source.[Is Current Month]
		);

	SET @ProcessRows = @@ROWCOUNT;

	PRINT '========================================';
	PRINT 'Stock Level Summary ETL Completed';
	PRINT '========================================';
	PRINT 'Period: ' + CAST(@Year AS NVARCHAR(4)) + '-' + RIGHT('0' + CAST(@Month AS NVARCHAR(2)), 2);
	PRINT 'Rows Processed: ' + CAST(@ProcessRows AS NVARCHAR(20));
	PRINT 'Execution Time: ' + CAST(GETDATE() AS NVARCHAR(30));

END
GO

GRANT EXECUTE ON [ax7].[SL_EAStockLevelSummary] TO [ETL_User]
GRANT EXECUTE ON [ax7].[SL_EAStockLevelSummary] TO [Report_User]
GO
