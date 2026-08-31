---
name: gemini-consult
description: "Consult Gemini reliably for math, algorithms, formal reasoning, frontend design, and UI/UX reviews. Uses a local wrapper that sources auth automatically and defaults to read-only plan mode; resolve the current premium model before pinning one."
---

# Gemini Consult

Spawn a Gemini agent that autonomously explores the codebase to answer your question — it reads files, greps, and navigates the project on its own. Strengths: math, algorithms, formal reasoning, frontend and visual work.

Always use the wrapper; never call `gemini` directly from shell automation. Shell state does not persist reliably between an agent's tool calls, so direct invocations are the #1 cause of auth failures.

```bash
consult-gemini -p "<prompt>"
```

The wrapper (`scripts/consult-gemini`; symlink it onto your PATH) sources `GEMINI_API_KEY` from `$GEMINI_ENV_FILE` (default `~/.config/consult-gemini/env`) if the key is not already in the environment, and defaults to `--approval-mode plan` for safe read-only consultations. It intentionally does not pin a model: check Google's current lineup and pass `--model <current-model>` when model tier matters.

Give the agent a task, not a pre-assembled prompt: what you're working on, what you've already tried, the specific question, and file/function pointers if you know them. It reads files itself.

Sessions save automatically per project:

```bash
consult-gemini --resume latest     # resume most recent session
consult-gemini --list-sessions     # list saved sessions
consult-gemini --resume 3          # resume by index
consult-gemini -i "..."            # run prompt, then stay interactive
```

Use `-i` instead of `-p` when you expect follow-ups. Other flags: `--model <m>` to pin a live-verified model, `--include-directories <dirs>` to widen scope, `--yolo` auto-approve (only with explicit user permission).

## Review-session safeguards

When review quality depends on model tier, resolve a current premium Gemini model, pass it explicitly with `--model`, and disable automatic routing in `~/.gemini/settings.json` for that session. Check the CLI output for any fallback notice and reject a review served by a cheaper tier. After 2–3 explore passes on the same codebase, reviews tend to become superficial narration, so start a fresh session rather than continuing to nudge the old one.

For a second opinion or triangulation, demand first-principles reasoning and an
explicit challenge-to-thesis section. Compare where the framing shifts, not only
where answers agree.

Troubleshooting: "gemini: command not found" → `npm install -g @google/gemini-cli`. "API key not found" → set `GEMINI_API_KEY` (env or the env file) and use the wrapper. Agent seems lost → run from the relevant subdirectory or pass `--include-directories`. Wrong-model error → pass `--model <supported-model>` explicitly.
