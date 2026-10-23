-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Attendance counts only sessions that were held. A session Alcovia cancels is never counted against a student.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days),
held AS (
  SELECT e.event_id, e.event_type FROM alcovia.program_events e, params p
  WHERE e.held AND e.scheduled_at::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of)
SELECT st.student_id, st.full_name,
       COUNT(*) FILTER (WHERE a.attended)                          AS attended,
       COUNT(*)                                                    AS held_sessions,
       ROUND(COUNT(*) FILTER (WHERE a.attended)::numeric / NULLIF(COUNT(*), 0), 3) AS attendance_rate
FROM alcovia.students st
JOIN alcovia.event_attendance a USING (student_id)
JOIN held h USING (event_id)
GROUP BY st.student_id, st.full_name
ORDER BY attendance_rate;

-- By session type, whole cohort
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days)
SELECT e.event_type, COUNT(*) FILTER (WHERE a.attended) AS attended, COUNT(*) AS held_slots,
       ROUND(COUNT(*) FILTER (WHERE a.attended)::numeric / COUNT(*), 3) AS rate
FROM alcovia.program_events e JOIN alcovia.event_attendance a USING (event_id), params p
WHERE e.held AND e.scheduled_at::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of
GROUP BY e.event_type ORDER BY e.event_type;
