# ZenEdge fusion harness — CSV-import hardening loop

This fork of [disler/fusion-harness](https://github.com/disler/fusion-harness) (branch `zenedge`, upstream tracked as `upstream`) adds a ZenEdge layer on top of Dan's Pi extension. The extension code under `extensions/` is untouched; everything ZenEdge lives in `zenedge/`, `.pi/fusion-harness/model-stack-zenedge*.yaml`, `ai_docs/`, and the `zen-*` recipes in the `justfile`.

First job: multi-model, multi-provider red-team and remediation of the zenedge-backend broker CSV import pipeline (`routers/trade_import/`), replacing the copy-paste loop between K3, GLM and Codex terminals that judged waves w1–w2.

## The stack

| Slot | Model | Role | Billing |
|---|---|---|---|
| `sol` | `openai-codex/gpt-5.6-sol` xhigh | ARCHITECT: validator, fusion writer, plan merger | ChatGPT Pro plan |
| `glm` | `zai/glm-5.3` high | primary/Main: raw-chat host and `/fh-auto-validate` builder | z.ai coding plan |
| `k3` | `kimi-coding/k3` medium | builder; Main of the attack stack (it ran w1–w2) | Kimi coding plan |
| `deep` | `deepseek/<catalog id>` | builder | API key — the one granted metered exception (`~/code/AGENTS.md`) |
| `terra` | `openai-codex/gpt-5.6-terra` (5-slot stack only) | builder | ChatGPT Pro plan |

No Fable slot. Pi can log into Claude Max, but pi's docs state third-party harness use bills to Anthropic extra usage per token, and we do not risk the Anthropic accounts. Fable runs outside the loop in Claude Code, reviewing `/tmp/fusion-harness-*` artifacts. To add it later: `pi` → `/login` → Claude, then one `fable` architect slot in the YAML.

Children are spawned `--no-extensions --no-context-files`, so `AGENTS.md` never reaches them. Every slot appends Dan's communication contract plus a rules file: `zenedge/prompts/ZENEDGE_HOUSE_RULES.md` (defend) or `zenedge/prompts/ZENEDGE_ATTACK_RULES.md` (attack). The attack stack never sees the defend rules, which point at the implementation map.

## Two launch surfaces

```
just zen-attack     cwd = ~/code/options-red-teaming        blind pack: BRIEF, specs, outbox, verdicts
just zen-defend     cwd = ~/code/zenedge-backend-fusion     worktree on feat/fusion-csv-import-hardening
```

Writer leases are cwd-scoped, so both can run at once. Override with `ZEN_WT=… ZEN_PACK=…`.

## The loop

```
zen-preflight ──▶ zen-defend ─▶ /fh-opinion  (01)  four defect lists
                              ─▶ /fh-debate   (02)  which class leads
                              ─▶ /fh-fusion   (03)  ATTACK_PLAN_w3.md  → redteam-harness/_private/
              ──▶ zen-attack ─▶ /fh-collaborate (04)  outbox/w3/ 30 files + manifest   (blind)
              ──▶ zen-verdicts w3                     verdicts/w3/*.json + _private/w3-diagnostics.jsonl
              ──▶ zen-defend ─▶ /fh-fusion   (05)  verdicts/w3/SUMMARY.md + _private/DEFECTS_w3.md
                              ─▶ /fh-auto-validate (06)  one defect → gate RED → fix → inline-CSV regression test → PR
```

Prompts live in `zenedge/prompts/csv-import/` (`README.md` there has the order table). `just zen-prompt N` puts prompt N on the clipboard; type the slash command in pi, paste. Prompts 03–06 have `<paste …>` slots you fill from the previous artifact.

## Recipes

| Recipe | Does |
|---|---|
| `just zen-preflight [defend\|attack\|defend5]` | auth per provider, child-visible models, no `.env`, worktree/branch/venv, pack boundary, verdict runner, test DB. PASS/FAIL lines, nonzero on any FAIL. |
| `just zen-defend [pi args]` / `zen-defend5` | launch the defend stack in the worktree |
| `just zen-attack [pi args]` | launch the attack stack in the pack |
| `just zen-verdicts <wave> [--file X.csv] [--verbose]` | judge a wave with the real pipeline from the worktree. Overwrites `verdicts/<wave>/`; for a smoke, copy a file into `outbox/_smoke/` and judge `_smoke`. |
| `just zen-prompt N` | prompt N → clipboard |
| `just zen-transcribe` | re-transcribe Dan's v2 video (`yt-digest`) |
| `just zen-enable-deepseek [id] [thinking]` | replace the `DEEPSEEK_PLACEHOLDER` line in every ZenEdge stack once `pi --list-models deepseek` lists the id |

## Where things land

- Every harness run: `/tmp/fusion-harness-<run>/` — `prompt.md`, `stack.json`, `agents/<slot>/answer.md`, `fused.md`, `acks/<slot>.md`, `gate.py` + `gate-round-N.txt`, `summary.json` (status, tokens, cost, tps per agent).
- Defender-only plans and fix lists: `~/code/redteam-harness/_private/` (never enters the pack or the backend repo).
- Public wave reviews: `~/code/options-red-teaming/verdicts/<wave>/SUMMARY.md`.
- Fixes: branch → PR to `main` in zenedge-backend, regression test with the hostile CSV inlined (the repo ignores every `*.csv`). Never `production`, never Heroku.

## Setup on a fresh machine

Runbook: `~/code/zenedge-recovery` (`bootstrap-repos.sh` clones this fork; keys restore into `~/.config/zenedge/secrets.env` via `zenedge-secret`). Then in this repo: `npm install`, `just zen-preflight`. Worktree: `git -C ~/code/zenedge-backend worktree add ~/code/zenedge-backend-fusion -b feat/fusion-csv-import-hardening origin/main`, then `uv venv --python 3.11 .venv && uv pip install --python .venv/bin/python -r requirements.txt -r requirements-dev.txt`. Test DB: `redteam-harness/LAUNCH.md`.

## Cost notes

Sol at xhigh is the expensive seat by tokens but plan-billed; the harness model bar (`/fh on`) shows context %, tps and cost per slot. DeepSeek is the only slot that bills real dollars; keep it at `medium` in the attack stack and watch its row. GPT-5.6 input pricing doubles past ~280k context on the API, which is why the plan path (`openai-codex`, 372k ceiling) stays the rule.
