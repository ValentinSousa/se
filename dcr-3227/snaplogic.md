in both pipelines, we need to add:


Target Column,SnapLogic Expression / Value,Behavior on Upsert Match
ad_summary_key,SlUtil.getMD5Hex($date + $campaign_id + ...),Identity Key (Matches existing)
_pipeline_run_id,pipe.ruuid,Overwrite (Tracks the latest run that touched this row)
_ingested_at,Date.now(),Ignore/Keep Original
_updated_at,Date.now(),Overwrite (Updates to current execution time)

Google ads:
SlUtil.getMD5Hex($date + $campaign_id + $ad_group_id)


