---
name: claude-consult
description: Spawn and drive a real interactive Claude Code session (subscription auth — zero API credits) in a detached tmux session. Use for spawning a persistent steerable Claude worker, second opinions from a fresh Claude with different context, or multi-turn programmatic consults where headless `claude -p` is too lossy.
---

# Claude Consult (tmux-driven Claude Code)

Spawn a full interactive Claude Code session in a detached tmux session and drive it programmatically: send prompts, await completion, read replies, multi-turn, kill. The child is a first-class Claude Code instance — tools, skills, MCP, repo context — not a stripped API call. Works identically with Claude or any other agent as the driver.

**Billing invariant:** billing follows auth, not interactivity. With no `ANTHROPIC_API_KEY` in the child's environment, `claude` uses the keychain OAuth login (Claude subscription) — zero API credits. The helper unsets `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` for the child, so this holds even if the driver's env is polluted. Headless `claude -p` bills identically but is lossy: it returns only the final text block (text emitted before a trailing tool call is dropped), and it cannot be steered mid-run. Prefer this interactive primitive unless a pipeline structurally requires `--output-format json`.

## Primary path: the helper

`scripts/claude-tmux` (sibling to this file; symlink it onto your PATH, e.g. `~/.local/bin/claude-tmux` — non-login shells may not have it otherwise).

```bash
claude-tmux spawn <session> [dir] [extra claude flags...]
claude-tmux ask   <session> "prompt" [timeout_s]   # send, wait until idle, print reply
claude-tmux send  <session> "prompt"               # fire and forget
claude-tmux wait  <session> [timeout_s]            # block until idle (rc 1 = timeout)
claude-tmux read  <session> [lines]                # dump recent scrollback
claude-tmux kill  <session>
```

Typical consult: `spawn review-authz ~/projects/myrepo`, then `ask review-authz "Review src/lib.rs for concurrency bugs. Be specific." 900`, follow-up asks, then `kill`. Pick unique purpose-named sessions, never reuse another task's. Default timeout 600s; real repo work needs 900–1800. Model defaults to the account default; force with spawn flags: `--model opus`. For an unattended child pass `--permission-mode` flags of your choice at spawn; answer any permission dialog via raw `tmux send-keys`.

## Raw primitives (fallback / custom drivers)

```bash
tmux new-session -d -s S -x 220 -y 50 -c /work/dir \
  'env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN claude'

tmux send-keys -t S -l 'the prompt'   # -l = literal: $ " ` % & | ; survive intact
sleep 0.4
tmux send-keys -t S Enter             # MUST be a separate call — bundled Enter gets swallowed

# done-detection — TWO UI surfaces since Claude Code 2.1.x (verified 2.1.201):
# 1. Task dashboard (bare `claude` in a repo): "esc to interrupt" NEVER appears;
#    busy iff the header counter shows a nonzero "N working":
tmux capture-pane -t S -p | grep -Eq '[1-9][0-9]* working'   # rc 0 = still working
# 2. Classic chat view (opened task, `claude -c`, resumed sessions):
tmux capture-pane -t S -p | grep -q 'esc to interrupt'       # rc 0 = still working
# Robust drivers check both; idle = neither matches.

tmux capture-pane -t S -p -S -2000    # read with scrollback (replies scroll past the viewport)
tmux kill-session -t S
```

## Sharp edges (all empirically hit)

1. **Two-step send.** Text and Enter as separate `send-keys` calls with ~0.4s between, or the Enter is swallowed by the TUI. The helper retries Enter once if the child isn't busy 2s after sending.
   Corollary: a `❯ text` line pinned above the status bar can be UNSUBMITTED composer text sitting there for many minutes — an order everyone believes in flight. Submission truth is the prompt appearing in scrollback (`capture-pane -S`) followed by a spinner, never the composer view. If synthetic Enter won't take, recover with `C-u` then resend the same text.
2. **Always `-l` for prompt text.** Without it tmux interprets key names.
3. **Read scrollback, not the viewport.** Replies scroll; use `-S -2000`.
4. **Wait before polling idle.** The busy marker takes ~1–2s to appear; an instant idle-check false-positives. (Helper handles this.)
5. **Pane size matters.** Spawn with `-x 220 -y 50`; tiny default panes wrap lines and break needle-matching on the echoed prompt.
6. **Don't nest-attach.** Everything works detached from inside another tmux session; never `tmux attach` from a driver.
7. **Dashboard vs classic surface (v2.1.201).** A bare `claude` opens the task dashboard: typed prompts become background tasks, busy = nonzero "N working" (never "esc to interrupt"), and the pane shows only a one-line task summary — the full reply is inside the task view (`Enter` to open), so `ask`/`read` scrollback semantics silently degrade. For consults, spawn with an initial prompt argument (`claude "first prompt"`) to get the classic chat surface, or open the task before reading. The helper's `is_busy` matches both surfaces; reply extraction still assumes classic view.
8. **Pane markers can go blind (v2.1.206).** The child can show `✽ Hashing…` while busy, with neither `esc to interrupt` nor `N working` visible. The reliable completion oracle: spawn with a caller-assigned `--session-id`, tell the child to end its reply with an exact terminal canary string, and watch the session's JSONL for that canary in a non-sidechain assistant `end_turn` record. Tmux pane markers are diagnostic only.
9. **Canary must not match the prompt echo (v2.1.207).** The prompt naming the canary is echoed into the pane, so a single `grep -q CANARY` fires immediately and falsely. Require ≥2 scrollback occurrences (`grep -c`), and note that in dashboard mode the reply can land in an agent/task transcript rather than the main session JSONL — occurrence-count on `capture-pane -S -3000` is the robust cross-surface check.

## Verification checklist (if something smells off)

- Subscription, not API: banner shows your subscription plan and account; `env | grep -i anthropic` in the driver shows no key exported. Session alive: `tmux ls`.
- Child stuck? `claude-tmux read S 100` — look for permission dialogs, trust prompts, or auth errors; answer via `tmux send-keys`.
