-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Third success metric: minutes an advisor spends preparing one weekly student review. It should fall once the dashboard is live.
SELECT a.full_name AS advisor, DATE_TRUNC('month', l.reviewed_on)::date AS month,
       COUNT(*) AS reviews, ROUND(AVG(l.prep_minutes), 1) AS avg_prep_minutes
FROM alcovia.advisor_review_log l JOIN alcovia.advisors a USING (advisor_id)
GROUP BY a.full_name, 2 ORDER BY 2, 1;
