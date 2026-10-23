-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Drop-off = visitors who left without leaving their details. Slow means an average load time over 3 seconds.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days)
SELECT l.page, SUM(l.visits) AS visits, SUM(l.leads) AS leads,
       ROUND(1 - SUM(l.leads)::numeric / NULLIF(SUM(l.visits), 0), 3) AS drop_off,
       ROUND(AVG(l.avg_load_s), 1) AS avg_load_s,
       CASE WHEN AVG(l.avg_load_s) > 3 THEN 'slow' ELSE 'ok' END AS speed
FROM alcovia.landing_page_daily l, params p
WHERE l.day BETWEEN p.as_of - (p.window_days - 1) AND p.as_of
GROUP BY l.page ORDER BY l.page;
