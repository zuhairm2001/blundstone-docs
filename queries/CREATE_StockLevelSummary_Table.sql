-- ===================================================================================
-- Create StockLevelSummary Table
-- Purpose: Monthly aggregated stock level summary for reporting and analytics
-- Author: Generated for Blundstone warehouse stock reporting
-- Date: 2025-10-28
-- EST: ~50K rows/month across all warehouses/locations, ~2GB/year
-- ===================================================================================

-- Drop table if exists (comment out for safety in production)
-- DROP TABLE IF EXISTS [dbo].[StockLevelSummary];

CREATE TABLE [dbo].[FactInventoryMovementSummary] (
	-- Primary Key
	[Summary Key] INT IDENTITY(1,1) NOT NULL,

	-- Date Keys (Monthly grain)
	[Year] INT NOT NULL,
	[Month] INT NOT NULL,
	[Period Start Date] DATE NOT NULL,
	[Period End Date] DATE NOT NULL,
	[Date Key] INT NULL,  -- Links to DimDate for the last day of the month

	-- Foreign Keys to Dimensions
	[Company Key] INT NULL,
	[Product Key] INT NULL,
	[Product Inventory Key] INT NULL,
	[Inventory Dimension Key] INT NULL,
	[Warehouse Key] INT NULL,

	-- Beginning of Month Stock Levels
	[BOM Physical Stock Quantity] DECIMAL(18, 4) NULL,
	[BOM Available Stock Quantity] DECIMAL(18, 4) NULL,
	[BOM Reserved Stock Quantity] DECIMAL(18, 4) NULL,
	[BOM On Order Stock Quantity] DECIMAL(18, 4) NULL,

	-- End of Month Stock Levels
	[EOM Physical Stock Quantity] DECIMAL(18, 4) NULL,
	[EOM Available Stock Quantity] DECIMAL(18, 4) NULL,
	[EOM Reserved Stock Quantity] DECIMAL(18, 4) NULL,
	[EOM On Order Stock Quantity] DECIMAL(18, 4) NULL,

	-- Monthly Movements/Changes
	[Total Inbound Quantity] DECIMAL(18, 4) NULL,        -- Total receipts for the month
	[Total Outbound Quantity] DECIMAL(18, 4) NULL,       -- Total issues for the month
	[Net Movement Quantity] DECIMAL(18, 4) NULL,         -- Inbound - Outbound
	[Quantity Change] DECIMAL(18, 4) NULL,               -- EOM - BOM

	-- Monthly Transaction Counts
	[Inbound Transaction Count] INT NULL,
	[Outbound Transaction Count] INT NULL,
	[Total Transaction Count] INT NULL,

	-- Average Stock Levels (for analysis)
	[Average Physical Stock Quantity] DECIMAL(18, 4) NULL,
	[Average Available Stock Quantity] DECIMAL(18, 4) NULL,

	-- Stock Health Indicators
	[Days Inventory Outstanding] DECIMAL(10, 2) NULL,    -- EOM / (Daily Avg Outbound)
	[Stock Turnover Ratio] DECIMAL(10, 4) NULL,          -- Outbound / Average Stock
	[Stockout Days] INT NULL,                             -- Count of days with zero stock

	-- Reference Fields
	[Product Count] INT NULL,                             -- Distinct products in warehouse for period
	[Transaction Types] NVARCHAR(500) NULL,              -- Comma-separated list of transaction types

	-- ETL Metadata
	[ea_Process_DateTime] DATETIME NULL DEFAULT GETDATE(),
	[ea_Last_Update_DateTime] DATETIME NULL,
	[Is Current Month] BIT NULL,

	-- Primary Key Constraint
	CONSTRAINT [PK_StockLevelSummary] PRIMARY KEY CLUSTERED ([Summary Key] ASC)
);
