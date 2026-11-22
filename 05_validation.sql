-- Automated assertions: query fails with a descriptive exception if a requirement is broken.
SELECT throwIf((SELECT count() FROM ad_analytics.channels) < 4, 'FAIL: fewer than 4 channels');
SELECT throwIf((SELECT count() FROM ad_analytics.campaigns) < 4, 'FAIL: fewer than 4 campaigns');
SELECT throwIf((SELECT count() FROM ad_analytics.raw_ads_events) < 10000, 'FAIL: fewer than 10000 events');
SELECT throwIf((SELECT uniqExact(event_type) FROM ad_analytics.raw_ads_events) < 3, 'FAIL: missing event types');
SELECT throwIf((SELECT uniqExact(device) FROM ad_analytics.raw_ads_events) < 2, 'FAIL: insufficient device variety');
SELECT throwIf((SELECT uniqExact(country) FROM ad_analytics.raw_ads_events) < 2, 'FAIL: insufficient country variety');
SELECT throwIf((SELECT count() FROM ad_analytics.campaign_kpi) = 0, 'FAIL: KPI mart is empty');

-- Event counts must reconcile exactly to the KPI mart.
SELECT throwIf(
    (SELECT sum(impressions) FROM ad_analytics.campaign_kpi) !=
    (SELECT countIf(event_type = 'impression') FROM ad_analytics.raw_ads_events),
    'FAIL: impressions do not reconcile');
SELECT throwIf(
    (SELECT sum(clicks) FROM ad_analytics.campaign_kpi) !=
    (SELECT countIf(event_type = 'click') FROM ad_analytics.raw_ads_events),
    'FAIL: clicks do not reconcile');
SELECT throwIf(
    (SELECT sum(conversions) FROM ad_analytics.campaign_kpi) !=
    (SELECT countIf(event_type = 'conversion') FROM ad_analytics.raw_ads_events),
    'FAIL: conversions do not reconcile');

-- Spend and revenue must reconcile to the raw events.
SELECT throwIf(
    abs(toFloat64((SELECT sum(spend) FROM ad_analytics.campaign_kpi)) -
        toFloat64((SELECT sum(cost) FROM ad_analytics.raw_ads_events))) > 0.01,
    'FAIL: spend does not reconcile');
SELECT throwIf(
    abs(toFloat64((SELECT sum(revenue) FROM ad_analytics.campaign_kpi)) -
        toFloat64((SELECT sum(revenue) FROM ad_analytics.raw_ads_events))) > 0.01,
    'FAIL: revenue does not reconcile');

-- Logical checks and summary.
SELECT throwIf((SELECT count() FROM ad_analytics.campaign_kpi
                WHERE impressions < 0 OR clicks < 0 OR conversions < 0
                   OR spend < 0 OR revenue < 0) > 0,
               'FAIL: negative KPI value');
SELECT throwIf((SELECT count() FROM ad_analytics.campaign_kpi
                WHERE ctr < 0 OR cvr < 0 OR cpa < 0) > 0,
               'FAIL: invalid ratio');
SELECT 'PASS: all project validation checks completed successfully' AS validation_result;

SELECT 'channels' AS object_name, count() AS rows FROM ad_analytics.channels
UNION ALL SELECT 'campaigns', count() FROM ad_analytics.campaigns
UNION ALL SELECT 'raw_ads_events', count() FROM ad_analytics.raw_ads_events
UNION ALL SELECT 'campaign_kpi', count() FROM ad_analytics.campaign_kpi;

SELECT event_type, count() AS events
FROM ad_analytics.raw_ads_events
GROUP BY event_type
ORDER BY event_type;

SELECT uniqExact(device) AS devices, uniqExact(country) AS countries
FROM ad_analytics.raw_ads_events;
