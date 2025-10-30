SELECT 
fIV.[Product Key],
[Inventory Size Key],
[Product Inventory Key],
[Warehouse Key],
[Status Date],
[Inventory Reference],
[Transaction Type],
SUM([Physical Quantity]) as [Physical Quantity]

FROM  
[dbo].[FactInventoryValue] fIV
join [dbo].[DimCompany] dC on dC.[Company Key] = fIV.[Company Key]
join [dbo].[DimProduct] dP on dP.[Product Key] = fIV.[Product Key]

WHERE 
dC.[Company Code] in ('blu', 'nzl', 'usa')
and [Commodity] in ('footwear', 'ancillary')

GROUP BY 
fIV.[Product Key],
[Inventory Size Key],
[Product Inventory Key],
[Warehouse Key],
[Status Date],
[Inventory Reference],
[Transaction Type]