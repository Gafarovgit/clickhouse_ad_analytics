-- Generate 20,000 deterministic, linked advertising events across 4 campaigns.
-- Event mix per 100 rows: 80 impressions, 15 clicks, 5 conversions.
-- Every event has cost and revenue fields; revenue is positive for conversions.
INSERT INTO ad_analytics.raw_ads_events
    (event_id, event_date, campaign_id, channel_id, event_type, cost, revenue, device, country)
SELECT
    generateUUIDv4() AS event_id,
    today() - toIntervalDay(number % 30) AS event_date,
    toUInt32(101 + intDiv(number, 5000)) AS campaign_id,
    toUInt32(1 + intDiv(number, 5000)) AS channel_id,
    multiIf(number % 100 < 80, 'impression',
            number % 100 < 95, 'click',
            'conversion') AS event_type,
    toDecimal64(
        multiIf(number % 100 < 80,
                0.002 + toFloat64(number % 7) * 0.001,
                number % 100 < 95,
                0.25 + toFloat64(number % 11) * 0.05,
                0.10 + toFloat64(number % 5) * 0.02), 4) AS cost,
    toDecimal64(
        if(number % 100 >= 95, 25 + (number % 17) * 3, 0), 2) AS revenue,
    arrayElement(['mobile', 'desktop', 'tablet'], toUInt64(number % 3) + 1) AS device,
    arrayElement(['US', 'GB', 'DE', 'FR', 'NO'], toUInt64(number % 5) + 1) AS country
FROM numbers(20000);
