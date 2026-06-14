# Essential dbt Macros for Daily Development

This list contains the most frequently used macros and packages in professional dbt projects. They are ordered by daily utility.

| Macro Name | Package | Description | When to Use |
| :--- | :--- | :--- | :--- |
| `ref()` | Built-in | Resolves model names and builds the DAG. | **Every model.** Mandatory for lineage. |
| `source()` | Built-in | Resolves raw source table names. | **Every staging model.** Mandatory for raw data entry. |
| `is_incremental()` | Built-in | Checks if the current run is incremental. | **Incremental models.** Use for performance gating. |
| `config()` | Built-in | Sets model-level configurations (materialization, tags). | **Every model.** Use at the top of the file. |
| `var()` | Built-in | Accesses variables from `dbt_project.yml` or CLI. | **Models/Macros.** Use for dynamic parameters (e.g., dates). |
| `generate_surrogate_key()` | `dbt_utils` | Hashes multiple columns into a single PK. | **Staging.** When a table has a composite key. |
| `deduplicate()` | `dbt_utils` | Cleans up duplicate rows based on a subset of columns. | **Staging.** When source data has duplicates. |
| `pivot()` | `dbt_utils` | Turns long rows into wide columns. | **Intermediate.** Creating feature flags or status counts. |
| `unpivot()` | `dbt_utils` | Turns wide columns into long rows. | **Staging.** Normalizing "spreadsheet-style" source data. |
| `get_column_values()` | `dbt_utils` | Returns a list of distinct values from a column. | **Jinja Loops.** When looping over data values. |
| `compare_relations()` | `audit_helper` | Audits variance between two tables/models. | **Refactoring.** To prove new logic matches prod. |
| `generate_model_yaml()` | `codegen` | Generates boilerplate YAML for models. | **Documentation.** To auto-populate `schema.yml`. |
| `generate_base_model()` | `codegen` | Generates SQL staging boilerplate from a source. | **New Sources.** To quickly bootstrap staging models. |
| `union_relations()` | `dbt_utils` | Unions tables with potentially different schemas. | **Staging.** Combining multiple source tables. |
| `date_spine()` | `dbt_utils` | Generates a continuous series of dates (no gaps). | **Marts.** Essential for filling gaps in time-series analysis. |
| `get_query_results_as_dict()` | `dbt_utils` | Runs a query and returns results as a Jinja dict. | **Macros.** When metadata needs to drive model logic. |
| `expect_column_values_to_...` | `dbt_expectations` | Suite of advanced data quality tests. | **Testing.** For regex, outliers, and distribution checks. |
| `safe_cast()` | `dbt_utils` | Casts a column but returns NULL on failure (no crash). | **Staging.** When cleaning "dirty" string data into types. |
| `last_day()` | `dbt_utils` | Returns the last day of a period (month, year). | **Marts.** Standardizing end-of-period reporting logic. |
| `compare_queries()` | `audit_helper` | Compares the results of two SQL snippets. | **Refactoring.** For checking small logic changes. |
| `env_var()` | Built-in | Accesses system environment variables. | **Profiles/Project.** For secrets or machine-specific paths. |
| `this` | Built-in | Reference to the current model's target table. | **Incremental.** To query the existing data in the table. |
| `target` | Built-in | Dictionary of the current connection target. | **Macros.** For environment-aware logic (`target.name`). |
| `log()` | Built-in | Prints messages to the terminal/log file. | **Debugging.** Tracing Jinja logic execution. |
| `expect_table_row_count_to_...` | `dbt_expectations` | Validates that row counts match another table. | **Audit.** Ensuring no data loss during transformations. |
| `get_relations_by_prefix()` | `dbt_utils` | Lists all tables matching a specific prefix. | **Macros.** For batch processing of dynamic sources. |
| `compare_column_values()` | `audit_helper` | Compares a single column across two relations. | **Audit.** Deep-diving into specific column discrepancies. |
| `safe_add()` | `dbt_utils` | Adds columns while handling NULLs as 0. | **Marts.** Preventing NULLs from breaking sum totals. |
| `width_bucket()` | `dbt_utils` | Buckets values into a set of equi-width intervals. | **Analysis.** Creating histograms or user segments. |
| `generate_source()` | `codegen` | Generates source YAML from an entire database schema. | **Setup.** Automating the `sources.yml` creation. |

---

### Implementation Highlights

#### 1. `date_spine`
Essential for creating complete time-series reports even when data is missing for some days.
```sql
with dates as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="current_date"
    ) }}
)
select * from dates
```

#### 2. `dbt_expectations` (Regex Test)
Validating that an email column strictly follows the required pattern.
```yaml
# schema.yml
- name: email
  tests:
    - dbt_expectations.expect_column_values_to_match_regex:
        regex: '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
```

#### 3. `codegen.generate_model_yaml`
Run this in your terminal to save hours of manual typing:
```bash
dbt run-operation generate_model_yaml --args '{"model_names": ["fct_orders"]}'
```
