Wave `w3` has been judged. Triage it.

Inputs: `/Users/zen/code/options-red-teaming/verdicts/w3/*.json` (public, sanitized), `/Users/zen/code/options-red-teaming/outbox/w3/manifest.json` (the attacker's declared economic truth), `/Users/zen/code/redteam-harness/_private/w3-diagnostics.jsonl` (full tracebacks, never shared), and the pipeline source in this worktree.

For every file decide one of: `defect` (ours — cite `file:line` and the root cause from the diagnostics), `file_invalid` (theirs — say exactly what the spec says and where their file departs), `mismatch` (their declared economic truth is wrong), `pending` (a product decision, not a bug — name the decision). Read for patterns, not per-file drama: internal errors first, then `parsed_rows > 0` with `logical_trades == 0`, then wrong structure names, then cross-file inconsistencies for the same economic truth.

Write two files:
1. `/Users/zen/code/options-red-teaming/verdicts/w3/SUMMARY.md` — the public wave review in the voice of `verdicts/w2/SUMMARY.md`: headline counts, each defect described in economic terms, which files were wrong and why (with the spec citation), the pending decisions, and the mandate for wave 4. No source paths, exception names, log lines, or strategy vocabulary.
2. `/Users/zen/code/redteam-harness/_private/DEFECTS_w3.md` — the defender fix list, ordered by the severity ladder (internal error · silent row loss · wrong structure name · wrong count/price/time · misleading message). Per defect: root cause with `file:line`, the red-team file(s) that prove it, the minimal fix, and the regression test to write (module path under `tests/unit/routers/trade_import/`, the CSV text to inline, the assertions).

Do not modify pipeline code in this run.
