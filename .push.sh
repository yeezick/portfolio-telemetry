#!/bin/bash
# Hourly telemetry push. Runs ONLY here. Never cd's out of this directory.
set -euo pipefail
cd "$HOME/Dev/portfolio-telemetry" || exit 0

# Refuse to run anywhere but the telemetry clone — a mis-set WorkingDirectory must not
# silently commit a project repo.
origin="$(git config --get remote.origin.url || true)"
case "$origin" in
  *portfolio-telemetry*) : ;;
  *) echo "$(date +%Y-%m-%dT%H:%M:%S%z) REFUSED: origin is '$origin', not the telemetry repo" >> .push.log; exit 2 ;;
esac

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
