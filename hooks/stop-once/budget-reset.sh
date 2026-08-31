#!/bin/bash
# budget-reset — UserPromptSubmit hook, the other half of stop-once.
#
# Resets the stop-once continuation budget at each REAL user prompt.
# Background wakes DO fire UserPromptSubmit: a task-notification turn
# carries the same event, and an unfiltered reset re-arms the blocks on
# every wake — the model then gets nudged forever. Synthetic prompts are
# filtered here by their fixed markers.

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
case "$prompt" in
  *"[SYSTEM NOTIFICATION - NOT USER INPUT]"*|*"<task-notification>"*) exit 0;;
esac
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
d="${XDG_STATE_HOME:-$HOME/.local/state}/stop-once"
mkdir -p "$d"
[ -n "$sid" ] && printf '0' > "$d/$sid"
find "$d" -type f -mtime +7 -delete 2>/dev/null
exit 0
