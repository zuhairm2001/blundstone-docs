/****** Object:  StoredProcedure [ax7].[SL_EAInventoryValueTransactions]    Script Date: 9/23/2025 5:02:14 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [ax7].[SL_EAInventoryValueTransactions]
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

	delete t
		from [dbo].[FactInventoryValue] t
		left join [ax7].[InventTrans] s on s.[RECID] = t.[Record Id] 
		where t.[Inventory Value Key] > 0 
		--and t.[Record Type] = 177
		and s.[DataAreaId] is null;
	
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


	with iv as 
	(
			SELECT 
				--src.DataLakeModified_DateTime
				src.[ExecutionId]
				,src.RECID [RECORDID]
				,[CurrencyCode]
				,src.DataAreaId [COMPANYCODE]
				,src.[ItemId]
				,[inventDimId]
				,[DatePhysical]
				,[StatusIssue]
				,[StatusReceipt]
				,[Qty]
				,[CostAmountPhysical]
				,[CostAmountPosted]
				--,[DateFinancial]
				--,src.[ProjId]
				--,[ProjCategoryId]
				--,src.[InventTransOrigin]
				--,src.MarkingRefInventTransOrigin [REFINVENTTRANSORIGIN]
				,[DateInvent]
				,[DateStatus]
				,[InterCompanyInventDimTransferred]
				--,[inventDimFixed]
				,ISNULL([InvoiceId], '') [InvoiceId]
				,[InvoiceReturned]
				,[LoadId]
				,ISNULL([PackingSlipId], '') [PackingSlipId]
				,[PackingSlipReturned]
				,[PickingRouteID]
				,[QtySettled]
				--,[ReturnInventTransOrigin]
				,[RevenueAmountPhysical]
				,[ShippingDateConfirmed]
				,[ShippingDateRequested]
				--,src.[MODIFIEDDATETIME]
				,[ReferenceCategory]
				,[ReferenceId]
				,[InventTransId]
				--,[Party]
				--,[IsExcludedFromInventoryValue]
				,T3.Voucher [VOUCHERNUMBERPHYSICAL]
				--,T3.RECID [INVENTTRANSPOSTINGPHYSICAL]
				--,T3.TransDate [TRANSDATEPHYSICAL]
				,T4.Voucher [VOUCHERNUMBERFINANCIAL]
				,T4.RECID [INVENTTRANSPOSTINGFINANCIAL]
				--,T4.TransDate [TRANSDATEFINANCIAL]
				,T3.DefaultDimension [DEFAULTDIMENSIONPHYSICAL]
				,T3.LedgerDimension [LEDGERDIMENSIONPHYSICAL]
				,T4.DefaultDimension [DEFAULTDIMENSIONFINANCIAL]
				,T4.LedgerDimension [LEDGERDIMENSIONFINANCIAL] 
		FROM [ax7].InventTrans src
		LEFT OUTER JOIN ax7.InventTransOrigin AS T2 ON src.InventTransOrigin = T2.RECID
		LEFT OUTER JOIN ax7.InventTransPosting AS T3 ON T3.InventTransPostingType = 0 AND src.DataAreaId = T3.DataAreaId AND src.InventTransOrigin = T3.InventTransOrigin 
			AND src.VoucherPhysical = T3.Voucher AND src.DatePhysical = T3.TransDate
		LEFT OUTER JOIN ax7.InventTransPosting AS T4 ON T4.InventTransPostingType = 1 AND src.InventTransOrigin = T4.InventTransOrigin AND src.DataAreaId = T4.DataAreaId 
			AND src.Voucher = T4.Voucher AND src.DateFinancial = T4.TransDate
		where (@IncrementalLoad = 0 or src.[EXECUTIONID] =   @ExecutionId )
			and 
			(
				src.STATUSISSUE in (  @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder ) 
				or 
				src.STATUSRECEIPT in    ( @sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered ) 
			)
			and [REFERENCECATEGORY] <> 26
	)
	,ev as 
	(
		select [Value Id],[Enum Name],[Value Label] from [ax7].[EnumValues]
		where [Enum Name] in (N'StatusIssue',N'StatusReceipt',N'InventTransType',N'NoYes')
	)
	,src as 
	(
		select 
			cast (177 as int) as [Record Type]

			,src.[RECORDID] as [Record Id] 
			,src.[COMPANYCODE] as [Company Code]
			,src.[ITEMID] as [Item Code]
			,src.[INVENTDIMID] as [Inventory Dimension Id]
			,src.[DATEPHYSICAL] as [Transaction Date] 

			,src.[STATUSISSUE] as [Status Issue]
			,src.[STATUSRECEIPT] as [Status Receipt]

			,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'StatusIssue' and ev.[Value Id] = src.[STATUSISSUE]) as nvarchar(20)) as [Issue Status]
			,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'StatusReceipt' and ev.[Value Id] = src.[STATUSRECEIPT]) as nvarchar(20)) as [Receipt Status]

			,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'InventTransType' and ev.[Value Id] = src.[REFERENCECATEGORY]) as nvarchar(20)) as [Transaction Type] 
			,[REFERENCEID] as [Inventory Reference] 
		
			,[QTY] as [Quantity] 

			,src.[CURRENCYCODE] as [Currency Code]
			,case when src.[INVENTTRANSPOSTINGFINANCIAL] = 0 then src.[COSTAMOUNTPHYSICAL] else src.[COSTAMOUNTPOSTED] end as [Cost Amount]
			,cast(case when src.[INVENTTRANSPOSTINGFINANCIAL] = 0 then N'Physical' else N'Financial' end as nvarchar(20)) as [Posting Type]
			,case when src.[INVENTTRANSPOSTINGFINANCIAL] = 0 then src.[VOUCHERNUMBERPHYSICAL] else src.[VOUCHERNUMBERFINANCIAL] end as [Voucher Number]
			--,case when src.[INVENTTRANSPOSTINGFINANCIAL] = 0 then src.[LEDGERDIMENSIONPHYSICAL] else src.[LEDGERDIMENSIONFINANCIAL] end as [Ledger Dimension Id]
			,case when src.[INVENTTRANSPOSTINGFINANCIAL] = 0 then src.[DEFAULTDIMENSIONPHYSICAL] else src.[DEFAULTDIMENSIONFINANCIAL] end as [Default Dimension Id]

			,cast(0 as bigint) as [Category Id]

		  ,[DATEINVENT] as [Inventory Date]
		  ,[DATESTATUS] as [Status Date]
		  ,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = src.[INTERCOMPANYINVENTDIMTRANSFERRED]) as nvarchar(20)) as [Is Inter Company Transfer]

		  ,[INVOICEID] as [Invoice Number]
		  ,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = src.[INVOICERETURNED]) as nvarchar(20)) as  [Is Invoice Returned]
		  ,[LOADID] as [Load Code]
		  ,[PACKINGSLIPID]  as [Product Receipt]
		  ,cast((select ev.[Value Label] from ev where ev.[Enum Name] = N'NoYes' and ev.[Value Id] = src.[PACKINGSLIPRETURNED]) as nvarchar(20)) as [Is Product Returned]
		  ,[PICKINGROUTEID] as [Picking Route Code]
		  ,[QTYSETTLED] as [Settled Quantity]

		  ,[REVENUEAMOUNTPHYSICAL] as [Physical Revenue Amount]
		  ,[SHIPPINGDATECONFIRMED] as [Shipping Comfirmed Date]
		  ,[SHIPPINGDATEREQUESTED] as [Shipping Requested Date]
		  ,[INVENTTRANSID] as [Inventory Transaction Id]
		  ,[VOUCHERNUMBERFINANCIAL] as [Invoice Voucher]

		  FROM iv src
	)
	, s as
	(
	select isnull(co.[Company Key], @NAKey) [Company Key]
		,isnull(p.[Product Key], @NAKey) [Product Key]
		,isnull(id.[Inventory Dimension Key], @NAKey) [Inventory Dimension Key]
		,isnull(trdate.[DateKey], @NADate) [Transaction Date]

		,s.[Record Type]
		,s.[Record Id]

		,isnull(s.[Issue Status], @NA) [Issue Status]
		,isnull(s.[Receipt Status], @NA) [Receipt Status]
		,isnull(s.[Transaction Type], @NA) [Transaction Type]
		,isnull(s.[Inventory Reference], @NA) [Inventory Reference]

		,p.[Inventory Unit]
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
		,isnull(pv.[Product Variant Key], @NAKey) [Product Variant Key]

	from src s
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

	left join [dbo].[DimSalesInvoice] si on si.[Company Code] = s.[Company Code] and si.[Invoice Number] = s.[Invoice Number] and si.Voucher = s.[Invoice Voucher]
	left join [dbo].[DimLoad] l on l.[Company Code] = s.[Company Code] and l.[Load Code] = s.[Load Code] 
	left join [dbo].[DimProductInventory] pinv on pinv.[Company Code] = s.[Company Code] and pinv.[Item Number]= s.[Item Code] and pinv.[Inventory Site Code] = id.[Inventory Site Code] and pinv.[Inventory Size Code] = id.[Size Code]
	left join [dbo].[DimProductVariant] pv on pv.[Company Code] = s.[Company Code] and pv.[Item Number] = s.[Item Code] and pv.[Product Size] = id.[Size Code]
	)

	merge [dbo].[FactInventoryValue] as t
	using  s
	on (t.[Record Type] = s.[Record Type] and t.[Record Id] = s.[Record Id])
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
			,s.[Product Variant Key]
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
			,t.[Product Variant Key]
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
			,t.[Product Variant Key] = s.[Product Variant Key]

			,t.[ea_Process_DateTime] = getdate()
			,t.[ea_Is_Deleted] = 0

	WHEN NOT MATCHED BY TARGET THEN 
		INSERT(
			[Company Key]
			,[Product Key]
			,[Inventory Dimension Key]
			,[Transaction Date]
			,[Record Type]
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
			,[Product Variant Key]
		) VALUES (
			s.[Company Key]
			,s.[Product Key]
			,s.[Inventory Dimension Key]
			,s.[Transaction Date]
			,s.[Record Type]
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
			,s.[Product Variant Key]
		)

	--OUTPUT $action, s.*
	;
	set @ProcessRows = @@ROWCOUNT;

	-- update sales order table incase the reserved qty changes
		--with p as
		--(
		--SELECT 
		--	--T1.DataLakeModified_DateTime as DATALAKEMODIFIED
		--	--, T1.EXECUTIONID AS EXECUTIONID
		--	T1.ACTIVATIONDATE AS ACTIVATIONDATE
		--	--, T1.COSTINGTYPE AS COSTINGTYPE
		--	--, T1.CREATEDDATETIME AS CREATEDDATEAMDTIME
		--	, T1.DATAAREAID AS COMPANYCODE
		--	, T1.INVENTDIMID AS INVENTDIMID
		--	, T1.ITEMID AS ITEMID
		--	--, T1.LASTPRICEUNIQUENESSALLOWANCE AS LASTPRICEUNIQUENESSALLOWANCE
		--	--, T1.MARKUP AS MARKUP
		--	--, T1.MODIFIEDDATETIME AS MODIFIEDDATEANDTIME
		--	, T1.PRICE AS PRICE
		--	--, T1.PRICEALLOCATEMARKUP AS PRICEALLOCATEMARKUP
		--	--, T1.PRICECALCID AS PRICECALCID
		--	--, T1.PRICEQTY AS PRICEQTY
		--	--, T1.PRICETYPE AS PRICETYPE
		--	--, T1.PRICEUNIT AS PRICEUNIT
		--	--, T1.RECID AS RECORDID
		--	--, T1.STDCOSTTRANSDATE AS STDCOSTTRANSDATE
		--	--, T1.STDCOSTVOUCHER AS STDCOSTVOUCHER
		--	--, T1.UNITID AS UNITID
		--	--, T1.VERSIONID AS VERSIONID
		--	--, T1.MODIFIEDDATETIME AS MODIFIEDDATETIME
		--	--, T1.CREATEDDATETIME AS CREATEDDATETIME
		--	--, T1.RECID AS RECID 
		--	FROM ax7.INVENTITEMPRICE T1 WHERE T1.DataLakeModified_DateTime is not null		
		with ipp as (
			select 
			 p.DATAAREAID AS COMPANYCODE
			,p.[ITEMID]
			,p.[INVENTDIMID]
			,p.[PRICE]
			,id.INVENTSITEID
			,p.ACTIVATIONDATE
			,isnull(dateadd(day,-1, lead(ACTIVATIONDATE) over(partition by p.[DATAAREAID],p.[ITEMID],p.[INVENTDIMID] order by ACTIVATIONDATE )),'9999-12-31') as [ExpiryDate] 
			from  ax7.INVENTITEMPRICE p
			join ax7.InventDim id on p.INVENTDIMID=id.INVENTDIMID and p.DATAAREAID=id.DataAreaId
			WHERE p.DataLakeModified_DateTime is not null
		), src as (
			SELECT 
				src.DataLakeModified_DateTime
				,src.[ExecutionId]
				,src.RECID [RECORDID]
				,src.DataAreaId [COMPANYCODE]
				,[StatusIssue]
				,[Qty]
				,[CostAmountPhysical]
				,[CostAmountPosted]
				,[DateStatus]
				,ISNULL([InvoiceId], '') [InvoiceId]
				,ISNULL([PackingSlipId], '') [PackingSlipId]
				,[InventTransId]
	FROM [ax7].InventTrans src
	LEFT OUTER JOIN ax7.InventTransOrigin AS T2 ON src.InventTransOrigin = T2.RECID
	LEFT OUTER JOIN ax7.InventTransPosting AS T3 ON T3.InventTransPostingType = 0 AND src.DataAreaId = T3.DataAreaId AND src.InventTransOrigin = T3.InventTransOrigin 
		AND src.VoucherPhysical = T3.Voucher AND src.DatePhysical = T3.TransDate
	LEFT OUTER JOIN ax7.InventTransPosting AS T4 ON T4.InventTransPostingType = 1 AND src.InventTransOrigin = T4.InventTransOrigin AND src.DataAreaId = T4.DataAreaId 
		AND src.Voucher = T4.Voucher AND src.DateFinancial = T4.TransDate
	where (@IncrementalLoad = 0 or src.[EXECUTIONID] =   @ExecutionId )
		and 
		(
			src.STATUSISSUE in (  @si_Sold, @si_Deducted, @si_Picked, @si_ReservPhysical, @si_ReservOrdered, @si_OnOrder ) 
			or 
			src.STATUSRECEIPT in    ( @sr_Purchased, @sr_Received, @sr_Registered, @sr_Arrived, @sr_Ordered ) 
		)
		and [REFERENCECATEGORY] <> 26

		), s as (
			 select 
			 src.COMPANYCODE as [Company Code]
			 ,src.[INVENTTRANSID] as [Inventory Transaction Id]
			 ,case 
				when SALESTYPE=4 then isnull(nullif(so.CostPrice,0),ipp.PRICE) --Return order: must use the original price.
				else
					case 
						when nullif(src.INVOICEID,'') is not null then (src.COSTAMOUNTPOSTED + isnull(ivs.COSTAMOUNTADJUSTMENT,0) ) / nullif(src.QTY,0) 
						when nullif(src.PACKINGSLIPID,'') is not null then src.COSTAMOUNTPHYSICAL / src.QTY
						else ipp.PRICE
					end 
			 end as [Cost Price]
			 ,isnull(src.ReservedDatePhysical,'1900-01-01') [Reserved Date Physical]
			 ,isnull(src.[ReservedPhysical],0) as [Reserved Physical]

			,src.[COSTAMOUNTPOSTED] as [Gross Cost Amount] 
			,so.[LineAmount] - src.[COSTAMOUNTPOSTED] as [Gross Margin Amount]		
		from (
		select	INVENTTRANSID
				,COMPANYCODE 
				,-SUM([COSTAMOUNTPOSTED]) as [COSTAMOUNTPOSTED]
				,SUM([COSTAMOUNTPHYSICAL]) as [COSTAMOUNTPHYSICAL]
				,SUM([QTY]) as [QTY]
				,MAX([INVOICEID]) as [INVOICEID], MAX([PACKINGSLIPID]) as [PACKINGSLIPID] 
				,-SUM(case when statusissue = 4 then [QTY] else 0 end) as [ReservedPhysical]
				,MAX(case when statusissue = 4 then DATESTATUS else '1900-01-01' end) [ReservedDatePhysical]
		from src
		group by INVENTTRANSID, COMPANYCODE
		) src
		inner join [ax7].[SalesLine] so on src.INVENTTRANSID = so.[InventTransId] and src.[COMPANYCODE] = so.[DataAreaId]
		left join ax7.InventDim id on so.InventDimId=id.INVENTDIMID and so.DataAreaId=id.DataAreaId
		left join ipp on ipp.ITEMID=so.ItemId and ipp.INVENTSITEID=id.INVENTSITEID and so.CREATEDDATETIME between ipp.ACTIVATIONDATE and ipp.ExpiryDate and ipp.COMPANYCODE = so.DataAreaId 	
		left join ( select INVENTTRANSID, DataAreaId, SUM([COSTAMOUNTADJUSTMENT]) as [COSTAMOUNTADJUSTMENT] from ax7.InventSettlement 
					group by INVENTTRANSID, [DataAreaId]
			) ivs on src.INVENTTRANSID = ivs.INVENTTRANSID and src.COMPANYCODE = ivs.DataAreaId
)

	merge [dbo].[FactSalesOrders] as t
	using s
	on (t.[Company Code] = s.[Company Code] and t.[Inventory Transaction Id] = s.[Inventory Transaction Id] )
	WHEN MATCHED and not exists 
		(
			select 
				s.[Company Code]
				,s.[Inventory Transaction Id]
				,s.[Cost Price]
				,s.[Reserved Date Physical]
				,s.[Reserved Physical]
				,s.[Gross Cost Amount]
				,s.[Gross Margin Amount]
			intersect
			select
				t.[Company Code]
				,t.[Inventory Transaction Id]
				,t.[Cost Price]
				,t.[Reserved Date Physical]
				,t.[Reserved Physical]
				,t.[Gross Cost Amount]
				,t.[Gross Margin Amount]
		)
		then UPDATE SET 
				t.[Company Code] = s.[Company Code]
				,t.[Inventory Transaction Id] = s.[Inventory Transaction Id]
				,t.[Cost Price] = s.[Cost Price]
				,t.[Reserved Date Physical] = s.[Reserved Date Physical]
				,t.[Reserved Physical] = s.[Reserved Physical]
				,t.[Gross Cost Amount] = s.[Gross Cost Amount]
				,t.[Gross Margin Amount] = s.[Gross Margin Amount]
				,t.[ea_Process_DateTime] = getdate()
				,t.[ea_Is_Deleted] = 0
	;

	set @ProcessRows = @ProcessRows + @@ROWCOUNT;

END
