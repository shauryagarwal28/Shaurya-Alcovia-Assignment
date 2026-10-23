-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Main metric. Engaged minutes = active time in the app + VERIFIED focus time, reported separately.
-- Students with no session count as zero, so the average is honest.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 7 AS window_days),
cohort AS (SELECT COUNT(*) AS n FROM alcovia.students),
mins AS (
  SELECT SUM(CASE WHEN s.kind = 'app' THEN s.active_seconds END) / 60.0                      AS active_min,
         SUM(CASE WHEN s.kind = 'focus' AND s.verified THEN s.active_seconds END) / 60.0     AS focus_min
  FROM alcovia.app_sessions s, params p
  WHERE (s.started_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of)
SELECT ROUND(COALESCE(active_min, 0) / (c.n * p.window_days), 2)                       AS active_min_per_student_day,
       ROUND(COALESCE(focus_min, 0) / (c.n * p.window_days), 2)                        AS verified_focus_min_per_student_day,
       ROUND((COALESCE(active_min, 0) + COALESCE(focus_min, 0)) / (c.n * p.window_days), 2) AS engaged_min_per_student_day,
       30 AS goal
FROM mins, cohort c, params p;

-- Weekly trend, last 8 weeks (the line the team view draws)
WITH params AS (SELECT DATE '2026-10-23' AS as_of),
cohort AS (SELECT COUNT(*) AS n FROM alcovia.students)
SELECT (p.as_of - (7 * w.k + 6)) AS week_start,
       ROUND(SUM(CASE WHEN s.kind = 'app' THEN s.active_seconds ELSE 0 END) / 60.0 / (c.n * 7), 2) AS active_min,
       ROUND(SUM(CASE WHEN s.kind = 'focus' AND s.verified THEN s.active_seconds ELSE 0 END) / 60.0 / (c.n * 7), 2) AS verified_focus_min
FROM params p CROSS JOIN cohort c CROSS JOIN generate_series(0, 7) AS w(k)
LEFT JOIN alcovia.app_sessions s
  ON (s.started_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p.as_of - (7 * w.k + 6) AND p.as_of - (7 * w.k)
GROUP BY w.k, p.as_of, c.n ORDER BY week_start;
