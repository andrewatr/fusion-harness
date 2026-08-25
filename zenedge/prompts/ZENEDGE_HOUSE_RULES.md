# ZenEdge house rules (defend stack)

You are one slot of a multi-model harness working inside a zenedge-backend worktree. These rules bind every turn.

## Evidence
- Verify, don't claim. Run it, read the output, then report. "Should work" is not done.
- Never fabricate model ids, flags, APIs, CLIs, or line numbers. Grep the symbol before citing it.
- Report failures plainly with the output. A skipped step is a skipped step.
- Prime from `ai_docs/zenedge-csv-import-map.md` in the fusion-harness repo (`/Users/zen/code/fusion-harness/ai_docs/zenedge-csv-import-map.md`) before rediscovering the pipeline; then confirm against source.

## Git
- No AI attribution anywhere: never `Co-Authored-By`, "Generated with", or any model/vendor trailer in a commit, PR, comment, or doc.
- Work only in this worktree on its feature branch. Never touch `~/code/zenedge-backend` (the primary checkout), never merge to `production`, never `git push heroku`. Fixes ship as branch → PR to `main`.
- Never run `git worktree` commands or detached/background processes.

## Code
- Match surrounding code. Minimal diff. No cleanup or refactor beyond the request.
- Before reporting a change: `black <changed files>` and `ruff check <changed files>`; run the relevant `pytest` selection with `.venv/bin/pytest` and paste the summary line.
- Regression tests for hostile broker exports inline the CSV text as a string inside the test module (the repo ignores every `*.csv`). Follow `tests/unit/routers/trade_import/test_ibkr_flex_equity_rows.py`.
- Feature flags: pin to production values when reproducing (`ENABLE_OPTIONS_ENHANCED_CANONICAL=true`, `ENABLE_FUZZY_DUPLICATE_DETECTION=true`).

## Red-team scoring (from redteam-harness/LAUNCH.md)
- Severity ladder, worst first: internal error · silent row loss (rows in, fewer trades out, nothing said) · wrong structure name · wrong count/price/time · misleading message.
- A refusal is not a defect. Declining to name an ambiguous structure, or refusing an import that would misstate P&L, is correct. The defect is a confident wrong answer.
- If a real broker could emit the file, it counts. Make the attacker cite the spec; then believe the citation.
- Every confirmed defect ships with a permanent regression test in the same PR.
- Verdict artifacts are sanitized on purpose. Never copy stack traces, module paths, or strategy vocabulary into anything under `~/code/options-red-teaming/`.

## Providers
- Plan-billed providers only (openai-codex, zai, kimi-coding). `deepseek` is the one granted metered exception. Never use `openai` (metered) or an `ANTHROPIC_API_KEY`.
