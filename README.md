# Shaurya Alcovia Assignment

Take-home for the Product, Systems and Analytics Lead role at Alcovia. The write-up is in [`docs/Approach_and_Execution_Plan.pdf`](docs/Approach_and_Execution_Plan.pdf). This repo holds the working parts behind it.

## Live dashboards

Interactive prototypes. They run in the browser on invented data, with no backend.

| Dashboard | Link |
|---|---|
| Student progress (Problem 4): advisor, parent, student and team views | https://shauryagarwal28.github.io/Shaurya-Alcovia-Assignment/dashboards/student_dashboard.html |
| GTM tracker (Problem 2): revenue, funnel, campaigns, campaign calls | https://shauryagarwal28.github.io/Shaurya-Alcovia-Assignment/dashboards/gtm_tracker.html |
| Landing page for both | https://shauryagarwal28.github.io/Shaurya-Alcovia-Assignment/ |

Tips: the student dashboard has buttons at the top to switch between Advisor, Parent, Student and Team, and a Week, Month, Quarter period. The GTM tracker has a timeline selector that changes every number.

## What is in this repo

| Path | What it is |
|---|---|
| [`dashboards/`](dashboards) | The two dashboards, one self-contained HTML file each. |
| [`db/schema.sql`](db/schema.sql) | The central Postgres store: 31 tables for students, syllabus, activity, delivery, marks, advisor work, leads, ads and invoices. |
| [`db/seed/`](db/seed) | A generator and its output: 20 students, 90 days of activity, 740 leads, campaigns, invoices. All invented. |
| [`sql/metrics/`](sql/metrics) | 18 queries, one per KPI in the write-up. |
| [`n8n/`](n8n) | 9 exported workflows that fill the store and act on it. |
| [`docs/`](docs) | The write-up, an architecture diagram, and a map from each metric to its query and screen. |
| [`scripts/run_checks.sh`](scripts/run_checks.sh) | Loads the schema and data and runs every query. |

## How the pieces fit

n8n receives events from the app, the family, ClickUp, Razorpay and Meta Ads, and writes them to one Postgres store. The metric queries read from it. Other workflows turn the same queries into advisor tasks and a weekly parent message. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`docs/METRICS.md`](docs/METRICS.md).

## Run the SQL yourself

```bash
docker compose up -d                 # a throwaway Postgres 16
./scripts/run_checks.sh              # loads schema and data, runs all 18 queries, stops on any error
```

Or point it at any Postgres 14+: `DATABASE_URL=postgresql://user:pass@host/db ./scripts/run_checks.sh`. To rebuild the dummy data: `python3 db/seed/generate_seed.py`.

## What is real, and what is not

Being clear about this matters more than looking complete.

- **Tested:** the schema and seed load into a real PostgreSQL, all 18 metric queries run and return sensible results, and every SQL statement inside the n8n workflows was run against that database with sample values.
- **Not run:** the n8n workflows have not been executed in a live n8n instance, and none of the outside calls (WhatsApp, Meta, ClickUp, Razorpay, the AI vision API) were made. They need credentials and a first run on test data.
- **The dashboards do not read from the database.** They compute the same measures in the browser from separate invented data, so the numbers on screen differ from what the queries return. The definitions are the same. Wiring the dashboards to the store is the first thing I would build next.
- **All data is dummy.** Prices, targets and campaign thresholds are placeholders, apart from the ₹3,999 workshop seat from the brief.
