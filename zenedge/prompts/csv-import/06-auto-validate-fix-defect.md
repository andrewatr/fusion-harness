Fix ONE confirmed red-team defect in the CSV import pipeline and prove it with a permanent regression test.

DEFECT: <paste one entry from /Users/zen/code/redteam-harness/_private/DEFECTS_w3.md — root cause, file:line, the hostile CSV text, the expected economics>

Definition of done, all required:
1. A new test module `tests/unit/routers/trade_import/test_<defect_slug>.py` that inlines the hostile CSV as a string (this repo ignores every `*.csv`; follow `tests/unit/routers/trade_import/test_ibkr_flex_equity_rows.py`), runs it through `process_csv_file` (and `process_trades_for_date` where the defect is downstream), and asserts the correct economics: row counts in vs out, UTC instants, quantities, prices, multiplier, and any user-facing message. The test must fail on the current code and pass after the fix.
2. The minimal fix in `routers/trade_import/` (or `services/option_position_grouping.py`), matching surrounding style. No refactors, no adjacent cleanups, no new feature flags unless the defect is a flag default.
3. `.venv/bin/pytest tests/unit/routers/trade_import -q` green, `.venv/bin/black <changed files>` applied, `.venv/bin/ruff check <changed files>` clean.
4. A docstring in the test naming the wave and file that found the defect, in the style of the existing red-team regression modules.

Never touch `~/code/zenedge-backend`, `production`, or Heroku. Never write into `/Users/zen/code/options-red-teaming/`. Report changed files with absolute paths and the pytest summary line.
