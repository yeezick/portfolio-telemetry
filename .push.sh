#!/bin/bash
# Hourly telemetry push. Runs ONLY here. Never cd's out of this directory.
set -euo pipefail
cd "$HOME/Dev/portfolio-telemetry" || exit 0

# Refuse to run anywhere but the telemetry clone — a mis-set WorkingDirectory must not
# silently commit a project repo.
# A git that cannot run (e.g. Apple's git behind an unaccepted Xcode licence) is a failure to
# report, not an empty origin: log its first stderr line and stop non-zero.
if ! origin="$(git remote get-url origin 2>&1)"; then
  echo "$(date +%Y-%m-%dT%H:%M:%S%z) GIT FAILED: $(printf '%s\n' "$origin" | head -n 1)" >> .push.log
  exit 3
fi
case "$origin" in
  *portfolio-telemetry*) : ;;
  *) echo "$(date +%Y-%m-%dT%H:%M:%S%z) REFUSED: origin is '$origin', not the telemetry repo" >> .push.log; exit 2 ;;
esac

# Pusher heartbeat for /health (DEC-066). Rewritten on every tick that passes the origin check,
# so every healthy tick commits and pushes. Schema and time only — this repo is public.
pushed_at="$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')"
printf '{"schema":"heartbeat/v1","pushed_at":"%s"}\n' "$pushed_at" > _heartbeat.json.tmp
mv _heartbeat.json.tmp _heartbeat.json

# Only generated payloads are ever committed. Anything else a stray process drops here is
# left alone rather than published.
git add -- '*.json' '*.events.ndjson' 2>/dev/null || true
if git diff --cached --quiet; then
  echo "$(date +%Y-%m-%dT%H:%M:%S%z) clean" >> .push.log
  exit 0
fi
files="$(git diff --cached --name-only | tr '\n' ' ')"
git -c user.name="telemetry-push" -c user.email="noreply@erickmanrique.com" \
    commit -q -m "telemetry: ${files}"
if git push -q origin HEAD 2>>.push.log; then
  echo "$(date +%Y-%m-%dT%H:%M:%S%z) pushed ${files}" >> .push.log
else
  echo "$(date +%Y-%m-%dT%H:%M:%S%z) PUSH FAILED (committed locally; will retry next hour)" >> .push.log
fi
