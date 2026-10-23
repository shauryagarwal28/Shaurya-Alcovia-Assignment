-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Why a student is on the advisor's radar. Each row is a reason, with an urgency: 1 today, 2 this week, 3 at the weekly review.
WITH params AS (SELECT DATE '2026-10-23' AS as_of),
flags AS (
  -- 1. syllabus more than 15 points behind plan
  SELECT st.student_id, 'behind_plan' AS flag_code, 2 AS urgency,
         'Syllabus ' || ROUND((alcovia.syllabus_plan(p.as_of) - cp.covered)::numeric * 100) || ' points behind plan' AS detail
  FROM alcovia.students st, params p,
       LATERAL (SELECT COUNT(*) FILTER (WHERE stage >= 2)::numeric / COUNT(*) AS covered
                FROM alcovia.student_chapter_progress WHERE student_id = st.student_id) cp
  WHERE cp.covered < alcovia.syllabus_plan(p.as_of) - 0.15
  UNION ALL
  -- 2. attended under 60% of held sessions in 30 days (3 or more sessions held)
  SELECT att.student_id, 'low_attendance', 2, 'Attended ' || ROUND(att.rate * 100) || '% of sessions this month'
  FROM (SELECT a.student_id, AVG(a.attended::int) AS rate, COUNT(*) AS n
        FROM alcovia.event_attendance a JOIN alcovia.program_events e USING (event_id), params p
        WHERE e.held AND e.scheduled_at::date BETWEEN p.as_of - 29 AND p.as_of
        GROUP BY a.student_id) att
  WHERE att.n >= 3 AND att.rate < 0.6
  UNION ALL
  -- 3. no app activity for 7 days
  SELECT st.student_id, 'inactive_7d', 1, 'No app activity for 7 days'
  FROM alcovia.students st, params p
  WHERE NOT EXISTS (SELECT 1 FROM alcovia.app_sessions s
                    WHERE s.student_id = st.student_id AND (s.started_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 7)
  UNION ALL
  -- 4. average marks fell across the last two exams
  SELECT m.student_id, 'marks_falling', 2, 'Marks have fallen across the last two exams'
  FROM (SELECT student_id, exam_date, AVG(marks_pct) AS avg_marks,
               LAG(AVG(marks_pct), 1) OVER (PARTITION BY student_id ORDER BY exam_date) AS prev1,
               LAG(AVG(marks_pct), 2) OVER (PARTITION BY student_id ORDER BY exam_date) AS prev2,
               ROW_NUMBER() OVER (PARTITION BY student_id ORDER BY exam_date DESC) AS rn
        FROM alcovia.exam_results GROUP BY student_id, exam_date) m
  WHERE m.rn = 1 AND m.avg_marks < m.prev1 - 1 AND m.prev1 < m.prev2 - 1
  UNION ALL
  -- 5. an exam in 21 days or fewer for a subject with readiness under 45%
  SELECT ue.student_id, 'exam_prep', CASE WHEN ue.exam_date - p.as_of <= 14 THEN 1 ELSE 2 END,
         sub.name || ' exam in ' || (ue.exam_date - p.as_of) || ' days, readiness ' || ROUND(rd.readiness * 100) || '%'
  FROM alcovia.upcoming_exams ue CROSS JOIN params p
  JOIN alcovia.subjects sub USING (subject_id),
  LATERAL (SELECT COALESCE(AVG(pr.stage / 5.0) FILTER (WHERE pr.stage >= 2), 0) AS readiness
           FROM alcovia.student_chapter_progress pr JOIN alcovia.syllabus_chapters c USING (chapter_id)
           WHERE pr.student_id = ue.student_id AND c.subject_id = ue.subject_id) rd
  WHERE ue.exam_date - p.as_of BETWEEN 0 AND 21 AND rd.readiness < 0.45
  UNION ALL
  -- 6. marks uploaded by the family and waiting for the advisor to verify
  SELECT DISTINCT student_id, 'verify_marks', 3, 'Latest marks waiting for verification'
  FROM alcovia.exam_results WHERE verified_at IS NULL)
SELECT f.student_id, st.full_name, f.flag_code, f.urgency, f.detail
FROM flags f JOIN alcovia.students st USING (student_id)
ORDER BY f.urgency, st.full_name, f.flag_code;
