-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Scale, Refresh, Hold or Drop for each campaign. Thresholds come from alcovia.gtm_rules, so they can be set from real results.
-- Uses at least min_window_days of data even if a shorter window is requested: 7 days is too thin to move ad budget.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days),
rule AS (SELECT MAX(value) FILTER (WHERE rule='drop_below_roas') AS drop_roas, MAX(value) FILTER (WHERE rule='scale_roas') AS scale_roas,
                MAX(value) FILTER (WHERE rule='refresh_frequency') AS refresh_freq, MAX(value) FILTER (WHERE rule='refresh_min_ctr') AS min_ctr,
                MAX(value) FILTER (WHERE rule='min_window_days') AS min_days FROM alcovia.gtm_rules),
win AS (SELECT p.as_of, GREATEST(p.window_days, r.min_days::int) AS days FROM params p, rule r),
ads AS (
  SELECT c.campaign_id, SUM(m.spend_inr) AS spend, SUM(m.impressions) AS impressions, SUM(m.clicks) AS clicks,
         MAX(af.avg_freq) AS max_frequency
  FROM alcovia.campaigns c
  JOIN alcovia.ad_assets a USING (campaign_id)
  JOIN alcovia.ad_daily_metrics m USING (asset_id), win w,
  LATERAL (SELECT AVG(m2.frequency) AS avg_freq FROM alcovia.ad_daily_metrics m2
           WHERE m2.asset_id = a.asset_id AND m2.day BETWEEN w.as_of - (w.days - 1) AND w.as_of) af
  WHERE m.day BETWEEN w.as_of - (w.days - 1) AND w.as_of
  GROUP BY c.campaign_id),
rev AS (
  SELECT c.campaign_id,
         COALESCE((SELECT SUM(i.amount_inr) FROM alcovia.leads l JOIN alcovia.invoices i ON i.lead_id = l.lead_id, win w
                   WHERE l.campaign_id = c.campaign_id AND i.raised_on BETWEEN w.as_of - (w.days - 1) AND w.as_of), 0)
       + COALESCE((SELECT SUM(r.amount_inr) FROM alcovia.workshop_registrations r, win w
                   WHERE r.campaign_id = c.campaign_id AND r.paid_at::date BETWEEN w.as_of - (w.days - 1) AND w.as_of), 0) AS revenue
  FROM alcovia.campaigns c)
SELECT c.name, c.kind, ROUND(ads.spend) AS spend_inr,
       ROUND(ads.clicks::numeric / ads.impressions, 4)           AS ctr,
       ROUND(ads.max_frequency, 1)                               AS frequency,
       ROUND(rev.revenue / ads.spend, 2)                         AS return_per_rupee,
       CASE WHEN rev.revenue / ads.spend < r.drop_roas                          THEN 'Drop'
            WHEN ads.max_frequency >= r.refresh_freq OR ads.clicks::numeric / ads.impressions < r.min_ctr THEN 'Refresh'
            WHEN rev.revenue / ads.spend >= r.scale_roas                        THEN 'Scale'
            ELSE 'Hold' END                                      AS call
FROM alcovia.campaigns c JOIN ads USING (campaign_id) JOIN rev USING (campaign_id), rule r
ORDER BY CASE WHEN rev.revenue / ads.spend < r.drop_roas THEN 4 WHEN ads.max_frequency >= r.refresh_freq OR ads.clicks::numeric / ads.impressions < r.min_ctr THEN 2
              WHEN rev.revenue / ads.spend >= r.scale_roas THEN 1 ELSE 3 END, c.name;
