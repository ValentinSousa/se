
I have 4 tables: ref_currency, ref_geography, stg_google_ads, stg_linkedin_ads
i need to create source for dashboard, which is now based on dasboard_marketing_performance
Tables ddl are in the ddl.sql file in the same folder.

data to tables stg_google_ads and stg_linkedin_ads ingested daily with lookback window of 14 days.
I need to create a proper data model follow the medalliion architecture. with light stransformation on stg layer.
consider the following:
- ingestion should be incremental
- as final table should be one big table, with some views on top of it if they will be needed
- should be data quality checks, with carantine or fail, need to discuss solutions and came to decision
- set of tools: redshift, dbt. May be that will: airfow send sql to redshift. 
- ingestion at any case will be via snaplogic



When a data quality check fails, you generally have two industry-standard choices: Quarantine (separate bad rows and keep going) or Fail-Fast (crash the pipeline).

Here is the comprehensive Mermaid diagram mapping your end-to-end data architecture framework across all three phases—from the initial API extraction to the final dynamic incremental star schema model.

```mermaid
graph LR
    %% Base Styles & Themes
    classDef apiStyle fill:#f9f,stroke:#333,stroke-width:2px,color:#000;
    classDef rawStyle fill:#f2dede,stroke:#a94442,stroke-width:2px,color:#000;
    classDef stgStyle fill:#d9edf7,stroke:#31708f,stroke-width:2px,color:#000;
    classDef martStyle fill:#dff0d8,stroke:#3c763d,stroke-width:2px,color:#000;
    classDef auditStyle fill:#fcf8e3,stroke:#8a6d3b,stroke-width:2px,color:#000;

    %% External Source & Raw Buffer
    API[LinkedIn API <br> q=statistics]:::apiStyle
    SNAP[SnapLogic Pipeline <br> Rolling 14-Day Overwrite]:::apiStyle
    RAW_TBL[raw.raw_linkedin_ads <br> Permissive VARCHAR Buffer]:::rawStyle

    subgraph PHASE_2 [Phase 2: Staging Layer - Historical Consolidation]
        direction TB
        STG_CHECK{Quality Control <br> Validation Gate}
        AUDIT_TBL[audit.quarantine_linkedin_ads <br> Log Negative Costs / Missing Keys]:::auditStyle
        STG_PURGE[Dynamic Block Pruning <br> DELETE WHERE date >= MIN_RAW_DATE <br> Uses Redshift SORTKEY]
        STG_LOAD[Compute Deterministic Hash <br> md5 PK Integration]
        STG_TBL[stg.stg_linkedin_ads <br> Permanent History Repository <br> Tracked by uploaded_at]:::stgStyle
        
        STG_CHECK -- Fails Checks --> AUDIT_TBL
        STG_CHECK -- Passes Validation --> STG_PURGE --> STG_LOAD --> STG_TBL
    end

    subgraph PHASE_3 [Phase 3: Core Marts Layer - Universal Star Schema]
        direction TB
        DIM_LOAD[Upsert Shared Matrix <br> SCD Type 1 via INSERT OR REPLACE] --> DIM_TBL[marts.dim_marketing_creatives <br> DISTSTYLE ALL Shared Matrix]:::martStyle
        
        MART_LOOKBACK[Determine Dynamic Range <br> SELECT MIN_DATE WHERE uploaded_at >= Delta Window] --> MART_PURGE[Targeted Idempotent Purge <br> Block Drop by Business date]
        
        REF_GEO[reference.map_linkedin_geo <br> Internal ID to ISO Translation]:::martStyle
        REF_CORP_GEO[paid_media.ref_geography <br> Corporate Standard ISO Master]:::martStyle
        REF_FX[paid_media.ref_currency <br> Corporate Multi-Currency Multiplier]:::martStyle
        
        MART_JOIN[Assemble Fact Metrics <br> Conformed Keys + FX Multipliers to EUR] --> FACT_TBL[marts.fact_marketing_performance <br> DISTKEY creative_key <br> SORTKEY date]:::martStyle
    end

    %% Pipeline Operational Lineage & Dependencies
    API --> SNAP --> RAW_TBL
    RAW_TBL --> STG_CHECK
    
    %% Staging to Mart Pipeline Mechanics
    STG_TBL --> DIM_LOAD
    STG_TBL --> MART_LOOKBACK
    
    %% Mart Assembly Inputs
    STG_TBL -- Filtering Delta Rows Only --> MART_JOIN
    REF_GEO --> MART_JOIN
    REF_CORP_GEO --> MART_JOIN
    REF_FX --> MART_
```

### Structural Pipeline Flow Highlights:

1. **The Ingestion Invariant:** SnapLogic extracts an unconditional 14-day window into the `raw` buffer table via an implicit `TRUNCATE` process, maintaining a lean operational memory footprint.
2. **The Guardrail Gate:** Valid transactions move downstream into the permanent historical `stg` matrix, whereas schema violations (negative metrics or missing granularity identifiers) are immediately dropped into the dedicated `audit` context.
3. **The Micro-Batch Optimization:** The `DELETE` operations inside Phase 2 and Phase 3 utilize subqueries checking the minimum business `date` against indexed target rows. This guarantees that your cluster executes rapid block-level disk truncations (**Zone Maps**) rather than crawling across millions of records.