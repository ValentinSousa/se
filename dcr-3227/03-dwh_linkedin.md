### Phase 3: Core Marts Layer (SQL Star Schema) — Final Specification

* **Conformed Dimensions:** Creative data from all networks is unified into `marts.dim_marketing_creatives`, keyed by a globally unique `creative_key` (`md5(source || '-' || id)`).
* **Source-Specific Geo Mapping:** Since ad network APIs return localized internal string/integer IDs instead of ISO country codes, individual mapping tables (e.g., `reference.map_linkedin_geo`) translate source IDs directly into a standard corporate `country_code`.
* **Corporate Geography Reference:** The unified `country_code` links directly to the production master table `paid_media.ref_geography`. Unmapped records fall back to `'UNKWN'`.
* **Multi-Currency Normalization to EUR:** The target financial currency is **EUR**. Costs are converted dynamically using the corporate `paid_media.ref_currency` table via the `exchangerate_in_euro` multiplier based on the source account's native currency.

---

#### 1. DDL Specification (DuckDB Native with Redshift Directives)

```sql
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS paid_media;

-- =========================================================================
-- CORPORATE MASTER REFERENCE: GEOGRAPHY
-- =========================================================================
CREATE OR REPLACE TABLE paid_media.ref_geography (
    id             INTEGER,
    country_code   VARCHAR PRIMARY KEY, -- REDSHIFT NOTE: Define explicit constraints, e.g., VARCHAR(6)
    country_name   VARCHAR,
    region_name    VARCHAR,
    region_code    VARCHAR,
    zone_val       VARCHAR,
    country_code_2 VARCHAR
);

-- =========================================================================
-- CORPORATE MASTER REFERENCE: CURRENCY EXCHANGE RATES
-- =========================================================================
CREATE OR REPLACE TABLE paid_media.ref_currency (
    id                   INTEGER,
    from_currency        VARCHAR,
    to_currency          VARCHAR,
    cur_date             TIMESTAMP, -- No timezone (aligns perfectly with Redshift TIMESTAMP)
    exchangerate         DOUBLE,
    exchangerate_in_euro DOUBLE     -- Direct conversion multiplier to EUR
);

-- =========================================================================
-- PLATFORM-SPECIFIC MAPPING: LINKEDIN TO CORPORATE ISO CODES
-- =========================================================================
CREATE OR REPLACE TABLE reference.map_linkedin_geo (
    linkedin_geo_id VARCHAR NOT NULL PRIMARY KEY, -- Raw API string (e.g., 'urn:li:geo:102890719')
    country_code    VARCHAR NOT NULL              -- Target link to paid_media.ref_geography.country_code
);

-- =========================================================================
-- CONFORMED DIMENSION: MARKETING CREATIVES (SHARED MATRIX)
-- =========================================================================
CREATE OR REPLACE TABLE marts.dim_marketing_creatives (
    creative_key   VARCHAR NOT NULL PRIMARY KEY, -- Globally unique hash: md5(source_network || '-' || creative_id)
    creative_id    VARCHAR NOT NULL,
    creative_name  VARCHAR,
    campaign_id    VARCHAR,
    campaign_name  VARCHAR,
    source_network VARCHAR NOT NULL              -- Lineage tracker: 'linkedin', 'google', 'facebook'
);
-- REDSHIFT MIGRATION NOTE: Optimize with DISTSTYLE ALL since dimension tables are relatively small 
-- and frequently joined across fact grains.

-- =========================================================================
-- CENTRAL UNIFIED FACT TABLE: PERFORMANCE METRICS (IN EUR)
-- =========================================================================
CREATE OR REPLACE TABLE marts.fact_marketing_performance (
    fact_key       VARCHAR NOT NULL PRIMARY KEY,
    date           DATE NOT NULL,
    creative_key   VARCHAR NOT NULL REFERENCES marts.dim_marketing_creatives(creative_key),
    country_code   VARCHAR NOT NULL,      -- Joins with paid_media.ref_geography.country_code
    cost_eur       DOUBLE,                -- All performance financials normalized to EUR
    impressions    INTEGER,
    clicks         INTEGER,
    source_network VARCHAR NOT NULL,      -- Partitions analytics queries by platform source
    run_id         VARCHAR NOT NULL,      -- Ingestion audit tracking
    inserted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- REDSHIFT MIGRATION NOTE: Append the following parameters for optimal pruning:
-- DISTSTYLE KEY DISTKEY (creative_key) SORTKEY (date);

```

