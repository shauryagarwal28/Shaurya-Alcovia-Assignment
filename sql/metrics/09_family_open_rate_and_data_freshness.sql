-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Two of the three success metrics.
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
-- Weekly family open rate: share of students whose family opened the dashboard in the last 7 days
SELECT ROUND(COUNT(DISTINCT v.student_id)::numeric / (SELECT COUNT(*) FROM alcovia.students), 3) AS weekly_family_open_rate
FROM alcovia.dashboard_views v, params p
WHERE (v.opened_at AT TIME ZONE 'Asia/Kolkata')::date > p.as_of - 7;

-- Chapters updated within 7 days: of the chapters in progress (stage 1 to 4), how many were touched this week.
-- If this falls, logging has slipped and the numbers are going stale.
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
SELECT ROUND(COUNT(*) FILTER (WHERE (p.updated_at AT TIME ZONE 'Asia/Kolkata')::date > pr.as_of - 7)::numeric / COUNT(*), 3) AS chapters_updated_within_7_days,
       COUNT(*) AS chapters_in_progress
FROM alcovia.student_chapter_progress p, params pr
WHERE p.stage BETWEEN 1 AND 4;
