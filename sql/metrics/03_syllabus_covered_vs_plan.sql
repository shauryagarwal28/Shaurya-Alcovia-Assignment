-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Progress number 1. Covered = chapters at stage 2 or higher (reading and notes done, proved by the chapter quiz).
-- Plan = 25% of the syllabus per quarter of the academic year (see alcovia.syllabus_plan).
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
SELECT st.student_id, st.full_name, st.class_level, st.board,
       COUNT(*) FILTER (WHERE p.stage >= 2)                                    AS covered_chapters,
       COUNT(*)                                                                AS total_chapters,
       ROUND(COUNT(*) FILTER (WHERE p.stage >= 2)::numeric / COUNT(*), 3)      AS covered_pct,
       ROUND(alcovia.syllabus_plan(pr.as_of), 3)                               AS plan_pct,
       ROUND((COUNT(*) FILTER (WHERE p.stage >= 2)::numeric / COUNT(*) - alcovia.syllabus_plan(pr.as_of)) * 100, 1) AS gap_pts
FROM alcovia.students st
CROSS JOIN params pr
JOIN alcovia.student_chapter_progress p USING (student_id)
GROUP BY st.student_id, st.full_name, st.class_level, st.board, pr.as_of
ORDER BY gap_pts;

-- By subject for one student (the drill-down screen)
SELECT sub.name AS subject,
       COUNT(*) FILTER (WHERE p.stage >= 2) AS covered, COUNT(*) AS total,
       ROUND(COUNT(*) FILTER (WHERE p.stage >= 2)::numeric / COUNT(*), 3) AS covered_pct
FROM alcovia.student_chapter_progress p
JOIN alcovia.syllabus_chapters c USING (chapter_id)
JOIN alcovia.subjects sub USING (subject_id)
WHERE p.student_id = 1
GROUP BY sub.name ORDER BY sub.name;
