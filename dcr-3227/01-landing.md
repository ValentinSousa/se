### Phase 1: Ingestion Layer (SnapLogic) — Technical Summary

---

### Architectural Design

* **ELT Philosophy ("Dumb Pipe"):** The SnapLogic pipeline acts as a pure data mover. It performs zero transformations, business logic application, currency conversion, or metric filtering. Raw data integrity is maintained exactly as returned by the LinkedIn API.
* **Rolling 14-Day Lookback Window:** To capture late-arriving attributions and platform data restatements, the pipeline extracts a sliding window of `[Current_Date - 14 Days]` to `[Current_Date]` during every daily execution.
* **Data Write Strategy (Full Overwrite):** The target table `raw.raw_linkedin_ads` functions as a transient landing buffer. Each execution truncates the table (or uses a bulk-overwrite mechanism) so that it exclusively holds the latest 14-day payload.
* **Lineage Enforcement:** SnapLogic generates a unique runtime identifier (`run_id`) for each execution execution and hardcodes it into every row of the incoming batch. This allows the downstream warehouse layers to isolate and process the exact data package deterministically.

---

### Data Contract & DDL (`raw.raw_linkedin_ads`)

This staging-buffer table uses permissive string data types (`VARCHAR`) for business entity identifiers to safeguard the ingestion pipeline against breaking changes if upstream API payload structures scale.

```sql
CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.raw_linkedin_ads (
    -- =========================================================================
    -- 1. LINEAGE & AUDIT METADATA (Populated by SnapLogic)
    -- =========================================================================
    run_id                 VARCHAR(100) NOT NULL, -- Unique SnapLogic pipeline execution ID

    -- =========================================================================
    -- 2. RAW BUSINESS DIMENSIONS (Direct from LinkedIn q=statistics API)
    -- =========================================================================
    date                   DATE NOT NULL,         -- Performance log date
    account_id             VARCHAR(50),           -- LinkedIn ad account identifier
    account_name           VARCHAR(255),          -- Name of the ad account
    campaign_id            VARCHAR(50),           -- Campaign identifier
    campaign_name          VARCHAR(255),          -- Name of the campaign
    creative_id            VARCHAR(50),           -- Creative/Ad identifier
    creative_name          VARCHAR(500),          -- Name of the ad creative
    objective_type         VARCHAR(100)          -- Campaign objective (e.g., LEAD_GENERATION)
    geo_id                 VARCHAR(100),          -- Raw Geography URN/ID for regional split

    -- =========================================================================
    -- 3. RAW PERFORMANCE METRICS (Direct from API payload)
    -- =========================================================================
    cost_in_usd            DOUBLE PRECISION,      -- Spend in default API currency (USD)
    cost_in_local_currency DOUBLE PRECISION,      -- Spend in original account billing currency
    impressions            INTEGER,               -- Impression counts
    clicks                 INTEGER,               -- Total click counts
    link_clicks            INTEGER,               -- Specific link click counts
    leads                  INTEGER,               -- Native lead form submission counts
    engagement             INTEGER,               -- Total social engagements
    video_plays            INTEGER                -- Video view counts
);

```

---

### Ingestion Execution Steps

1. **Time Evaluation:** The pipeline evaluates parameters at runtime to resolve the dynamic query windows (`pipe.startTime.minusDays(14)`).
2. **API Payload Ingestion:** A `REST GET` node targets the `/v2/adAnalyticsV2` endpoint utilizing the `q=statistics` parameter state to ensure granular `geo_id` outputs are fetched.
3. **Metadata Mapping:** A `Mapper` node stamps the current `pipe.ruid` value onto the `run_id` field across all parsed JSON items.
4. **Target Mutation:** A database connector issues a `TRUNCATE` command against `raw.raw_linkedin_ads` immediately followed by a high-velocity bulk insert block.