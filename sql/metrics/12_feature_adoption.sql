-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Share of students who used each feature area at least once. The brief gives the baseline: 100% Home ... 15% Study and Wellness (last 7 days).
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
SELECT f.feature,
       ROUND(COUNT(DISTINCT e.student_id) FILTER (WHERE (e.occurred_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 7)::numeric
             / NULLIF((SELECT COUNT(DISTINCT student_id) FROM alcovia.app_sessions s WHERE (s.started_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 7), 0), 3) AS share_of_active_7d,
       ROUND(COUNT(DISTINCT e.student_id) FILTER (WHERE (e.occurred_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 45)::numeric
             / (SELECT COUNT(*) FROM alcovia.students), 3) AS share_of_all_45d
FROM (VALUES ('home'),('focus_game'),('study'),('plan'),('wellness'),('other')) AS f(feature)
CROSS JOIN params p
LEFT JOIN alcovia.app_feature_events e ON e.feature = f.feature
GROUP BY f.feature, p.as_of ORDER BY share_of_active_7d DESC;
