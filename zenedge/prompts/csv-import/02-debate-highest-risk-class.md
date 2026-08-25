Which single defect class in the CSV import pipeline (`routers/trade_import/`) does the most damage to a trader's P&L record, and therefore deserves wave 3's first ten files and the first fix PR?

Candidates: silent row discard · timezone/DST conversion · options-on-futures multiplier and strike handling · duplicate/replay idempotency · strike-label precision · cross-zero lifecycle arithmetic. You may propose another.

Judge by: probability a real broker export triggers it, whether the failure is silent or loud, the size of the P&L misstatement, and how many brokers share the code path. Cite source (`file:line`) and the wave-2 evidence in `/Users/zen/code/options-red-teaming/verdicts/w2/SUMMARY.md`. A loud failure with a clear message ranks below a plausible wrong number.
