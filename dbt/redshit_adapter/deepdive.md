the goal of that folder is "deepdive" into aws redshift adapter behavior
describe how different types of materialzation work:
- view
- table
- incremental:
    - append
    - merge
    - delete+insert
    - microbatch

description should include:
    - logic for every type
    - code samples from dbt github adapter
    - expamples of run folder and log file