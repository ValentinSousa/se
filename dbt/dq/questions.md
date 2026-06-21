dbt testing + redshift

I have a following questions:
- if i test source i will test all source data every time. it is not efficient way, how dbt suggest to do it?
    - **Answer:** Use the `where` configuration in your tests to limit the scan to a specific window. This is necessary for Redshift performance to avoid full table scans.
    ```yaml
    sources:
      - name: my_source
        tables:
          - name: orders
            tests:
              - unique:
                  column_name: order_id
                  where: "loaded_at >= dateadd('day', -3, current_date)"
    ```
    - Additionally, use `dbt source freshness` for low-overhead monitoring of data arrival.
    - Leverage `state:modified+` and `--defer` (Slim CI) to isolate testing to changed sources or downstream impacts.

    follow up:
    - strange to test only current_day, what if bad data arrive yesterday?
        - **Answer:** Implement a **Sliding Window**. Define a window that covers the expected late-data arrival SLA (e.g., 3 or 7 days).
        - Use variables in `dbt_project.yml` or macros to manage this window centrally.
        - For complete coverage, schedule a weekly "Deep Audit" without `where` filters (e.g., `dbt test --select source:my_source --vars 'full_audit: true'`).

- in case i have src_orders (source) -> stg_order (view? incremental? table?) -> int_orders(incremental), how would i protect int_orders from polluted data?
    - **Answer:** Select a pattern based on failure tolerance:
        1. **WAP (Write-Audit-Publish):** Materialize `stg_orders` as a table. Test the table. Only insert into `int_orders` if tests pass. This prevents polluted data from entering incremental models.
        2. **Circuit Breaker:** Configure `error_if` thresholds in tests. If exceeded, the pipeline execution stops.
        3. **DLQ (Dead Letter Queue) / Quarantine:** Filter invalid records in `stg_orders` into a separate table. Only clean records are processed by `int_orders`.
    - **Recommendation:** Use `dbt build`. This command enforces the dependency graph; if `stg_orders` tests fail, `int_orders` is skipped automatically.

    follow up:
    - if Materialize `stg_orders` as a `table`. then I will recreate that table every time.
        - **Answer:** Use **Incremental Staging** to avoid full recreations. When staging is incremental, dbt only processes new records. Apply tests to this new delta using the same sliding window filters as source tests.

    could you provide a complete solution? using standard and recommended by dbt way?
    - **Complete Solution: The "Build-Once-Test-Recent" Workflow**
        1. **Staging (`stg_orders.sql`):** Use `view` for simple logic or `incremental` for heavy transformations.
        2. **Tests (`schema.yml`):** Apply `where` filters to scan only recent data relative to the run time.
        3. **Incremental Logic (`int_orders.sql`):** Implement standard `is_incremental()` logic.
        4. **Execution:** Run `dbt build`.

        **Workflow logic:**
        - `stg_orders` is executed.
        - Tests run on `stg_orders` (Circuit Breaker).
        - If tests fail: `int_orders` is skipped, preserving data integrity.
        - If tests pass: `int_orders` updates incrementally.

        **Redshift Optimized Configuration:**
        ```yaml
        models:
          - name: stg_orders
            tests:
              - not_null:
                  column_name: order_id
                  where: "loaded_at >= dateadd('day', -3, current_date)"
              - relationships:
                  to: ref('stg_customers')
                  field: customer_id
                  column_name: customer_id
                  where: "loaded_at >= dateadd('day', -3, current_date)"
        ```


