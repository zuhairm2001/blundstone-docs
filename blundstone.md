    A list of the business keys you must keep stable (e.g. ItemId, InventLocationId, InventTransOrigin, DatePhysical, Qty, CostAmount…). 
     

    The grain you want in the new fact table(s):   
        “one row per inventory movement per item per site per date” or  
        “one row per work line per item per date” or whatever is agreed.
         
     

    Which measures the reports cannot lose (Qty, CostAmount, SettlementQty, SettlementCost, ClosingQty, ClosingValue…). 
     

    A short inventory KPI list (e.g. “Stock value by site”, “Average stock turns”, “Settlement variance”) so I can check that the new design can still calculate them. 
     

    The naming convention you follow (schemas, prefix Fact/Dim, camelCase vs PascalCase). 
     

    Your partitioning / indexing rules (clustered on date? partition by month? column-store per site?). 
     

    Whether financial cost must still come from the old inventtrans or from a separate InventCost table. 
     

    Preferred output format:   
        Just the SQL DDL?  
        SQL + YAML documentation?  
        Markdown page for DevOps Wiki with before/after DAX snippets?
         
     

Send me 1–10 (even if some answers are “same as current”) and I’ll return: 


At this warehouse or iis it not, current stock level is the priority
Sum from start of time
Summaries + detail --> 6 months detail to a year
Move summaries into slow storage sql server or to the data lake
Archigin
Values over time --> low prio --> in relation to summary + detail
We don't use the financial data at all
Brand new table concerned with just stock levels


Not caring about what is happening in this warehouse


Hand this over to Dennis


Compare select statement performance with detail and summary table, make sure that the numbers add up, validation script
