-- 1. Top 5 campaigns by weighted ROI over the last 7 days.
SELECT
    k.campaign_id,
    any(c.campaign_name) AS campaign_name,
    sum(k.spend) AS spend,
    sum(k.revenue) AS revenue,
    if(sum(k.spend) = 0, 0.,
       (toFloat64(sum(k.revenue)) - toFloat64(sum(k.spend))) / toFloat64(sum(k.spend))) AS roi
FROM ad_analytics.campaign_kpi AS k
LEFT JOIN ad_analytics.campaigns AS c USING (campaign_id)
WHERE k.event_date >= today() - 6
GROUP BY k.campaign_id
ORDER BY roi DESC
LIMIT 5;

-- 2. Top 5 channels by weighted CPA (lower is better; campaigns with no conversions are excluded).
SELECT
    k.channel_id,
    any(ch.channel_name) AS channel_name,
    sum(k.spend) AS spend,
    sum(k.conversions) AS conversions,
    toFloat64(sum(k.spend)) / nullIf(toFloat64(sum(k.conversions)), 0) AS cpa
FROM ad_analytics.campaign_kpi AS k
LEFT JOIN ad_analytics.channels AS ch USING (channel_id)
GROUP BY k.channel_id
HAVING sum(k.conversions) > 0
ORDER BY cpa ASC
LIMIT 5;

-- 3. Campaigns with weighted CTR below 1%.
SELECT
    k.campaign_id,
    any(c.campaign_name) AS campaign_name,
    sum(k.impressions) AS impressions,
    sum(k.clicks) AS clicks,
    if(sum(k.impressions) = 0, 0.,
       toFloat64(sum(k.clicks)) / toFloat64(sum(k.impressions))) AS ctr
FROM ad_analytics.campaign_kpi AS k
LEFT JOIN ad_analytics.campaigns AS c USING (campaign_id)
GROUP BY k.campaign_id
HAVING ctr < 0.01
ORDER BY ctr ASC;

-- 4. Daily spend and revenue for campaign 101 (change the ID to inspect another campaign).
SELECT event_date, sum(spend) AS spend, sum(revenue) AS revenue
FROM ad_analytics.campaign_kpi
WHERE campaign_id = 101
GROUP BY event_date
ORDER BY event_date;

-- 5. Actual daily spend versus campaign daily budget.
SELECT
    k.campaign_id,
    any(c.campaign_name) AS campaign_name,
    k.event_date,
    sum(k.spend) AS actual_spend,
    any(c.daily_budget) AS daily_budget,
    sum(k.spend) - toDecimal64(any(c.daily_budget), 4) AS budget_delta,
    if(any(c.daily_budget) = 0, 0.,
       toFloat64(sum(k.spend)) / toFloat64(any(c.daily_budget))) AS budget_utilization
FROM ad_analytics.campaign_kpi AS k
LEFT JOIN ad_analytics.campaigns AS c USING (campaign_id)
GROUP BY k.campaign_id, k.event_date
ORDER BY k.event_date DESC, k.campaign_id;
