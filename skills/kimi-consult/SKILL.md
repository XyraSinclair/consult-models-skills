---
name: kimi-consult
description: Consult Kimi reliably for long-context analysis, code review, architecture review, and diverse model perspective. `consult-kimi` is the first-class agentic path, running Kimi as an exploratory coding agent through the oh-my-pi harness via OpenRouter.
---

# Kimi Consult

`consult-kimi` (`scripts/consult-kimi`; symlink it onto your PATH) is the primary path: an agentic Kimi consult through [oh-my-pi](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent) with clean-room defaults. One lower-level wrapper sits beneath it: `kimi-omp` (`scripts/kimi-omp`) when you want direct OMP control. Use Kimi when you want a perspective from outside the Anthropic/OpenAI/Google training lineage, or a long-context exploratory agent with a different taste profile. K3 tool-calling through OMP is verified good (multi-step bash/read/find investigations with verbatim outputs and honest tool-limit reporting); trust it with agentic inspection tasks, but spot-check load-bearing numbers — one `du` figure drifted ~15% in verification. Do not hardcode a new Kimi model ID from memory; verify the current OpenRouter model slug first.

```bash
consult-kimi "question"        # recommended agentic consult
consult-kimi -i "question"     # run prompt then stay interactive
consult-kimi -c "follow-up"    # continue previous consult
consult-kimi -r latest "..."   # reopen the latest project thread
kimi-omp "question"            # lower-level OMP-backed inspection
```

What the wrapper does automatically: sources `OPENROUTER_API_KEY` from the environment or `$KIMI_OPENROUTER_ENV_FILE` (default `~/.config/consult-kimi/env`); validates the key before running (an exhausted key still returns 200 from `/auth/key` but 403s on completions, so the check inspects `limit_remaining`); defaults to `openrouter/moonshotai/kimi-k3` (1M context), low thinking, and the repo-focused tool set `read,bash,grep,glob,lsp`; disables OMP extension/rule/skill discovery unless you opt back in; attaches small repo files named in the prompt as `@file` context; keeps a wrapper-managed latest transcript per project so headless `-c` and `-r latest` stay reliable; transparently retries in an isolated OMP agent home if the primary SQLite home is locked; retries one empty successful response, then fails loudly.

## Prompting

Give the prompt an explicit context contract: SITUATION, KNOWN FACTS or PRIOR WORK, the specific QUESTION, POINTERS (files, symbols, commands) when Kimi should inspect the repo, a STOP CONDITION, and an OUTPUT CONTRACT (e.g. "3 risks ordered by severity"; "say 'agent inspection required' if you cannot ground this"). Exact repo facts need tools and tight POINTERS; broad judgment can be direct synthesis but still needs KNOWN FACTS. Omitting PRIOR WORK makes Kimi redo dead ends; omitting the OUTPUT CONTRACT invites verbose drift. If the answer will affect production or schema decisions, ask for evidence, not opinion.

For a second opinion or triangulation, demand first-principles reasoning and an
explicit challenge-to-thesis section. Compare where the framing shifts, not only
where answers agree.

Latency: tiny lookups ~5-20s, scoped file review ~20-90s, broader codebase validation ~1-4 minutes. Don't run expensive consults in parallel unless the questions are truly independent; prefer one long-lived `-c` thread over many overlapping launches.

## Flags and env knobs

| Flag | Purpose |
|------|---------|
| `-w` / `--write` | Enable edit/write tools beyond the exploratory set |
| `-i` / `--interactive` | Stay interactive after prompt |
| `--thinking high` | Increase reasoning depth |
| `--no-session` | Ephemeral consult — captures ONLY the final assistant turn; if the harness interjects mid-consult, the substantive first-turn answer is unrecoverable. Omit it for any consult whose full answer you need |
| `-c` / `-r latest` | Continue previous / latest project thread |

Env: `KIMI_CONSULT_MODEL=openrouter/moonshotai/kimi-k3`, `KIMI_CONSULT_THINKING=low|medium|high`, `KIMI_OPENROUTER_ENV_FILE=~/.config/consult-kimi/env`, `KIMI_OPENROUTER_KEY_CHECK_TIMEOUT=8`, `KIMI_CONSULT_AUTO_CONTEXT_MAX_BYTES=200000`, `PI_CODING_AGENT_DIR=/custom/omp/home`, `KIMI_CONSULT_STATE_DIR=/custom/state`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "consult-kimi: command not found" | Symlink `scripts/consult-kimi` into a PATH dir |
| "Missing or invalid OPENROUTER_API_KEY" | Set a valid key in env or the env file |
| `401 User not found` | Stale key; rotate it |
| `403 Key limit exceeded` | Key hit its OpenRouter spend limit; raise the limit or add credit |
| "database is locked" | Wrapper retries automatically; if you set `PI_CODING_AGENT_DIR`, use a distinct path per concurrent consult |
| OpenRouter rejects K3: requested 64k output exceeds key balance | Cap that model's `maxTokens` in the active agent home's `models.yml`; `--config` overlays do NOT change model metadata |
| Loose or verbose answers | Tighten POINTERS, STOP CONDITION, OUTPUT CONTRACT |
