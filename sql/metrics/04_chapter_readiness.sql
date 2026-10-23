-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Progress number 2. How far each COVERED chapter has climbed: 2 notes, 3 practice above 70%, 4 timed past paper, 5 exam ready (80%+).
-- Readiness = average of stage / 5 over covered chapters.
SELECT st.student_id, st.full_name,
       ROUND(AVG(p.stage / 5.0) FILTER (WHERE p.stage >= 2), 3) AS readiness
FROM alcovia.students st
JOIN alcovia.student_chapter_progress p USING (student_id)
GROUP BY st.student_id, st.full_name
ORDER BY readiness;

-- By subject, with the cohort average beside it (advisor view)
WITH r AS (
  SELECT p.student_id, c.subject_id, AVG(p.stage / 5.0) FILTER (WHERE p.stage >= 2) AS readiness
  FROM alcovia.student_chapter_progress p JOIN alcovia.syllabus_chapters c USING (chapter_id)
  GROUP BY p.student_id, c.subject_id)
SELECT sub.name AS subject,
       ROUND(AVG(readiness) FILTER (WHERE student_id = 1), 3) AS student_1,
       ROUND(AVG(readiness), 3) AS cohort_average
FROM r JOIN alcovia.subjects sub USING (subject_id)
GROUP BY sub.name ORDER BY sub.name;
