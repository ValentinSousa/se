# dbt Logging

Logging in dbt is required for debugging Jinja logic and tracing query generation. These standards ensure production logs remain clean and secure.

---

### Core Concepts

1. **The `log()` Macro**: The primary tool for printing messages. It takes a message string and an optional `info` boolean.
2. **`info=True` vs `info=False`**: 
   - `info=True`: Prints to both the console (terminal) and `logs/dbt.log`.
   - `info=False` (default): Only prints to the `logs/dbt.log` file.
3. **`dbt.log` File**: A record of every SQL query, compilation step, and error. It is the primary artifact for post-mortem debugging.
4. **Environment Context (`target.name`)**: Used to determine execution environment and adjust log verbosity.

---

### Common Use Cases

1. **Variable Debugging**: Printing variable values or dictionary contents during development.
2. **Execution Tracing**: Identifying active branches in complex `{% if %}` blocks.
3. **Macro Validation**: Confirming that macros receive expected arguments.
4. **Performance Benchmarking**: Logging start/end markers for heavy Jinja loops or metadata queries to identify compilation bottlenecks.
5. **Incremental Row Count Auditing**: Logging row counts about to be processed in incremental runs.
6. **Schema Drift Monitoring**: Logging warnings if optional source columns are missing or if data types have changed.
7. **Environment Audit**: Logging the `run_id`, `invocation_id`, or `target` for forensic auditing.

---

### Implementation: The "Smart Logging" Pattern

#### 1. Custom Logging Macro (`macros/smart_log.sql`)
A wrapper to handle environment-specific logic.

```sql
{% macro smart_log(msg, force_info=False) %}
    {# 
       LOGGING STRATEGY:
       1. Always log to the dbt.log file.
       2. Only print to terminal (info=True) if in dev OR if forced.
    #}
    
    {% set is_dev = target.name in ['dev', 'local', 'default'] %}
    
    {% if is_dev or force_info %}
        {{ log(msg, info=True) }}
    {% else %}
        {{ log(msg, info=False) }}
    {% endif %}
{% endmacro %}
```

#### 2. Usage in Models or Macros
```sql
{{ smart_log("Pivoting payment methods for order: " ~ order_id) }}
```

### Why This Matters for Architecture:

*   **Security & PII**: Using `info=True` in production can leak sensitive data into centralized logging systems (e.g., CloudWatch, Datadog).
*   **Log Cleanliness**: Orchestration tools capture terminal output. Excessive logs make it difficult to identify actual failure messages.
*   **Performance**: High-iteration loops with `info=True` increase compilation time due to I/O overhead.

### Best Practices & Constraints:

- **PII Protection**: Do not log raw data values. Log only metadata and execution flow.
- **Loop Efficiency**: Avoid logging inside high-iteration loops (>100 iterations).
- **Log Levels**: Use prefixes like `[DEBUG]`, `[INFO]`, `[WARN]`, `[PERF]`, or `[AUDIT]` for better filtering in log aggregators.
- **Production Debugging**: Retrieve the `logs/dbt.log` file for full SQL execution context after a failure.

