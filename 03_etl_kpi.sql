-- Rebuild the daily campaign KPI mart from raw events.
-- CTR = clicks / impressions; CVR = conversions / clicks.
-- CPA = spend / conversions; ROI = (revenue - spend) / spend.
-- Ratios are stored as fractions (0.05 means 5%). Zero denominators return 0.
TRUNCATE TABLE ad_analytics.campaign_kpi;

INSERT INTO ad_analytics.campaign_kpi
    (campaign_id, event_date, channel_id, impressions, clicks, conversions,
     spend, revenue, ctr, cvr, cpa, roi)
SELECT
    campaign_id,
    event_date,
    channel_id,
    toUInt64(countIf(event_type = 'impression')) AS impressions,
    toUInt64(countIf(event_type = 'click')) AS clicks,
    toUInt64(countIf(event_type = 'conversion')) AS conversions,
    toDecimal64(sum(cost), 4) AS spend,
    toDecimal64(sum(revenue), 2) AS revenue,
    if(impressions = 0, 0., toFloat64(clicks) / toFloat64(impressions)) AS ctr,
    if(clicks = 0, 0., toFloat64(conversions) / toFloat64(clicks)) AS cvr,
    if(conversions = 0, 0., toFloat64(spend) / toFloat64(conversions)) AS cpa,
    if(spend = 0, 0., (toFloat64(revenue) - toFloat64(spend)) / toFloat64(spend)) AS roi
FROM ad_analytics.raw_ads_events
GROUP BY campaign_id, event_date, channel_id;
