-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Weekly active = any app session in the last 7 days. Regular focus user = 3 or more verified focus sessions in 7 days.
WITH params AS (SELECT DATE '2026-10-23' AS as_of),
w AS (
  SELECT s.student_id,
         COUNT(*) AS sessions,
         COUNT(*) FILTER (WHERE s.verified) AS verified_focus
  FROM alcovia.app_sessions s, params p
  WHERE (s.started_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN p.as_of - 6 AND p.as_of
  GROUP BY s.student_id)
SELECT (SELECT COUNT(*) FROM w)                                       AS weekly_active_students,
       (SELECT COUNT(*) FROM alcovia.students)                        AS enrolled_students,
       (SELECT COUNT(*) FROM w WHERE verified_focus >= 3)             AS regular_focus_users;
