# AGENTS.md - Development Guidelines

## Build/Test Commands
- **Python scripts**: `python <script_name>.py` (no test framework detected)
- **SQL execution**: Run through SQL Server Management Studio or Azure Synapse
- **No automated tests**: Manual testing required for SQL functions/procedures

## Code Style Guidelines

### SQL Standards
- Use `SET ANSI_NULLS ON` and `SET QUOTED_IDENTIFIER ON` headers
- Naming: PascalCase for tables/columns (e.g., `[Period Key]`, `[Fiscal Year]`)
- Prefix conventions: `ufn_` for functions, `usp_` for procedures, `SL_` for ETL
- Include comprehensive comments for business logic
- Always use schema prefixes (e.g., `[dbo].[TableName]`)

### Python Standards  
- Use descriptive function names with docstrings
- Follow PEP 8 naming: snake_case for functions/variables
- Import pandas as `pd` consistently
- Include main execution block: `if __name__ == "__main__":`

### Documentation
- Maintain schema documentation in `*_schema.md` files
- Document business logic in implementation guides
- Include performance estimates in SQL comments: `/* EST: 6M rows/year, 40GB/year */`

### Error Handling
- SQL: Use `ISNULL()` for null handling in calculations
- Python: Basic error handling with file operations
- Validate data existence before processing