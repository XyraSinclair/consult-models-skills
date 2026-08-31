#!/bin/bash
# repo-red-gate — an example PROJECT-level Stop hook that composes with
# stop-once: refuse to stop only while CLEARLY-BROKEN state exists.
#
# Division of labor: stop-once (user level) supplies the generic
# conscientiousness passes; this hook (project level, .claude/settings.json
# in the repo) blocks on nothing but deterministic red signals — a failing
# build, a red test battery. Speculative or planning-heavy work never
# blocks a stop. One nudge per stop attempt: the stop_hook_active guard
# means a genuinely stuck fix can still hand off.
#
# Replace the CHECK block with your repo's own fast, deterministic signal.

set -u
INPUT=$(cat)

# Never loop: if a prior Stop hook already forced continuation, allow stop.
if printf '%s' "$INPUT" | grep -q '"stop_hook_active":[[:space:]]*true'; then
  exit 0
fi

REPO="${CLAUDE_PROJECT_DIR:-.}"
cd "$REPO" || exit 0

REASONS=""

# --- CHECK: your deterministic red signals ---------------------------------
# Example: does the workspace compile?
# if ! cargo check -q >/tmp/stop-gate-check.log 2>&1; then
#   ERRS=$(grep -m3 -E '^error' /tmp/stop-gate-check.log)
#   REASONS="${REASONS}The workspace does not compile:\n${ERRS}\n"
# fi
# ---------------------------------------------------------------------------

if [ -n "$REASONS" ]; then
  printf '{"decision": "block", "reason": %s}\n' \
    "$(printf 'Clearly-broken state exists — fix the obvious problem before stopping (if another session owns it and is actively mid-surgery, say so explicitly and hand off instead):\n%b' "$REASONS" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
fi
exit 0
