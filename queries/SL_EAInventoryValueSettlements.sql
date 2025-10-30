/****** Object:  StoredProcedure [ax7].[SL_EAInventoryValueSettlements]    Script Date: 9/23/2025 5:04:27 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [ax7].[SL_EAInventoryValueSettlements]
(
	@ExecutionId [nvarchar](90) 
	,@IncrementalLoad [bit] 
	,@ProcessRows [bigint] OUTPUT
)
AS
BEGIN

	SET NOCOUNT ON;

	declare @NA nvarchar(10);
	declare @NANumber int;
	declare @NAKey int;
	declare @NADate datetime;
	declare @MaxDate datetime;
	select top (1) @NA = [NA String], @NAKey = [NA Key], @NANumber = [NA Number], @NADate = [NA DateTime]
		,@MaxDate = [Maximum Date]
	from [edw].[EtlParams];

	-- StatusIssue variables
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

	-- StatusReceipt variables
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

	-- InventSettleModel variables
	declare @ism_PhysicalValue int;
	select @ism_PhysicalValue = [Value Id] from [ax7].[EnumValues] where [Enum Name] = N'InventSettleModel' and [Value Name] = N'PhysicalValue';

	delete t
	from [dbo].[FactInventorySettlement] t
	left join ax7.INVENTSETTLEMENT s on s.RecId = t.[Record Id] 
	where t.[Inventory Settlement Key] > 0 
	and s.dataareaid is null;

	with s as 
	(
		select 
			cast (173 as int) as [Record Type]

			,T2.[RECID] as [Record Id] 
			,t1.[dataareaid] as [Company Code]
			,t1.[ITEMID] as [Item Code]
			,t1.[INVENTDIMID] as [Inventory Dimension Id]
			,t2.[TRANSDATE] as [Transaction Date] 

			,t1.[STATUSISSUE] as [Status Issue]
			,t1.[STATUSRECEIPT] as [Status Receipt]

			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'StatusIssue' and ev.[Value Id] = t1.[STATUSISSUE]) as nvarchar(20)) as [Issue Status]
			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'StatusReceipt' and ev.[Value Id] = t1.[STATUSRECEIPT]) as nvarchar(20)) as [Receipt Status]

			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'InventTransType' and ev.[Value Id] = t3.[REFERENCECATEGORY]) as nvarchar(20)) as [Transaction Type] 
			,t3.[REFERENCEID] as [Inventory Reference] 

			,t10.[UNITID] as [Inventory Unit] 
			,null as [Quantity] 

			,t1.[CURRENCYCODE] as [Currency Code]
			,t2.[COSTAMOUNTADJUSTMENT] as [Cost Amount]
			,cast(N'Adjustment' as nvarchar(20)) as [Posting Type]
			,t2.[VOUCHER] as [Voucher Number]
			,T9.RECID as [Ledger Dimension Id]
			,T8.RECID as [Default Dimension Id]

			,cast(0 as bigint) as [Category Id]

			,[DATEINVENT] as [Inventory Date]
			,[DATESTATUS] as [Status Date]
			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = t1.[INTERCOMPANYINVENTDIMTRANSFERRED]) as nvarchar(20)) as [Is Inter Company Transfer]

			,[INVOICEID] as [Invoice Number]
			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = t1.[INVOICERETURNED]) as nvarchar(20)) as  [Is Invoice Returned]
			,[LOADID] as [Load Code]
			,[PACKINGSLIPID]  as [Product Receipt]
			,cast((select ev.[Value Label] from [ax7].[EnumValues] ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = t1.[PACKINGSLIPRETURNED]) as nvarchar(20)) as [Is Product Returned]
			,[PICKINGROUTEID] as [Picking Route Code]
			,t1.[QTYSETTLED] as [Settled Quantity]

			,[REVENUEAMOUNTPHYSICAL] as [Physical Revenue Amount]
			,[SHIPPINGDATECONFIRMED] as [Shipping Comfirmed Date]
			,[SHIPPINGDATEREQUESTED] as [Shipping Requested Date]
			,t3.[INVENTTRANSID] as [Inventory Transaction Id]
			,[DATEEXPECTED]as [Date Expected]

		from ax7.INVENTTRANS T1 
		CROSS JOIN ax7.INVENTSETTLEMENT T2 
		CROSS JOIN ax7.INVENTTRANSORIGIN T3 
		LEFT OUTER JOIN ax7.INVENTTRANSPOSTING T4 ON(((((( T4.INVENTTRANSPOSTINGTYPE  =  1)  AND ( T1.DATAAREAID  =  T4.DATAAREAID)))  AND ((( T1.INVENTTRANSORIGIN  =  T4.INVENTTRANSORIGIN)  AND ( T1.DATAAREAID  =  T4.DATAAREAID))))  AND ((( T1.VOUCHER  =  T4.VOUCHER)  AND ( T1.DATAAREAID  =  T4.DATAAREAID))))  AND ((( T1.DATEFINANCIAL  =  T4.TRANSDATE)  AND ( T1.DATAAREAID  =  T4.DATAAREAID)))) 
		LEFT OUTER JOIN ax7.INVENTTABLE T5 ON((( T1.ITEMID  =  T5.ITEMID)  AND ( T1.DATAAREAID  =  T5.DATAAREAID)) ) 
		LEFT OUTER JOIN ax7.INVENTTRANSORIGIN T6 ON((( T1.MARKINGREFINVENTTRANSORIGIN  =  T6.RECID)  AND ( T1.DATAAREAID  =  T6.DATAAREAID)) ) 
		LEFT OUTER JOIN ax7.INVENTTRANSORIGIN T7 ON((( T1.RETURNINVENTTRANSORIGIN  =  T7.RECID)  AND ( T1.DATAAREAID  =  T7.DATAAREAID))) 
		LEFT OUTER JOIN ax7.DIMENSIONATTRIBUTEVALUESET T8 ON(( T2.DEFAULTDIMENSION  =  T8.RECID)  ) 
		LEFT OUTER JOIN ax7.DIMENSIONATTRIBUTEVALUECOMBINATION T9 ON(( T4.LEDGERDIMENSION  =  T9.RECID)) 
		CROSS JOIN ax7.INVENTTABLEMODULE T10 
		WHERE T1.RECID  =  T2.TRANSRECID AND T1.DATAAREAID  =  T2.DATAAREAID AND T1.INVENTTRANSORIGIN  =  T3.RECID AND T1.DATAAREAID  =  T3.DATAAREAID AND T10.MODULETYPE =  0 AND T5.ITEMID  =  T10.ITEMID AND T5.DATAAREAID  =  T10.DATAAREAID 
		AND T1.DataLakeModified_DateTime is not null	
		and (@IncrementalLoad = 0 or t2.[EXECUTIONID] = @ExecutionId)
		and (t1.STATUSISSUE in ( @si_Sold ) or t1.STATUSRECEIPT in ( @sr_Purchased ))
		and t2.SETTLEMODEL <> @ism_PhysicalValue
		and T2.RECID <> 0
	), iv as (
	select isnull(co.[Company Key], @NAKey) [Company Key]
		,isnull(p.[Product Key], @NAKey) [Product Key]
		,isnull(id.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key]
		,isnull(trdate.[DateKey], @NADate) [Transaction Date]

		,s.[Record Id]

		,isnull(s.[Issue Status], @NA) [Issue Status]
		,isnull(s.[Receipt Status], @NA) [Receipt Status]
		,isnull(s.[Transaction Type], @NA) [Transaction Type]
		,isnull(s.[Inventory Reference], @NA) [Inventory Reference]

		,s.[Inventory Unit]
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received ) then s.[Quantity] end as [Quantity] 

		,isnull(cr.[Currency Key], @NAKey) [Currency Key]
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received ) then s.[Cost Amount] end as [Cost Amount] 

		,isnull(s.[Posting Type], @NA) [Posting Type]
		,isnull(s.[Voucher Number], @NA) [Voucher Number]

		,isnull(dd.[Default Dimension Key], @NAKey) [Default Dimension Key]

		,isnull(ch.[Category Hierarchy Key], @NAKey) [Category Hierarchy Key]
		,isnull(cl.[Inventory Color Key], @NAKey) [Inventory Color Key]
		,isnull(cn.[Inventory Config Key], @NAKey) [Inventory Config Key]
		,isnull(sz.[Inventory Size Key], @NAKey) [Inventory Size Key]
		,isnull(sy.[Inventory Style Key], @NAKey) [Inventory Style Key]

		,isnull(w.[Warehouse Key], @NAKey) [Warehouse Key]

		,case when s.[Status Issue] = @si_Sold or s.[Status Receipt] = @sr_Purchased then s.[Quantity] end as [Posted Quantity] 
	    ,case when s.[Status Issue] = @si_Sold or s.[Status Receipt] = @sr_Purchased then s.[Cost Amount] end as [Posted Cost Amount] 

		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Quantity] end as [Physical Quantity]    
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Cost Amount] end as [Physical Cost Amount]

		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Quantity] end as [Available Physical Quantity]
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Cost Amount] end as [Available Physical Cost Amount]

		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered ) then s.[Quantity] end as [Total Available Quantity]
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered ) then s.[Cost Amount] end as [Total Available Cost Amount]

		,case when s.[Status Issue] = @si_ReservPhysical then -s.[Quantity] end as [Physical Reserved Quantity]
		,case when s.[Status Issue] = @si_ReservPhysical then -s.[Cost Amount] end as [Physical Reserved Cost Amount]
		
		,case when s.[Status Receipt] in ( @sr_Arrived, @sr_Ordered ) then s.[Quantity] end as [Ordered In Total Quantity]  
		,case when s.[Status Receipt] in ( @sr_Arrived, @sr_Ordered ) then s.[Cost Amount]  end as [Ordered In Total Cost Amount]

		,case when s.[Status Issue] = @si_OnOrder then -s.[Quantity]  end as [On Order Quantity]
		,case when s.[Status Issue] = @si_OnOrder then -s.[Cost Amount] end as [On Order Cost Amount]       
		
		,case when s.[Status Issue] = @si_ReservOrdered then -s.[Quantity] end as [Ordered Reserved Quantity]
		,case when s.[Status Issue] = @si_ReservOrdered then -s.[Cost Amount] end as [Ordered Reserved Cost Amount]

		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Quantity] end as [Available For Reservation Quantity]
		,case when s.[Status Issue] in ( @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical ) or s.[Status Receipt] in ( @sr_Purchased, @sr_Received, @sr_Registered ) then s.[Cost Amount] end as [Available For Reservation Cost Amount]

		,isnull(si.[Sales Invoice Key], @NAKey) [Sales Invoice Key]
		,isnull(l.[Load Key], @NAKey) [Load Key]
		,s.[Inventory Date]
		,s.[Status Date]
		,s.[Is Inter Company Transfer]
		,s.[Is Invoice Returned]
		,s.[Product Receipt]
		,s.[Is Product Returned]
		,s.[Picking Route Code]
		,s.[Settled Quantity]
		,s.[Physical Revenue Amount]
		,s.[Shipping Comfirmed Date]
		,s.[Shipping Requested Date]

		,isnull(pinv.[Product Inventory Key], @NAKey) [Product Inventory Key]
		,s.[Inventory Transaction Id]
		,s.[Date Expected]

	from s
	left join [dbo].[DimCompany] co on co.[Company Code] = s.[Company Code]
	left join [dbo].[DimCurrency] cr on cr.[Currency Code] = s.[Currency Code] 
	left join [dbo].[DimProduct] p on p.[Company Code] = s.[Company Code] and p.[Item Number] = s.[Item Code] 
	left join [dbo].[DimInventoryDimension] id on id.[Company Code] = s.[Company Code] and id.[Inventory Dimension Id] = s.[Inventory Dimension Id] 
	left join [dbo].[DimDefaultDimension] dd on dd.[Default Dimension Id] = s.[Default Dimension Id] 
	left join [dbo].[DimDate] trdate on trdate.[DateKey] = s.[Transaction Date]

	left join [dbo].[DimInventoryColor] cl on cl.[Company Code] = s.[Company Code] and cl.[Item Code] = s.[Item Code] and cl.[Inventory Color Code] = id.[Color Code] 
	left join [dbo].[DimInventoryConfig] cn on cn.[Company Code] = s.[Company Code] and cn.[Item Code] = s.[Item Code] and cn.[Inventory Config Code] = id.[Configuration Code] 
	left join [dbo].[DimInventorySize] sz on sz.[Company Code] = s.[Company Code] and sz.[Item Code] = s.[Item Code] and sz.[Inventory Size Code] = id.[Size Code] 
	left join [dbo].[DimInventoryStyle] sy on sy.[Company Code] = s.[Company Code] and sy.[Item Code] = s.[Item Code] and sy.[Inventory Style Code] = id.[Style Code] 

	left join [dbo].[DimCategoryHierarchy] ch on ch.[Category Id] = s.[Category Id] 
	left join [dbo].[DimWarehouse] w on w.[Company Code] = id.[Company Code] and w.[Inventory Site Code] = id.[Inventory Site Code] and w.[Warehouse Code] = id.[Warehouse Code] 

	left join [dbo].[DimSalesInvoice] si on si.[Company Code] = s.[Company Code] and si.[Invoice Number] = s.[Invoice Number] and si.[Voucher] = s.[Voucher Number]
	left join [dbo].[DimLoad] l on l.[Company Code] = s.[Company Code] and l.[Load Code] = s.[Load Code] 
	left join [dbo].[DimProductInventory] pinv on pinv.[Company Code] = s.[Company Code] and pinv.[Item Number]= s.[Item Code] and pinv.[Inventory Site Code] = id.[Inventory Site Code] and pinv.[Inventory Size Code] = id.[Size Code]
	)

	merge [dbo].[FactInventorySettlement] as t
	using IV as s
	on (t.[Record Id] = s.[Record Id])
	when matched and not exists
	(
		select s.[Company Key]
			,s.[Product Key]
			,s.[Inventory Dimension Key]
			,s.[Transaction Date]
			,s.[Issue Status]
			,s.[Receipt Status]
			,s.[Transaction Type]
			,s.[Inventory Reference]
			,s.[Inventory Unit]
			,s.[Quantity]
			,s.[Currency Key]
			,s.[Cost Amount]
			,s.[Posting Type]
			,s.[Voucher Number]
			,s.[Default Dimension Key]
			,s.[Category Hierarchy Key]
			,s.[Inventory Color Key]
			,s.[Inventory Config Key]
			,s.[Inventory Size Key]
			,s.[Inventory Style Key]
			,s.[Warehouse Key]
			,s.[Posted Quantity]
			,s.[Posted Cost Amount]
			,s.[Physical Quantity]    
			,s.[Physical Cost Amount]
			,s.[Available Physical Quantity]
			,s.[Available Physical Cost Amount]
			,s.[Total Available Quantity]
			,s.[Total Available Cost Amount]
			,s.[Physical Reserved Quantity]      
			,s.[Physical Reserved Cost Amount]     
			,s.[Ordered In Total Quantity]  
			,s.[Ordered In Total Cost Amount]   
			,s.[On Order Quantity]
			,s.[On Order Cost Amount]        
			,s.[Ordered Reserved Quantity]          
			,s.[Ordered Reserved Cost Amount]                   
			,s.[Available For Reservation Quantity]    
			,s.[Available For Reservation Cost Amount]
			,s.[Sales Invoice Key]
			,s.[Load Key]
			,s.[Inventory Date]
			,s.[Status Date]
			,s.[Is Inter Company Transfer]
			,s.[Is Invoice Returned]
			,s.[Product Receipt]
			,s.[Is Product Returned]
			,s.[Picking Route Code]
			,s.[Settled Quantity]
			,s.[Physical Revenue Amount]
			,s.[Shipping Comfirmed Date]
			,s.[Shipping Requested Date]
			,s.[Product Inventory Key]
			,s.[Inventory Transaction Id]
			,s.[Date Expected]
		intersect
		select t.[Company Key]
			,t.[Product Key]
			,t.[Inventory Dimension Key]
			,t.[Transaction Date]
			,t.[Issue Status]
			,t.[Receipt Status]
			,t.[Transaction Type]
			,t.[Inventory Reference]
			,t.[Inventory Unit]
			,t.[Quantity]
			,t.[Currency Key]
			,t.[Cost Amount]
			,t.[Posting Type]
			,t.[Voucher Number]
			,t.[Default Dimension Key]
			,t.[Category Hierarchy Key]
			,t.[Inventory Color Key]
			,t.[Inventory Config Key]
			,t.[Inventory Size Key]
			,t.[Inventory Style Key]
			,t.[Warehouse Key]
			,t.[Posted Quantity]
			,t.[Posted Cost Amount]
			,t.[Physical Quantity]    
			,t.[Physical Cost Amount]
			,t.[Available Physical Quantity]
			,t.[Available Physical Cost Amount]
			,t.[Total Available Quantity]
			,t.[Total Available Cost Amount]
			,t.[Physical Reserved Quantity]      
			,t.[Physical Reserved Cost Amount]     
			,t.[Ordered In Total Quantity]  
			,t.[Ordered In Total Cost Amount]   
			,t.[On Order Quantity]
			,t.[On Order Cost Amount]        
			,t.[Ordered Reserved Quantity]          
			,t.[Ordered Reserved Cost Amount]                   
			,t.[Available For Reservation Quantity]    
			,t.[Available For Reservation Cost Amount]
			,t.[Sales Invoice Key]
			,t.[Load Key]
			,t.[Inventory Date]
			,t.[Status Date]
			,t.[Is Inter Company Transfer]
			,t.[Is Invoice Returned]
			,t.[Product Receipt]
			,t.[Is Product Returned]
			,t.[Picking Route Code]
			,t.[Settled Quantity]
			,t.[Physical Revenue Amount]
			,t.[Shipping Comfirmed Date]
			,t.[Shipping Requested Date]
			,t.[Product Inventory Key]
			,t.[Inventory Transaction Id]
			,t.[Date Expected]
	)
	then
		UPDATE SET t.[Company Key]=s.[Company Key]
			,t.[Product Key]=s.[Product Key]
			,t.[Inventory Dimension Key]=s.[Inventory Dimension Key]
			,t.[Transaction Date]=s.[Transaction Date]
			,t.[Issue Status]=s.[Issue Status]
			,t.[Receipt Status]=s.[Receipt Status]
			,t.[Transaction Type]=s.[Transaction Type]
			,t.[Inventory Reference]=s.[Inventory Reference]
			,t.[Inventory Unit]=s.[Inventory Unit]
			,t.[Quantity]=s.[Quantity]
			,t.[Currency Key]=s.[Currency Key]
			,t.[Cost Amount]=s.[Cost Amount]
			,t.[Posting Type]=s.[Posting Type]
			,t.[Voucher Number]=s.[Voucher Number]
			,t.[Default Dimension Key]=s.[Default Dimension Key]

			,t.[Category Hierarchy Key]=s.[Category Hierarchy Key]
			,t.[Inventory Color Key]=s.[Inventory Color Key]
			,t.[Inventory Config Key]=s.[Inventory Config Key]
			,t.[Inventory Size Key]=s.[Inventory Size Key]
			,t.[Inventory Style Key]=s.[Inventory Style Key]

			,t.[Warehouse Key]=s.[Warehouse Key]

			,t.[Posted Quantity] = s.[Posted Quantity]
			,t.[Posted Cost Amount] = s.[Posted Cost Amount]
			,t.[Physical Quantity] = s.[Physical Quantity]
			,t.[Physical Cost Amount] =s.[Physical Cost Amount]
			,t.[Available Physical Quantity] = s.[Available Physical Quantity]
			,t.[Available Physical Cost Amount] = s.[Available Physical Cost Amount]
			,t.[Total Available Quantity] = s.[Total Available Quantity]
			,t.[Total Available Cost Amount] = s.[Total Available Cost Amount]
			,t.[Physical Reserved Quantity] = s.[Physical Reserved Quantity]
			,t.[Physical Reserved Cost Amount] = s.[Physical Reserved Cost Amount]
			,t.[Ordered In Total Quantity] = s.[Ordered In Total Quantity]
			,t.[Ordered In Total Cost Amount]  = s.[Ordered In Total Cost Amount]
			,t.[On Order Quantity] = s.[On Order Quantity]
			,t.[On Order Cost Amount] = s.[On Order Cost Amount]       
			,t.[Ordered Reserved Quantity] = s.[Ordered Reserved Quantity] 
			,t.[Ordered Reserved Cost Amount] = s.[Ordered Reserved Cost Amount]                
			,t.[Available For Reservation Quantity] = s.[Available For Reservation Quantity]
			,t.[Available For Reservation Cost Amount] = s.[Available For Reservation Cost Amount]

			,t.[Sales Invoice Key] = s.[Sales Invoice Key]
			,t.[Load Key] = s.[Load Key]
			,t.[Inventory Date] = s.[Inventory Date]
			,t.[Status Date] = s.[Status Date]
			,t.[Is Inter Company Transfer] = s.[Is Inter Company Transfer]
			,t.[Is Invoice Returned] = s.[Is Invoice Returned]
			,t.[Product Receipt] = s.[Product Receipt]
			,t.[Is Product Returned] = s.[Is Product Returned]
			,t.[Picking Route Code] = s.[Picking Route Code]
			,t.[Settled Quantity] = s.[Settled Quantity]
			,t.[Physical Revenue Amount] = s.[Physical Revenue Amount]
			,t.[Shipping Comfirmed Date] = s.[Shipping Comfirmed Date]
			,t.[Shipping Requested Date] = s.[Shipping Requested Date]

			,t.[Product Inventory Key] = s.[Product Inventory Key]
			,t.[Inventory Transaction Id] = s.[Inventory Transaction Id]
			,t.[Date Expected]=s.[Date Expected]

			,t.[ea_Process_DateTime] = getdate()

	WHEN NOT MATCHED BY TARGET THEN 
		INSERT(
			[Company Key]
			,[Product Key]
			,[Inventory Dimension Key]
			,[Transaction Date]
			,[Record Id]
			,[Issue Status]
			,[Receipt Status]
			,[Transaction Type]
			,[Inventory Reference]
			,[Inventory Unit]
			,[Quantity]
			,[Currency Key]
			,[Cost Amount]
			,[Posting Type]
			,[Voucher Number]
			,[Default Dimension Key]

			,[Category Hierarchy Key]
			,[Inventory Color Key]
			,[Inventory Config Key]
			,[Inventory Size Key]
			,[Inventory Style Key]

			,[Warehouse Key]

			,[Posted Quantity]
			,[Posted Cost Amount]
			,[Physical Quantity]    
			,[Physical Cost Amount]
			,[Available Physical Quantity]
			,[Available Physical Cost Amount]
			,[Total Available Quantity]
			,[Total Available Cost Amount]
			,[Physical Reserved Quantity]      
			,[Physical Reserved Cost Amount]     
			,[Ordered In Total Quantity]  
			,[Ordered In Total Cost Amount]   
			,[On Order Quantity]
			,[On Order Cost Amount]        
			,[Ordered Reserved Quantity]          
			,[Ordered Reserved Cost Amount]                   
			,[Available For Reservation Quantity]    
			,[Available For Reservation Cost Amount]

			,[Sales Invoice Key]
			,[Load Key]
			,[Inventory Date]
			,[Status Date]
			,[Is Inter Company Transfer]
			,[Is Invoice Returned]
			,[Product Receipt]
			,[Is Product Returned]
			,[Picking Route Code]
			,[Settled Quantity]
			,[Physical Revenue Amount]
			,[Shipping Comfirmed Date]
			,[Shipping Requested Date]

			,[Product Inventory Key]
			,[Inventory Transaction Id]
			,[Date Expected]
		) VALUES (
			s.[Company Key]
			,s.[Product Key]
			,s.[Inventory Dimension Key]
			,s.[Transaction Date]
			,s.[Record Id]
			,s.[Issue Status]
			,s.[Receipt Status]
			,s.[Transaction Type]
			,s.[Inventory Reference]
			,s.[Inventory Unit]
			,s.[Quantity]
			,s.[Currency Key]
			,s.[Cost Amount]
			,s.[Posting Type]
			,s.[Voucher Number]
			,s.[Default Dimension Key]

			,s.[Category Hierarchy Key]
			,s.[Inventory Color Key]
			,s.[Inventory Config Key]
			,s.[Inventory Size Key]
			,s.[Inventory Style Key]

			,s.[Warehouse Key]

			,s.[Posted Quantity]
			,s.[Posted Cost Amount]
			,s.[Physical Quantity]    
			,s.[Physical Cost Amount]
			,s.[Available Physical Quantity]
			,s.[Available Physical Cost Amount]
			,s.[Total Available Quantity]
			,s.[Total Available Cost Amount]
			,s.[Physical Reserved Quantity]      
			,s.[Physical Reserved Cost Amount]     
			,s.[Ordered In Total Quantity]  
			,s.[Ordered In Total Cost Amount]   
			,s.[On Order Quantity]
			,s.[On Order Cost Amount]        
			,s.[Ordered Reserved Quantity]          
			,s.[Ordered Reserved Cost Amount]                   
			,s.[Available For Reservation Quantity]    
			,s.[Available For Reservation Cost Amount]

			,s.[Sales Invoice Key]
			,s.[Load Key]
			,s.[Inventory Date]
			,s.[Status Date]
			,s.[Is Inter Company Transfer]
			,s.[Is Invoice Returned]
			,s.[Product Receipt]
			,s.[Is Product Returned]
			,s.[Picking Route Code]
			,s.[Settled Quantity]
			,s.[Physical Revenue Amount]
			,s.[Shipping Comfirmed Date]
			,s.[Shipping Requested Date]

			,s.[Product Inventory Key]
			,s.[Inventory Transaction Id]
			,s.[Date Expected]
		)
	--WHEN NOT MATCHED BY SOURCE THEN DELETE;
	--OUTPUT $action, s.*
	;

	set @ProcessRows = @@ROWCOUNT;

END
