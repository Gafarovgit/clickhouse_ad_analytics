-- ClickHouse Ads Analytics: database, dimensions, raw events, KPI mart
-- Rebuilds the project from scratch. Safe to rerun; existing project database is replaced.
DROP DATABASE IF EXISTS ad_analytics;
CREATE DATABASE ad_analytics;

CREATE TABLE ad_analytics.channels
(
    channel_id UInt32,
    channel_name String,
    channel_type LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY channel_id;

CREATE TABLE ad_analytics.campaigns
(
    campaign_id UInt32,
    campaign_name String,
    channel_id UInt32,
    start_date Date,
    end_date Date,
    daily_budget Decimal(12, 2),
    target_audience LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY campaign_id;

CREATE TABLE ad_analytics.raw_ads_events
(
    event_id UUID,
    event_date Date,
    campaign_id UInt32,
    channel_id UInt32,
    event_type Enum8('impression' = 1, 'click' = 2, 'conversion' = 3),
    cost Decimal(12, 4),
    revenue Decimal(12, 2),
    device LowCardinality(String),
    country LowCardinality(String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (campaign_id, event_date, channel_id, event_type, event_id)
TTL event_date + INTERVAL 24 MONTH DELETE;

CREATE TABLE ad_analytics.campaign_kpi
(
    campaign_id UInt32,
    event_date Date,
    channel_id UInt32,
    impressions UInt64,
    clicks UInt64,
    conversions UInt64,
    spend Decimal(16, 4),
    revenue Decimal(16, 2),
    ctr Float64,
    cvr Float64,
    cpa Float64,
    roi Float64
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (campaign_id, event_date, channel_id)
TTL event_date + INTERVAL 36 MONTH DELETE;

INSERT INTO ad_analytics.channels (channel_id, channel_name, channel_type) VALUES
    (1, 'Search Ads', 'search'),
    (2, 'Social Media', 'social'),
    (3, 'Display Network', 'display'),
    (4, 'Video Ads', 'video');

INSERT INTO ad_analytics.campaigns
    (campaign_id, campaign_name, channel_id, start_date, end_date, daily_budget, target_audience)
VALUES
    (101, 'Search - Brand Awareness', 1, today() - 29, today(), 180.00, 'broad audience'),
    (102, 'Social - New Customers', 2, today() - 29, today(), 240.00, 'new customers'),
    (103, 'Display - Retargeting', 3, today() - 29, today(), 150.00, 'returning visitors'),
    (104, 'Video - Product Launch', 4, today() - 29, today(), 300.00, 'technology enthusiasts');
