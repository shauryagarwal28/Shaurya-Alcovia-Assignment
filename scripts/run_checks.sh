#!/usr/bin/env bash
# Loads the schema and the dummy data into a scratch database, then runs every metric query.
# Stops at the first SQL error. Needs PostgreSQL 14+ (docker compose up -d gives you one).
#   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres ./scripts/run_checks.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PSQL="${PSQL:-psql}"
URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/postgres}"
run() { "$PSQL" "$URL" -v ON_ERROR_STOP=1 -q "$@"; }

echo "Loading schema and dummy data..."
run -c "SET client_min_messages = warning; DROP SCHEMA IF EXISTS alcovia CASCADE;"
run -f db/schema.sql
run -f db/seed/seed.sql > /dev/null

for f in sql/metrics/*.sql; do
  echo; echo "== $f"
  run -f "$f"
done
echo; echo "All metric queries ran without errors."
