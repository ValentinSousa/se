[DOCS](https://docs.aws.amazon.com/redshift/latest/dg/merge-examples.html)  
An **upsert** (update or insert) in Amazon Redshift cannot be done with a single command because Redshift doesn't natively support a `MERGE` statement.

Instead, the standard, most efficient way to perform an upsert is by using a **staging table**.

---

## The 4-Step Upsert Process

### 1. Create a Staging Table

Create a temporary staging table that matches the schema of your target table. It's fastest to copy the structure of your target table.

```sql
CREATE TEMP TABLE staging_table (LIKE target_table);

```

### 2. Load Data into Staging

Populate your staging table with the new and updated data using a `COPY` command or `INSERT INTO`.

### 3. Delete Matching Rows from Target

To prevent duplicate rows, delete the records from the target table that match the primary keys of the incoming data in the staging table.

```sql
BEGIN TRANSACTION;

DELETE FROM target_table
USING staging_table
WHERE target_table.primary_key = staging_table.primary_key;

```

### 4. Insert Everything from Staging

Because the conflicting rows have just been deleted, you can safely insert all rows from the staging table into the target table.

```sql
INSERT INTO target_table
SELECT * FROM staging_table;

END TRANSACTION;

```

---

## Why this method?

* **Performance:** Redshift is a columnar storage database. Individual `UPDATE` statements are highly inefficient. Deleting and inserting in bulk is much faster.
* **Data Integrity:** Wrapping steps 3 and 4 in a `BEGIN TRANSACTION ... END TRANSACTION` block ensures that if anything fails, the entire operation rolls back.