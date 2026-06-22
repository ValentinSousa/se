## Pipeline Description (English Translation)

### Step 1: Ingestion Layer (`raw.raw_linkedin_ads`)

* **Operation:** Full overwrite (Truncate & Insert).
* **Data:** Flat, strictly containing a rolling 14-day lookback window fetched from the API.

### Step 2: Historical Archive / Staging Layer (`stg.stg_linkedin_ads`)

* **Operation:** Idempotent `DELETE + INSERT` based on the date range.
* **Data:** Complete history in a flat format, preserving the immutable digital footprint of performance metrics (clicks, impressions, spend).

### Step 3: Physical OBT (`marts.obt_marketing_performance`)

* **Operation:** Atomic execution within a single database transaction. Window functions (`ROW_NUMBER()`) extract the latest campaign and creative names, which are then joined with the historical metrics from `stg`.
* **Data:** A clean, fully materialized flat table optimized for rapid read access.
* **Purpose:** To isolate heavy analytical calculations (like window functions) from the BI tools.

### Step 4: Semantic Facade (`marts.fact_marketing_performance` — **VIEW**)

* **Operation:** Abstraction layer: `CREATE OR REPLACE VIEW marts.fact_marketing_performance AS SELECT * FROM marts.obt_marketing_performance;`
* **Purpose:** Dashboards and analysts connect **strictly to this View**. Currently, it simply passes through data from the Step 3 table. However, if data volumes scale and you need to implement a Blue-Green deployment later, you can easily spin up two physical tables (`obt_blue` and `obt_green`) behind this View and swap them with a single command. The transition remains entirely invisible to end-users.

---

## Architectural Evaluation for Expansion (Оценка для расширения)

Твоя текущая архитектура готова к такому расширению на **9.5 из 10**. Выбранный подход с OBT + View идеально ложится на новые источники.

Вот как новые сущности впишутся в пайплайн и на что стоит обратить внимание:

### Как это будет работать (Плюсы схемы):

1. **Масштабирование без боли:** Для Facebook и Google Ads ты просто создаешь аналогичные изолированные цепочки (Шаг 1 и Шаг 2). Шаг 3 (`marts.obt`) расширяется обычным добавлением новых блоков `DELETE` и `INSERT` по конкретному `source_network`.
2. **Универсальная дедупликация имен:** Логика с оконными функциями (`latest_campaigns`) на Шаге 3 автоматически почистит переименования и для Facebook, и для Google Ads, подтягивая только самые свежие названия к историческим ID.
3. **Локальные команды:** Так как их отчеты имеют ту же структуру, их загрузка на Шаг 2 вообще не вызовет проблем. Для них `source_network` может принимать значения вида `'local_team_uk'`, `'local_team_es'` и т.д.
4. **Слой View спасает дашборды:** Аналитики и BI-инструменты даже не заметят изменений в инфраструктуре. В дашбордах просто органично появятся новые строки и новые фильтры по источникам в колонке `source_network`.

### Зоны риска (На что обратить внимание):

* **Человеческий фактор в локальных отчетах:** Даже если структура отчетов «одинаковая», ручной ввод или выгрузки от локальных команд — это всегда источник Schema Drift (забыли колонку, поменяли местами, написали дату текстом). На Шаге 1 для локальных команд обязательна жесткая валидация типов данных (Data Quality Gate), чтобы кривой файл не уронил сборку общей витрины.
* **Объем данных в Redshift:** Google Ads и Facebook генерируют кратно больше строк, чем LinkedIn. Когда OBT разрастется, транзакционный `DELETE + INSERT` внутри одного батча начнет занимать больше времени. Вот тогда-то скрытый за `VIEW` паттерн **Blue-Green** и превратится из теории в реальную необходимость.

Каким способом планируется забирать локальные отчеты (S3 bucket, Google Sheets, или прямая загрузка через интерфейс)?