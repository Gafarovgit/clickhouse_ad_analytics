-- Active parts, row counts, storage footprint and partitions.
SELECT
    table,
    partition,
    sum(rows) AS rows,
    formatReadableSize(sum(bytes_on_disk)) AS data_size,
    count() AS active_parts
FROM system.parts
WHERE database = 'ad_analytics' AND active
GROUP BY table, partition
ORDER BY table, partition;

-- Current merges (may legitimately return zero rows on a small, idle training dataset).
SELECT database, table, elapsed, progress, num_parts, result_part_name
FROM system.merges
WHERE database = 'ad_analytics'
ORDER BY elapsed DESC;

-- Flush query log so the current audit queries are visible where query logging is enabled.
SYSTEM FLUSH LOGS;

SELECT
    event_time,
    type,
    query_duration_ms,
    read_rows,
    formatReadableSize(read_bytes) AS read_size,
    left(query, 160) AS query_preview
FROM system.query_log
WHERE event_time >= now() - INTERVAL 1 DAY
  AND type = 'QueryFinish'
  AND query ILIKE '%ad_analytics%'
ORDER BY event_time DESC
LIMIT 20;

-- Explain how the campaign/date sorting key is used by a typical report.
EXPLAIN indexes = 1
SELECT campaign_id, event_date, sum(spend)
FROM ad_analytics.campaign_kpi
WHERE campaign_id = 101
  AND event_date >= today() - 6
GROUP BY campaign_id, event_date
ORDER BY event_date;
