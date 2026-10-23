-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Revenue = invoices raised (full program, 3-month trial) + workshop seats paid for. Target is pro-rated to the window.
WITH params AS (SELECT DATE '2026-10-23' AS as_of, 30 AS window_days),
inv AS (
  SELECT COALESCE(SUM(amount_inr) FILTER (WHERE kind = 'full'), 0) AS full_program,
         COALESCE(SUM(amount_inr) FILTER (WHERE kind = 'trial'), 0) AS trial,
         COUNT(*) AS students_onboarded
  FROM alcovia.invoices i, params p WHERE i.raised_on BETWEEN p.as_of - (p.window_days - 1) AND p.as_of),
ws AS (
  SELECT COALESCE(SUM(amount_inr), 0) AS workshop, COALESCE(SUM(seats), 0) AS seats
  FROM alcovia.workshop_registrations r, params p WHERE r.paid_at::date BETWEEN p.as_of - (p.window_days - 1) AND p.as_of),
tgt AS (
  SELECT revenue_inr * p.window_days / 30.0 AS target
  FROM alcovia.revenue_targets t, params p WHERE t.month = DATE_TRUNC('month', p.as_of)::date)
SELECT inv.full_program, inv.trial, ws.workshop,
       inv.full_program + inv.trial + ws.workshop                          AS revenue,
       ROUND(tgt.target)                                                    AS target,
       ROUND((inv.full_program + inv.trial + ws.workshop) / tgt.target, 3) AS pct_of_target,
       inv.students_onboarded, ws.seats                                     AS workshop_seats
FROM inv, ws, tgt;
