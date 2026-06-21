-- ==========================================
-- 1. REFERENCE TABLES (image_93cd08.jpg)
-- ==========================================

-- create table for ref source with currency
CREATE OR REPLACE TABLE paid_media.ref_currency (
    id integer,
    from_currency varchar(6),
    to_currency varchar(6),
    cur_date timestamp, -- no timezone (aligns with Redshift TIMESTAMP)
    exchangerate double,
    exchangerate_in_euro double
);

-- create table for ref source with geography
CREATE OR REPLACE TABLE paid_media.ref_geography (
    id integer,
    country_code varchar(6),
    country_name varchar(60),
    region_name varchar(60),
    region_code varchar(6),
    zone_val varchar(30),
    country_code_2 varchar(6)
);


-- ==========================================
-- 2. STAGING TABLES
-- ==========================================

-- create table for raw data from google ads api (image_93cd0d.jpg)
    CREATE OR REPLACE TABLE paid_media.stg_google_ads (
        date DATE,
        account_id VARCHAR,
        account_name VARCHAR,
        campaign_id VARCHAR,
        campaign_name VARCHAR,
        objective_type VARCHAR,
        ad_group_id VARCHAR,
        ad_group_name VARCHAR,
        currency VARCHAR(6),
        spend DOUBLE, -- DECIMAL(18,4)
        impressions INTEGER,
        clicks INTEGER,
        engagements INTEGER,
        leads INTEGER,
        video_views INTEGER
    );

    -- create table for raw data from linkedin api (image_93cd29.jpg)
    CREATE OR REPLACE TABLE paid_media.stg_linkedin_ads (
        date DATE,
        account_id VARCHAR,
        account_name VARCHAR,
        campaign_id VARCHAR,
        campaign_name VARCHAR,
        creative_id VARCHAR,
        creative_name VARCHAR,
        objective_type VARCHAR,
        cost_in_usd DOUBLE,
        cost_in_local_currency DOUBLE, -- DECIMAL(18,4)
        impressions INTEGER,
        clicks INTEGER,
        link_clicks INTEGER,
        leads INTEGER,
        engagement INTEGER,
        video_plays INTEGER
    );


-- ==========================================
-- 3. DASHBOARD TABLES  that should be result of data modeling
-- ==========================================

-- create table on which based current dashboard
CREATE OR REPLACE TABLE paid_media.dasboard_marketing_performance (
    costnature VARCHAR,
    country VARCHAR(100),
    division VARCHAR(100),
    engaged_accounts BOOLEAN,
    graph_period VARCHAR(50),
    is_current_year BOOLEAN,
    is_past_year_ytd BOOLEAN,
    last_13_months BOOLEAN,
    marketing_campaign VARCHAR(255),
    marketing_channel VARCHAR(255),
    marketing_tactic VARCHAR(255),
    month_date DATE,
    operations VARCHAR(255),
    source VARCHAR(100),
    spend_type VARCHAR(50),
    zone VARCHAR(100),
    amount_in_eur DOUBLE,
    total_clicks INTEGER,
    total_impressions INTEGER
);