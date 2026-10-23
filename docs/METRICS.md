# Metrics, queries and screens

Each KPI in the write-up has one query in `sql/metrics/`. The dashboards compute the same measures in the browser from invented data, so their numbers differ from the seeded database. The definitions are identical.

| Measure | Query | Where it shows |
|---|---|---|
| Engaged minutes per student per day (main metric) | `01_engaged_minutes_per_student_per_day.sql` | Team view, Engagement |
| Weekly active students, regular focus users | `02_weekly_active_and_regular_focus_users.sql` | Team view, first screen |
| Syllabus covered against plan | `03_syllabus_covered_vs_plan.sql` | Student and parent: Progress. Advisor: students list |
| Chapter readiness | `04_chapter_readiness.sql` | Student and parent: Progress |
| Attendance rate | `05_attendance_rate.sql` | Participation |
| Exam trend against target (verified only for families) | `06_exam_trend_vs_target.sql` | Exam trend |
| Advisor flags | `07_advisor_flags.sql` | Advisor: reasons behind each task |
| Advisor tasks, top 5 and at most 2 per student | `08_advisor_tasks_from_flags.sql` | Advisor: first screen |
| Weekly family open rate, chapters updated within 7 days | `09_family_open_rate_and_data_freshness.sql` | Success metrics |
| Advisor review prep time | `10_advisor_review_prep_time.sql` | Success metrics |
| Program scorecard: quantity and quality | `11_program_scorecard.sql` | Team view, Delivery and feedback |
| Feature adoption | `12_feature_adoption.sql` | Team view, Adoption |
| Revenue against target | `13_revenue_vs_target.sql` | GTM: Overview, Revenue |
| Funnel, cost per qualified lead, conversion | `14_funnel_and_cost_per_qualified_lead.sql` | GTM: Funnel |
| Scale, Refresh, Hold, Drop | `15_campaign_calls.sql` | GTM: What to do (RCA) |
| Unpaid invoices | `16_unpaid_invoices.sql` | GTM: Revenue |
| Trial renewals and risk | `17_trial_renewals_upcoming.sql` | GTM: Revenue |
| Landing page health | `18_landing_page_health.sql` | GTM: Campaigns |

Change `as_of` and `window_days` in the `params` CTE at the top of each file.
