-- Alcovia central store. PostgreSQL 14+.
-- One database feeds both dashboards. n8n writes to it; the app, ClickUp, Razorpay and Meta Ads are the sources.
-- Rule behind every table: nothing is typed twice, and nothing is typed by someone who was not there.

CREATE SCHEMA IF NOT EXISTS alcovia;
SET search_path = alcovia, public;

-- ---------------------------------------------------------------- people
CREATE TABLE advisors (
  advisor_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name    text NOT NULL,
  email        text UNIQUE NOT NULL
);

CREATE TABLE students (
  student_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name           text NOT NULL,
  class_level         smallint NOT NULL CHECK (class_level BETWEEN 6 AND 12),
  board               text NOT NULL CHECK (board IN ('CBSE','ICSE','IB','STATE','OTHER')),
  phone_type          text NOT NULL DEFAULT 'unknown' CHECK (phone_type IN ('own','shared','unknown')),  -- day-one sheet
  advisor_id          integer REFERENCES advisors,
  enrolled_on         date NOT NULL,
  plan                text NOT NULL CHECK (plan IN ('trial','full')),
  wearable_connected  boolean NOT NULL DEFAULT false,
  clickup_task_id     text
);

CREATE TABLE guardians (
  guardian_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id    integer NOT NULL REFERENCES students,
  full_name     text NOT NULL,
  phone         text,
  email         text,
  consent_at    timestamptz            -- written consent for a minor's data; required before any family view is shown
);

-- ---------------------------------------------------------------- syllabus and study
CREATE TABLE subjects (
  subject_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text UNIQUE NOT NULL     -- one name per subject, so "Math" and "Mathematics" cannot both exist
);

CREATE TABLE syllabus_chapters (        -- preset per board and class, loaded once (CBSE and ICSE first)
  chapter_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  board        text NOT NULL,
  class_level  smallint NOT NULL,
  subject_id   integer NOT NULL REFERENCES subjects,
  chapter_no   smallint NOT NULL,
  title        text NOT NULL,
  UNIQUE (board, class_level, subject_id, chapter_no)
);

-- stage: 0 not started, 1 reading, 2 notes done, 3 practice above 70%, 4 timed past paper, 5 exam ready (80%+)
-- "Covered" means stage >= 2. A chapter reaches stage 2 or higher when the student passes its short quiz.
CREATE TABLE student_chapter_progress (
  student_id         integer NOT NULL REFERENCES students,
  chapter_id         integer NOT NULL REFERENCES syllabus_chapters,
  stage              smallint NOT NULL DEFAULT 0 CHECK (stage BETWEEN 0 AND 5),
  practice_accuracy  numeric(5,2),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, chapter_id)
);

CREATE TABLE quiz_attempts (
  attempt_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id  integer NOT NULL REFERENCES students,
  kind        text NOT NULL CHECK (kind IN ('chapter','daily')),
  chapter_id  integer REFERENCES syllabus_chapters,      -- set for chapter quizzes
  taken_at    timestamptz NOT NULL,
  score_pct   numeric(5,2) NOT NULL,
  passed      boolean NOT NULL
);

-- ---------------------------------------------------------------- app activity (written by n8n from the app)
CREATE TABLE app_sessions (
  session_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id         integer NOT NULL REFERENCES students,
  started_at         timestamptz NOT NULL,
  kind               text NOT NULL CHECK (kind IN ('app','focus')),
  active_seconds     integer NOT NULL CHECK (active_seconds >= 0),
  -- A focus session counts only when verified: app stayed in the foreground, no long idle stretch,
  -- and the student confirmed with the one-tap check-in at the end.
  stayed_foreground  boolean,
  longest_idle_s     integer,
  checked_in         boolean,
  verified           boolean GENERATED ALWAYS AS (
                       kind = 'focus' AND COALESCE(stayed_foreground,false)
                       AND COALESCE(longest_idle_s,0) <= 300 AND COALESCE(checked_in,false)) STORED
);
CREATE INDEX ON app_sessions (student_id, started_at);

CREATE TABLE app_feature_events (       -- one row per feature area opened, for the adoption view
  event_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id   integer NOT NULL REFERENCES students,
  feature      text NOT NULL CHECK (feature IN ('home','focus_game','study','plan','wellness','other')),
  occurred_at  timestamptz NOT NULL
);
CREATE INDEX ON app_feature_events (occurred_at, feature);

