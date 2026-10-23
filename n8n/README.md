# n8n workflows

Nine exports. Import each with *Workflows, Import from file*. All are saved inactive.

| File | Trigger | What it does |
|---|---|---|
| `01_app_events_to_store` | Webhook | The app posts sessions and feature opens. Validated, then written to Postgres. |
| `02a_send_attendance_links` | Every 5 minutes | Sends each student a one-use link before a session. |
| `02b_mark_attendance` | Webhook | Checks the link (time window, unused, room code) and marks the student present. |
| `03_marks_photo_upload_verify` | Webhook | Reads a marks photo with an AI vision API, saves it **unverified**, and tasks the advisor to verify. |
| `04_flags_to_advisor_tasks` | Daily 7:00 | Runs the flag query, inserts new advisor tasks, and puts urgent ones in ClickUp. |
| `05_weekly_parent_summary` | Sunday 18:00 | A plain-words message per family with a link to the child's screen. |
| `06_razorpay_to_store` | Webhook | Workshop seats and paid invoices from Razorpay. |
| `07_meta_ads_weekly` | Monday 6:00 | Last 7 days of ad metrics from the Meta Marketing API. |
| `08_clickup_leads_sync` | ClickUp trigger | Stamps funnel stages on a lead when its ClickUp status changes. |
| `09_reengagement_day3_day7` | Daily 9:00 | Day 3 quiet: nudge task. Day 7 quiet: the advisor calls the parent. |

## Before you run them

Everything marked `REPLACE_...` needs a real value: the Postgres, ClickUp, WhatsApp provider, vision API and Meta credentials, ClickUp list and workspace ids, ad account id, and the app domain.

## What has and has not been checked

- **Checked:** every file is valid JSON, every connection points at a real node, and every SQL statement inside a Postgres node was run against the seeded database with sample values.
- **Not checked:** the workflows have not been run in a live n8n instance, and none of the external calls (WhatsApp, Meta, ClickUp, Razorpay, the vision API) were made. Treat them as working drafts that need a credentials pass and a first run on test data.
- The Razorpay workflow should verify the `X-Razorpay-Signature` header before trusting a payload. That step is marked in the workflow note and left for the live setup.
