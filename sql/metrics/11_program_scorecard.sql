-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Team-only view. Quantity: did we run it. Quality: did students like it. Families never see ratings.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 90 AS window_days)
SELECT e.event_type,
       COUNT(DISTINCT e.event_id)                                       AS planned,
       COUNT(DISTINCT e.event_id) FILTER (WHERE e.held)                 AS held,
       ROUND(AVG(a.attended::int) FILTER (WHERE e.held), 3)             AS attendance_rate,
       ROUND(AVG(a.rating), 2)                                          AS avg_rating,
       ROUND(COUNT(a.rating)::numeric / NULLIF(COUNT(*) FILTER (WHERE a.attended), 0), 3) AS rating_response_rate
FROM alcovia.program_events e
LEFT JOIN alcovia.event_attendance a USING (event_id), params p
WHERE e.scheduled_at::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of
GROUP BY e.event_type ORDER BY e.event_type;

-- Soft skills from the workshop scorecard: cohort average per skill
SELECT k.key AS skill, ROUND(AVG((k.value)::numeric), 2) AS avg_score
FROM alcovia.event_attendance a, LATERAL jsonb_each_text(a.skills) AS k(key, value)
WHERE a.skills IS NOT NULL GROUP BY k.key ORDER BY k.key;