CREATE TABLE student_tasks (            -- the app's existing to-do list
  task_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id    integer NOT NULL REFERENCES students,
  title         text NOT NULL,
  source        text NOT NULL CHECK (source IN ('advisor','self')),
  due_on        date,
  completed_at  timestamptz
);

CREATE TABLE dashboard_views (          -- families opening their dashboard
  view_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id  integer NOT NULL REFERENCES students,
  role        text NOT NULL CHECK (role IN ('parent','student')),
  opened_at   timestamptz NOT NULL
);

-- ---------------------------------------------------------------- program delivery
CREATE TABLE program_events (
  event_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_type     text NOT NULL CHECK (event_type IN ('adv','ws','pod','peer','mentor','pc')),
  title          text NOT NULL,
  scheduled_at   timestamptz NOT NULL,
  held           boolean NOT NULL DEFAULT true,       -- false = cancelled by Alcovia, never counted against a student
  student_id     integer REFERENCES students          -- set for one-to-one events (advisor session, mentor call)
);
CREATE INDEX ON program_events (scheduled_at, event_type);

CREATE TABLE event_attendance (
  event_id    integer NOT NULL REFERENCES program_events,
  student_id  integer NOT NULL REFERENCES students,
  attended    boolean NOT NULL,
  marked_via  text NOT NULL CHECK (marked_via IN ('link','meeting_export','facilitator')),
  rating      smallint CHECK (rating BETWEEN 1 AND 5),   -- one tap by the student, team-only
  skills      jsonb,                                       -- facilitator scorecard at workshops, each skill 1 to 5
  PRIMARY KEY (event_id, student_id)
);

CREATE TABLE attendance_links (         -- time-limited, one per student per session
  link_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id        integer NOT NULL REFERENCES program_events,
  student_id      integer NOT NULL REFERENCES students,
  token           text UNIQUE NOT NULL,
  opens_at        timestamptz NOT NULL,
  closes_at       timestamptz NOT NULL,
  room_code_hash  text,                  -- sha256 (hex) of the code shown in the room, for in-person sessions
  used_at         timestamptz
);

-- ---------------------------------------------------------------- exams and marks
CREATE TABLE exam_targets (
  student_id  integer NOT NULL REFERENCES students,
  subject_id  integer NOT NULL REFERENCES subjects,
  target_pct  numeric(5,2) NOT NULL,     -- set with the family, reviewed monthly
  PRIMARY KEY (student_id, subject_id)
);

CREATE TABLE exam_results (
  result_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id    integer NOT NULL REFERENCES students,
  subject_id    integer NOT NULL REFERENCES subjects,
  exam_label    text NOT NULL,           -- Formative 1, Unit test 1, Mid-term, Half-yearly
  exam_date     date NOT NULL,
  marks_pct     numeric(5,2) NOT NULL,
  uploaded_at   timestamptz NOT NULL DEFAULT now(),
  verified_at   timestamptz,             -- NULL until an advisor checks it; families never see unverified marks
  verified_by   integer REFERENCES advisors
);

CREATE TABLE upcoming_exams (           -- from the date sheet the family uploads
  student_id  integer NOT NULL REFERENCES students,
  subject_id  integer NOT NULL REFERENCES subjects,
  exam_date   date NOT NULL,
  PRIMARY KEY (student_id, subject_id, exam_date)
);

-- ---------------------------------------------------------------- advisor work
CREATE TABLE advisor_tasks (            -- an action queue: things the advisor must do about students
  advisor_task_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  advisor_id       integer NOT NULL REFERENCES advisors,
  student_id       integer NOT NULL REFERENCES students,
  flag_code        text NOT NULL,
  detail           text NOT NULL,
  urgency          smallint NOT NULL CHECK (urgency BETWEEN 1 AND 3),
  created_at       timestamptz NOT NULL DEFAULT now(),
  done_at          timestamptz,
  clickup_task_id  text,
  UNIQUE (student_id, flag_code, detail)
);

CREATE TABLE advisor_review_log (       -- weekly review, one student at a time
  review_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  advisor_id    integer NOT NULL REFERENCES advisors,
  student_id    integer NOT NULL REFERENCES students,
  reviewed_on   date NOT NULL,
  prep_minutes  smallint NOT NULL
);

-- ---------------------------------------------------------------- go-to-market
CREATE TABLE campaigns (
  campaign_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         text NOT NULL,
  kind         text NOT NULL CHECK (kind IN ('program','workshop')),
  landing_page text NOT NULL
);

