Find concrete defects in the broker CSV import pipeline under `routers/trade_import/` — read `parsers.py`, `parsers_rithmic.py`, `processing.py`, `grouping.py`, `validation.py`, and `services/option_position_grouping.py`. Prime from `/Users/zen/code/fusion-harness/ai_docs/zenedge-csv-import-map.md`, then verify every claim in source.

Return a ranked list of at most 12 defects. For each:
1. `file:line` and the function.
2. A minimal failing input: the exact CSV header plus 1–3 rows that trigger it, in a broker format the detector chain actually accepts.
3. Expected behaviour vs actual behaviour, in a trader's terms (rows lost, wrong count, wrong UTC instant, wrong multiplier, wrong label, internal error).
4. Severity on this ladder, worst first: internal error · silent row loss · wrong structure name · wrong count/price/time · misleading message.
5. Confidence, and the one experiment that would confirm it.

Exclude the eight defects already banked in wave 2 (silent equity-row discard in Schwab/Fidelity/tastytrade/Robinhood, the Schwab `Execution ID` contract, the Fidelity action vocabulary). Focus where wave 3 is pointed: options on futures (multiplier = point value, four-digit fractional strikes, root collisions), timezone/DST edges (2026-03-08 nonexistent hour, 2026-11-01 ambiguous hour, Rithmic fixed-offset headers), encoding/locale/CSV mechanics (BOM, UTF-16, CRLF, decimal comma, quoted newlines, duplicate headers), idempotency and lifecycle arithmetic (replayed executions, reversal through zero, partial fills).

Read-only. Do not propose fixes yet; a wrong diagnosis costs more than a missing one.
