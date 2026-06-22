Вот горизонтальная схема (`graph LR`) итоговой структуры **Star Schema** (слой `marts`), включая таблицы связей (`reference` и `paid_media`), со всеми типами данных и указанием полей распределения/сортировки для Redshift:

```mermaid
graph LR
    %% Base Styles & Themes
    classDef factStyle fill:#dff0d8,stroke:#3c763d,stroke-width:2px,color:#000;
    classDef dimStyle fill:#d9edf7,stroke:#31708f,stroke-width:2px,color:#000;
    classDef refStyle fill:#fcf8e3,stroke:#8a6d3b,stroke-width:2px,color:#000;

    %% Left Side: Supporting Geography Infrastructure
    MAP_LINKEDIN_GEO["reference.map_linkedin_geo
    
    **PK:** linkedin_geo_id (VARCHAR)
    country_code (VARCHAR)"]:::refStyle

    REF_GEO["paid_media.ref_geography
    
    **PK:** country_code (VARCHAR)
    id (INTEGER)
    country_name (VARCHAR)
    region_name (VARCHAR)
    region_code (VARCHAR)
    zone_val (VARCHAR)
    country_code_2 (VARCHAR)"]:::refStyle

    %% Center: Core Fact Table
    FACT["marts.fact_marketing_performance
    
    **PK:** fact_key (VARCHAR)
    date (DATE)
    **FK:** creative_key (VARCHAR)
    **FK:** country_code (VARCHAR)
    cost_eur (DOUBLE)
    impressions (INTEGER)
    clicks (INTEGER)
    source_network (VARCHAR)
    run_id (VARCHAR)
    inserted_at (TIMESTAMP)
    
    *DISTKEY: creative_key*
    *SORTKEY: date*"]:::factStyle

    %% Right Side: Requested Dimensions and Currency Assets
    DIM_CREATIVE["marts.dim_marketing_creatives
    
    **PK:** creative_key (VARCHAR)
    creative_id (VARCHAR)
    creative_name (VARCHAR)
    campaign_id (VARCHAR)
    campaign_name (VARCHAR)
    source_network (VARCHAR)
    
    *DISTSTYLE: ALL*"]:::dimStyle

    REF_CURRENCY["paid_media.ref_currency
    
    id (INTEGER)
    from_currency (VARCHAR)
    to_currency (VARCHAR)
    cur_date (TIMESTAMP)
    exchangerate (DOUBLE)
    exchangerate_in_euro (DOUBLE)"]:::refStyle

    %% Relationships & Joins (Flowing Left-to-Center and Right-to-Center)
    MAP_LINKEDIN_GEO -.->|Translates to| REF_GEO
    REF_GEO -->|1:N Join via country_code| FACT
    
    DIM_CREATIVE -->|1:N Join via creative_key| FACT
    REF_CURRENCY -.->|Calculates cost_eur| FACT
```
