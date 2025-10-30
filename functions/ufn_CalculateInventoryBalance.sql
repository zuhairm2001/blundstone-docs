/****** Object:  UserDefinedFunction [dbo].[ufn_CalculateInventoryBalance] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ufn_CalculateInventoryBalance]
(
    @CompanyKey INT,
    @ProductKey INT,
    @InventoryDimensionKey INT,
    @WarehouseKey INT,
    @AsOfDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        -- Opening Balances (from the most recent period)
        ISNULL(ob.[Opening Posted Quantity], 0) AS [Opening Posted Quantity],
        ISNULL(ob.[Opening Physical Quantity], 0) AS [Opening Physical Quantity],
        ISNULL(ob.[Opening Available Physical Qty], 0) AS [Opening Available Physical Qty],
        ISNULL(ob.[Opening Total Available Qty], 0) AS [Opening Total Available Qty],
        ISNULL(ob.[Opening Reserved Physical Qty], 0) AS [Opening Reserved Physical Qty],
        ISNULL(ob.[Opening Ordered Total Qty], 0) AS [Opening Ordered Total Qty],
        ISNULL(ob.[Opening On Order Qty], 0) AS [Opening On Order Qty],
        ISNULL(ob.[Opening Ordered Reserved Qty], 0) AS [Opening Ordered Reserved Qty],
        ISNULL(ob.[Opening Available For Res Qty], 0) AS [Opening Available For Res Qty],
        ISNULL(ob.[Opening Settled Quantity], 0) AS [Opening Settled Quantity],
        
        -- Period Transactions (from opening balance period start to as-of-date)
        ISNULL(pt.[Period Posted Quantity], 0) AS [Period Posted Quantity],
        ISNULL(pt.[Period Physical Quantity], 0) AS [Period Physical Quantity],
        ISNULL(pt.[Period Avail Physical Qty], 0) AS [Period Avail Physical Qty],
        ISNULL(pt.[Period Total Available Qty], 0) AS [Period Total Available Qty],
        ISNULL(pt.[Period Reserved Physical Qty], 0) AS [Period Reserved Physical Qty],
        ISNULL(pt.[Period Ordered Total Qty], 0) AS [Period Ordered Total Qty],
        ISNULL(pt.[Period On Order Qty], 0) AS [Period On Order Qty],
        ISNULL(pt.[Period Ordered Reserved Qty], 0) AS [Period Ordered Reserved Qty],
        ISNULL(pt.[Period Available For Res Qty], 0) AS [Period Available For Res Qty],
        ISNULL(pt.[Period Settled Quantity], 0) AS [Period Settled Quantity],
        
        -- Current Balances (Opening + Period)
        (ISNULL(ob.[Opening Posted Quantity], 0) + ISNULL(pt.[Period Posted Quantity], 0)) AS [Current Posted Quantity],
        (ISNULL(ob.[Opening Physical Quantity], 0) + ISNULL(pt.[Period Physical Quantity], 0)) AS [Current Physical Quantity],
        (ISNULL(ob.[Opening Available Physical Qty], 0) + ISNULL(pt.[Period Avail Physical Qty], 0)) AS [Current Available Physical Qty],
        (ISNULL(ob.[Opening Total Available Qty], 0) + ISNULL(pt.[Period Total Available Qty], 0)) AS [Current Total Available Qty],
        (ISNULL(ob.[Opening Reserved Physical Qty], 0) + ISNULL(pt.[Period Reserved Physical Qty], 0)) AS [Current Reserved Physical Qty],
        (ISNULL(ob.[Opening Ordered Total Qty], 0) + ISNULL(pt.[Period Ordered Total Qty], 0)) AS [Current Ordered Total Qty],
        (ISNULL(ob.[Opening On Order Qty], 0) + ISNULL(pt.[Period On Order Qty], 0)) AS [Current On Order Qty],
        (ISNULL(ob.[Opening Ordered Reserved Qty], 0) + ISNULL(pt.[Period Ordered Reserved Qty], 0)) AS [Current Ordered Reserved Qty],
        (ISNULL(ob.[Opening Available For Res Qty], 0) + ISNULL(pt.[Period Available For Res Qty], 0)) AS [Current Available For Res Qty],
        (ISNULL(ob.[Opening Settled Quantity], 0) + ISNULL(pt.[Period Settled Quantity], 0)) AS [Current Settled Quantity],
        
        -- Cost Balances
        (ISNULL(ob.[Opening Cost Amount], 0) + ISNULL(pt.[Period Posted Cost Amount], 0)) AS [Current Cost Amount],
        (ISNULL(ob.[Opening Posted Cost Amount], 0) + ISNULL(pt.[Period Posted Cost Amount], 0)) AS [Current Posted Cost Amount],
        (ISNULL(ob.[Opening Physical Cost Amount], 0) + ISNULL(pt.[Period Physical Cost Amount], 0)) AS [Current Physical Cost Amount],
        (ISNULL(ob.[Opening Physical Revenue Amt], 0) + ISNULL(pt.[Period Physical Revenue Amt], 0)) AS [Current Physical Revenue Amt],
        
        -- Period Information
        ob.[Period Start Date],
        ob.[Period End Date],
        ob.[Fiscal Year],
        ob.[Fiscal Period],
        @AsOfDate AS [Balance As Of Date]
        
    FROM (SELECT 1 as dummy) d
    LEFT JOIN [dbo].[ufn_GetInventoryOpeningBalance](@CompanyKey, @ProductKey, @InventoryDimensionKey, @WarehouseKey, @AsOfDate) ob ON 1=1
    LEFT JOIN [dbo].[ufn_GetPeriodTransactions](@CompanyKey, @ProductKey, @InventoryDimensionKey, @WarehouseKey, ob.[Period Start Date], @AsOfDate) pt ON 1=1
)
GO