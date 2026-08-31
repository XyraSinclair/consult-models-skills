#!/bin/bash
# stop-once — a budgeted conscientiousness pass for Claude Code sessions.
#
# When the model tries to end its turn, grant up to STOP_BUDGET (default 3)
# continuation passes per user prompt — "finish anything clearly in scope,
# then a short digest" — and honor the stop at the fixed point: a pass that
# made no mutating tool call changed nothing, so another nudge would only
# repeat itself.
#
# Safety properties:
#   * A stop with stop_hook_active=true is always honored — no loops, ever.
#   * The budget counts ALL stop events, including background wakes from
#     task notifications; only a genuine user prompt resets it
#     (budget-reset.sh filters synthetic notification-shaped prompts,
#     which do fire UserPromptSubmit).
#   * A turn whose final action was ScheduleWakeup is honored immediately:
#     the harness ends such turns without re-invoking the model, so a
#     block could never be acted on.
#   * Every scan failure fails open toward granting the pass — degraded
#     means "one extra nudge", never "stuck".
#
# Config:
#   STOP_ONCE=0             kill switch
#   STOP_BUDGET=N           max passes per user prompt (default 3)
#   STOP_BOOKKEEPING_RE=…   Python regex; Bash tool calls whose input
#                           matches do NOT count as work in the fixed-point
#                           scan. Point it at any end-of-turn ritual your
#                           own instructions mandate (status renders, log
#                           stamps) — otherwise the ritual reads as "still
#                           working" and burns the whole budget every turn.
#
# State: ${XDG_STATE_HOME:-~/.local/state}/stop-once/<session_id>
#   holds "count offset" — passes granted this prompt, and the transcript
#   byte offset where the fixed-point scan starts.

input=$(cat)
[ "${STOP_ONCE:-1}" = "0" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

# Never loop.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

# Sleeping stop: if the turn ended with ScheduleWakeup, the model will not
# be re-invoked — honor the stop. The final assistant event is often not
# yet flushed to the transcript when this hook runs, so re-read the tail
# for up to ~4s before concluding it was something else.
if [ -n "$tp" ] && [ -r "$tp" ]; then
  lasttool=$(python3 - "$tp" <<'PY' 2>/dev/null
import json, sys, time
def last_tool(path):
    last = ''
    with open(path, 'rb') as fh:
        try: fh.seek(-300000, 2)
        except OSError: fh.seek(0)
        for raw in fh:
            try: e = json.loads(raw)
            except Exception: continue
            if e.get('type') == 'assistant':
                for b in (e.get('message') or {}).get('content') or []:
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        last = b.get('name') or last
    return last
deadline = time.time() + 4.0
while True:
    lt = last_tool(sys.argv[1])
    if lt == 'ScheduleWakeup' or time.time() >= deadline:
        print(lt); break
    time.sleep(0.5)
PY
)
  [ "$lasttool" = "ScheduleWakeup" ] && exit 0
fi

[ -z "$sid" ] && exit 0

budget=${STOP_BUDGET:-3}
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/stop-once"
mkdir -p "$state_dir"
state_file="$state_dir/$sid"
count=0
offset=""
{ read -r count offset < "$state_file"; } 2>/dev/null
case "$count" in (''|*[!0-9]*) count=0;; esac
case "$offset" in (''|*[!0-9]*) offset="";; esac
[ "$count" -ge "$budget" ] && exit 0

# Fixed point: since the last granted pass, did any tool call mutate
# anything? Only an explicit clean scan ("0") settles; failure grants the
# pass.
if [ "$count" -ge 1 ] && [ -n "$offset" ] && [ -n "$tp" ] && [ -r "$tp" ]; then
  mutated=$(BOOKKEEPING_RE="${STOP_BOOKKEEPING_RE:-}" python3 - "$tp" "$offset" <<'PY' 2>/dev/null
import json, os, re, sys
tp, off = sys.argv[1], int(sys.argv[2])
MUT = {'Edit', 'Write', 'NotebookEdit', 'Agent', 'Workflow', 'Bash'}
pat = os.environ.get('BOOKKEEPING_RE') or ''
try:
    book = re.compile(pat) if pat else None
except re.error:
    book = None
mut = 0
with open(tp, 'rb') as fh:
    fh.seek(off)
    for raw in fh:
        try:
            e = json.loads(raw)
        except Exception:
            continue
        if e.get('type') != 'assistant':
            continue
        for b in (e.get('message') or {}).get('content') or []:
            if not (isinstance(b, dict) and b.get('type') == 'tool_use'):
                continue
            name = b.get('name') or ''
            if name not in MUT:
                continue
            if name == 'Bash' and book and book.search(json.dumps(b.get('input') or {})):
                continue
            mut = 1
            break
        if mut:
            break
print(mut)
PY
)
  [ "$mutated" = "0" ] && exit 0
fi

size=$(wc -c < "$tp" 2>/dev/null | tr -d '[:space:]')
case "$size" in (''|*[!0-9]*) size=0;; esac
printf '%s %s' "$((count + 1))" "$size" > "$state_file"

# Identical wording every pass, by design: each pass re-asks the same
# questions, so a fresh look can catch what the last pass rationalized.
reason="Pass $((count + 1))/$budget: finish clearly-in-scope work if any obviously remains; reassess anything you deferred to the user that you have the context to decide yourself. Then a short digest — verdict first; one line (or one word) if nothing changed since the last pass."

jq -n --arg r "$reason" '{decision: "block", suppressOutput: true, reason: $r}'
exit 0
