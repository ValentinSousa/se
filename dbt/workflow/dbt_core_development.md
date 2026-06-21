# dbt Development: Step-by-Step Guide

### Step 1: Model & YAML Initialization
1.  **Create the SQL file**: Place your model in the correct directory (`staging/`, `intermediate/`, or `marts/`).
    *   *Naming*: Use the required prefix (`stg_`, `int_`, `fct_`, or `dim_`).
2.  **Add to YAML**: Open the corresponding `.yml` file in that directory (e.g., `staging.yml`). 
    *   *Standard*: Do not create new YML files for single models. Add your model to the existing directory YML.
    *   Add the model name and a basic description immediately.

---

### Step 2: Write Logic with Development Limits (Staging Layer ONLY)
To minimize Redshift costs, implement data filters **strictly and exclusively in models that read directly from a source using the `{{ source() }}` macro**.

> **MANDATORY RULE**: These filters MUST NOT be used in models that use `{{ ref() }}`. By filtering at the source entry point (the "Gatekeeper"), all downstream models in your development schema will automatically be performant without needing any extra code.

While these patterns can be written manually, they should be abstracted into the **[limit_data_in_dev.sql](../macros/limit_data_in_dev.sql)** macro. Choose the strategy that best fits your data structure:

#### Strategy A: Sliding Window (Standard)
Filters for the most recent data. High performance on Redshift `sortkey` columns.
```sql
select *
from {{ source('raw', 'orders') }} -- ONLY used here
{% if target.name in ['dev', 'local'] %}
  where created_at >= dateadd('day', -3, current_date)
{% endif %}
```

#### Strategy B: Deterministic Hash Sampling
Ensures **join integrity** across the DAG by consistently selecting the same subset of IDs (e.g., users).
```sql
select *
from {{ source('raw', 'events') }} -- ONLY used here
{% if target.name in ['dev', 'local'] %}
  where mod(abs(strtol(left(md5(user_id::text), 15), 16)), 100) < 5
{% endif %}
```
> **CRITICAL SAFETY RULE FOR JOINS**: For a join to be "safe" (return results) in development, **both tables must be sampled using the same key** in their respective staging models.

---

### Step 3: Compile and Validate (The Loop)

Once the logic is solid, materialize the model in your development schema.
1.  **Build**: Run `dbt build --select your_model_name`.
    *   *Why*: `dbt build` runs both the model and its tests. It acts as a **Circuit Breaker**—if a test fails, it stops before creating bad data downstream.
2.  **Debugging Failed Runs**: If the build fails, your first resource is the **dbt log file**.

#### Using the Log File (`logs/dbt.log`)
*   **Location**: Found in the `logs/` directory at the root of your dbt project.
*   **When it is useful**: 
    *   **Traceability**: It contains a full history of every command executed and every query sent to Redshift.
    *   **Detailed Errors**: When dbt returns a vague error in the terminal, the log file often provides the specific line number and full error message from the database.
    *   **Macro Debugging**: If your Jinja logic is failing, the log file shows the result of every `{{ log(...) }}` call.
*   **Standard**: For detailed logging practices and how to use environment-aware logging, refer to the **[dbt Logging Standards](dbt_logging.md)**.

---

### Step 5: Documentation & Final Tests
Before finishing your development:
1.  **Add Column Tests**: At a minimum, add `unique` and `not_null` tests for your primary key in the `.yml` file.
2.  **Complete Descriptions**: Ensure all columns and the model itself have clear, technical descriptions.
3.  **Format Code**: Run `sqlfluff fix` to ensure your SQL adheres to the team's style guide.
4.  **Final Check**: Run a full build of the model and its downstream dependencies to ensure no regressions: `dbt build --select your_model_name+`.
