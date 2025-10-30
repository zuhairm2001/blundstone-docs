/****** Object:  UserDefinedFunction [dbo].[ufn_GetPeriodTransactions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ufn_GetPeriodTransactions]
(
    @CompanyKey INT,
    @ProductKey INT,
    @InventoryDimensionKey INT,
    @WarehouseKey INT,
    @PeriodStartDate DATE,
    @PeriodEndDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        -- Quantities by Status (mirroring the logic from current SL_EAInventoryValueTransactions)
        SUM(CASE WHEN [Issue Status] = 'Sold' OR [Receipt Status] = 'Purchased' 
                 THEN [Quantity] ELSE 0 END) AS [Period Posted Quantity],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered')
                 THEN [Quantity] ELSE 0 END) AS [Period Physical Quantity],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered')
                 THEN [Quantity] ELSE 0 END) AS [Period Avail Physical Qty],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical', 'ReservOrdered', 'OnOrder') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered', 'Arrived', 'Ordered')
                 THEN [Quantity] ELSE 0 END) AS [Period Total Available Qty],
        
        SUM(CASE WHEN [Issue Status] = 'ReservPhysical' THEN -[Quantity] ELSE 0 END) AS [Period Reserved Physical Qty],
        
        SUM(CASE WHEN [Receipt Status] IN ('Arrived', 'Ordered') THEN [Quantity] ELSE 0 END) AS [Period Ordered Total Qty],
        
        SUM(CASE WHEN [Issue Status] = 'OnOrder' THEN -[Quantity] ELSE 0 END) AS [Period On Order Qty],
        
        SUM(CASE WHEN [Issue Status] = 'ReservOrdered' THEN -[Quantity] ELSE 0 END) AS [Period Ordered Reserved Qty],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered')
                 THEN [Quantity] ELSE 0 END) AS [Period Available For Res Qty],
        
        SUM([Settled Quantity]) AS [Period Settled Quantity],
        
        -- Costs
        SUM(CASE WHEN [Issue Status] = 'Sold' OR [Receipt Status] = 'Purchased' 
                 THEN [Cost Amount] ELSE 0 END) AS [Period Posted Cost Amount],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered')
                 THEN [Cost Amount] ELSE 0 END) AS [Period Physical Cost Amount],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered')
                 THEN [Available Physical Cost Amount] ELSE 0 END) AS [Period Avail Physical Cost],
        
        SUM(CASE WHEN [Issue Status] IN ('Sold', 'Deducted', 'Picked', 'ReservPhysical', 'ReservOrdered', 'OnOrder') 
                  OR [Receipt Status] IN ('Purchased', 'Received', 'Registered', 'Arrived', 'Ordered')
                 THEN [Total Available Cost Amount] ELSE 0 END) AS [Period Total Available Cost],
        
        SUM([Physical Reserved Cost Amount]) AS [Period Reserved Physical Cost],
        
        SUM(CASE WHEN [Receipt Status] IN ('Arrived', 'Ordered') THEN [Ordered In Total Cost Amount] ELSE 0 END) AS [Period Ordered Total Cost],
        
        SUM([On Order Cost Amount]) AS [Period On Order Cost],
        
        SUM([Ordered Reserved Cost Amount]) AS [Period Ordered Reserved Cost],
        
        SUM([Available For Reservation Cost Amount]) AS [Period Available For Res Cost],
        
        SUM([Physical Revenue Amount]) AS [Period Physical Revenue Amt]
        
    FROM [dbo].[FactInventoryValue]
    WHERE [Company Key] = @CompanyKey
        AND [Product Key] = @ProductKey
        AND [Inventory Dimension Key] = @InventoryDimensionKey
        AND [Warehouse Key] = @WarehouseKey
        AND [Transaction Date] >= @PeriodStartDate
        AND [Transaction Date] <= @PeriodEndDate
        AND [ea_Is_Deleted] = 0
)
GO