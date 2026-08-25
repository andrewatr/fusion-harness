# zenedge-backend — CSV import pipeline map (priming context for harness slots)

Scouted 2026-08-25 against `origin/main` (a59646ae). Line numbers drift; symbols do not. Grep the symbol before citing a line.

## Entry point

| Path | Handler | Notes |
|---|---|---|
| `POST /api/v1/upload-apex-csv` and `POST /api/trade-import/upload-apex-csv` | `routers/trade_import/routes.py` → `upload_apex_csv` (~line 371) | the core import endpoint; double-mounted via `routers/registry/imports_registry.py` |
| `POST /…/trades/upload/confirm` | `confirm_fuzzy_import` (~1293) | fuzzy-duplicate confirmation, HMAC token |
| `POST /…/ingest-rithmic-direct/v1` | `ingest_rithmic_direct_v1` (~1517) | Rithmic microservice path |

Call sequence inside `upload_apex_csv`: `process_csv_file` → `detect_fuzzy_duplicates` → `validate_no_open_positions` / `validate_and_filter_open_positions` → `_exact_duplicate_preflight` → `process_trades_for_date` → background `verify_import_prices_background` / `attribute_zones_background`; options second pass `_maybe_options_enhanced_2nd_pass` → `services/option_position_grouping.py::run_option_grouping_second_pass`.

Sibling broker routers (separate endpoints, same downstream): `routers/ninja_csv_import.py` (`/api/upload-ninja-csv/`), `routers/tradeovate_csv_import.py`, `routers/project_x_csv_import.py`; agent JSON uploads `routers/{ninja,sierra,tradovate,ibkr}_agent_upload.py`. Out of scope for the blind engagement (NinjaTrader/Tradovate/Project-X) — see `options-red-teaming/BRIEF.md`.

## Core modules — `routers/trade_import/`

- `parsers.py` (~1500 lines) — the parsing/normalization core.
  - `load_csv_flexible`, `load_csv_from_completed_orders` (skips the "Completed Orders" banner)
  - Broker detectors (required-column signature sets ~387–423): `_is_ibkr_flex_format`, `_is_robinhood_activity_format`, `_is_tastytrade_transaction_format`, `_is_schwab_tos_trade_history_format`, `_is_fidelity_atp_history_format`
  - Canonicalizers → APEX schema: `canonicalize_ibkr_flex_to_apex`, `canonicalize_robinhood_activity_to_apex`, `canonicalize_tastytrade_transactions_to_apex`, `canonicalize_schwab_tos_trade_history_to_apex`, `canonicalize_fidelity_atp_history_to_apex`
  - Symbol/contract: `extract_root_symbol`, `get_tick_size_for` (equity coverage gap: only QQQ registered at 0.01, others fall to the futures 0.25 default — known, see w2 SUMMARY), `map_micro_to_base`, `normalize_contract`, OCC helpers `_build_occ_symbol_from_parts`, `_normalize_option_symbol_from_parts`
  - Timezone: `_eastern_wallclock_series_to_utc_naive`, `_robinhood_activity_series_to_utc_naive`
  - Orchestrator: `process_csv_file` (~1235): detector chain then `canonicalize_rithmic_to_apex` fallback with an "Unrecognised broker export" diagnosis
- `parsers_rithmic.py` — `canonicalize_rithmic_to_apex`, `_detect_time_col_and_tz`, `_normalize_time_to_utc_naive`, `convert_rithmic_to_trade`, `_has_fill` / `_is_filled_like`
- `validation.py` — `validate_no_open_positions`, `validate_and_filter_open_positions`, `is_likely_duplicate`, `detect_fuzzy_duplicates`, confirmation-token HMAC
- `processing.py` (~1030) — `resolve_source_policy`, natural-key dedup `_natural_key_from_trade` / `_natural_key_from_row`, weak-identity probe, `_duplicate_fast_path_probe`, `process_trades_for_instrument`, `_build_logical_groups_for_instrument`, `process_trades_for_date`
- `grouping.py` — cross-zero algorithm: `group_fills_cross_zero`, `CrossZeroCycle`, `_build_logical_group`
- `db.py` (~990) — `insert_raw_trade(s)`, `_try_batch_insert_raw_trades`, `insert_logical_trade_group`, `persist_logical_trade_groups_batch`, `update_raw_trades_logical_ids_batch`
- `rebuild.py`, `excursions.py`, `models.py::Trade`
- Options: `services/option_position_grouping.py` (`parse_option_leg`, `_temporal_groups`, `classify_strategy`), `services/option_materialization.py`

## Brokers auto-detected inside `upload-apex-csv`

Rithmic/Apex Completed Orders (canonical), IBKR Flex Trades, Robinhood account activity, tastytrade transactions, Schwab/thinkorswim Trade History, Fidelity ATP History. Detection order is the chain in `process_csv_file`.

## Feature flags (read `docs/import-algorithm/FEATURE_FLAG_INVENTORY.md`)

