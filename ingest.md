**Transactional Outbox / S3 Metadata Catalog Pattern**.

*AWS Glue Workflows* or *Step Functions Data Processing Templates*

1. **Ingest & Register (Event-Driven):** A file lands in S3 $\rightarrow$ S3 Event Notification sends an event to Lambda $\rightarrow$ Lambda performs an atomic `PutItem` in DynamoDB with the `PENDING` status (file name as PK). No file moving, they stay in place.
2. **Orchestration (Batch Queue):** Airflow schedules and triggers a Step Functions.
3. **Fetch & Lock:** The process fetches a batch (`LIMIT N`) of records from DynamoDB via a GSI by the `PENDING` status, immediately updating them to `PROCESSING`.
4. **Load (Manifest COPY):** A JSON manifest for Redshift is generated based on this batch, and a `COPY` from S3 directly into staging is executed.
5. **Finalize & Clean:** Successfully loaded file statuses are updated to `COMPLETED`, and old records are eventually purged via TTL.