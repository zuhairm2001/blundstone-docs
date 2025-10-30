SELECT
fIV.[Product Key]
,fIV.[Product Inventory Key]
,fIV.[Inventory Dimension Key]
,SUM(ISNULL([Physical Quantity],0)) as [Physical Quantity]
,SUM([Available Physical Quantity]) as [Available Physical Quantity]
,SUM(ISNULL([Physical Reserved Quantity],0)) as [Physical Reserved Quantity]

FROM
[dbo].[FactInventoryValue] fIV
join [dbo].[DimProduct] dP on dP.[Product Key] = fIV.[Product Key] 
join [dbo].[DimInventoryDimension] dID on dID.[Inventory Dimension Key] = fIV.[Inventory Dimension Key] 
	
WHERE 
dP.[Company Code] in ('blu', 'nzl')
and [Commodity] in ('FOOTWEAR', 'ANCILLARY', 'POS')
and [Warehouse Code] in ('DOMDC', 'AUCK')

GROUP BY
fIV.[Product Key]
,fIV.[Inventory Dimension Key]
,fIV.[Product Inventory Key]