`ENABLE_OPTIONS_ENHANCED_CANONICAL` (default true, protected) · `ENABLE_FUZZY_DUPLICATE_DETECTION` (false locally, **true in prod**) · `ENABLE_PARTIAL_CSV_IMPORT` (true) · `ENABLE_CSV_ROUTE_DUPLICATE_PREFLIGHT` (false) · `ENABLE_CSV_BATCH_RAW_INSERT` · `ENABLE_CSV_BATCH_LOGICAL_PERSISTENCE` · `ENABLE_VERBOSE_IMPORT_DEBUG` · `ENABLE_OPTION_GROUPING_BATCH_PERSISTENCE` · `ENABLE_ASYNC_OPTION_MATERIALIZATION` · `ENABLE_DELAYED_GROUPING` · `ENABLE_QA_IMPORT_TIMINGS`. The verdict runner pins the production values.

## Tests

- Unit (no DB): `tests/unit/routers/trade_import/` — `test_import_parsers.py`, `test_parsers_extended.py`, `test_ibkr_flex_equity_rows.py` (red-team regression pattern: CSV inlined as a string), `test_unrecognised_export_diagnosis.py`, `test_validation.py`, `test_group_fills_cross_zero.py`, `test_build_logical_group.py`, `test_duplicate_fast_path*.py`, `test_source_import_policy.py`, `test_fop_pnl_ticks_characterization.py`
- Integration (no DB): `tests/integration/routers/trade_import/` — `test_import_vector_integration.py`, `test_synthetic_golden_characterization.py`, `test_options_corpus_classifier_oracle.py`, `test_options_near_miss_refusals.py`, `test_broker_options_slices.py`, `test_cross_zero_loop_parity.py`, `test_rithmic_header_variants.py`, `test_real_export_acceptance.py`
- Smoke: `tests/smoke/routers/test_trade_import_smoke.py`; e2e: `tests/e2e/local/test_trade_import_flow.py`; realdb (needs `TEST_DATABASE_URL`): `tests/realdb/test_equity_csv_import_e2e.py`, `test_options_leg_linker_csv_e2e.py`
- Run: `make test` (unit+integration+smoke), `make test-unit`; `pytest.ini` timeout 30 s, `asyncio_mode=auto`. `tests/conftest.py` autouse `mock_db_pool` — the whole import path runs without Postgres.
- CI: `black` on changed files + `ruff` repo-wide; coverage gate 70 %.
- **`.gitignore` ignores every `*.csv`** — a hostile CSV becomes a test by inlining its text in the test module, never as a fixture file.

## Fixtures and generators

- `tests/fixtures/synthetic_large/` (per-broker CSVs + `EXPECTED_*.csv` + `MANIFEST.md`), `tests/fixtures/ibkr/` (agent JSON incl. `adversarial/`), `tests/import_test_helpers.py` (the 7 import vectors), `tests/factories.py`
- `scripts/generate_broker_fixtures.py` — deterministic multi-broker generator (`--broker {ibkr,ninjatrader,tradovate,rithmic_apex,schwab,fidelity,tastytrade,robinhood} --asset-class {equities,options}`)
- `scripts/generate_synthetic_rithmic_csvs.sh`, `scripts/smoke_import_variants.sh` (live HTTP variants)

## Docs

`docs/import-algorithm/` — `CANONICAL_REFERENCE_PRIMARY_IMPORT_GROUPING_ALGORITHM_DOCS-11-2.md`, `CSV_IMPORT_SYSTEMS_ARCHITECTURE_ULTRA_DETAILED_TECHNICAL_GUIDE_11-15.md`, `CSV_IMPORT_ALGORITHM_FLOW_DIAGRAM.md`, edge-case postmortems (timestamps exact-match, reversal, reject-open-positions), broker guides, `FEATURE_FLAG_INVENTORY.md`. Also `docs/postmortems/BUG_27_IMPORT_DE_DUP_IDX_EDGECASE_POSTMORTEM.md`, `docs/testing/E2E_ACCEPTANCE_TEST_MATRIX.md`.

## Red-team engagement state (2026-08-25)

- Pack (what the attacker sees): `~/code/options-red-teaming/` — `BRIEF.md`, `FEEDBACK_SCHEMA.md`, `specs/{FIELDS,FOP,README}.md`, `outbox/{w0-selftest,w1,w2}`, `verdicts/{w0-selftest,w1,w2}`.
- Defender side: `~/code/redteam-harness/` — `run_verdicts.py` (drives `process_csv_file → process_trades_for_date → options 2nd pass` against the ephemeral DB `127.0.0.1:5453/zenedge_test`, writes sanitized verdicts + `_private/<wave>-diagnostics.jsonl`), `LAUNCH.md` (scoring rules), `HANDOFF-lane-a-k3-wave3.md` (w3 mandate), `HANDOFF-lane-b-adapters.md` (fix lane).
- w2 verdict: 11 match · 8 defect · 1 pending · 0 internal errors. Banked defects (do not re-spend): five silent-row-discard files (Schwab/Fidelity/tastytrade/Robinhood equity rows, Robinhood prose Description), two Schwab `Execution ID` files, one Fidelity action-vocabulary file. Shipped fixes: #725, #726, #727.
- w3 mandate: ~10 FOP (`specs/FOP.md`), ~8 TZ/DST, ~7 encoding/locale/CSV mechanics, ~5 idempotency/lifecycle arithmetic. 30 files.
