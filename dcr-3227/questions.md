## Questions:
- which snap use for redshift? now strategy is to overwrite all table every time we load the data from api
- what level of details do we need for geo data? MEMBER_COUNTRY_V2 / MEMBER_REGION_V2 (use =analytics&pivot=MEMBER_COUNTRY_V2 for list of active countries)  
[LinkedIn docs](https://learn.microsoft.com/en-us/linkedin/marketing/integrations/ads-reporting/ads-reporting-schema?view=li-lms-2026-06#statistics-finder-query-parameters)  
[google geo](https://developers.google.com/google-ads/api/data/geotargets)
- 

Use the Redshift Bulk Load (or Multi-Execute) Snap to write the incoming 10-day chunk into a temporary staging table first. Then, execute a post-load SQL script (via the Redshift Execute Snap) to perform a "Delete and Insert" pattern:
```sql 
DELETE FROM fact_ads WHERE date >= CURRENT_DATE - 10;
INSERT INTO fact_ads SELECT * FROM staging_ads;
```

1. The SnapLogic License Constraint
SnapLogic sells its connectors (Snaps) in bundles or individual packs.

To use the Redshift Bulk Load Snap, it typically requires the Amazon Redshift Snap Pack.

Furthermore, optimal bulk loading in Redshift usually requires an intermediate landing zone (like Amazon S3) for the COPY command to work. This means you also need the Amazon S3 Snap Pack.

If your company has a restricted SnapLogic license that only includes basic JDBC/SQL Snaps, you won't have access to the specialized Bulk Load Snaps, forcing us to write a different, less optimal ingestion pipeline.

2. The Team Capabilities Constraint
The "Bulk Load + Staging" pattern requires splitting the work into three distinct steps within SnapLogic or Redshift:

Truncating a staging table and loading raw data into it.

Executing a custom SQL script containing the DELETE and INSERT logic.

Managing the orchestration and error handling across these steps.

If your team consists of pure drag-and-drop integration developers who aren't comfortable writing and optimizing raw Redshift SQL scripts, they might prefer using a native, out-of-the-box Upsert Snap because it handles the logic visually behind the scenes, even if it is slower on the database side.