-- ===================================================================================
-- Create FactStockLevel Table
-- Purpose: Create the target fact table for warehouse stock levels
-- Author: Generated for Blundstone warehouse stock reporting
-- Date: 2025-10-16
-- ===================================================================================

-- Drop table if exists (comment out for safety in production)
-- DROP TABLE IF EXISTS [dbo].[FactStockLevel];

CREATE TABLE [dbo].[FactStockLevel] (
    -- Primary Key
    [Stock Level Key] INT IDENTITY(1,1) NOT NULL,

    -- Foreign Keys to Dimensions
    [Company Key] INT NULL,
    [Product Key] INT NULL,
    [Product Inventory Key] INT NULL,
    [Inventory Dimension Key] INT NULL,
    [Warehouse Key] INT NULL,

    -- Date Keys
    [Transaction Date] DATETIME NULL,

    -- Stock Quantity Measures (Non-Financial)
    [Physical Stock Quantity] DECIMAL(18, 4) NULL,
    [Available Stock Quantity] DECIMAL(18, 4) NULL,
    [Reserved Stock Quantity] DECIMAL(18, 4) NULL,
    [Ordered Stock Quantity] DECIMAL(18, 4) NULL,
    [On Order Stock Quantity] DECIMAL(18, 4) NULL,

    -- Transaction Attributes
    [Transaction Type] NVARCHAR(50) NULL,
    [Transaction Status] NVARCHAR(50) NULL,
    [Movement Type] NVARCHAR(50) NULL,

    -- Reference Fields
    [Inventory Reference] NVARCHAR(50) NULL,
    [Inventory Transaction Id] NVARCHAR(50) NULL,
    [Warehouse Transaction Id] NVARCHAR(50) NULL,  -- Reserved for future use
    [Item Set Id] NVARCHAR(50) NULL,               -- Reserved for future use

    -- Date Fields (Business Dates)
    [Inventory Date] DATETIME NULL,
    [Status Date] DATETIME NULL,

    -- ETL Metadata
    [ea_Process_DateTime] DATETIME NULL,
    [Record Id] BIGINT NULL,  -- Maps to RECID in source system

    -- Primary Key Constraint
    CONSTRAINT [PK_FactStockLevel] PRIMARY KEY CLUSTERED ([Stock Level Key] ASC)
);

-- ===================================================================================
-- Create Indexes for Performance
-- ===================================================================================

-- Index on Record Id (used in MERGE operation)
CREATE UNIQUE NONCLUSTERED INDEX [IX_FactStockLevel_RecordId]
ON [dbo].[FactStockLevel] ([Record Id])
WHERE [Stock Level Key] > 0
WITH (ONLINE = OFF);

-- Index on dimension keys for reporting queries
CREATE NONCLUSTERED INDEX [IX_FactStockLevel_DimensionKeys]
ON [dbo].[FactStockLevel] (
    [Company Key],
    [Product Key],
    [Warehouse Key],
    [Inventory Dimension Key]
)
INCLUDE (
    [Physical Stock Quantity],
    [Available Stock Quantity],
    [Reserved Stock Quantity]
)
WITH (ONLINE = OFF);

-- Index on transaction date for time-based queries
CREATE NONCLUSTERED INDEX [IX_FactStockLevel_TransactionDate]
ON [dbo].[FactStockLevel] ([Transaction Date])
INCLUDE (
    [Product Key],
    [Warehouse Key],
    [Physical Stock Quantity]
)
WITH (ONLINE = OFF);

-- Index on Product Key for product-level reporting
CREATE NONCLUSTERED INDEX [IX_FactStockLevel_ProductKey]
ON [dbo].[FactStockLevel] ([Product Key])
INCLUDE (
    [Warehouse Key],
    [Physical Stock Quantity],
    [Available Stock Quantity],
    [Reserved Stock Quantity]
)
WITH (ONLINE = OFF);

-- Index on Warehouse Key for warehouse-level reporting
CREATE NONCLUSTERED INDEX [IX_FactStockLevel_WarehouseKey]
ON [dbo].[FactStockLevel] ([Warehouse Key])
INCLUDE (
    [Product Key],
    [Physical Stock Quantity],
    [Available Stock Quantity]
)
WITH (ONLINE = OFF);

-- ===================================================================================
-- Create Foreign Key Constraints (Optional - comment out if dimensions not ready)
-- ===================================================================================

-- Uncomment when dimension tables are ready and populated
/*
ALTER TABLE [dbo].[FactStockLevel]
ADD CONSTRAINT [FK_FactStockLevel_Company]
FOREIGN KEY ([Company Key]) REFERENCES [dbo].[DimCompany]([Company Key]);

ALTER TABLE [dbo].[FactStockLevel]
ADD CONSTRAINT [FK_FactStockLevel_Product]
FOREIGN KEY ([Product Key]) REFERENCES [dbo].[DimProduct]([Product Key]);

ALTER TABLE [dbo].[FactStockLevel]
ADD CONSTRAINT [FK_FactStockLevel_Warehouse]
FOREIGN KEY ([Warehouse Key]) REFERENCES [dbo].[DimWarehouse]([Warehouse Key]);

ALTER TABLE [dbo].[FactStockLevel]
ADD CONSTRAINT [FK_FactStockLevel_InventoryDimension]
FOREIGN KEY ([Inventory Dimension Key]) REFERENCES [dbo].[DimInventoryDimension]([Inventory Dimension Key]);
*/

-- ===================================================================================
-- Grant Permissions
-- ===================================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON [dbo].[FactStockLevel] TO [ETL_User];
GRANT SELECT ON [dbo].[FactStockLevel] TO [Report_User];

-- ===================================================================================
-- Verify Table Creation
-- ===================================================================================

PRINT '========================================';
PRINT 'Table Creation Summary';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('[dbo].[FactStockLevel]', 'U') IS NOT NULL
BEGIN
    PRINT '✓ Table [dbo].[FactStockLevel] created successfully';
    PRINT '';

    -- Show column information
    PRINT 'Column Information:';
    SELECT
        c.name AS [Column Name],
        t.name AS [Data Type],
        c.max_length AS [Max Length],
        c.precision AS [Precision],
        c.scale AS [Scale],
        CASE WHEN c.is_nullable = 1 THEN 'YES' ELSE 'NO' END AS [Nullable]
    FROM sys.columns c
    JOIN sys.types t ON c.user_type_id = t.user_type_id
    WHERE c.object_id = OBJECT_ID('[dbo].[FactStockLevel]')
    ORDER BY c.column_id;

    PRINT '';
    PRINT 'Index Information:';
    SELECT
        i.name AS [Index Name],
        i.type_desc AS [Index Type],
        CASE WHEN i.is_unique = 1 THEN 'YES' ELSE 'NO' END AS [Unique]
    FROM sys.indexes i
    WHERE i.object_id = OBJECT_ID('[dbo].[FactStockLevel]')
    AND i.name IS NOT NULL;

    PRINT '';
    PRINT 'Ready for ETL process!';
END
ELSE
BEGIN
    PRINT '✗ ERROR: Table creation failed';
END

PRINT '';
PRINT '========================================';
PRINT 'Next Steps:';
PRINT '========================================';
PRINT '1. Run queries/SL_EAWarehouseStockLevels.sql to create the stored procedure';
PRINT '2. Run queries/TEST_SL_EAWarehouseStockLevels.sql to test the ETL process';
PRINT '3. Run queries/VALIDATE_ETL_Results.sql to validate data quality';
PRINT '========================================';

GO
