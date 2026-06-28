
## dbt Model Conventions
- Staging dbt models select from data sources.
- Generally, dbt models in the Integration layer or Warehouse layer select from dbt models in a lower layer.
- A warehouse layer model can select directly from the staging layer if an integration model is not necessary.
- Integration models generally join other models to enrich data.

The diagram below illustrates when to use staging, integration, fact, dimension and XA models
![Model Selection](resources/model_selection.png)

## dbt Model configuration
- Model-specific attributes (like unique keys and partitioning) should be specified in the model config.
- Include a description of the model in the config to help developers.
- Global configurations such as materialisation are specified in the dbt_project.yml.  If a particular configuration applies to all models in a directory, please add it to the `dbt_project.yml`.
- Marts should always be configured as tables
- Other layers should generally prefer using a view or CTE materialization

## Testing
- We use an open source tool called droughty to auto-generate the dbt schema (droughty_schema.yml) for consistency and to reduce manual work. Separate dbt schema files do not need to be created. However, droughty is only maintained to work with BigQuery and may not work with other data warehouses. If droughty does not work with your data warehouse, please create dbt schema files manually and ensure they are kept up to date.

## Naming and field conventions
- Rename columns to business-friendly, snake_case names, following the naming conventions in the coding conventions (e.g., natural keys, suffixes for timestamps, booleans, etc.)
- Source system IDs should be renamed `<descriptive name>_natural_key` e.g. `subscription_natural_key`
- Primary keys must use the suffix '_pk' e.g. 'subscription_pk'
- Foreign keys must use the suffix '_fk' e.g. 'subsription_fk'
- Both '_pk' and '_fk' columns must use the dbt_utils.generate_surrogate_key macro.
- Timestamp columns must use the suffix '_ts', e.g. `created_ts`.  If a timzone is not in UTC, this should be indicated, e.g `created_cet_ts`.
- Booleans should use '_is_' or '_has_' or '_was_'
- Revenue columns should include the '_amount' and '_currency' suffixes
- Always use dbt macros (e.g., dbt.type_string(), dbt.type_numeric(), dbt.type_boolean(), dbt.type_timestamp() ) for all type casting in SQL models, as shown in the project coding conventions
- Order columns in the output as: keys, attributes, indexes/ranks, metrics, booleans, temporal data types.

## CTEs
- All `{{ ref('...') }}` statements should be placed in CTEs at the top of the file and the CTE name prefixed with 's_'
- Where performance permits, CTEs should perform a single, logical unit of work.
- CTE names should convey what they do
- CTEs with confusing or notable logic should be commented
- The final CTE in a model should be named `final` which makes it easier to debug code within a model (without having to comment out code!)