---

#### 2. Atomic Mart Transformation Script (DuckDB Native)

```sql
-- REDSHIFT MIGRATION NOTE: Swap 'BEGIN;' for 'BEGIN TRANSACTION;'
BEGIN;

-- =========================================================================
-- STEP 1: UPSERT CONFORMED DIMENSION (SCD TYPE 1)
-- Merge LinkedIn creative metadata into the global marketing dimension.
-- =========================================================================
INSERT OR REPLACE INTO marts.dim_marketing_creatives (
    creative_key, creative_id, creative_name, campaign_id, campaign_name, source_network
)
SELECT DISTINCT
    md5('linkedin-' || COALESCE(creative_id, '_dbt_utils_surrogate_key_null_')),
    creative_id,
    creative_name,
    campaign_id,
    campaign_name,
    'linkedin'
FROM stg.stg_linkedin_ads;

-- =========================================================================
-- STEP 2: DYNAMIC IDEMPOTENT TARGETED PURGE
-- Finds the earliest reporting date within today's fresh ingestion batch 
-- and wipes the Mart from that specific checkpoint forward.
-- REDSHIFT NOTE: Leverages Zone Maps on SORTKEY(date) for fast block-level drops.
-- =========================================================================
DELETE FROM marts.fact_marketing_performance
WHERE source_network = 'linkedin'
  AND date >= (
      SELECT MIN(date) 
      FROM stg.stg_linkedin_ads 
      WHERE uploaded_at >= now() - INTERVAL '1 day'
    --   WHERE uploaded_at >= DATEADD(day, -1, GETDATE()) -- redshift
  );

-- =========================================================================
-- STEP 3: CONSOLIDATE FACT DATA WITH MULTI-MAPPING AND FX CONVERSION
-- Processes ONLY the fresh delta batch from staging into the cleared lookback window.
-- =========================================================================
INSERT INTO marts.fact_marketing_performance (
    fact_key, date, creative_key, country_code, cost_eur, impressions, clicks, source_network, run_id
)
SELECT
    md5('linkedin-' || stg.linkedin_ad_id) AS fact_key,
    stg.date,
    md5('linkedin-' || stg.creative_id) AS creative_key,
    
    -- GEO TRANSLATION: Map API internal codes to ISO code. Fallback to 'UNKWN'.
    COALESCE(geo_map.country_code, 'UNKWN') AS country_code,
    
    -- FINANCIAL TRANSLATION RULE (TO EUR):
    CASE 
        WHEN 'USD' = 'EUR' THEN stg.cost_in_local_currency 
        ELSE stg.cost_in_local_currency * COALESCE(fx.exchangerate_in_euro, 1.0)
    END AS cost_eur,
    
    stg.impressions,
    stg.clicks,
    'linkedin' AS source_network,
    stg.run_id
FROM stg.stg_linkedin_ads stg

-- Resolve the surrogate creative pointer
LEFT JOIN marts.dim_marketing_creatives dc 
    ON dc.creative_id = stg.creative_id 
   AND dc.source_network = 'linkedin'

-- Resolve source-specific geographical mapping
LEFT JOIN reference.map_linkedin_geo geo_map 
    ON geo_map.linkedin_geo_id = stg.geo_id

-- Fetch the corporate currency exchange rate based on the reporting date 
LEFT JOIN paid_media.ref_currency fx 
    ON CAST(fx.cur_date AS DATE) = stg.date 
   AND fx.from_currency = 'USD'

-- Ingestion Delta Filter: Only extract rows updated in the last landing cycle
WHERE uploaded_at >= now() - INTERVAL '1 day';
-- WHERE stg.uploaded_at >= DATEADD(day, -1, GETDATE()); -- redshift

COMMIT;

```
