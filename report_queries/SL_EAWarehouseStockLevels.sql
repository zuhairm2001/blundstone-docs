/****** Object:  StoredProcedure [dbo].[SL_EAWarehouseStockLevels]    Script Date: 10/03/2025 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SL_EAWarehouseStockLevels]
(
    @ExecutionId [nvarchar](90),
    @IncrementalLoad [bit],
    @ProcessRows [bigint] OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    declare @NA nvarchar(10);
    declare @NANumber int;
    declare @NAKey int;
    declare @NADate datetime;
    declare @MaxDate datetime;

    -- Initialize system parameters
    select top (1) @NA = [NA String], @NAKey = [NA Key], @NANumber = [NA Number], @NADate = [NA DateTime],
           @MaxDate = [Maximum Date]
    from [edw].[EtlParams];

    -- Clean up existing data for incremental load
    DELETE t
    FROM [dbo].[FactWarehouseStockLevels] t
    LEFT JOIN [ax7].[InventTrans] s ON s.[RECID] = t.[Record Id]
    WHERE t.[Stock Level Key] > 0 
    AND s.[DataAreaId] IS NULL;

    -- StatusIssue variables for filtering
    declare @si_None int;
    declare @si_Sold int;
    declare @si_Deducted int;
    declare @si_Picked int;
    declare @si_ReservPhysical int;
    declare @si_ReservOrdered int;
    declare @si_OnOrder int;
    declare @si_QuotationIssue int;

    -- Initialize StatusIssue variables
    select @si_None = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'None';
    select @si_Sold = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Sold';
    select @si_Deducted = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Deducted';
    select @si_Picked = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Picked';
    select @si_ReservPhysical = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'ReservPhysical';
    select @si_ReservOrdered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'ReservOrdered';
    select @si_OnOrder = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'OnOrder';
    select @si_QuotationIssue = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'QuotationIssue';

    -- StatusReceipt variables for filtering
    declare @sr_None int;
    declare @sr_Purchased int;
    declare @sr_Received int;
    declare @sr_Registered int;
    declare @sr_Arrived int;
    declare @sr_Ordered int;
    declare @sr_QuotationReceipt int;

    -- Initialize StatusReceipt variables
    select @sr_None = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'None';
    select @sr_Purchased = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Purchased';
    select @sr_Received = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Received';
    select @sr_Registered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Registered';
    select @sr_Arrived = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Arrived';
    select @sr_Ordered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Ordered';
    select @sr_QuotationReceipt = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'QuotationReceipt';

    -- Clean up existing data for incremental load
    DELETE t
    FROM [dbo].[FactWarehouseStockLevels] t
    LEFT JOIN [ax7].[InventTrans] s ON s.[RECID] = t.[Record Id]
    WHERE t.[Stock Level Key] > 0 
    AND s.[DataAreaId] IS NULL;

    -- Main data extraction and transformation
    WITH StockData AS (
        SELECT 
            src.[ExecutionId],
            src.RECID [RECORDID],
            src.DataAreaId [COMPANYCODE],
            src.[ItemId],
            src.[inventDimId],
            src.[DatePhysical],
            src.[StatusIssue],
            src.[StatusReceipt],
            src.[Qty],
            src.[CostAmountPhysical],
            src.[CostAmountPosted],
            src.[DateInvent],
            src.[DateStatus],
            src.[InterCompanyInventDimTransferred],
            ISNULL(src.[InvoiceId], '') [InvoiceId],
            src.[InvoiceReturned],
            src.[LoadId],
            ISNULL(src.[PackingSlipId], '') [PackingSlipId],
            src.[PackingSlipReturned],
            src.[PickingRouteID],
            src.[QtySettled],
            src.[RevenueAmountPhysical],
            src.[ShippingDateConfirmed],
            src.[ShippingDateRequested],
            src.[ReferenceCategory],
            src.[ReferenceId],
            src.[InventTransId],
            T3.Voucher [VOUCHERNUMBERPHYSICAL],
            T4.Voucher [VOUCHERNUMBERFINANCIAL],
            T3.DefaultDimension [DEFAULTDIMENSIONPHYSICAL],
            T3.LedgerDimension [LEDGERDIMENSIONPHYSICAL],
            T4.DefaultDimension [DEFAULTDIMENSIONFINANCIAL],
            T4.LedgerDimension [LEDGERDIMENSIONFINANCIAL]
        FROM [ax7].InventTrans src
        LEFT OUTER JOIN ax7.InventTransOrigin AS T2 ON src.InventTransOrigin = T2.RECID
        LEFT OUTER JOIN ax7.InventTransPosting AS T3 ON T3.InventTransPostingType = 0 AND src.DataAreaId = T3.DataAreaId AND src.InventTransOrigin = T3.InventTransOrigin 
            AND src.VoucherPhysical = T3.Voucher AND src.DatePhysical = T3.TransDate
        LEFT OUTER JOIN ax7.InventTransPosting AS T4 ON T4.InventTransPostingType = 1 AND src.InventTransOrigin = T4.InventTransOrigin AND src.DataAreaId = T4.DataAreaId 
            AND src.Voucher = T4.Voucher AND src.DateFinancial = T4.TransDate
        WHERE (@IncrementalLoad = 0 OR src.[EXECUTIONID] = @ExecutionId)
        AND (
            src.STATUSISSUE IN (@si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder) 
            OR src.STATUSRECEIPT IN (@sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered)
        )
        AND [REFERENCECATEGORY] <> 26
    ),
    AggregatedData AS (
        SELECT 
            ISNULL(co.[Company Key], @NAKey) [Company Key],
            ISNULL(p.[Product Key], @NAKey) [Product Key],
            ISNULL(p.[Product Inventory Key], @NAKey) [Product Inventory Key],
            ISNULL(id.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key],
            ISNULL(trdate.[DateKey], @NADate) [Transaction Date],
            p.[Item Code],
            p.[Product Name],
            p.[Commodity],
            p.[Inventory Unit],
            id.[Inventory Size Key],
            id.[Inventory Color Key],
            id.[Inventory Config Key],
            id.[Inventory Style Key],
            w.[Warehouse Key],
            SUM(CASE WHEN src.[Status Issue] IN (@si_Sold, @si_Deducted) OR src.[Status Receipt] IN (@sr_Purchased, @sr_Received) THEN src.[Qty] END) AS [Physical Stock Quantity],
            SUM(CASE WHEN src.[Status Issue] IN (@si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical) OR src.[Status Receipt] IN (@sr_Purchased, @sr_Received, @sr_Registered) THEN src.[Qty] END) AS [Available Stock Quantity],
            SUM(CASE WHEN src.[Status Issue] = @si_ReservPhysical THEN -src.[Qty] END) AS [Reserved Stock Quantity],
            SUM(CASE WHEN src.[Status Issue] IN (@si_OnOrder) OR src.[Status Receipt] IN (@sr_Ordered) THEN src.[Qty] END) AS [Ordered Stock Quantity],
            SUM(CASE WHEN src.[Status Issue] IN (@si_OnOrder) OR src.[Status Receipt] IN (@sr_Ordered) THEN src.[Qty] END) AS [On Order Stock Quantity],
            src.[Transaction Type],
            src.[Transaction Status],
            src.[Inventory Reference],
            src.[Status Date],
            src.[Inventory Transaction Id],
            src.[Warehouse Transaction Id],
            src.[DateInvent] [Inventory Date]
        FROM StockData src
        LEFT JOIN [dbo].[DimCompany] co ON co.[Company Code] = src.[COMPANYCODE]
        LEFT JOIN [dbo].[DimProduct] p ON p.[Company Code] = src.[COMPANYCODE] AND p.[Item Number] = src.[ItemId]
        LEFT JOIN [dbo].[DimInventoryDimension] id ON id.[Company Code] = src.[COMPANYCODE] AND id.[Inventory Dimension Id] = src.[inventDimId]
        LEFT JOIN [dbo].[DimWarehouse] w ON w.[Company Code] = src.[COMPANYCODE] AND w.[Inventory Site Code] = id.[Inventory Site Code] AND w.[Warehouse Code] = id.[Warehouse Code]
        LEFT JOIN [dbo].[DimDate] trdate ON trdate.[DateKey] = src.[DatePhysical]
        GROUP BY 
            ISNULL(co.[Company Key], @NAKey),
            ISNULL(p.[Product Key], @NAKey),
            ISNULL(p.[Product Inventory Key], @NAKey),
            ISNULL(id.[Inventory Dimension Key], @NAKey),
            ISNULL(trdate.[DateKey], @NADate),
            p.[Item Code],
            p.[Product Name],
            p.[Commodity],
            p.[Inventory Unit],
            id.[Inventory Size Key],
            id.[Inventory Color Key],
            id.[Inventory Config Key],
            id.[Inventory Style Key],
            w.[Warehouse Key],
            src.[Transaction Type],
            src.[Transaction Status],
            src.[Inventory Reference],
            src.[Status Date],
            src.[Inventory Transaction Id],
            src.[Warehouse Transaction Id],
            src.[DateInvent]
    )
    SELECT 
        [Company Key],
        [Product Key],
        [Product Inventory Key],
        [Inventory Dimension Key],
        [Transaction Date],
        [Item Code],
        [Product Name],
        [Commodity],
        [Inventory Unit],
        [Inventory Size Key],
        [Inventory Color Key],
        [Inventory Config Key],
        [Inventory Style Key],
        [Warehouse Key],
        [Physical Stock Quantity],
        [Available Stock Quantity],
        [Reserved Stock Quantity],
        [Ordered Stock Quantity],
        [On Order Stock Quantity],
        [Transaction Type],
        [Transaction Status],
        [Inventory Reference],
        [Inventory Date],
        [Status Date],
        [Inventory Transaction Id],
        [Warehouse Transaction Id],
        GETDATE() [ea_Process_DateTime],
        0 [ea_Is_Deleted]
    FROM AggregatedData
)

-- Merge into target table
MERGE [dbo].[FactWarehouseStockLevels] AS t
USING AggregatedData AS s
ON (t.[Record Id] = s.[Record Id])
WHEN MATCHED THEN 
    UPDATE SET 
        t.[Company Key] = s.[Company Key],
        t.[Product Key] = s.[Product Key],
        t.[Product Inventory Key] = s.[Product Inventory Key],
        t.[Inventory Dimension Key] = s.[Inventory Dimension Key],
        t.[Transaction Date] = s.[Transaction Date],
        t.[Item Code] = s.[Item Code],
        t.[Product Name] = s.[Product Name],
        t.[Commodity] = s.[Commodity],
        t.[Inventory Unit] = s.[Inventory Unit],
        t.[Inventory Size Key] = s.[Inventory Size Key],
        t.[Inventory Color Key] = s.[Inventory Color Key],
        t.[Inventory Config Key] = s.[Inventory Config Key],
        t.[Inventory Style Key] = s.[Inventory Style Key],
        t.[Warehouse Key] = s.[Warehouse Key],
        t.[Physical Stock Quantity] = s.[Physical Stock Quantity],
        t.[Available Stock Quantity] = s.[Available Stock Quantity],
        t.[Reserved Stock Quantity] = s.[Reserved Stock Quantity],
        t.[Ordered Stock Quantity] = s.[Ordered Stock Quantity],
        t.[On Order Stock Quantity] = s.[On Order Stock Quantity],
        t.[Transaction Type] = s.[Transaction Type],
        t.[Transaction Status] = s.[Transaction Status],
        t.[Inventory Reference] = s.[Inventory Reference],
        t.[Inventory Date] = s.[Inventory Date],
        t.[Status Date] = s.[Status Date],
        t.[Inventory Transaction Id] = s.[Inventory Transaction Id],
        t.[Warehouse Transaction Id] = s.[Warehouse Transaction Id],
        t.[ea_Process_DateTime] = s.[ea_Process_DateTime],
        t.[ea_Is_Deleted] = s.[ea_Is_Deleted]
WHEN NOT MATCHED BY TARGET THEN 
    INSERT (
        [Company Key],
        [Product Key],
        [Product Inventory Key],
        [Inventory Dimension Key],
        [Transaction Date],
        [Item Code],
        [Product Name],
        [Commodity],
        [Inventory Unit],
        [Inventory Size Key],
        [Inventory Color Key],
        [Inventory Config Key],
        [Inventory Style Key],
        [Warehouse Key],
        [Physical Stock Quantity],
        [Available Stock Quantity],
        [Reserved Stock Quantity],
        [Ordered Stock Quantity],
        [On Order Stock Quantity],
        [Transaction Type],
        [Transaction Status],
        [Inventory Reference],
        [Inventory Date],
        [Status Date],
        [Inventory Transaction Id],
        [Warehouse Transaction Id],
        [ea_Process_DateTime],
        [ea_Is_Deleted]
    ) VALUES (
        s.[Company Key],
        s.[Product Key],
        s.[Product Inventory Key],
        s.[Inventory Dimension Key],
        s.[Transaction Date],
        s.[Item Code],
        s.[Product Name],
        s.[Commodity],
        s.[Inventory Unit],
        s.[Inventory Size Key],
        s.[Inventory Color Key],
        s.[Inventory Config Key],
        s.[Inventory Style Key],
        s.[Warehouse Key],
        s.[Physical Stock Quantity],
        s.[Available Stock Quantity],
        s.[Reserved Stock Quantity],
        s.[Ordered Stock Quantity],
        s.[On Order Stock Quantity],
        s.[Transaction Type],
        s.[Transaction Status],
        s.[Inventory Reference],
        s.[Inventory Date],
        s.[Status Date],
        s.[Inventory Transaction Id],
        s.[Warehouse Transaction Id],
        s.[ea_Process_DateTime],
        s.[ea_Is_Deleted]
    );

SET @ProcessRows = @@ROWCOUNT;

END
GO