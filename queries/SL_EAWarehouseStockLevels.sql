SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [ax7].[SL_EAStockLevels]
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

    select top (1) @NA = [NA String], @NAKey = [NA Key], @NANumber = [NA Number], @NADate = [NA DateTime],
           @MaxDate = [Maximum Date]
    from [edw].[EtlParams];

    declare @si_None int;
    declare @si_Sold int;
    declare @si_Deducted int;
    declare @si_Picked int;
    declare @si_ReservPhysical int;
    declare @si_ReservOrdered int;
    declare @si_OnOrder int;
    declare @si_QuotationIssue int;

    declare @sr_None int;
    declare @sr_Purchased int;
    declare @sr_Received int;
    declare @sr_Registered int;
    declare @sr_Arrived int;
    declare @sr_Ordered int;
    declare @sr_QuotationReceipt int;

    select @si_None = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'None';
    select @si_Sold = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Sold';
    select @si_Deducted = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Deducted';
    select @si_Picked = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'Picked';
    select @si_ReservPhysical = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'ReservPhysical';
    select @si_ReservOrdered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'ReservOrdered';
    select @si_OnOrder = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'OnOrder';
    select @si_QuotationIssue = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusIssue' and [Value Name] = N'QuotationIssue';

    select @sr_None = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'None';
    select @sr_Purchased = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Purchased';
    select @sr_Received = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Received';
    select @sr_Registered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Registered';
    select @sr_Arrived = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Arrived';
    select @sr_Ordered = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'Ordered';
    select @sr_QuotationReceipt = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'StatusReceipt' and [Value Name] = N'QuotationReceipt';

    DELETE t
    FROM [dbo].[FactStockLevel] t
    LEFT JOIN [ax7].[InventTrans] s ON s.[RECID] = t.[Record Id]
    WHERE t.[Stock Level Key] > 0 
    AND s.[DataAreaId] IS NULL;

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
            ISNULL(T2.[ReferenceCategory], 0) [ReferenceCategory],
            T2.[ReferenceId] [ReferenceId],
            CAST(src.[recid] AS NVARCHAR(50)) [InventTransId],
            T3.Voucher [VOUCHERNUMBERPHYSICAL],
            T4.Voucher [VOUCHERNUMBERFINANCIAL]
        FROM [ax7].InventTrans src
        LEFT OUTER JOIN ax7.InventTransOrigin AS T2 ON src.InventTransOrigin = T2.RECID
        LEFT OUTER JOIN ax7.InventTransPosting AS T3 ON T3.InventTransPostingType = 0 
            AND src.DataAreaId = T3.DataAreaId 
            AND src.InventTransOrigin = T3.InventTransOrigin 
            AND src.VoucherPhysical = T3.Voucher 
            AND src.DatePhysical = T3.TransDate
        LEFT OUTER JOIN ax7.InventTransPosting AS T4 ON T4.InventTransPostingType = 1 
            AND src.InventTransOrigin = T4.InventTransOrigin 
            AND src.DataAreaId = T4.DataAreaId 
            AND src.Voucher = T4.Voucher 
            AND src.DateFinancial = T4.TransDate
        WHERE (@IncrementalLoad = 0 OR src.[EXECUTIONID] = @ExecutionId OR @ExecutionId IS NULL)
        AND (
            src.STATUSISSUE IN (@si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder) 
            OR src.STATUSRECEIPT IN (@sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered)
        )
        AND ISNULL(T2.[ReferenceCategory], 0) <> 26
    ),
    
    TransactionMapping AS (
        SELECT 
            *,
            CASE 
                WHEN [StatusIssue] IN (@si_Sold, @si_Deducted) THEN 'OUT'
                WHEN [StatusReceipt] IN (@sr_Purchased, @sr_Received) THEN 'IN'
                WHEN [StatusIssue] = @si_Picked THEN 'TRANSFER'
                WHEN [StatusIssue] = @si_ReservPhysical THEN 'RESERVATION'
                WHEN [StatusReceipt] IN (@sr_Arrived, @sr_Ordered) THEN 'ON_ORDER'
                ELSE 'OTHER'
            END AS [Movement Type],
            CASE ISNULL([ReferenceCategory], 0)
                WHEN 0 THEN 'None'
                WHEN 1 THEN 'Sales Order'
                WHEN 2 THEN 'Purchase Order'
                WHEN 3 THEN 'Inventory Journal'
                WHEN 4 THEN 'Production Order'
                WHEN 5 THEN 'Transfer Order'
                WHEN 6 THEN 'Quotation'
                WHEN 7 THEN 'Return Order'
                WHEN 8 THEN 'Inventory Movement'
                WHEN 9 THEN 'Counting Journal'
                WHEN 10 THEN 'BOM'
                WHEN 11 THEN 'Kanban'
                WHEN 12 THEN 'Quality Order'
                WHEN 13 THEN 'Inventory Blocking'
                WHEN 14 THEN 'Inventory Adjustment'
                WHEN 15 THEN 'Inventory Transfer'
                WHEN 16 THEN 'Inventory Receipt'
                WHEN 17 THEN 'Inventory Issue'
                WHEN 18 THEN 'Inventory Counting'
                WHEN 19 THEN 'Inventory On-hand'
                WHEN 20 THEN 'Inventory Reservation'
                WHEN 21 THEN 'Inventory Marking'
                WHEN 22 THEN 'Inventory Settlement'
                WHEN 23 THEN 'Inventory Cost Adjustment'
                WHEN 24 THEN 'Inventory Standard Cost'
                WHEN 25 THEN 'Inventory Cost Group'
                ELSE 'Unknown'
            END AS [Transaction Type],
            CASE 
                WHEN [StatusIssue] IS NOT NULL AND [StatusIssue] <> @si_None
                    THEN CAST((SELECT ev.[Value Label] FROM [ax7].[EnumValues] ev WHERE ev.[Enum Name] = N'StatusIssue' AND ev.[Value Id] = [StatusIssue]) AS NVARCHAR(50))
                WHEN [StatusReceipt] IS NOT NULL AND [StatusReceipt] <> @sr_None
                    THEN CAST((SELECT ev.[Value Label] FROM [ax7].[EnumValues] ev WHERE ev.[Enum Name] = N'StatusReceipt' AND ev.[Value Id] = [StatusReceipt]) AS NVARCHAR(50))
                ELSE NULL
            END AS [Transaction Status]
        FROM StockData
    ),
    
    AggregatedStockLevels AS (
        SELECT 
            ISNULL(co.[Company Key], @NAKey) [Company Key],
            ISNULL(p.[Product Key], @NAKey) [Product Key],
            ISNULL(pinv.[Product Inventory Key], @NAKey) [Product Inventory Key],
            ISNULL(id.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key],
            ISNULL(trdate.[DateKey], @NADate) [Transaction Date],
            w.[Warehouse Key],
            
            SUM(CASE 
                WHEN src.[StatusIssue] IN (@si_Sold, @si_Deducted) OR src.[StatusReceipt] IN (@sr_Purchased, @sr_Received) 
                THEN src.[Qty] 
                ELSE 0 
            END) AS [Physical Stock Quantity],
            
            SUM(CASE 
                WHEN src.[StatusIssue] IN (@si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical) 
                    OR src.[StatusReceipt] IN (@sr_Purchased, @sr_Received, @sr_Registered) 
                THEN src.[Qty] 
                ELSE 0 
            END) AS [Available Stock Quantity],
            
            SUM(CASE 
                WHEN src.[StatusIssue] = @si_ReservPhysical 
                THEN -src.[Qty] 
                ELSE 0 
            END) AS [Reserved Stock Quantity],
            
            SUM(CASE 
                WHEN src.[StatusIssue] IN (@si_OnOrder) OR src.[StatusReceipt] IN (@sr_Arrived, @sr_Ordered) 
                THEN src.[Qty] 
                ELSE 0 
            END) AS [Ordered Stock Quantity],
            
            SUM(CASE 
                WHEN src.[StatusIssue] IN (@si_OnOrder) OR src.[StatusReceipt] IN (@sr_Arrived, @sr_Ordered) 
                THEN src.[Qty] 
                ELSE 0 
            END) AS [On Order Stock Quantity],
            
            src.[Transaction Type],
            src.[Transaction Status],
            src.[Movement Type],
            src.[ReferenceId] AS [Inventory Reference],
            src.[DateInvent] AS [Inventory Date],
            src.[DateStatus] AS [Status Date],
            src.[InventTransId] AS [Inventory Transaction Id],
            NULL AS [Warehouse Transaction Id],
            NULL AS [Item Set Id],
            src.[RECORDID] AS [Record Id]
            
        FROM TransactionMapping src
        LEFT JOIN [dbo].[DimCompany] co ON co.[Company Code] = src.[COMPANYCODE]
        LEFT JOIN [dbo].[DimProduct] p ON p.[Company Code] = src.[COMPANYCODE] AND p.[Item Number] = src.[ItemId]
        LEFT JOIN [dbo].[DimInventoryDimension] id ON id.[Company Code] = src.[COMPANYCODE] AND id.[Inventory Dimension Id] = src.[inventDimId]
        LEFT JOIN [dbo].[DimProductInventory] pinv ON pinv.[Company Code] = src.[COMPANYCODE] 
            AND pinv.[Item Number] = src.[ItemId] 
            AND pinv.[Inventory Site Code] = id.[Inventory Site Code] 
            AND pinv.[Inventory Size Code] = id.[Size Code]
        LEFT JOIN [dbo].[DimWarehouse] w ON w.[Company Code] = src.[COMPANYCODE] 
            AND w.[Inventory Site Code] = id.[Inventory Site Code] 
            AND w.[Warehouse Code] = id.[Warehouse Code]
        LEFT JOIN [dbo].[DimDate] trdate ON trdate.[DateKey] = src.[DatePhysical]
        
         GROUP BY 
            ISNULL(co.[Company Key], @NAKey),
            ISNULL(p.[Product Key], @NAKey),
            ISNULL(pinv.[Product Inventory Key], @NAKey),
            ISNULL(id.[Inventory Dimension Key], @NAKey),
            ISNULL(trdate.[DateKey], @NADate),
            w.[Warehouse Key],
            src.[Transaction Type],
            src.[Transaction Status],
            src.[Movement Type],
            src.[ReferenceId],
            src.[DateInvent],
            src.[DateStatus],
            src.[InventTransId],
            src.[RECORDID]
    )

    MERGE [dbo].[FactStockLevel] AS t
    USING AggregatedStockLevels AS s
    ON (t.[Record Id] = s.[Record Id])
    
    WHEN MATCHED THEN 
        UPDATE SET 
            t.[Company Key] = s.[Company Key],
            t.[Product Key] = s.[Product Key],
            t.[Product Inventory Key] = s.[Product Inventory Key],
            t.[Inventory Dimension Key] = s.[Inventory Dimension Key],
            t.[Transaction Date] = s.[Transaction Date],
            t.[Warehouse Key] = s.[Warehouse Key],
            t.[Physical Stock Quantity] = s.[Physical Stock Quantity],
            t.[Available Stock Quantity] = s.[Available Stock Quantity],
            t.[Reserved Stock Quantity] = s.[Reserved Stock Quantity],
            t.[Ordered Stock Quantity] = s.[Ordered Stock Quantity],
            t.[On Order Stock Quantity] = s.[On Order Stock Quantity],
            t.[Transaction Type] = s.[Transaction Type],
            t.[Transaction Status] = s.[Transaction Status],
            t.[Movement Type] = s.[Movement Type],
            t.[Inventory Reference] = s.[Inventory Reference],
            t.[Inventory Date] = s.[Inventory Date],
            t.[Status Date] = s.[Status Date],
            t.[Inventory Transaction Id] = s.[Inventory Transaction Id],
            t.[Warehouse Transaction Id] = s.[Warehouse Transaction Id],
            t.[Item Set Id] = s.[Item Set Id],
            t.[ea_Process_DateTime] = GETDATE()
    
    WHEN NOT MATCHED BY TARGET THEN 
        INSERT (
            [Company Key],
            [Product Key],
            [Product Inventory Key],
            [Inventory Dimension Key],
            [Transaction Date],
            [Warehouse Key],
            [Physical Stock Quantity],
            [Available Stock Quantity],
            [Reserved Stock Quantity],
            [Ordered Stock Quantity],
            [On Order Stock Quantity],
            [Transaction Type],
            [Transaction Status],
            [Movement Type],
            [Inventory Reference],
            [Inventory Date],
            [Status Date],
            [Inventory Transaction Id],
            [Warehouse Transaction Id],
            [Item Set Id],
            [ea_Process_DateTime],
            [Record Id]
        ) VALUES (
            s.[Company Key],
            s.[Product Key],
            s.[Product Inventory Key],
            s.[Inventory Dimension Key],
            s.[Transaction Date],
            s.[Warehouse Key],
            s.[Physical Stock Quantity],
            s.[Available Stock Quantity],
            s.[Reserved Stock Quantity],
            s.[Ordered Stock Quantity],
            s.[On Order Stock Quantity],
            s.[Transaction Type],
            s.[Transaction Status],
            s.[Movement Type],
            s.[Inventory Reference],
            s.[Inventory Date],
            s.[Status Date],
            s.[Inventory Transaction Id],
            s.[Warehouse Transaction Id],
            s.[Item Set Id],
            GETDATE(),
            s.[Record Id]
        );

    SET @ProcessRows = @@ROWCOUNT;

END
GO

GRANT EXECUTE ON [ax7].[SL_EAStockLevels] TO [ETL_User]
GRANT EXECUTE ON [ax7].[SL_EAStockLevels] TO [Report_User]
GO
