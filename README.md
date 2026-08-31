# consult-models-skills

Three [Claude Code](https://code.claude.com/docs) skills that let a coding
agent consult other frontier models — a second Claude, Gemini, and Kimi —
from its own terminal, reliably, with the footgun doctrine we learned by
running each of them daily.

A coding agent gets better when a genuinely different mind reviews its
hardest calls. But "just shell out to the other CLI" fails in practice:
auth doesn't survive between an agent's tool calls, TUIs swallow synthetic
keystrokes, busy-detection markers change between releases, and headless
modes silently drop parts of the answer. Each skill here is the residue of
making one consult path actually dependable — a small wrapper plus the
operating doctrine an agent needs to drive it well.

## The skills

- **claude-consult** — spawn and drive a full interactive Claude Code
  session in a detached tmux session: send prompts, await completion, read
  replies, multi-turn, kill. The child is a first-class Claude Code
  instance on subscription auth (zero API credits), not a stripped API
  call. Includes the empirically-earned sharp edges: two-step Enter,
  scrollback-not-viewport reads, the two busy-detection surfaces, and the
  canary-string completion oracle for when pane markers go blind.
- **gemini-consult** — an autonomously-exploring Gemini agent over
  [gemini-cli](https://github.com/google-gemini/gemini-cli), defaulting to
  read-only plan mode, with auth sourced automatically so it works from
  non-persistent agent shells. Plus the review-session doctrine: pin a
  verified premium model, reject silent fallbacks, restart instead of
  nudging a session gone superficial.
- **kimi-consult** — an agentic Kimi K3 consult (1M context, a taste
  profile from outside the Anthropic/OpenAI/Google lineage) through the
  [oh-my-pi](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent)
  harness via OpenRouter: key validation that catches spend-exhausted keys
  before you wait on a dead consult, per-project continuation threads,
  automatic small-file attachment, and the SITUATION / QUESTION /
  POINTERS / OUTPUT CONTRACT prompting contract.

The fourth seat — GPT Pro through a background browser that never steals
focus — lives in its own repo:
[quiet-oracle](https://github.com/XyraSinclair/quiet-oracle).

## Install

```bash
git clone https://github.com/XyraSinclair/consult-models-skills
ln -s "$PWD/consult-models-skills/skills/"* ~/.claude/skills/
```

Claude Code discovers each `SKILL.md` from there. The wrappers live beside
their skills in `scripts/`; symlink the ones you want onto your PATH:

```bash
ln -s "$PWD/consult-models-skills/skills/claude-consult/scripts/claude-tmux" ~/.local/bin/
ln -s "$PWD/consult-models-skills/skills/gemini-consult/scripts/consult-gemini" ~/.local/bin/
ln -s "$PWD/consult-models-skills/skills/kimi-consult/scripts/consult-kimi" ~/.local/bin/
```

Everything also works standalone, without Claude Code — the skills are
readable doctrine, the wrappers are plain bash.

## Requirements

Per seat, only what that seat uses:

- **claude-consult**: `tmux` and a logged-in `claude` CLI.
- **gemini-consult**: `npm install -g @google/gemini-cli` and a
  `GEMINI_API_KEY` (env, or `~/.config/consult-gemini/env`).
- **kimi-consult**: the `omp` CLI
  (`bun install -g @oh-my-pi/pi-coding-agent`) and an `OPENROUTER_API_KEY`
  (env, or `~/.config/consult-kimi/env`).

## Doctrine that spans the skills

A consult's answer is input, not authority. Every skill ends the same way:
demand first-principles reasoning and an explicit challenge-to-thesis
section, compare where the framing shifts rather than only where answers
agree, and close with your own accept/reject/modify judgment.

## Credits

- [gemini-cli](https://github.com/google-gemini/gemini-cli) (Google) and
  [oh-my-pi](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent) do
  the actual agent-harness work for their seats; the wrappers here are
  reliability and doctrine layers on top.
- [OpenRouter](https://openrouter.ai) provides the metered path to Kimi K3.
- `tmux` is the whole machinery of the Claude seat — the skill is mostly
  hard-won knowledge about driving TUIs through it.

## License

[Harvest License](LICENSE.md). Free to use, copy, modify, and sell. The
one condition: at most once in any twelve months (and never in your first
180 days), the Steward can ask you what the work has been worth to you,
and you must answer honestly within 60 days. An honest zero satisfies the
license in full. Only silence is a breach.
