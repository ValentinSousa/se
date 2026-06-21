### Phase 2: Staging Layer (SQL) — Core Explanations

* **`linkedin_ad_id` Generation (dbt-style):** We generate a deterministic surrogate key using `md5` compiled from the business grain (`date`, `creative_id`, `geo_id`). To prevent `NULL` values from breaking the string concatenation, `COALESCE` replaces missing fields with the standard dbt string `'_dbt_utils_surrogate_key_null_'`.
* **Targeted `DELETE` Strategy:** Because the `raw` table contains exactly one fresh 14-day payload from the daily SnapLogic run, the subquery `DELETE WHERE linkedin_ad_id IN (SELECT ... FROM raw)` isolates and cuts out *only* the historical rows matched by the incoming batch. This keeps your historical ledger intact without dropping data for overlapping dates or other untouched campaigns.
* **Lineage & Audit (`run_id` & `uploaded_at`):** We append `run_id` to trace the data back to its specific execution batch, and a default `uploaded_at` timestamp to register exactly when the record was modified in the warehouse.
* **Data Quarantine Execution:** Rows carrying invalid metrics (e.g., negative cost/clicks) or missing core granularity keys are instantly routed to a persistent `audit.quarantine_linkedin_ads` logging table, keeping the `stg` layer perfectly clean and preventing transaction failures.

---

#### 1. DDL (DuckDB Native)

```sql
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS audit;

-- Permanent historical staging repository
CREATE TABLE stg.stg_linkedin_ads (
    linkedin_ad_id         VARCHAR NOT NULL PRIMARY KEY,
    date                   DATE NOT NULL,
    account_id             VARCHAR,
    account_name           VARCHAR,
    campaign_id            VARCHAR,
    campaign_name          VARCHAR,
    creative_id            VARCHAR NOT NULL,
    creative_name          VARCHAR,
    objective_type         VARCHAR,
    geo_id                 VARCHAR NOT NULL,
    cost_in_usd            DOUBLE, 
    cost_in_local_currency DOUBLE,
    impressions            INTEGER,
    clicks                 INTEGER,
    link_clicks            INTEGER,
    leads                  INTEGER,
    engagement             INTEGER,
    video_plays            INTEGER,
    run_id                 VARCHAR NOT NULL,
    uploaded_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Синхронизировано с Phase 3
); 
-- REDSHIFT MIGRATION NOTE: For performance optimization, append Redshift cluster distribution and sort patterns here:
-- DISTSTYLE KEY DISTKEY (linkedin_ad_id) SORTKEY (date);

-- Repository for logging anomalies and bad data payloads
CREATE TABLE audit.quarantine_linkedin_ads (
    -- REDSHIFT MIGRATION NOTE: Replace 'BIGSERIAL' with 'BIGINT IDENTITY(1,1)' for AWS Redshift identity sequences
    quarantine_id          BIGSERIAL,                    
    run_id                 VARCHAR NOT NULL,
    date                   DATE,
    creative_id            VARCHAR,
    geo_id                 VARCHAR,
    cost_in_usd            DOUBLE,
    clicks                 INTEGER,
    impressions            INTEGER,
    quarantine_reason      VARCHAR NOT NULL,
    quarantined_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

```

#### 2. Atomic SQL Transaction (DuckDB Native)

```sql
-- REDSHIFT MIGRATION NOTE: Replace 'BEGIN;' with 'BEGIN TRANSACTION;' on Redshift cluster environments
BEGIN;

-- =========================================================================
-- STEP 1: QUARANTINE ANOMALIES
-- Intercept invalid metrics or missing primary dimensions and archive them 
-- for monitoring before they can taint the clean staging environment.
-- =========================================================================
INSERT INTO audit.quarantine_linkedin_ads (run_id, date, creative_id, geo_id, cost_in_usd, clicks, impressions, quarantine_reason)
SELECT 
    run_id, date, creative_id, geo_id, cost_in_usd, clicks, impressions,
    CASE 
        WHEN cost_in_usd < 0 THEN 'Negative cost'
        WHEN clicks < 0 THEN 'Negative clicks'
        WHEN impressions < 0 THEN 'Negative impressions'
        ELSE 'Missing core granularity keys'
    END
FROM raw.raw_linkedin_ads
-- Target rows failing basic business validation checks
WHERE cost_in_usd < 0 OR clicks < 0 OR impressions < 0 OR creative_id IS NULL OR geo_id IS NULL;

-- =========================================================================
-- STEP 2: TARGETED IDEMPOTENT DELETE
-- Selectively remove existing records in stg using both DISTKEY and SORTKEY 
-- for maximum performance and block pruning in Amazon Redshift.
-- =========================================================================
DELETE FROM stg.stg_linkedin_ads
WHERE date >= (SELECT MIN(date) FROM raw.raw_linkedin_ads) -- REDSHIFT OPTIMIZATION: Activates Zone Maps
  AND linkedin_ad_id IN (
    SELECT md5(COALESCE(CAST(date AS VARCHAR), '_dbt_utils_surrogate_key_null_') || '-' ||
               COALESCE(CAST(creative_id AS VARCHAR), '_dbt_utils_surrogate_key_null_') || '-' ||
               COALESCE(CAST(geo_id AS VARCHAR), '_dbt_utils_surrogate_key_null_'))
    FROM raw.raw_linkedin_ads
    WHERE cost_in_usd >= 0 AND clicks >= 0 AND impressions >= 0 AND creative_id IS NOT NULL AND geo_id IS NOT NULL
);

-- =========================================================================
-- STEP 3: INSERT CLEAN BATCH
-- Append the verified daily batch from the raw layer while computing the 
-- dbt-style hash primary key on the fly.
-- =========================================================================
INSERT INTO stg.stg_linkedin_ads (
    linkedin_ad_id, date, account_id, account_name, campaign_id, campaign_name,
    creative_id, creative_name, objective_type, geo_id, cost_in_usd, 
    cost_in_local_currency, impressions, clicks, link_clicks, leads, engagement, video_plays, run_id
)
SELECT 
    -- Compute deterministic surrogate key handling potential nulls natively
    md5(COALESCE(CAST(date AS VARCHAR), '_dbt_utils_surrogate_key_null_') || '-' ||
        COALESCE(CAST(creative_id AS VARCHAR), '_dbt_utils_surrogate_key_null_') || '-' ||
        COALESCE(CAST(geo_id AS VARCHAR), '_dbt_utils_surrogate_key_null_')),
    date, account_id, account_name, campaign_id, campaign_name,
    creative_id, creative_name, objective_type, geo_id, cost_in_usd, 
    cost_in_local_currency, impressions, clicks, link_clicks, leads, engagement, video_plays, run_id
FROM raw.raw_linkedin_ads
-- Only ingest entries that successfully passed validation in previous steps
WHERE cost_in_usd >= 0 AND clicks >= 0 AND impressions >= 0 AND creative_id IS NOT NULL AND geo_id IS NOT NULL;

-- Save changes permanently to the database file
COMMIT;

```
