## Dynamic Lookback Window Incremental Architecture

This pattern automatically adjusts the deletion and reload window in the Data Mart based on the actual reporting dates processed by SnapLogic today.

### Prerequisites

* **`stg.stg_google_ads`**: Contains `date` (Report Date, Redshift `SORTKEY`) and `uploaded_at` (Ingestion Timestamp).
* **`marts.fact_marketing_performance`**: Target table, partitioned/sorted by `SORTKEY(date)`.

---

### Implementation SQL (Amazon Redshift)

```sql
BEGIN TRANSACTION;

-- Step 1: Find the minimum business date processed in today's ingestion batch
CREATE TEMP TABLE tmp_lookback_window AS
SELECT MIN(date) AS min_report_date
FROM stg.stg_google_ads
WHERE uploaded_at >= DATEADD(day, -1, GETDATE());

-- Step 2: Delete existing rows from the Mart starting from the dynamic lookback date
-- (Redshift utilizes Zone Maps on SORTKEY(date) for instant block-level deletion)
DELETE FROM marts.fact_marketing_performance
WHERE source_network = 'google'
  AND date >= (SELECT min_report_date FROM tmp_lookback_window);

-- Step 3: Transform and Insert today's batch into the Mart
INSERT INTO marts.fact_marketing_performance (
    fact_key, 
    date, 
    creative_key, 
    country_code, 
    cost_eur, 
    impressions, 
    clicks, 
    source_network, 
    run_id
)
SELECT
    MD5(COALESCE('google', '') || '-' || COALESCE(stg.date::varchar, '') || '-' || COALESCE(stg.creative_id, '') || '-' || COALESCE(stg.geo_id, '')) AS fact_key,
    stg.date,
    MD5('google-' || stg.creative_id) AS creative_key,
    COALESCE(geo_map.country_code, 'UNKWN') AS country_code,
    CASE 
        WHEN fx.from_currency = 'EUR' THEN stg.cost_in_local_currency
        ELSE stg.cost_in_local_currency * COALESCE(fx.exchangerate_in_euro, 1.0)
    END AS cost_eur,
    stg.impressions,
    stg.clicks,
    'google'::varchar(30) AS source_network,
    stg.run_id
FROM stg.stg_google_ads stg
LEFT JOIN reference.map_google_geo geo_map 
    ON geo_map.google_geo_id = stg.geo_id
LEFT JOIN paid_media.ref_currency fx 
    ON fx.cur_date::date = stg.date 
   AND fx.from_currency = 'GBP' -- Adjust source currency accordingly
WHERE stg.uploaded_at >= DATEADD(day, -1, GETDATE());

COMMIT;

```

---

### Key Benefits for Implementation

* **Zero Maintenance:** Eliminates the need for separate Daily (3-day) and Weekly (30-day) pipeline schedules. A single script handles both standard daily runs and historical reloads automatically.
* **Redshift Optimized:** The `DELETE` step relies on the `date` column (`SORTKEY`). Redshift skips scanning the 2-year history and drops blocks instantly via metadata (Zone Maps).
* **Data Consistency:** Wiping out the entire affected date range protects the Data Mart against duplicates, even if natural business keys or dimensions change retroactively in the source API.