CREATE TABLE ad_assets (
  asset_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id  integer NOT NULL REFERENCES campaigns,
  name         text NOT NULL
);

CREATE TABLE ad_daily_metrics (         -- weekly Meta Ads pull, stored per day
  day          date NOT NULL,
  asset_id     integer NOT NULL REFERENCES ad_assets,
  impressions  integer NOT NULL,
  clicks       integer NOT NULL,
  spend_inr    numeric(12,2) NOT NULL,
  frequency    numeric(5,2) NOT NULL,   -- how often the same person saw the ad; 3 or more means change it
  PRIMARY KEY (day, asset_id)
);

CREATE TABLE landing_page_daily (
  day         date NOT NULL,
  page        text NOT NULL,
  visits      integer NOT NULL,
  leads       integer NOT NULL,
  avg_load_s  numeric(4,1) NOT NULL,
  PRIMARY KEY (day, page)
);

-- One row per lead. Stage timestamps are filled by n8n as the ClickUp task moves through the funnel.
CREATE TABLE leads (
  lead_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at         timestamptz NOT NULL,
  source             text NOT NULL CHECK (source IN ('meta','organic','referral','school')),  -- tagged on entry, or CPL is a guess
  campaign_id        integer REFERENCES campaigns,
  qualified_at       timestamptz,
  discovery_set_at   timestamptz,
  discovery_held_at  timestamptz,
  ambition_held_at   timestamptz,
  architect_held_at  timestamptz,
  signed_up_at       timestamptz,
  signup_type        text CHECK (signup_type IN ('trial','full')),
  dropped_at         timestamptz,
  student_id         integer REFERENCES students,
  clickup_task_id    text
);
CREATE INDEX ON leads (created_at);

CREATE TABLE invoices (                 -- Razorpay
  invoice_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id    integer REFERENCES students,
  lead_id       bigint REFERENCES leads,
  kind          text NOT NULL CHECK (kind IN ('full','trial')),
  amount_inr    numeric(12,2) NOT NULL,
  raised_on     date NOT NULL,
  due_on        date NOT NULL,
  paid_on       date,
  razorpay_ref  text
);

CREATE TABLE workshop_events (
  workshop_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  held_on      date NOT NULL,
  capacity     integer NOT NULL DEFAULT 60,
  price_inr    numeric(10,2) NOT NULL DEFAULT 3999
);

CREATE TABLE workshop_registrations (   -- Razorpay, fortnightly workshop
  registration_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  workshop_id      integer NOT NULL REFERENCES workshop_events,
  campaign_id      integer REFERENCES campaigns,
  seats            integer NOT NULL,
  amount_inr       numeric(12,2) NOT NULL,
  paid_at          timestamptz NOT NULL,
  razorpay_ref     text
);

CREATE TABLE trial_renewals (
  student_id      integer PRIMARY KEY REFERENCES students,
  trial_ends_on   date NOT NULL,
  renewed_on      date
);

CREATE TABLE revenue_targets (
  month         date PRIMARY KEY,        -- first day of the month
  revenue_inr   numeric(12,2) NOT NULL,
  students      integer NOT NULL
);

-- Thresholds for the campaign calls live in data, so they can be set from real results without a code change.
CREATE TABLE gtm_rules (
  rule   text PRIMARY KEY,
  value  numeric NOT NULL
);
INSERT INTO gtm_rules VALUES
  ('drop_below_roas', 1.0),       -- returns under Rs 1 per Rs 1 spent: drop
  ('scale_roas', 3.0),            -- Rs 3 or more per Rs 1 with healthy frequency: scale
  ('refresh_frequency', 3.0),     -- frequency 3 or more: refresh the creative
  ('refresh_min_ctr', 0.009),     -- click rate under 0.9%: refresh
  ('min_window_days', 30);        -- fewer days than this is too thin to move budget

-- Plan for syllabus coverage: 25% of the syllabus per quarter of the academic year (April to March).
CREATE OR REPLACE FUNCTION syllabus_plan(as_of date) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT LEAST(1.0, ((as_of - make_date(
           CASE WHEN EXTRACT(month FROM as_of) >= 4 THEN EXTRACT(year FROM as_of)::int ELSE EXTRACT(year FROM as_of)::int - 1 END,
           4, 1))::numeric / 365.0) )
$$;
