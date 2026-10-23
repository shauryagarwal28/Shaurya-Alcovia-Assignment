-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Lead to sign-up, for leads created in the window. Show-up rate = held / set. Drop-off = ambition interviews lost after the discovery call.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days),
l AS (SELECT * FROM alcovia.leads x, params p WHERE x.created_at::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of),
spend AS (
  SELECT COALESCE(SUM(m.spend_inr), 0) AS paid_program_spend
  FROM alcovia.ad_daily_metrics m JOIN alcovia.ad_assets a USING (asset_id) JOIN alcovia.campaigns c USING (campaign_id), params p
  WHERE c.kind = 'program' AND m.day BETWEEN p.as_of - (p.window_days - 1) AND p.as_of)
SELECT COUNT(*)                                   AS total_leads,
       COUNT(*) FILTER (WHERE source <> 'meta')   AS organic_leads,
       COUNT(qualified_at)                        AS qualified,
       COUNT(discovery_set_at)                    AS discovery_set,
       COUNT(discovery_held_at)                   AS discovery_held,
       COUNT(ambition_held_at)                    AS ambition_interview,
       COUNT(architect_held_at)                   AS architect_session,
       COUNT(signed_up_at)                        AS signed_up,
       ROUND(COUNT(discovery_held_at)::numeric / NULLIF(COUNT(discovery_set_at), 0), 3)       AS show_up_rate,
       ROUND(1 - COUNT(ambition_held_at)::numeric / NULLIF(COUNT(discovery_held_at), 0), 3)   AS ambition_drop_off,
       ROUND(COUNT(signed_up_at)::numeric / NULLIF(COUNT(qualified_at), 0), 3)                AS program_conversion,
       ROUND((SELECT paid_program_spend FROM spend) / NULLIF(COUNT(qualified_at) FILTER (WHERE source = 'meta'), 0)) AS cost_per_qualified_lead_inr,
       ROUND(AVG(EXTRACT(EPOCH FROM signed_up_at - created_at) / 86400)::numeric, 1)          AS avg_days_lead_to_signup
FROM l;
