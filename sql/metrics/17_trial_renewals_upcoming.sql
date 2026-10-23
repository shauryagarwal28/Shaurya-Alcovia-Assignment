-- Change as_of and window_days in the params CTE. All times are read in IST.
-- 3-month trial teens whose trial ends in the next 30 days, with a renewal-risk flag taken from app use and attendance.
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
SELECT st.full_name, t.trial_ends_on, (t.trial_ends_on - p.as_of) AS days_left,
       act.sessions_14d, ROUND(att.rate, 2) AS attendance_30d,
       CASE WHEN act.sessions_14d = 0 OR att.rate < 0.5 THEN 'high'
            WHEN act.sessions_14d < 5 OR att.rate < 0.7 THEN 'medium' ELSE 'low' END AS renewal_risk
FROM alcovia.trial_renewals t JOIN alcovia.students st USING (student_id), params p,
LATERAL (SELECT COUNT(*) AS sessions_14d FROM alcovia.app_sessions s
         WHERE s.student_id = t.student_id AND (s.started_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 14) act,
LATERAL (SELECT COALESCE(AVG(a.attended::int), 0) AS rate FROM alcovia.event_attendance a JOIN alcovia.program_events e USING (event_id)
         WHERE a.student_id = t.student_id AND e.held AND e.scheduled_at::date BETWEEN p.as_of - 29 AND p.as_of) att
WHERE t.renewed_on IS NULL AND t.trial_ends_on BETWEEN p.as_of AND p.as_of + 30
ORDER BY t.trial_ends_on;
