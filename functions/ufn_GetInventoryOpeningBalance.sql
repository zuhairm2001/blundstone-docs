/****** Object:  UserDefinedFunction [dbo].[ufn_GetInventoryOpeningBalance] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ufn_GetInventoryOpeningBalance]
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
    SELECT TOP 1
        ob.[Opening Balance Key],
        ob.[Company Key],
        ob.[Product Key], 
        ob.[Inventory Dimension Key],
        ob.[Warehouse Key],
        ob.[Period Start Date],
        ob.[Period End Date],
        ob.[Fiscal Year],
        ob.[Fiscal Period],
        
        -- Opening Balance Quantities
        ob.[Opening Posted Quantity],
        ob.[Opening Physical Quantity],
        ob.[Opening Available Physical Qty],
        ob.[Opening Total Available Qty],
        ob.[Opening Reserved Physical Qty],
        ob.[Opening Ordered Total Qty],
        ob.[Opening On Order Qty],
        ob.[Opening Ordered Reserved Qty],
        ob.[Opening Available For Res Qty],
        ob.[Opening Settled Quantity],
        
        -- Opening Balance Costs
        ob.[Opening Cost Amount],
        ob.[Opening Posted Cost Amount],
        ob.[Opening Physical Cost Amount],
        ob.[Opening Avail Physical Cost],
        ob.[Opening Total Available Cost],
        ob.[Opening Reserved Physical Cost],
        ob.[Opening Ordered Total Cost],
        ob.[Opening On Order Cost],
        ob.[Opening Ordered Reserved Cost],
        ob.[Opening Available For Res Cost],
        ob.[Opening Physical Revenue Amt],
        
        -- Audit Fields
        ob.[Created DateTime],
        ob.[Created By],
        ob.[Last Updated DateTime],
        ob.[Last Updated By],
        ob.[Is Locked]
        
    FROM [dbo].[FactInventoryOpeningBalance] ob
    WHERE ob.[Company Key] = @CompanyKey
        AND ob.[Product Key] = @ProductKey
        AND ob.[Inventory Dimension Key] = @InventoryDimensionKey
        AND ob.[Warehouse Key] = @WarehouseKey
        AND ob.[Period Start Date] <= @AsOfDate
        AND ob.[Is Locked] = 0
    ORDER BY ob.[Period Start Date] DESC
)
GO