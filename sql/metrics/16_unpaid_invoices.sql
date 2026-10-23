-- Change as_of and window_days in the params CTE. All times are read in IST.
-- Invoices generated but not paid, oldest first.
WITH params AS (SELECT DATE '2026-10-23' AS as_of)
SELECT i.invoice_id, i.kind, i.amount_inr, i.raised_on, i.due_on,
       CASE WHEN i.due_on < p.as_of THEN (p.as_of - i.due_on) || ' days overdue' ELSE 'due in ' || (i.due_on - p.as_of) || ' days' END AS status
FROM alcovia.invoices i, params p
WHERE i.paid_on IS NULL
ORDER BY i.due_on;
