-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Set family_view to true for the parent and student screens: only marks an advisor has verified are shown.
-- Set it to false for the advisor, who also sees uploads still waiting for verification.
WITH params AS (SELECT false AS family_view),
r AS (
  SELECT er.*, ROW_NUMBER() OVER (PARTITION BY student_id, subject_id ORDER BY exam_date DESC) AS rn
  FROM alcovia.exam_results er, params p
  WHERE NOT p.family_view OR er.verified_at IS NOT NULL)
SELECT st.full_name, sub.name AS subject, cur.exam_label AS latest_exam, cur.marks_pct AS latest,
       prev.marks_pct AS previous, ROUND(cur.marks_pct - prev.marks_pct, 1) AS change_pts,
       t.target_pct AS target, ROUND(cur.marks_pct - t.target_pct, 1) AS vs_target_pts,
       cur.verified_at IS NOT NULL AS verified,
       co.cohort_average
FROM r cur
JOIN (SELECT subject_id, ROUND(AVG(marks_pct), 1) AS cohort_average FROM r WHERE rn = 1 GROUP BY subject_id) co ON co.subject_id = cur.subject_id
JOIN r prev ON prev.student_id = cur.student_id AND prev.subject_id = cur.subject_id AND prev.rn = 2
JOIN alcovia.students st ON st.student_id = cur.student_id
JOIN alcovia.subjects sub ON sub.subject_id = cur.subject_id
JOIN alcovia.exam_targets t ON t.student_id = cur.student_id AND t.subject_id = cur.subject_id
WHERE cur.rn = 1 AND cur.student_id = 1
ORDER BY sub.name;
