# Appendix C — Database substrate matrices (every table, PK/FK, index, RLS policy, migration object)

## LENS 1/6 — Complete RLS scope matrix across both databases (primary + Sierra), seed vs migrations, plus the GUC-set-site cross-check in database.py

**Coverage.** ENUMERATED (not sampled): all 76 tables in db/schema_test_seed.sql and all 68 tables in db/schema_test_seed_sierra.sql, extracted mechanically with awk over each CREATE TABLE...) block, cross-joined against every ALTER TABLE ... ENABLE/FORCE ROW LEVEL SECURITY and every CREATE POLICY in the same file; plus 32 migration-only tables (educator_*, guardrail_*, phonetic_mappings, apns_*, support_intake_*, recap_shares, idempotency_keys, regime_cell_stats, session_analysis, coaching_memos, transcription_jobs/corrections, morning_feeds, pre_computed_coaching, alert_level_touches, attribution_signals, sg_token_refresh_runs, deploy_drift_alert_state, stale_pr_alert_state) enumerated by grepping CREATE TABLE + ENABLE/FORCE across all 131 db/migrations/*.sql. All 52 db/migrations_sierra/*.sql grepped for ROW LEVEL SECURITY / CREATE POLICY / current_setting — zero hits, verified by count.

READ IN FULL: db/migrations/20260709130000 (Stage 1 svc_role_bypass), 20260709140000 (Stage 2 require_tenant_scope), 20260419092247 (NULLIF rewrite), 20260305065235 (workspace policy drop), 20260226070000 (P1 RLS + exclusion list), 20260623120000/123000/130000 (educator tenancy/content/phonetic), database.py lines 80-240 and 380-680 (every GUC set site), tests/realdb/test_rls_enforcement.py helpers + audit_log class.

CONFIRMED GUC INVENTORY (database.py): app.current_user_id set at :500 (get_db_rls_dep), :552 (get_db_educator_dep), :222 (RESET on fresh conn). app.current_educator_id set ONLY at :570. app.service_role set at :102, :173, :184, :406, :423, :505('off'), :557('off'), :646; RESET at :227, :410. app.request_id set at :501, :553, :647. NO POLICY ANYWHERE REFERENCES app.request_id (0 hits in seed and in all 131 migrations) — it is telemetry only, not a security input; nothing is broken by that, but it is not a scope GUC. Conversely app.service_role and app.current_educator_id have ZERO references in schema_test_seed.sql (see finding rls-05) while being live in prod migrations.

SAMPLED, NOT ENUMERATED: application reachability. I confirmed RLS *posture* for every table but only spot-checked router code for 6 of the un-RLS'd tables (recording_chunks, trade_voice_segments, trade_zone_attribution, recap_shares, gsst_signals, hiro_flatline_user_prefs). Findings whose blast radius depends on a specific endpoint are marked INFERRED. I did NOT run psql, so all policy semantics are read from DDL text, not from pg_policies on a live database.

NOT COVERED: sequences, views/matviews (RLS does not apply but a SECURITY INVOKER view over an un-RLS'd table would inherit the hole), column-level GRANTs (there are zero GRANT statements in db/ at all — verified), and the 6 known-issue classes I was told to skip.

## A. Primary DB — the conforming baseline (41 policies, 40 tables)

`STD` = ENABLE=Y, FORCE=Y, one policy named `tenant_isolation`, granted to PUBLIC (no `TO` clause — **zero** policies in the entire repo carry a `TO` clause, and there are **zero** `GRANT` statements), predicate shape **fail-open** `current_setting('app.current_user_id', true) IS NULL OR user_id = current_setting(...)`, USING and WITH CHECK **identical**. In the seed these 41 have **no** `svc_role_bypass` and **no** `require_tenant_scope` veto.

STD tables (40): api_keys, bookmap_sync_request, coaching_sessions, daily_coaching_briefs, feature_submissions, feature_votes, gsst_compliance_cache, gsst_rule_compliance, health_metrics, ibb_rule_compliance, logical_trades, mindfulness_sessions, ml_verification_stats, ml_verification_votes, pending_excursions, playbook_taps, raw_trades, recall_frames, recording_sessions, report_registry, sg_rule_compliance, support_requests, trade_excursions, trade_notes, transcriptions, user_account_risk, user_cursor_rules, user_feedback, user_gsst_settings, user_instrument_risk, user_notifications, user_patterns, user_profiles, user_risk_profiles, user_rithmic_config, user_trading_preferences, video_requests, voice_match_views, voice_training_feedback, zdpsb_rule_compliance — all at db/schema_test_seed.sql:5487–5760.

## B. Primary DB — every DEVIATING row

| table | tenant col | ENABLE | FORCE | policies | predicate shape | veto | verdict |
|---|---|---|---|---|---|---|---|
| **playbooks** | none | **Y** (5445) | **Y** (1891) | **NONE** | — | no (sweep needs a GUC policy) | **DENY-ALL to every role incl. owner** |
| **users** | auth0_id (root) | **–** | – | none | — | no | **no RLS anywhere; 76 cols incl. email, disclaimer IPs, coaching_personality** |
| audit_log | user_id | Y (5342) | Y (1247) | `audit_insert` FOR INSERT **WITH CHECK (true)**; `audit_select` FOR SELECT fail-open | **read scoped / write OPEN** | yes | **write-open across tenants** |
| playbook_votes | user_id | Y (7187) | **– in seed** (migration 20260619130100 adds it) | 4: select_authenticated / insert_owner / update_owner / delete_owner | select `cs <> '' OR cs IS NULL` = **read ALL rows**; writes owner-scoped | yes | **read-open; no FORCE in the CI seed** |
| deleted_execution_ids | user_id, deleted_by | **– in seed** (migration 20260619130200 adds it) | – | none in seed | — | no | seed/prod divergence |
| rithmic_fill_retry_queue | user_id, account | **–** | – | none anywhere | — | no | **user-scoped, never RLS'd** (explicitly excluded, 20260226070000:20) |
| recording_chunks | (session_id→user) | – | – | none | — | no | **child of RLS'd parent, holds transcript + s3_key** |
| recording_chunk_entities | (chunk_id→…→user) | – | – | none | — | no | child hole |
| trade_voice_segments | (logical_trade_id→user) | – | – | none | — | no | child hole |
| trade_zone_attribution | (logical_trade_id→user) | – | – | none | — | no | child hole |
| report_findings | (report_id→user) | – | – | none | — | no | child hole |
| ml_verification_candidates | none | – | – | none | — | no | shared corpus, OK |
| regime_daily_snapshots | none | – | – | none | — | no | shared, OK |
| scotts_zones_game_board | none | – | – | none | — | no | shared, OK |
| instruments / spotgamma_watchlist / options_strategy_templates / sg_playbook_regime_filters / sg_playbook_content / playbook_instrument_membership / sg_transferability_verdicts / sg_forward_validation | none | – | – | none | — | no | shared reference data, OK |
| user_playbook_definitions | owner_user_id | Y (5933) | Y (5934) | 4: owner_read, owner_write, service_role_write, service_role_read_published | NULLIF form; **owner_read also admits `visibility='ecosystem' AND status='published'`** | yes | cross-tenant read **bounded** by explicit publish |
| sg_rulebook_firings / _outcomes / _stats | via playbook_id | Y | Y | 2 each: `*_read`, `*_service_write` | read inherits the ecosystem-published overlay; **writes service-only** | yes | bounded |
| options_strategies / option_position_verdicts / option_materialization_jobs | user_id | Y | Y | 2 each: owner_read + owner_write | NULLIF, symmetric | yes | OK |
| trade_flow_alignment | user_id | Y (7378) | Y (7379) | tfa_owner_read + tfa_write | NULLIF, symmetric | yes | OK |
| flow_alignment_edge_stats | none | Y (7436) | Y (7437) | `faes_read USING (true)` + `faes_service_write` | **read TRUE / write service-only** | yes | intentional aggregate |
| coach_conversations / coach_turns | user_id | Y | Y | tenant_isolation, NULLIF form | symmetric | yes | OK |
| sierra_chart.hiro_flatline_signals / roll_periods / spotgamma_daily_levels (in primary seed) | – | – | – | none | — | no | shared market data |

## C. Migration-only tables (32) — not in the CI seed at all

| table | tenant col | ENABLE | FORCE | scope GUC | verdict |
|---|---|---|---|---|---|
| educators | id | Y | Y | `app.current_educator_id` | OK |
| educator_users | auth0_id | Y | Y | `app.current_user_id` | OK (bootstrap by design) |
| educator_recordings / _transcripts / _briefings / _usage_events | educator_id | Y | Y | `app.current_educator_id` | OK |
| educator_zoom_connections / educator_oauth_states | educator_id | Y | Y | `app.current_educator_id` | OK (holds Zoom OAuth tokens) |
| **recap_shares** | educator_id | **–** | – | — | **no RLS by design** (20260623123000:6) — every tenant's share tokens in one unprotected table |
| phonetic_mappings | user_id + educator_id | Y | Y | both | multi-branch; global rows readable by all — bounded |
| guardrail_cues/_feedback/_outcome_links/_user_priors, voice_guardrail_signals | user_id | Y | Y | user | OK |
| attribution_signals, transcription_jobs, transcription_corrections, session_analysis, coaching_memos, morning_feeds, pre_computed_coaching, alert_level_touches, apns_device_tokens, apns_push_log, support_intake_events, support_intake_processing_events | user_id | Y | Y | user | OK |
| **idempotency_keys** | user_id (in PK) | **–** | – | — | **user-scoped, no RLS** (excluded 20260226070000:18) |
| **regime_cell_stats** | user_id | **–** | – | — | **RLS explicitly deferred** (20260517083756:18-25) |
| sg_token_refresh_runs, deploy_drift_alert_state, stale_pr_alert_state | none | – | – | — | operational, OK |

## D. Sierra DB — 68 tables, uniform

| metric | value |
|---|---|
| tables in db/schema_test_seed_sierra.sql | 68 |
| `ROW LEVEL SECURITY` occurrences (seed) | **0** |
| `CREATE POLICY` occurrences (seed) | **0** |
| `current_setting` occurrences (seed) | **0** |
| `ROW LEVEL SECURITY` across all 52 db/migrations_sierra/*.sql | **0** |
| `CREATE POLICY` across all 52 migrations_sierra | **0** |
| tables carrying a `user_id` column | **7**: gsst_signals, ibb_signals, zdpsb_signals, hiro_divergence_signals, hiro_divergence_preferences, hiro_flatline_signals, hiro_flatline_user_prefs |
| GUC set anywhere on the Sierra pool (database.py:737-860) | **none** |

Every other Sierra table is genuinely shared market data (OHLC, SpotGamma levels, HIRO ticks, roll calendars) where no RLS is warranted.

---

## Lens 3/6 — Indexation: every index, every missing one (FK coverage, RLS predicate coverage, duplicates, unique-index/app mismatch, partial-predicate drift, expression-form drift, hot-path support, CONCURRENTLY discipline)

**Coverage.** ENUMERATED (not sampled): all 109 `CREATE INDEX` statements in db/schema_test_seed.sql, all 125 in db/schema_test_seed_sierra.sql, all 83 `ADD CONSTRAINT ... PRIMARY KEY|UNIQUE` in the public seed and all 57 in the sierra seed (= 374 index-backed objects). Cross-checked against all 84 `REFERENCES` clauses in the public seed and all 128 `CREATE INDEX` + 64 `DROP INDEX` statements across the 131 files in db/migrations/. All 54 `ENABLE ROW LEVEL SECURITY` tables in the public seed were individually cross-referenced against the index list for a leading-column index on their policy predicate column.

SAMPLED, not enumerated: the query sites. I read query text in ~25 files under routers/ and services/ chosen by grep on the tables that the index audit flagged (logical_trades, raw_trades, transcriptions, recall_frames, trade_excursions, phonetic_mappings, option_materialization_jobs, sierra_ohlc_1min/1sec, collective_pulse, streak_*). There are 121 `FROM logical_trades` sites alone; I did not read all of them. The "top-10 seq-scan" ranking below is therefore a ranking of what I read, not a proven global maximum.

NOT COVERED: db/migrations_sierra/ (I audited only db/migrations/ as the task named); db/seeds/; any live `pg_indexes` / `pg_stat_user_indexes` reality (read-only audit, no psql permitted) — so every claim about what is actually present in the production database is INFERRED from the file chain, never observed. Where the seed and the migration chain disagree I say so explicitly rather than guessing which one prod matches.

A structural caveat that limits everything below: 12 tables created by migrations (phonetic_mappings, transcription_corrections, transcription_jobs, apns_device_tokens, educator_users, educator_recordings, support_intake_events, session_analysis, coaching_memos, guardrail_signals, pre_computed_coaching, morning_feeds) appear ZERO times in db/schema_test_seed.sql, so their indexes have no test-database existence at all. I could only audit those from migration text.

## A. Duplicate / redundant indexes — public schema (all deviating rows)

| index | table | columns | uniq | partial | subsumed by | verdict |
|---|---|---|---|---|---|---|
| `idx_logical_trades_user_id` (seed:4381) | logical_trades | (user_id) | no | – | `idx_logical_trades_user_entry_time` (user_id, entry_time) seed:4374 | **DROP** — strict prefix; on the largest tenant table |
| `idx_raw_trades_user_id` (seed:4493) | raw_trades | (user_id) | no | – | `idx_raw_trades_user_fill_time` (user_id, fill_time_utc) seed:4486 | **DROP** — strict prefix; highest-write table |
| `uq_auth0` (seed:3998) | users | (auth0_id) | YES | – | `users_pkey` (auth0_id) seed:4134 | exact dup; 20260302100500:28-30 admits it and skips (43 FKs point at it) |
| `daily_coaching_briefs_user_id_brief_date_key` (seed:3614) | daily_coaching_briefs | (user_id, brief_date) | YES | – | `uq_daily_coaching_brief` (seed:4014) identical | **exact duplicate UNIQUE** |
| `idx_daily_briefs_user_date` (seed:4262) | daily_coaching_briefs | (user_id, brief_date DESC) | no | – | both of the above | 3rd index on the same pair |
| `coaching_sessions_user_id_session_date_instrument_key` (seed:3598) | coaching_sessions | (user_id, session_date, instrument) | YES | – | `uq_coaching_session` (user_id, session_date) seed:4006 | **dead constraint** — the 2-col unique is strictly stricter |
| `idx_coaching_sessions_user_date` (seed:4248) | coaching_sessions | (user_id, session_date DESC) | no | – | `uq_coaching_session` | redundant |
| `idx_gsst_cache_trade_id` (seed:4297) | gsst_compliance_cache | (trade_id) | no | – | `gsst_compliance_cache_trade_id_key` UNIQUE seed:3654 | redundant; dropped twice by migrations, still in seed |
| `idx_gsst_cache_user_id` (seed:4311) | gsst_compliance_cache | (user_id) | no | – | `idx_gsst_cache_user_grade` (user_id, overall_grade) seed:4304 | prefix-redundant |
| `idx_trade_notes_user_id` (seed:4577) | trade_notes | (user_id) | no | – | `uq_trade_notes_user_logical_trade` seed:4682 | prefix-redundant |
| `idx_voice_match_views_user_id` (seed:4661) | voice_match_views | (user_id) | no | – | `voice_match_views_user_id_transcription_id_key` seed:4158 | prefix-redundant |
| `idx_feature_votes_user_id` (seed:4276) | feature_votes | (user_id) | no | – | `unique_user_feature` (user_id, feature_id) seed:3990 | prefix-redundant |
| `idx_recall_frames_new_user_id` (seed:4507) | recall_frames | (user_id) ON ONLY | no | – | `recall_frames_new_unique_user_ts` (user_id, ts_utc) seed:3798 | prefix-redundant **and** invalid (see idx-11) |
| `idx_trade_excursions_trade_id` (mig 20260308000100:17) | trade_excursions | (trade_id) | no | – | `trade_excursions_pkey` (trade_id, granularity) seed:3934 | redundant (see idx-03) |
| `idx_ibb_rule_compliance_trade_id` (mig :19) | ibb_rule_compliance | (trade_id) | no | – | `ibb_rule_compliance_trade_id_key` UNIQUE seed:3694 | redundant |
| `idx_zdpsb_rule_compliance_trade_id` (mig :21) | zdpsb_rule_compliance | (trade_id) | no | – | `zdpsb_rule_compliance_trade_id_unique` seed:4182 | redundant |
| `idx_api_keys_user_id` (mig :23) | api_keys | (user_id) | no | – | `api_keys_user_id_key_type_key` seed:3566 | redundant |

## B. Duplicate / redundant indexes — sierra_chart (all deviating rows)

| index | table | columns | subsumed by | verdict |
|---|---|---|---|---|
| `idx_sierra_1min_lookup_heap` (sierra:3487) | sierra_ohlc_1min | (instrument, contract, ts DESC) | `sierra_ohlc_1min_heap_pkey` (sierra:2723) | **exact dup of PK** ×19 partitions — hottest ingest table |
| `idx_tws_1min_lookup` (sierra:3655) | tws_ohlc_1min | (instrument, contract, ts DESC) | `tws_ohlc_1min_pkey` (sierra:2874) | exact dup of PK |
| `idx_menthorq_v2_instr_contract_ts` (sierra:3417) | menthorq_v2 | (instrument, contract, ts DESC) | `menthorq_v2_pkey` (sierra:2683) | exact dup of PK |
| `spotgamma_v4_hiro_ts_idx` (sierra:3732) | spotgamma_v4_hiro | (minute_utc DESC) | `spotgamma_v4_hiro_pkey` (sierra:2866) | exact dup of PK |
| `idx_trace_timestamp` (sierra:3641) | spotgamma_trace | (timestamp_utc DESC) | `spotgamma_trace_pkey` (sierra:2858) | exact dup of PK |
| `ix_rho_sym_ts` (sierra:2786) | spotgamma_running_hiro_overview | (sym, snapshot_ts DESC) | pkey (sym, snapshot_ts) sierra:2779 | exact dup of PK |
| `idx_hiro_snapshot_date` (sierra:3235) | hiro_daily_snapshot | (snapshot_date) | `..._snapshot_date_key` UNIQUE sierra:2571 | exact dup |
| `idx_qscore_symbol_date` (sierra:3445) | qscore_daily | (symbol, date DESC) | `qscore_daily_symbol_date_key` sierra:2699 | exact dup |
| `idx_ib_daily_stats_instrument_date` (sierra:3249) | ib_daily_stats | (instrument, trade_date DESC) | `uq_ib_daily_stats_instrument_date` sierra:2914 | exact dup |
| `idx_gap_fill_stats_instrument_date` (sierra:3172) | gap_fill_statistics | (instrument, trade_date DESC) | `uq_gap_fill_stats_instrument_date` sierra:2906 | exact dup |
| `idx_menthorq_daily_gex_lookup` (sierra:3389) | menthorq_daily_gex | (instrument, trade_date) | `menthorq_daily_gex_unique` sierra:2675 | exact dup |
| `idx_menthorq_daily_gex_date_desc` (sierra:3375) | menthorq_daily_gex | (trade_date DESC) | `idx_menthorq_daily_gex_date` (trade_date) sierra:3368 | **dup pair** — btree scans backwards |
| `idx_menthorq_daily_gex_instrument` (sierra:3382) | menthorq_daily_gex | (instrument) | `menthorq_daily_gex_unique` | prefix-redundant |
| `idx_gsst_signals_user_id` (sierra:3228) | gsst_signals | (user_id) | `idx_gsst_signals_user_analysis` sierra:3221 | prefix-redundant |
| `idx_gsst_signals_settings_hash` (sierra:3200) | gsst_signals | (settings_hash) | `idx_gsst_signals_stats` sierra:3207 | prefix-redundant |
| `idx_div_signals_user` (sierra:3053) | hiro_divergence_signals | (user_id) | `idx_unique_daily_divergence_signal` sierra:3669 | prefix-redundant |
| `idx_rolling_stats_window` (sierra:3480) | hiro_flatline_rolling_stats | (time_window) | `uq_time_window_rolling_period_level` sierra:2922 | prefix-redundant |
| `idx_rolling_stats_period` (sierra:3466) | hiro_flatline_rolling_stats | (rolling_period) | `idx_rolling_stats_period_level` sierra:3473 | prefix-redundant |
| `idx_spotgamma_memory_level_type` (sierra:3578) | spotgamma_level_memory | (instrument, level_type) | `spotgamma_level_memory_unique` sierra:2818 | prefix-redundant |
| `idx_ibb_auto_log_date` (sierra:3263) | ibb_auto_detection_log | (trade_date) | `..._trade_date_symbol_key` sierra:2635 | prefix-redundant |
| `idx_ea_gapfill_sync_date` (sierra:3060) | emini_addict_gapfill | (sync_date DESC) | `..._sync_date_source_key` sierra:2515 | prefix-redundant |
| `idx_confluence_instrument_date` (sierra:2997) | confluence_zones | (instrument, trade_date DESC) | `unique_zone` (instrument, trade_date, rank) sierra:2890 | prefix-redundant |
| `idx_ib_daily_stats_instrument` (sierra:3242) | ib_daily_stats | (instrument) | `uq_ib_daily_stats_instrument_date` | prefix-redundant |

**23 sierra + 17 public = 40 of 374 index objects (11%) are provably redundant.** The remaining 334 are distinct and non-subsumed.

## C. Foreign keys with NO covering index (complete list, public seed)

| child table.column | → parent | ON DELETE | index? | consequence |
|---|---|---|---|---|
| `gsst_rule_compliance.user_id` (seed:4866) | users(auth0_id) | NO ACTION | **none** | user delete → seq scan; RLS predicate unindexed |
| `ibb_rule_compliance.user_id` (seed:4882) | users | NO ACTION | **none** | same |
| `zdpsb_rule_compliance.user_id` (seed:5058) | users | NO ACTION | **none** | same |
| `trade_excursions.user_id` (seed:4970) | users | NO ACTION | **none** | same |
| `transcriptions.user_id` (seed:4994) | users | **RESTRICT** | **none** | see idx-04 |
| `trade_voice_segments.chunk_id` (seed:5210) | recording_chunks(id) | CASCADE | **none** | chunk delete → seq scan child |
| `trade_voice_segments.user_override_logical_trade_id` (seed:5226) | logical_trades(id) | NO ACTION | **none** | every logical_trade delete scans this table |
| `trade_zone_attribution.zone_id` (seed:5242) | scotts_zones_game_board(zone_id) | CASCADE | **none** | zone delete → seq scan |
| `report_findings.report_id` (seed:5178) | report_registry(id) | CASCADE | **none** (table has 0 indexes) | report delete → seq scan |
| `report_registry.supersedes_id` (seed:5186) | report_registry(id) | NO ACTION | **none** | self-FK unindexed |
| `user_feedback.session_id` (seed:5266) | coaching_sessions(id) | SET NULL | **none** | session delete → seq scan |
| `instruments.tracked_index` / `.proxy_futures` (seed:6185-6186), `.etf_proxy` (seed:7518) | instruments(symbol) | SET NULL | **none** ×3 | small table; low impact |
| `raw_trades.logical_trade_id` (seed:5130) | logical_trades(id) | NO ACTION | **none in seed**; `idx_raw_trades_logical_trade_id_fill` exists only in mig 20260531170000 | seed/prod drift |

The other **69 of 84** FK references are covered by a PK, UNIQUE, or explicit index whose leading column is the FK column. Conforming.

## D. RLS tables whose policy predicate column is unindexed

54 tables carry `ENABLE ROW LEVEL SECURITY` in the public seed. 48 have a leading-column index on their predicate column. The 6 that do not:

| table | policy line | predicate col | indexes present | verdict |
|---|---|---|---|---|
| `transcriptions` | seed:5655 | user_id | logical_trade_id, status, suggested_playbook(partial) | **unindexed** |
| `gsst_rule_compliance` | seed:5536 | user_id | (trade_id, overall_score, trend_direction, calculated_at) | **unindexed** |
| `ibb_rule_compliance` | seed:5550 | user_id | (trade_id, overall_score, calculated_at) | **unindexed** |
| `zdpsb_rule_compliance` | seed:5760 | user_id | (trade_id, overall_score, gamma_exposure_percent, calculated_at) | **unindexed** |
| `trade_excursions` | seed:5641 | user_id | none (PK is trade_id, granularity) | **unindexed** |
| `coach_turns` | seed:7483 | user_id | (conversation_id, created_at) only | **unindexed** |
| `gsst_compliance_cache` | seed:5529 | user_id | seed has it; migration chain drops **both** user_id indexes (20260223070100:11, 20260302100500:16) | **unindexed in prod (INFERRED)** |

Note the three `*_rule_compliance` tables all name their sole index `..._user_analysis` while indexing `trade_id` first — the name asserts a user-scoped index that does not exist.

## E. Partial / expression indexes vs the query's actual predicate

| index | its WHERE / expr | query form at the call site | match? |
|---|---|---|---|
| `phonetic_mappings_global_idx` (mig 20260608000100:48) | `(scope) WHERE user_id IS NULL` | `WHERE user_id IS NULL` (phonetic_rules.py:68) | predicate matches, **semantics no longer do** — see idx-13 |
| `phonetic_mappings_uniq` (mig 20260623130000:47) | `(COALESCE(user_id,''), COALESCE(educator_id::text,''), lower(spoken))` | `ON CONFLICT (COALESCE(user_id,''), lower(spoken))` at internal_glossary.py:67 + transcription_corrections.py:67 | **NO** — see idx-01 |
| same | 3-col expr | `WHERE user_id = $1` (phonetic_rules.py:103), `WHERE scope='user' AND user_id=$1` (user_glossary.py:25,62) | **NO** — plain column ≠ COALESCE expr; seq scan |
| `idx_logical_trades_user_entry_time` (seed:4374) | `(user_id, entry_time)` btree | `DATE(entry_time) BETWEEN` (services/logical_trades.py:415,429; routers/logical_trades.py:475; routers/health_metrics.py:1077) | **range half unusable** — user_id prefix only |
| `idx_logical_trades_entry_time` (seed:4346) | BRIN(entry_time) | `DATE(entry_time AT TIME ZONE 'America/New_York')` (collective_pulse_service.py:373,397,880) | **NO** — see idx-06 |
| `raw_trades_dedupe_key_uniq` (seed:4675) | `(dedupe_key)` | 9-predicate `to_char(fill_time AT TIME ZONE 'UTC',…)` recovery lookup, trade_import/db.py:415-441 | **NO** — see idx-08 |
| `idx_option_materialization_jobs_user_status` (seed:6616) | `(user_id, status, updated_at DESC)` | `WHERE user_id=… AND logical_trades.id = ANY(logical_trade_ids)` (services/logical_trades.py:346-353) | **array half unindexed** — see idx-07 |
| `uq_users_at_most_one_demo_data_source` (seed:2928) | `((is_demo_data_source)) WHERE is_demo_data_source = TRUE` | zero code references to this constraint anywhere in routers/ or services/ | app-invisible unique; a 2nd flag flip raises an unhandled 23505 |
| `idx_pending_excursions_retry`, `idx_firings_anti_dup`, `idx_coach_conversations_open_idle`, `idx_transcriptions_suggested_playbook`, `idx_raw_trades_logical_trade_id_fill`, `idx_upd_ecosystem`, 20 others | various | matching | **conforming** |

## F. CONCURRENTLY discipline — migrations creating indexes on large production tables

| migration | target table | statement | header claims | verdict |
|---|---|---|---|---|
| `20260302090000_p2_composite_indexes.sql:21,26` | raw_trades, logical_trades | plain `CREATE INDEX` | ":9 `@risk-level: LOW (CONCURRENTLY — no table lock, no downtime)`" | **write-blocking; claim false** |
| `20260302090200_p2_gin_import_metadata.sql:28` | logical_trades (GIN, JSONB) | plain `CREATE INDEX` | ":20 `@risk-level: LOW (CONCURRENTLY — no table lock)`" | **write-blocking; claim false** |
| `20260302100400_add_missing_user_id_indexes.sql:16-33` | 6 tables incl. pending_excursions | plain `CREATE INDEX` | ":10-11 "Using CONCURRENTLY… Using transaction:false"" | **write-blocking; both claims false** (`-- migrate:up` has no `transaction:false`) |
| `20260302070100_p1_brin_conversions.sql:45-57` | logical_trades, raw_trades | `DROP INDEX` then plain `CREATE INDEX` | – | drop+recreate inside one txn = **index gone under ACCESS EXCLUSIVE** |
| `20260530150000_add_option_support.sql:323-327` | logical_trades ×3 | plain `CREATE INDEX` | :313-322 explicitly acknowledges and defers the fix | honest, still write-blocking |
| `20260616160000_..._dedupe_idx.sql:20` (down) | raw_trades | plain `CREATE UNIQUE INDEX` | – | write-blocking on rollback |
| `20260223060200_migrate_recall_frames_data.sql:11-16` | recall_frames_new | plain | ":6 "table is new and not serving traffic"" | correct |
| `20260308000100_fk_supporting_indexes.sql:15` | 4 tables | plain, `SET lock_timeout='5s'` | ":14 "Not using CONCURRENTLY because Heroku PgBouncer wraps in transactions"" | honest + lock_timeout guard |
| `20260426113001:4`, `20260531170000:20` | users, raw_trades | `CREATE INDEX CONCURRENTLY` + `transaction:false` | – | **the only 2 of 128 done correctly** |

## G. Top 10 hot queries most likely to sequential-scan (ranked over what I read)

| # | site | table | why no index helps |
|---|---|---|---|
| 1 | `services/outcome_resolver.py:512-519` | `sierra_ohlc_1sec` | table has **zero** secondary indexes; PK (instrument, contract, ts) — query has no `contract`, so `instrument=$1` prefix scan of full 1-second history, once per firing resolution |
| 2 | `services/collective_pulse_service.py:880` | logical_trades | `DATE(entry_time AT TIME ZONE 'America/New_York') = $1`, **no user_id** — unindexable full scan, per snapshot |
| 3 | `services/collective_pulse_service.py:373` + `:397-399` | logical_trades ⋈ playbooks | same expression, 30-day window, no user_id |
| 4 | `routers/transcription_manager.py:135` + `:143-147` | transcriptions | `COUNT(*)` then `ORDER BY recorded_at DESC LIMIT/OFFSET` — no user_id index, no recorded_at index; OR-of-two-user_ids |
| 5 | `services/strategy_level_touch_ledger.py:477-483` | sierra_ohlc_1min | `GROUP BY contract` with **no timestamp bound** → zero partition pruning, all ~19 partitions |
| 6 | `routers/trade_import/db.py:415-441` | raw_trades | `to_char(fill_time AT TIME ZONE 'UTC',…)` + 3×`COALESCE()` + `ORDER BY created_at DESC` — only `user_id` usable; runs once **per duplicate fill** |
| 7 | `services/logical_trades.py:346-353` (LATERAL) | option_materialization_jobs | `= ANY(logical_trade_ids)` on an unindexed `UUID[]`, evaluated **per logical_trades row** |
| 8 | `services/market_state.py:437-445` | sierra_ohlc_1min | 140-day `instrument + timestamp` range; no `(instrument, timestamp)` index exists |
| 9 | `routers/health_metrics.py:1077-1079` | logical_trades | `DATE(entry_time) >= / <=` + `GROUP BY DATE(entry_time)` — user_id prefix only |
| 10 | `services/streak_metrics.py:36,95,178,233` + `streak_analysis.py:60,406,595` | logical_trades | `DATE(entry_time AT TIME ZONE 'UTC') BETWEEN` — 7 sites, same unindexable form |

Runner-up: `services/verdict_v0_data.py:167-171` and the other 15 `sierra_ohlc_1min WHERE instrument=$1 AND timestamp range` sites (idx-05).

---

## Lens 2/6 — Primary-key / foreign-key integrity across every table in db/schema_test_seed.sql, db/schema_test_seed_sierra.sql and db/migrations/*.sql (plus the app code that assumes those constraints)

**Coverage.** ENUMERATED (not sampled): every `CREATE TABLE` in db/schema_test_seed.sql (55 in the pg_dump body + 20 in the post-dump appends), every `CREATE TABLE` in db/schema_test_seed_sierra.sql (52 base tables + 19 `sierra_ohlc_1min_p*` partitions, which I treated as one unit and did not row-by-row), and every `CREATE TABLE` across all 131 files in db/migrations/ (31 tables that exist only in migrations and never in the seed). Every `PRIMARY KEY`, `UNIQUE`, `CREATE UNIQUE INDEX`, `REFERENCES` and `FOREIGN KEY` line in both seed files was read (grepped exhaustively, then the ALTER-TABLE/constraint pairs were read in context). `NOT VALID` was grepped across db/ — all 6 FK instances live in 20260302100600_add_fk_constraints.sql; 5 are VALIDATEd in the same file and video_requests is VALIDATEd later by 20260312000100 (so the seed's line 5042 `NOT VALID` is stale dump state, not a live unvalidated FK — I did NOT report it as a finding).

PARTIAL / SAMPLED, and I say so: (a) db/migrations_sierra/ (52 files) was NOT audited — the task named only db/migrations/*.sql; sierra constraint claims rest on the seed dump alone. (b) models/ — I did not read all 217 files. I grepped the whole directory for SQLAlchemy (only models/trade_notes.py has any) and for `playbook_id:` / `logical_trade_id` typing, then read models/coach_conversation.py and models/coach_turn.py in full. The models layer is Pydantic DTOs, not an ORM, so there are no `relationship()` declarations to contradict the DB; the FK-assumption defects surfaced instead in services/ and routers/ SQL, which is where I chased them. (c) I did not enumerate RLS policies (that is another lens) except where a policy substitutes for a missing FK. (d) I ran no database — every claim is static file reading. (e) Composite-key column-order vs app lookup: I checked the composite PKs in the primary DB against their index/lookup sites and found no order mismatch worth reporting; I did not do this for every Sierra composite PK.

NOT re-reported (matched the known-issues list): the RLS Stage-2 relkind='r' gap, require_tenant_scope absence, mark_dump_satisfied_migrations auto-marking, compute_dedupe_key/raw_trades_dedupe_key_uniq being seed-only, the second-truncation dedupe collapse, instrument-registry disagreement, tick_value defaults, win_rate operator split, int(multiplier), agent-upload success=True, the rithmic proxy, deps.py admin grant, Zoom CRC, snitch env vars, worker.py UTC, user_context cache, safe_task, response_model, MAE/MFE divergence, zone_attribution engine leak.

## A. public schema — seed pg_dump body (db/schema_test_seed.sql:1196–3317), 55 tables

| table | PK | natural / unique keys | FKs out (target, ON DELETE) | FKs in | verdict |
|---|---|---|---|---|---|
| users | (auth0_id) | uq_auth0(auth0_id), uq_email(email), partial uniq one demo_data_source | — | 41 tables | hub; 13 inbound FKs are NO ACTION/RESTRICT → see F5 |
| logical_trades | (id) | logical_trades_unique_trade(user_id,instrument,entry_time,exit_time,direction,total_quantity,account) | users(auth0_id) **NO ACTION**; playbooks(id) **NO ACTION**; options_strategies(id) SET NULL | 11 tables | position_group_id has **no FK** → F2 |
| raw_trades | (id) | UNIQUE(dedupe_key) [seed-only] | logical_trades(id) **NO ACTION**; users(auth0_id) **NO ACTION** | — | parent-first deletes fail → F14 |
| deleted_execution_ids | (user_id, execution_id) | = PK | users(auth0_id) CASCADE | — | **no account column** → F4 |
| transcriptions | (id) | — | users **RESTRICT**; logical_trades SET NULL; playbooks SET NULL | voice_match_views, voice_guardrail_signals | RESTRICT blocks user delete |
| trade_zone_attribution | (id) | UNIQUE(logical_trade_id,zone_id,attribution_type) | logical_trades CASCADE; **scotts_zones_game_board(zone_id) CASCADE** | — | global→tenant cascade → F3 |
| scotts_zones_game_board | (id) | UNIQUE(zone_id) | — | trade_zone_attribution (CASCADE) | global table, no tenant column |
| playbook_taps | (id) | — | users CASCADE; logical_trades SET NULL | — | **playbook_id int, no FK** → F11 |
| playbooks | (id) | — | — | logical_trades, transcriptions | int identity space |
| recall_frames | (id, ts_utc) partitioned BY RANGE(ts_utc) | UNIQUE(user_id, ts_utc) | users CASCADE | — | **zero partitions in seed** → F15 |
| recording_sessions | (id) | — | users CASCADE | recording_chunks, session_analysis | — |
| recording_chunks | (id) | UNIQUE(session_id, chunk_index) | recording_sessions CASCADE | recording_chunk_entities, trade_voice_segments, (attribution_signals: none) | — |
| recording_chunk_entities | (id) | UNIQUE(chunk_id) | recording_chunks CASCADE | — | conforming |
| trade_voice_segments | (id) | UNIQUE(logical_trade_id, chunk_id) | recording_chunks CASCADE; logical_trades CASCADE; logical_trades(user_override) **NO ACTION** | — | override col blocks trade delete |
| trade_excursions | (trade_id, granularity) | = PK | logical_trades CASCADE; users **NO ACTION** | — | — |
| pending_excursions | (trade_id) | — | logical_trades CASCADE; users **NO ACTION** | — | — |
| gsst_rule_compliance | (id) | UNIQUE(trade_id) | logical_trades CASCADE; users **NO ACTION** | — | — |
| ibb_rule_compliance | (id) | UNIQUE(trade_id) | logical_trades CASCADE; users **NO ACTION** | — | — |
| zdpsb_rule_compliance | (id) | UNIQUE(trade_id) | logical_trades CASCADE; users **NO ACTION** | — | — |
| sg_rule_compliance | (id) | UNIQUE(trade_id) | logical_trades CASCADE; users CASCADE | — | conforming |
| gsst_compliance_cache | (id) | UNIQUE(trade_id) | users CASCADE | — | **trade_id has no FK** |
| user_risk_profiles | (user_id) | — | users CASCADE | user_cursor_rules | cascade target of a NO ACTION child |
| user_cursor_rules | (user_id) | — | **user_risk_profiles(user_id) NO ACTION** | — | two-hop cascade blocker → F5 |
| user_feedback | (id) | — | users CASCADE; coaching_sessions SET NULL | — | conforming |
| coaching_sessions | (id) | UNIQUE(user_id,session_date,instrument), uq_coaching_session(user_id,session_date) | users CASCADE | user_feedback | two overlapping natural keys |
| daily_coaching_briefs | (id) | UNIQUE(user_id,brief_date) ×2 names | users CASCADE | — | duplicate constraint, harmless |
| report_registry | (id) | — | users CASCADE; **report_registry(supersedes_id) NO ACTION (self)** | report_findings | self-FK, no cycle possible (DAG by insert order, unenforced) |
| report_findings | (id) | — | report_registry CASCADE | — | conforming |
| ml_verification_candidates | (id) | — | — | ml_verification_votes | — |
| ml_verification_votes | (id) | UNIQUE(candidate_id,user_id) | candidates CASCADE; users CASCADE | — | conforming |
| ml_verification_stats | (user_id) | — | users CASCADE | — | conforming |
| voice_match_views | (id) | UNIQUE(user_id,transcription_id) | transcriptions CASCADE; users CASCADE | — | conforming |
| trade_notes | (id) | uq idx (user_id, logical_trade_id) | logical_trades CASCADE; users CASCADE | — | conforming |
| api_keys | (id) | UNIQUE(api_key), UNIQUE(user_id,key_type) | users CASCADE | — | conforming |
| audit_log | (id) | — | **none** | — | user_id text, **no FK to users** |
| health_metrics | (id) | uq idx(user_id,metrics_date,source) | users CASCADE | — | conforming |
| mindfulness_sessions | (id) | 2 partial uq idxs on (user_id,session_date,…) | users CASCADE | — | conforming |
| rithmic_fill_retry_queue | (id) | UNIQUE(user_id,account,instrument,trade_date) | users CASCADE | — | conforming |
| user_account_risk | (id) | UNIQUE(user_id,account_name) | users CASCADE | — | conforming |
| user_instrument_risk | (user_id, instrument) | = PK | users CASCADE | — | conforming |
| user_gsst_settings | (id) | UNIQUE(user_id) | users CASCADE | — | surrogate PK + natural key both present |
| feature_submissions | (id) | — | users CASCADE | — | — |
| feature_votes | (id) | unique_user_feature(user_id,feature_id) | users CASCADE | — | **feature_id has no FK to feature_submissions** |
| video_requests | (id) | — | users **NO ACTION** (dump says NOT VALID; validated by 20260312000100) | — | seed/prod drift only |
| regime_daily_snapshots | (id) | UNIQUE(snapshot_date) | — | — | global table |
| bookmap_sync_request, support_requests, user_notifications, user_patterns, user_profiles, user_trading_preferences, user_rithmic_config, voice_training_feedback, mindfulness/coaching leftovers | (id) or (user_id) | as dumped | users CASCADE | — | conforming |
| sierra_chart.hiro_flatline_signals / roll_periods / spotgamma_daily_levels (mirrored into primary seed) | (id) / (id) / (level_date,symbol) | — | none | — | mirrors, no FK possible |

## B. public schema — seed post-dump appends (db/schema_test_seed.sql:5880–7532), 20 tables

| table | PK | natural / unique keys | FKs out | FKs in | verdict |
|---|---|---|---|---|---|
| user_playbook_definitions | (id UUID) | UNIQUE(public_id) | users(auth0_id) **NO ACTION** | sg_rulebook_firings, sg_rulebook_stats, playbook_instrument_membership | **parent_playbook_id TEXT, self-ref, no FK** |
| sg_rulebook_firings | (id) | — | user_playbook_definitions CASCADE | sg_rulebook_outcomes | conforming |
| sg_rulebook_outcomes | (id) | UNIQUE(firing_id) | sg_rulebook_firings CASCADE | — | conforming |
| sg_rulebook_stats | (playbook_id) | = PK | user_playbook_definitions CASCADE | — | conforming |
| sg_playbook_regime_filters | (playbook_id TEXT) | = PK | — | sg_playbook_content, playbook_votes | **TEXT id space disjoint from UPD.public_id** |
| sg_playbook_content | (playbook_id TEXT) | = PK | sg_playbook_regime_filters CASCADE | — | conforming |
| playbook_votes | (user_id, playbook_id) | = PK | users CASCADE; sg_playbook_regime_filters CASCADE | — | conforming |
| playbook_instrument_membership | (playbook_id, instrument_symbol) | = PK | user_playbook_definitions CASCADE; **instruments(symbol) CASCADE** | — | global ref table cascades into per-user rows → F16 |
| sg_transferability_verdicts | (playbook_public_id, instrument) | = PK | **none** | — | → F12 |
| sg_forward_validation | (playbook_public_id, instrument) | = PK | **none** | — | → F12 |
| instruments | (symbol) | — | self ×3: tracked_index / proxy_futures / etf_proxy → instruments(symbol) SET NULL DEFERRABLE | playbook_instrument_membership | 2-cycles (CL↔USO) exist; SET NULL + DEFERRABLE makes them safe |
| options_strategies | (id SERIAL) | UNIQUE(position_group_id) | users **NO ACTION** | logical_trades.strategy_id (SET NULL) | **no FK to logical_trades** → F2 |
| option_position_verdicts | (position_group_id) | = PK | users **NO ACTION** | — | **no FK to options_strategies or logical_trades** → F2 |
| option_materialization_jobs | (id) | UNIQUE(dedupe_key) — global, but hash includes user_id | users **NO ACTION** | — | `logical_trade_ids UUID[]` / `position_group_ids UUID[]` = FK-shaped arrays, unenforceable by construction |
| spotgamma_watchlist | (sym) | = PK | — | — | mirror of a Sierra table, no FK possible |
| options_strategy_templates | (strategy_type) | = PK | — | — | conforming |
| trade_flow_alignment | (id) | UNIQUE(trade_id) | logical_trades CASCADE | — | **user_id has no FK** |
| flow_alignment_edge_stats | (id) | UNIQUE(pass,family,instrument) | — | — | global stats table |
| coach_conversations | (conversation_id TEXT) | = PK, **global not tenant-scoped** | **none** | coach_turns | → F7 |
| coach_turns | (id BIGINT) | **none** | coach_conversations CASCADE | — | no (conversation_id,turn_id) uniqueness → replay duplicates |

## C. public schema — tables that exist ONLY in db/migrations (31)

| table | PK | unique keys | FKs out | verdict |
|---|---|---|---|---|
| attribution_signals | (id) | UNIQUE(logical_trade_id,chunk_id,playbook_id) | **none — all three targets exist** | **playbook_id typed uuid vs playbooks.id integer** → F1 |
| transcription_jobs | (id) | uq idx(recording_session_id) | **none** | recording_session_id orphans on user delete → F10 |
| transcription_corrections | (id) | uq idx(user_id,lower(original),lower(corrected)) | **none** | source_chunk_id uuid, no FK |
| phonetic_mappings | (id) | uq idx(COALESCE(user_id,''),lower(spoken)) | **none** | user_id no FK; NULL-sentinel key is correct |
| idempotency_keys | (idempotency_key, user_id) | = PK | **none** | user_id no FK (acceptable — TTL table) |
| regime_cell_stats | (id) | UNIQUE(user_id,window_days,slice_type,slice_value,gamma,vol,vix,tod) | **none** | user_id no FK **and no RLS** (deferred by comment) |
| voice_guardrail_signals | (id) | — | users NO ACTION; transcriptions CASCADE | conforming |
| guardrail_cues | (id) | — | users NO ACTION; voice_guardrail_signals CASCADE | conforming |
| guardrail_feedback | (id) | UNIQUE(cue_id) | guardrail_cues CASCADE; users NO ACTION | conforming |
| guardrail_outcome_links | (id) | UNIQUE(cue_id,logical_trade_id) | guardrail_cues CASCADE; logical_trades CASCADE | conforming |
| guardrail_user_priors | (id) | UNIQUE(user_id) | users NO ACTION | surrogate PK + natural key |
| pre_computed_coaching | (id) | UNIQUE(user_id,target_date) | **none** | user_id no FK |
| morning_feeds | (id) | UNIQUE(user_id,feed_date) | pre_computed_coaching(id) **NO ACTION** | blocks pcc deletes |
| session_analysis | (id) | UNIQUE(session_id) | recording_sessions CASCADE | user_id no FK |
| coaching_memos | (id) | UNIQUE(idempotency_key) | **none** | user_id no FK |
| educators | (id) | UNIQUE(slug), UNIQUE(owner_auth0_id) | **none** | owner_auth0_id no FK → F9 |
| educator_users | (id) | UNIQUE(auth0_id) | educators CASCADE | **auth0_id no FK — this is the access grant** → F9 |
| educator_recordings | (id) | uq(educator_id,external_ref) | educators CASCADE | conforming |
| educator_transcripts | (id) | UNIQUE(recording_id) | educator_recordings CASCADE; educators CASCADE | conforming |
| educator_briefings | (id) | UNIQUE(recording_id) | educator_recordings CASCADE; educators CASCADE | conforming |
| recap_shares | (id) | UNIQUE(token) | educator_recordings CASCADE; educators CASCADE | conforming |
| educator_usage_events | (id) | — | educators CASCADE; educator_recordings SET NULL | conforming |
| educator_zoom_connections | (id) | UNIQUE(educator_id), UNIQUE(zoom_account_id) | educators CASCADE | conforming |
| educator_oauth_states | (nonce) | = PK | educators CASCADE | conforming |
| support_intake_events | (id) | UNIQUE(sequence_id), UNIQUE(ticket_id) | users(auth0_id) SET NULL | best FK hygiene in the repo |
| support_intake_processing_events | (id) | UNIQUE(intake_event_id,idempotency_key) | support_intake_events CASCADE | conforming |
| apns_device_tokens | (user_id, token) | = PK | **none** | user_id no FK |
| apns_push_log | (id) | — | **none** | service ledger |
| sg_token_refresh_runs | (id) | — | — | service ledger, no tenant |
| deploy_drift_alert_state | (repo) | = PK | — | ops state |
| stale_pr_alert_state | (repo, pr_number) | = PK | — | ops state |

## D. Sierra DB (db/schema_test_seed_sierra.sql) — 52 base tables + 19 partitions. **Total FKs in the entire database: 1.**

Deviating rows only:

| table | PK | unique keys | FKs | verdict |
|---|---|---|---|---|
| **sierra_ohlc_5min** | **NONE** (id int NOT NULL, seq default, no constraint) | uq_5m_spine(instrument, contract, timestamp) — instrument and timestamp are **NULLABLE** | none | → F8 |
| sierra_ohlc_1min | (instrument, contract, timestamp) via constraint named `sierra_ohlc_1min_heap_pkey` | — | none | PARTITION BY RANGE(timestamp); PK includes partition key ✓; constraint name is a stale heap-era artifact |
| sierra_adr_data_v2 | (exchange, instrument, timestamp) via constraint named **`sierra_adr_data_v3_pkey`** | — | none | constraint name names a different table than it sits on (rename artifact) |
| gsst_signals | (id) | UNIQUE(user_id,symbol,trade_date,direction) | none possible (separate DB) | user-scoped, cross-DB, no RLS → F13 |
| hiro_divergence_preferences | (user_id) | = PK | none possible | user-scoped, cross-DB, no RLS → F13 |
| hiro_divergence_signals | (id) | uq idx(user_id,instrument,date(ts@NY)) | none possible | user-scoped, cross-DB, no RLS → F13 |
| hiro_flatline_user_prefs | (user_id) | = PK | none possible | user-scoped, cross-DB, no RLS → F13 |
| spotgamma_level_history | (id) | UNIQUE(instrument,level_type,price_level,appearance_date) | **spotgamma_level_memory(id) CASCADE** — the only FK in the DB | conforming |
| spotgamma_vx_term | (contract, snapshot_date) | = PK | none | carries `sample_time` but keys on date → intraday samples overwrite |
| spotgamma_market_context | (id) | UNIQUE(email_message_id), UNIQUE(context_date,session) | none | conforming |
| sierra_ohlc_1min_p2025_01 … p2026_07 (19 partitions) | inherited | inherited | none | conforming as a group |

Conforming remainder (41 tables — confluence_run_log, confluence_zones, emini_addict_gapfill, gamma_density_settings, gamma_density_zones, gap_fill_statistics, hiro_daily_snapshot, hiro_flatline_rolling_stats, hiro_flatline_signals, ib_daily_stats, ibb_auto_detection_log, ibb_signals, level_edge_baselines, menthorq_daily_gex, menthorq_v2, qscore_daily, roll_periods, sierra_ohlc_1s, sierra_tick_data, spotgamma_daily_levels, strategy_level_touches, spotgamma_hiro_additional, spotgamma_running_hiro_overview, spotgamma_level_memory, spotgamma_level_touches, spotgamma_trace, spotgamma_hiro_tick, spotgamma_v3_snapshot, spotgamma_equity_chart_levels, spotgamma_tns_highlights, spotgamma_v4_hiro, zdpsb_signals, tws_ohlc_1min, spotgamma_synth_oi_daily, spotgamma_synth_oi_chart, spotgamma_trace_stats, spotgamma_trace_lens, sierra_meta.roll_calendar, sierra_meta.roll_windows, + 2 mirrors): each has a declared PRIMARY KEY and, where a natural key exists, a matching UNIQUE constraint; none declares or could declare a foreign key.

## E. Cascade tree from `users` — what one DELETE actually does

```
DELETE FROM users WHERE auth0_id = X
├─ CASCADE (28 tables, deleted silently):
│   api_keys, audit-free tables…, bookmap_sync_request, coaching_sessions ─► user_feedback.session_id SET NULL
│   daily_coaching_briefs, deleted_execution_ids  ← RE-IMPORT TOMBSTONES DESTROYED
│   feature_submissions, feature_votes, gsst_compliance_cache, health_metrics,
│   mindfulness_sessions, ml_verification_stats, ml_verification_votes,
│   playbook_taps, playbook_votes, recall_frames, report_registry ─► report_findings CASCADE,
│   recording_sessions ─► recording_chunks ─► recording_chunk_entities CASCADE
│   │                                      └─► trade_voice_segments CASCADE
│   │                     └─► session_analysis CASCADE
│   rithmic_fill_retry_queue, sg_rule_compliance, support_requests, trade_notes,
│   user_account_risk, user_feedback, user_gsst_settings, user_instrument_risk,
│   user_notifications, user_patterns, user_profiles, user_rithmic_config,
│   user_trading_preferences, voice_match_views, voice_training_feedback,
│   user_risk_profiles ──► user_cursor_rules (NO ACTION) ✗ ABORTS
└─ NO ACTION / RESTRICT — every one of these ABORTS the whole statement:
    logical_trades, raw_trades, transcriptions (RESTRICT), trade_excursions,
    pending_excursions, gsst_rule_compliance, ibb_rule_compliance,
    zdpsb_rule_compliance, video_requests, user_playbook_definitions,
    options_strategies, option_position_verdicts, option_materialization_jobs,
    voice_guardrail_signals, guardrail_cues, guardrail_feedback,
    guardrail_user_priors, morning_feeds→pre_computed_coaching
```

**Which single DELETE removes trade history?** None can. `DELETE FROM logical_trades WHERE id=$1` is the intended one — it CASCADEs away gsst/ibb/sg/zdpsb_rule_compliance, pending_excursions, trade_excursions, trade_zone_attribution, trade_voice_segments, trade_flow_alignment, trade_notes, guardrail_outcome_links, and SET NULLs playbook_taps + transcriptions — but `raw_trades_logical_trade_id_fkey` is **NO ACTION**, so the statement fails unless raw_trades is deleted or unlinked first. Both real call sites do that by hand (services/logical_trades.py:492 deletes, routers/trade_import/rebuild.py:206 unlinks); one one-off script does it backwards (F14).

**What should not be CASCADE:** `trade_zone_attribution.zone_id → scotts_zones_game_board CASCADE` (F3) and `playbook_instrument_membership.instrument_symbol → instruments CASCADE` (F16) both let a delete on a *global, non-tenant* reference row destroy per-user analytical history across every tenant. Both should be RESTRICT. `deleted_execution_ids` CASCADEing off users is also wrong-direction: it is the re-import tombstone, so it must outlive the user, not vanish with them.

---

## LENS 6/6 — Sierra database: every table, partition/hypertable object, stored function, trigger, sequence, and the two-database (FDW) boundary.

**Coverage.** ENUMERATED (not sampled): all 68 `CREATE TABLE` objects in db/schema_test_seed_sierra.sql (49 base tables + 19 sierra_ohlc_1min partitions — I grepped and counted them, matching the stated 68); all 5 Sierra views (ohlc_1min_freshness, ohlc_coverage_comparison, sierra_ohlc_1sec, sierra_adr_data, plus mv_regime_minute_snapshot from migration); all 18 Sierra sequences (every one has an explicit ALTER SEQUENCE ... OWNED BY — I read all 18 OWNED BY lines); all 11 Sierra stored functions and all 4 Sierra triggers (read in full, seed lines 192-443 and 3760-3781); all 24 primary-DB functions and 12 primary-DB triggers by name (grep of `^CREATE FUNCTION|^CREATE TRIGGER` in db/schema_test_seed.sql, cross-checked each name against db/migrations/ for a defining migration); all 3 foreign tables + 1 foreign server + the FDW bootstrap script; the file list of all 52 db/migrations_sierra/*.sql. I read ~15 of those 52 migrations in full (the baseline, both partition migrations, both columnstore migrations, the chunk/retention migration, the three get_contract_at rewrites, the ghost-object drops, the 1s-partition drop, the equity-excursion migration in the primary set) and read only the grep-matched lines of the rest.

SECURITY DEFINER: `rg -n "SECURITY DEFINER" db/` returns ZERO hits across both dumps and all migrations. There is no SECURITY DEFINER privilege-escalation surface in either database. The nearest analogue is the FDW user mapping (finding sierra-11 / sierra-19).

RLS in Sierra: `grep -c "ROW LEVEL SECURITY" db/schema_test_seed_sierra.sql` = 0, and there are no CREATE POLICY / GRANT / ALTER DEFAULT PRIVILEGES statements anywhere in the Sierra dump. The Sierra DB has no row-level security at all, yet holds per-user rows in 7 tables (gsst_signals, ibb_signals, hiro_flatline_signals, hiro_flatline_user_prefs, hiro_divergence_signals, hiro_divergence_preferences, zdpsb_signals). Isolation there is 100% app-level WHERE user_id. On the specific flagged question "any partition-creation path that omits RLS or an index the parent has": no, because there is no RLS to omit, and PostgreSQL propagates parent-level indexes to new partitions automatically (all three sierra_ohlc_1min indexes are declared on the parent, seed:3431/3487/3494), so schedulers/ensure_sierra_partitions.py minting a bare `PARTITION OF ... WITH (autovacuum…)` inherits them correctly. What the scheduler path DOES lose is described in sierra-06/sierra-07.

NOT COVERED / would need a live DB: whether prod's Sierra `sierra_ohlc_1min` is today a hypertable or native RANGE partitions (repo sources contradict each other — sierra-07); the actual retention high-water mark on spotgamma_running_hiro_overview (sierra-08's hole size is arithmetic from two file dates, not measured); whether the ADR TXT-batch importer ever resends rows older than the 7-day columnstore window; the live server TimeZone GUC that decides whether sierra-15 is currently firing. I ran no psql and modified nothing.

## A. Sierra tables — deviating rows only (49 base tables examined; the 19 `sierra_ohlc_1min_p2025_01…p2026_07` partitions are summarised in section B)

| table | key | writer | reader | partition/retention | race | deviation |
|---|---|---|---|---|---|---|
| `sierra_ohlc_1min` | PK (instrument, contract, timestamp) | routers/sierra_ingest.py ACSIL stream + TXT batch | market_state, sierra_marketdata, FDW→primary | RANGE-partitioned by month in dump; hypertable in prod per CLAUDE.md:341 | yes — stream + batch upsert same key, guarded by `WHERE EXCLUDED.last <> 0 OR t.last = 0` | **parent + all 19 partitions exist only in the seed; no migration creates them (sierra-06)**; readers drop `contract` (sierra-01) |
| `sierra_ohlc_1s` | PK (instrument, contract, timestamp) | none live (4 one-off scripts) | 5 live call sites | **partitioned parent with ZERO partitions** — deliberate "EMPTY SHIM" | n/a | **always returns 0 rows; INSERT impossible (sierra-02)**; 2 readers select a column it does not have (sierra-03) |
| `tws_ohlc_1min` | PK (instrument, contract, timestamp) | TWS ingest (dormant since 2026-02) | `compute_excursions_1m` STEP 1 via FDW | plain heap | no | primary MFE/MAE prefers a feed dormant 6 months |
| `sierra_adr_data_v2` | PK (exchange, instrument, timestamp) | routers/sierra_ingest.py `/indicator-bars` (ON CONFLICT DO UPDATE) | freshness endpoint | hypertable + columnstore after 7d (20260806090000:71-77) | yes | ON CONFLICT DO UPDATE into a compressed chunk (>7d backfill) is unsupported in Timescale |
| `hiro_flatline_signals` | id (seq) | live detector + `scripts/hiro_flatline_backfill.py` (`is_backtest: True`) | stats service + stats_sync | none | yes | **stats queries never filter `is_backtest` (sierra-04)** |
| `spotgamma_running_hiro_overview` | (sym, snapshot_ts) | spotgamma_client scheduler | 45 files + `mv_regime_minute_snapshot` | hypertable, 7d chunks, **90-day retention** (20260612075902:17) | no | retention added 2026-06-12, AFTER the matview that unions across it (sierra-08) |
| `spotgamma_v4_hiro` | minute_utc | **0 writers** (dead since 2026-04-17) | 49 files + matview historical slab | 1-month chunks | n/a | frozen slab; the matview's only pre-2026-04-20 source |
| `spotgamma_hiro_additional` | (symbol, minute_utc) | **0 writers** (dead since 2026-04-17) | 16 files incl. `_fetch_vix` | 1-month chunks | n/a | intentionally left broken so `_fetch_vix` raises (market_state.py:336-344) |
| `spotgamma_level_touches` | id uuid | detector | analytics | none | yes | trigger `spotgamma_touches_updated` calls `update_spotgamma_memory_timestamp()`, **not** `update_touches_timestamp()` — the latter is dead code |
| `spotgamma_tns_highlights` | PK changed to (fetched_at, id) | spotgamma_client | routers/tns_highlights.py (≤1440 min) | hypertable, columnstore 7d, **90d retention** | dedup by `payload_md5` in a 15-min window | dedup key added 2026-08-06; anything stored before that is duplicated |
| `sierra_ohlc_5min` | id (int4 seq) + UNIQUE (instrument, contract, timestamp) | 14 write statements | 85 files; `get_active_contract` fallback | 1-month chunks | yes | only int4 sequence on a bar table; `AS integer` caps at 2.1B |
| `roll_calendar` / `roll_windows` | id + UNIQUE(root,start_utc) + **EXCLUDE gist no-overlap** | 20260424000000 seed INSERTs | `get_contract_at`, `slice_calendar` | none | no | overlap correctly prevented; functions still return session-TZ wall clock named `*_utc` (sierra-15) |
| `sierra_meta.instruments` | — | 20260312000100 | `get_contract_at` (plpgsql version) | none | n/a | **absent from the seed dump entirely**; the dump's `get_contract_at` never reads it (sierra-05) |

**Conforming (36 tables):** `confluence_run_log`, `confluence_zones`, `emini_addict_gapfill`, `gamma_density_settings`, `gamma_density_zones`, `gap_fill_statistics`, `gsst_signals`, `hiro_daily_snapshot`, `hiro_divergence_preferences`, `hiro_divergence_signals`, `hiro_flatline_rolling_stats`, `hiro_flatline_user_prefs`, `ib_daily_stats`, `ibb_auto_detection_log`, `ibb_signals`, `level_edge_baselines`, `menthorq_daily_gex`, `menthorq_v2`, `qscore_daily`, `roll_periods`, `sierra_tick_data`, `spotgamma_daily_levels`, `spotgamma_equity_chart_levels`, `spotgamma_hiro_tick`, `spotgamma_level_history`, `spotgamma_level_memory`, `spotgamma_market_context`, `spotgamma_synth_oi_chart`, `spotgamma_synth_oi_daily`, `spotgamma_trace`, `spotgamma_trace_lens`, `spotgamma_trace_stats`, `spotgamma_v3_snapshot`, `spotgamma_vx_term`, `strategy_level_touches`, `zdpsb_signals` — each has a declared PK or unique constraint, a single identifiable writer, and upserts on its key. The 7 tables carrying `user_id` among them sit in a database with **no RLS at all** (see coverage note).

## B. Partitioned / hypertable objects (both DBs)

| object | key | how partitions appear | row with no partition | inherits |
|---|---|---|---|---|
| `sierra_chart.sierra_ohlc_1min` | `timestamp` (timestamptz), monthly RANGE | seed dump (p2025_01…p2026_07), migration 20260530120500 (p2026_08…10), `schedulers/ensure_sierra_partitions.py` (current + `SIERRA_PARTITION_MONTHS_AHEAD`=3) | **hard error** `no partition of relation found for row` — there is no DEFAULT partition | parent PK + 3 parent indexes propagate automatically; storage params re-specified by hand each time |
| `sierra_chart.sierra_ohlc_1s` | `timestamp`, monthly RANGE | **none** — all 16 detached and dropped by 20260226070000 | INSERT impossible | n/a |
| Timescale hypertables (`spotgamma_hiro_tick`, `spotgamma_running_hiro_overview`, `spotgamma_v3_snapshot`, `menthorq_v2`, `sierra_ohlc_5min`, `spotgamma_hiro_additional`, `spotgamma_v4_hiro`, `spotgamma_synth_oi_daily`, `spotgamma_synth_oi_chart`, `spotgamma_trace_lens`, `spotgamma_trace_stats`, `sierra_adr_data_v2`, `spotgamma_tns_highlights`) | see migrations 20260612075902, 20260806090000, 20260806091000 | Timescale creates chunks automatically | n/a | **every one of these DDL blocks is a guaranteed no-op in CI** (sierra-17) |
| `public.mv_regime_minute_snapshot` (matview, Sierra DB) | `minute_utc` unique | REFRESH | n/a | unions a dead source with a retention-policied one (sierra-08) |

## C. Functions & triggers

| name | DB | defined in a migration? | volatility | notes |
|---|---|---|---|---|
| `sierra_chart.get_active_contract` | sierra | **NO — seed only** | plpgsql (VOLATILE) | **references `sierra_chart.contract_calendar`, which does not exist** (sierra-14) |
| `sierra_chart.update_spotgamma_memory_timestamp` | sierra | **NO — seed only** | trigger | bound to 2 triggers |
| `sierra_chart.update_touches_timestamp` | sierra | **NO — seed only** | trigger | **bound to nothing — dead** |
| `sierra_meta.get_contract_at` | sierra | yes ×3 (…305072517, …312000200, …424000000) | STABLE | **dump holds the OLD `LANGUAGE sql` version; migration holds `LANGUAGE plpgsql` + registry** (sierra-05) |
| `sierra_meta.get_roll_windows_at` | sierra | yes ×3 | STABLE | same divergence |
| `sierra_meta.slice_calendar` | sierra | yes (…412000100) | STABLE | dump matches migration; TZ defect (sierra-15) |
| `sierra_meta.get_cme_trade_context` | sierra | yes (…424000000) | STABLE | correct — uses explicit `AT TIME ZONE 'America/Chicago'` |
| `sierra_meta.roll_calendar_version` / `roll_windows_version` | sierra | yes (…424000000) | STABLE | sha256 digests; correct |
| `sierra_meta.touch_updated_at` | sierra | yes (…424000000) | trigger | bound to 2 triggers |
| `public.to_ticks(numeric,text)` | primary | **NO — seed only**, but *called* by 4 migrations | IMMUTABLE | (sierra-12) |
| `public.compute_excursions_batch_1m` | primary | **NO — seed only**, called by 3 scripts | VOLATILE | (sierra-12) |
| `public.calculate_excursion_retry_delay` | primary | **NO — seed only** | IMMUTABLE | correctly immutable |
| `public.ticks_per_point` | primary | yes (20260314000100) | IMMUTABLE | **dump lacks the QQQ branch the migration adds** (sierra-13) |
| `public.compute_excursions_1m` / `verify_trade_prices_1m` / `map_micro_to_base` / `map_micro_to_base_contract` | primary | yes | plpgsql | cross-DB via FDW; see section D |
| `public.compute_dedupe_key`, `get_cme_trading_date`, `get_user_risk_unit`, `is_level_touched_today`, `record_level_touch`, `start_touch_outcome_tracking`, `expire_tracking_for_date`, `update_touch_outcome`, `update_trade_note`, 7 × `update_*_timestamp` triggers, `sierra_chart.detect_level_touches` | primary | **NO — seed only (16 of 24)** | trigger/VOLATILE | `compute_dedupe_key` is already logged (known #4) |

No function in either DB is IMMUTABLE-mislabelled *and* used in an index. The only expression index is `idx_unique_daily_divergence_signal … date(signal_timestamp AT TIME ZONE 'America/New_York')` (seed:3669), which uses PostgreSQL's own genuinely-IMMUTABLE `timezone(text,timestamptz)`. No SECURITY DEFINER anywhere.

## D. Two-database boundary

| surface | direction | mechanism | privileges | failure mode |
|---|---|---|---|---|
| `sierra_chart_remote.sierra_ohlc_1min` | primary → Sierra | postgres_fdw, `sierra_srv` | user mapping FOR CURRENT_USER with the raw Sierra URL user+password | Sierra down ⇒ `compute_excursions_1m` STEP 2 raises inside the primary transaction |
| `sierra_chart_remote.tws_ohlc_1min` | primary → Sierra | same server | same | **destroyed by re-running the "idempotent" setup script (sierra-11)** |
| `sierra_chart.sierra_ohlc_1s` (foreign table in the **primary** DB, seed:3248) | primary → Sierra | same server | same | points at the empty shim ⇒ always 0 rows; also destroyed by sierra-11 |
| App-level correlation | both | ~39 modules hold both a primary session and `get_sierra_pool_conn()` | two independent asyncpg/SQLAlchemy pools, **no 2PC** | a Sierra read that fails mid-request leaves the primary write already committed; `utils/safe_task.py` log-and-drop (known #17) applies |
| Schema name collision | — | `sierra_chart` exists in **both** databases with different contents | — | `sierra_chart.detect_level_touches` lives in the primary dump while a Sierra migration drops the Sierra copy |

---

## Lens 4/6 — column, type and constraint integrity across every table in db/schema_test_seed.sql + db/schema_test_seed_sierra.sql, cross-checked against read/write sites in routers/, services/, models/, schedulers/, worker.py

**Coverage.** ENUMERATED (not sampled): I parsed every CREATE TABLE block in db/schema_test_seed.sql (7532 lines) and db/schema_test_seed_sierra.sql (3895 lines) with a block-aware awk extractor — 1378 column definitions across 149 base tables + 19 sierra_ohlc_1min partitions. Of those, 574 columns matched the MONEY/QUANTITY/PRICE/MULTIPLIER/RATE/TIME lens and are the unit_count. I enumerated exhaustively for: (a) full declared-type distribution of all 574 in-scope columns; (b) every column typed text/varchar/integer/double-precision whose NAME implies money, price, quantity or a multiplier; (c) every timestamp column, confirming exactly ONE naive column exists (mindfulness_sessions.session_time) and 128 timestamptz; (d) every enum-shaped text/varchar column, with a second block-aware pass that correctly attributes table-level CONSTRAINT ... CHECK lines to their columns (my first pass produced ~35 false positives; the corrected pass yields 53 genuinely unconstrained enum columns); (e) every jsonb column (81); (f) dead tables, by grepping each of the 149 table names against services/ routers/ models/ utils/ schedulers/ worker.py.

NOT fully covered / SAMPLED, stated honestly:
- "Columns the code reads that DO NOT EXIST" — I did NOT build a complete SQL-identifier-vs-schema validator. I grepped the OHLC-table read sites exhaustively (that is where the cluster is) and spot-checked logical_trades, raw_trades, trade_excursions, option_position_verdicts, trade_flow_alignment, user_account_risk, user_risk_profiles, user_trading_preferences, gsst/ibb/zdpsb signals. Three phantom-column sites were found and confirmed; there are almost certainly more in the ~90 routers I did not open.
- Dead-COLUMN analysis was run exhaustively only on 5 hot tables (logical_trades, raw_trades, trade_excursions, instruments, option_position_verdicts); dead-TABLE analysis was run on all 149.
- db/migrations/*.sql (131 files): I did NOT read all 131. I read 20260314000100_equity_excursion_support.sql and 20260709120000_add_import_price_verification.sql in full and grepped the rest for specific constraint names. Seed-vs-migration drift is therefore reported only where I read both sides; more drift is likely.
- I ran NO database, NO tests, NO app. Every claim marked CONFIRMED was read at the exact line I quote. Where I could not read both halves of a claim I marked it INFERRED and said what would confirm it.
- ludwig/, sierra/, scripts/one-off/ were only grepped, not audited.

## In-scope unit inventory: 574 money / quantity / price / multiplier / rate / time columns

### Conforming population (summary — 512 rows not listed individually)

| declared type | count | verdict |
|---|---|---|
| `timestamp with time zone` / `timestamptz` | 128 | **OK** — every instant column in both schemas is tz-aware. Exactly one naive exception exists (listed below). No `timestamp without time zone` anywhere. |
| `numeric(12,4)` | 45 | OK for equity/index/most futures; insufficient for 6J/M6J/ZN (see px-01) |
| `numeric(14,4)` / `numeric(14,6)` / `numeric(14,8)` | 10 + instruments cols | OK — `instruments.tick_increment NUMERIC(14,8)` is the only column in either schema that can represent a 6J tick |
| `numeric(5,2)` / `numeric(3,2)` / `numeric(6,4)` / `numeric(5,4)` | 51 | OK — bounded ratios/percentiles/confidences, most with range CHECKs |
| `date` | 40 | OK |
| `integer` (counts: bar_count, sample_size, n_a, volume, num_trades, leg_count, attempt_count, wins/losses) | ~70 | OK — genuinely discrete |
| `bigint` (order_number, volume) | 8 | OK |
| `double precision` | 6 | all in `sierra_chart.spotgamma_synth_oi_daily` (skew/iv/garch analytics, never money) — OK |
| `jsonb` | 81 total, 12 in-scope | mostly raw-vendor-payload archives — OK; one money-bearing exception below |

### Deviating rows (62)

| table.column | declared type | prec/scale | null | default | verdict |
|---|---|---|---|---|---|
| `public.trade_excursions.data_status` | text | — | NOT NULL | **`'ok'`** | **BROKEN** — default is not in its own CHECK `('complete','gap','low_coverage','no_coverage','partial')` (seed:2332). Any INSERT omitting it → CheckViolation. **exc-01** |
| `public.logical_trades.total_quantity` | integer | — | NOT NULL | **`0`** | **BROKEN** — default violates `ck_logical_trades_qty_positive CHECK (total_quantity > 0)` (seed:1684). **lt-01** |
| `public.pending_excursions.status` | text | — | null | `'pending'` | **DRIFT** — seed CHECK omits `'skipped'`, which `worker.py:911` writes. **exc-02** |
| `public.logical_trades.direction` | character(1) | — | NOT NULL | none | **BROKEN for one writer** — `routers/trade_voice_segments.py:682` omits it → NotNullViolation. Vocabulary `B`/`S`. **lt-01** |
| `sierra_chart.sierra_ohlc_1min.open/high/low/last` | numeric(10,2) | 10,2 | NOT NULL | none | **PRECISION** — cannot represent SI(0.005), NG(0.001), ZB(0.03125), ZN(0.015625), 6E(0.00005), 6J(0.0000005). **ohlc-03** |
| `sierra_chart.sierra_ohlc_5min.open/high/low/last` | numeric(10,2) | 10,2 | null | none | same as above |
| `sierra_chart.tws_ohlc_1min.open/high/low/last` | numeric(10,2) | 10,2 | NOT NULL | none | same as above |
| `sierra_chart.sierra_tick_data.open/high/low/last` | numeric(12,2) | 12,2 | NOT NULL | none | same — TICK data at 2dp |
| `sierra_chart.sierra_ohlc_1s.open/high/low/last/close` | numeric(12,4) | 12,4 | **nullable** | none | **INCONSISTENT** — same price, 4dp here vs 2dp at 1min/5min; NULL-able while 1min is NOT NULL. `close` is a **dead column** (every reader does `last AS close`) |
| `public.raw_trades.price` | numeric(10,4) | 10,4 | NOT NULL | none | **PRECISION** — rounds 6E/6J/M6J/ZB/ZN fills at the storage boundary. **px-01** |
| `public.logical_trades.avg_entry_price` / `avg_exit_price` | numeric(10,4) | 10,4 | nullable | none | same. NULL has no defined meaning (open trade vs unknown) |
| `public.logical_trades.pnl_ticks` | integer | — | nullable | none | fractional ticks discarded; NULL undefined |
| `public.logical_trades.multiplier` | **INTEGER** | — | nullable | none | **WRONG TYPE** — comment (seed:6779) says it holds `contract_size`; seed sets MYM=0.5, MBT=0.1 |
| `public.logical_trades.entry_time` + `entry_time_utc` | timestamptz ×2 | — | NOT NULL / nullable | none | **UNCONSTRAINED PAIR** — nothing forces agreement; `bookmap_stats_import.py:318` writes a tz-stripped copy to one and the aware copy to the other. **tz-01** |
| `public.raw_trades.fill_time` + `fill_time_utc` | timestamptz ×2 | — | NOT NULL / nullable | none | same pair problem |
| `public.logical_trades.price_verification` | text | — | nullable | none | **NO CHECK**; 5-value vocabulary lives only in a plpgsql body. **pv-01** |
| `public.logical_trades.price_verification_at` | timestamptz | — | nullable | none | **DEAD** — zero references in Python |
| `public.logical_trades.price_verification_detail` | jsonb | — | nullable | none | **DEAD** — zero references in Python |
| `public.logical_trades.asset_class` | text | — | nullable | none | CHECK vocabulary excludes `'option'`, which `services/logical_trades.py:320` reads. **ac-01** |
| `sierra_chart.gsst_signals.direction` | varchar(10) | — | NOT NULL | none | **NO CHECK**; Pydantic `direction: str` unvalidated; evaluator treats anything ≠ "LONG" as SHORT. **gsst-02** |
| `sierra_chart.gsst_signals.outcome` | varchar(20) | — | NOT NULL | `'PENDING'` | **NO CHECK** (siblings `ibb_signals.outcome`, `zdpsb_signals.outcome` DO have one) |
| `sierra_chart.gsst_signals.pnl_ticks` | integer | — | nullable | none | written by hardcoded `int(pts*4)` in 2 places. **gsst-01** |
| `sierra_chart.gsst_signals.settings_contracts_per_50k` | integer | — | NOT NULL | none | position-size quantity as integer, no CHECK > 0 |
| `sierra_chart.ibb_signals.pnl_ticks` / `zdpsb_signals.pnl_ticks` / `hiro_flatline_signals.pnl_ticks` / `hiro_flatline_rolling_stats.total_pnl_ticks` | integer | — | nullable | none | fractional ticks discarded |
| `public.coaching_sessions.total_pnl_ticks` | integer | — | nullable | `0` | 0 vs NULL indistinguishable |
| `public.user_account_risk.account_size` | numeric(15,2) | 15,2 | NOT NULL | **`25000.00`** | **BUSINESS-ASSUMPTION DEFAULT** — 10× the Python fallback. **rp-01** |
| `public.user_risk_profiles.account_size` | numeric(14,2) | 14,2 | NOT NULL | none | different scale from its twin; **no CHECK > 0** (twin has one) |
| `public.user_risk_profiles.default/low/high_risk_percent` | numeric(7,4) | 7,4 | **nullable** | 1.0 / 0.5 / 2.0 | **NO CHECK** — twin table constrains the same three to (0,100]; 500% is storable here |
| `public.user_risk_profiles.prop_multiplier` | numeric(8,4) | 8,4 | NOT NULL | **`1.0`** | multiplier default = silent "no prop scaling" |
| `public.trade_excursions.coverage_ratio` | numeric(3,2) | 3,2 | nullable | **`1.0`** | default asserts 100% bar coverage when the writer forgets |
| `public.option_position_verdicts.residual_category` | TEXT | — | nullable | none | **NO CHECK** while 3 sibling taxonomy cols in the same table have one. **rc-01** |
| `public.option_position_verdicts.delta/gamma/vega/theta/unexplained/total_pnl` | NUMERIC(14,4) ×6 | 14,4 | nullable | none | no CHECK that the five components sum to `total_pnl` |
| `public.option_position_verdicts.anti_pattern_tags` | TEXT[] | — | NOT NULL | `'{}'` | free-form array, no element vocabulary |
| `public.options_strategies.strategy_type` | TEXT | — | NOT NULL | none | **no CHECK and no FK** to `options_strategy_templates.strategy_type` (which is a PK) |
| `public.options_strategies.net_debit_credit / max_loss / max_profit` | NUMERIC(14,4) | 14,4 | nullable | none | sign convention lives only in a COMMENT; NULL overloaded ("undefined risk" vs "not computed") |
| `public.user_trading_preferences.commission_overrides` | jsonb | — | nullable | none | **MONEY IN JSONB** — only `jsonb_typeof='object'`; no key/value/sign constraint; no P&L reader. **co-01** |
| `sierra_chart.spotgamma_tns_highlights.premium` | jsonb | — | NOT NULL | none | money-named column as schemaless jsonb |
| `sierra_chart.spotgamma_daily_levels.data_timestamp` | **text** | — | nullable | none | **TIMESTAMP AS TEXT** — the only one in either schema. **txt-01** |
| `sierra_chart.level_edge_baselines.rr_ratio` | **text** | — | NOT NULL | none | **RATIO AS TEXT** |
| `public.sg_rule_compliance.entry_time_et` | varchar(10) | — | NOT NULL | none | wall-clock time as text, ET implied, no companion tz |
| `public.mindfulness_sessions.session_time` | **time without time zone** | — | nullable | none | only naive temporal column in 574 |
| `public.ml_verification_candidates.timestamp_start/_end` | numeric(10,2) | 10,2 | NOT NULL | none | time-offset-as-numeric (audio clip seconds) — acceptable but undocumented |
| `public.flow_alignment_edge_stats.mean_pnl_a` / `mean_pnl_b` | NUMERIC(12,4) | 12,4 | nullable | none | named "pnl" but populated from `pnl_ticks` (`services/flow_alignment_validator.py:72`) — unit mislabel |
| `public.report_findings.total_pnl` | integer | — | nullable | none | a P&L total as integer while its sibling `avg_pnl` is numeric(12,2) — **DEAD TABLE** |
| `public.report_findings.win_rate / avg_pnl / p_value / z_score / direction / regime` (18 cols) | mixed | — | — | — | **DEAD** — table referenced by no app code |
| `public.report_registry.*` (all cols) | mixed | — | — | — | **DEAD** — only `tests/realdb/test_rls_enforcement.py:576` |
| `public.user_patterns.*` / `public.user_profiles.*` (all cols) | mixed | — | — | — | **DEAD** — only realdb tests |
| 53 enum-shaped text/varchar columns with **no CHECK** (block-aware pass) | text / varchar | — | mixed | mixed | notable: `gsst_signals.direction`, `gsst_signals.outcome`, `gsst_signals.signal_source`, `hiro_divergence_signals.outcome`, `ibb_signals.regime/target_type/outcome_type`, `zdpsb_signals.outcome_type`, `level_edge_baselines.level_type/direction/data_source`, `confluence_zones.zone_type`, `gamma_density_zones.zone_type/threshold_source`, `qscore_daily.regime/option_label/volatility_label/momentum_label/seasonality_label`, `spotgamma_trace.pattern_type`, `report_findings.finding_type/direction`, `support_requests.status/request_type`, `feature_submissions.status/category`, `api_keys.key_type`, `audit_log.entity_type`, `coaching_sessions.risk_state`, `trade_flow_alignment.flow_type`, `options_strategies.strategy_type`, `option_position_verdicts.residual_category`, `menthorq_daily_gex.asset_class`, `sg_playbook_regime_filters.vol_state` |
| `sierra_chart.spotgamma_daily_levels` CHECK `spotgamma_daily_levels_price_range` | — | — | — | — | hardcoded price band `SPX call_wall BETWEEN 3000 AND 10000` — a market rally past 10000 rejects valid ingest |

---

## Lens 5/6 — migration ⇄ seed object-by-object drift (db/migrations 131, db/migrations_sierra 52, db/schema_test_seed.sql, db/schema_test_seed_sierra.sql, mark_dump_satisfied_migrations.py, lint-migrations.sh, lint-tenant-isolation.sh, .github/workflows/test.yml, Procfile, Makefile)

**Coverage.** ENUMERATED MECHANICALLY (every file, not sampled): all 183 migration files (131 primary + 52 sierra) parsed with awk/grep for up-section CREATE/DROP/ALTER TABLE, CREATE/DROP INDEX, CREATE/DROP POLICY, ENABLE/FORCE ROW LEVEL SECURITY, CREATE FUNCTION/TRIGGER/VIEW/MATERIALIZED VIEW, ADD CONSTRAINT, ADD/DROP COLUMN, INSERT/UPDATE/DELETE/TRUNCATE, and SET lock_timeout position; both seed files inventoried for the same classes; the two sets diffed per object class. The mark_dump_satisfied classifier was re-implemented in shell and run over both directories to reproduce its marked/deferred/partial verdicts. Every down-block was structurally compared to its up (ADD COLUMN vs DROP COLUMN counts, CREATE TABLE vs DROP TABLE, no-op detection).

READ IN FULL (not just grepped): mark_dump_satisfied_migrations.py, lint-migrations.sh, .github/workflows/test.yml, Procfile, Makefile, .migration-lint-baseline, and ~35 individual migrations named in findings. lint-tenant-isolation.sh and audit_rls_callers.py were read for scope/config only (first ~150 and ~40 lines respectively), NOT line-by-line — gate-01 rests on the SKIP_DIRS/changed-file logic I quoted, which I did read.

NOT COVERED / SAMPLED: (a) I could not run psql, so every claim about what production actually contains is INFERRED from migration text plus the dump; claims about the CI database are CONFIRMED from the seed + classifier logic. (b) Column-level drift: I enumerated all 47 ADD COLUMN sites and checked each against the seed by name, but I did NOT diff column TYPES/DEFAULTS/NOT-NULL for columns present in both — a type-level drift would be missed. (c) I did not read the bodies of every seed function to check for further references to dropped objects; dead-01 lists the six I found by cross-referencing the drop set, which may be incomplete. (d) FK constraint diff was not done exhaustively (only FK-supporting indexes). (e) Sequences: not diffed. (f) tests/realdb/*.py was not read, so I state what the CI schema can and cannot support, not which specific tests are affected. (g) A DELETE in scripts/refresh_sg_watchlist.py:437 was seen in passing and is out of this lens.

## A. Structural baseline (the frame everything else sits in)

| unit | migrations say | seed says | classifier verdict | runs in CI? |
|---|---|---|---|---|
| `20260222000000_baseline.sql` (primary) | up-section is `SELECT 1;` | 76 tables, ~30 functions, ~13 triggers, all pre-2026-02-22 objects | marked applied | n/a — nothing to run |
| `20260222000000_baseline.sql` (sierra) | up-section is `SELECT 1;` | 60 tables, 11 functions, 4 views | marked applied | n/a |
| classifier non-table branch (`mark_dump_satisfied_migrations.py:158`) | — | — | **92/131 primary + 36/52 sierra = 128/183 (70%) marked applied with zero verification** | never |
| classifier `any()` branch | — | — | 2 sierra migrations "partially present", warned, marked anyway | never |

## B. Tables

| object | in migrations | in seed | consequence |
|---|---|---|---|
| 39 primary tables (apns_device_tokens, apns_push_log, attribution_signals, coaching_memos, deploy_drift_alert_state, educator_briefings/oauth_states/recordings/transcripts/usage_events/users, educators, educator_zoom_connections, guardrail_cues/feedback/outcome_links/user_priors, idempotency_keys, morning_feeds, phonetic_mappings, pre_computed_coaching, recall_frames_2025_11…2026_03, recall_frames_default, recall_frames_new, recap_shares, regime_cell_stats, session_analysis, sg_token_refresh_runs, stale_pr_alert_state, support_intake_events, support_intake_processing_events, transcription_corrections, transcription_jobs, voice_guardrail_signals) | ✅ | ❌ | correctly DEFERRED → dbmate creates them. Self-healing, no finding. |
| `sierra_chart.spotgamma_watchlist` | ✅ `20260416161300:139` | ❌ | **`any()` rule marks the migration applied (3 sibling tables present) → never created.** sierra-01 |
| `sierra_meta.instruments` | ✅ ×2 | ❌ | created by the earlier migration (deferred); the later restore migration is `any()`-marked. Shape differs from prod. sierra-02 |
| `sierra_chart.regime_alignment_snapshots`, `scott_regime_matview_meta`, `spotgamma_flow_patrol`, `spotgamma_flow_patrol_symbols`, `spotgamma_ticker_profile`, `spotgamma_walkforward_signals`, `tigerdb_verdict`, `sierra_ohlc_1min_p2026_08/09/10` | ✅ | ❌ | deferred → created. no finding. |
| `audit_log` | created 20260224070000, **DROPPED 20260302100500:21**, then ALTERed by 20260310100000 and 20260728020000 | present, at the Feb-2026 shape | stream not replayable from empty. mig-02 |
| `alert_level_touches`, `level_touch_outcomes` | dropped 20260302100500 | absent as tables, but 6 seed FUNCTIONS still reference them | dead-01 |

## C. Partitions

| object | migrations | seed | consequence |
|---|---|---|---|
| `public.recall_frames` children | 6 created, renamed to `_ghost_*`, dropped; then `create_recall_partition()`/`ensure_recall_partitions()` mint them at runtime | **`PARTITION BY RANGE (ts_utc)` at :1970 with ZERO partitions; 0 occurrences of `PARTITION OF`/`ATTACH PARTITION` in the whole file** | every recall_frames INSERT in CI fails. seed-01 |
| `create_recall_partition` / `ensure_recall_partitions` | ✅ 20260306153000 | ❌ (0 occurrences) | rls-04, seed-01 |
| `sierra_chart.sierra_ohlc_1min_*` | p2026_08/09/10 added 20260530120500 | p2025_01 … p2026_07 | deferred → created. down-03 on rollback. |

## D. RLS

| object | migrations | seed | consequence |
|---|---|---|---|
| 41 of 68 `tenant_isolation`/`audit_select` policies (api_keys, logical_trades, raw_trades, transcriptions, health_metrics, trade_excursions, pending_excursions, user_* ×12, gsst/ibb/zdpsb_rule_compliance, recall_frames, …) | `nullif(current_setting(…),'')` wrap applied by 20260419092247 | **unwrapped `current_setting(…)` — the pre-fix vulnerable shape** (e.g. :5557, :5599) | rls-01 |
| `deleted_execution_ids` ENABLE+FORCE+policy | ✅ 20260619130200:27-40 | **table present at :1328, no RLS, no policy** | rls-02 |
| `playbook_votes` FORCE | ✅ 20260619130100:24 | **ENABLE only, :7187 — the only ENABLE-without-FORCE table in the seed** | rls-03 |
| `audit_log` policies | migrations create `tenant_isolation`; 20260419092247:93 does `DROP POLICY audit_select` (no IF EXISTS) for a policy NO migration creates | `audit_select` + `audit_insert WITH CHECK (true)` | mig-02 |
| all other ENABLE/FORCE pairs | — | — | in sync (verified per table) |

## E. Constraints / functions / triggers

| object | migrations | seed | consequence |
|---|---|---|---|
| `is_valid_playbook_primitive_name()` + CHECK `user_playbook_definitions_conditioning_name_valid` | ✅ 20260501060000:141 | **0 occurrences; and the seed's own 6 playbook rows violate it** | seed-03 |
| `audit_log_action_check` | regex `^[a-z][a-z0-9_]{0,63}$` (20260728020000) | 3-value enum `create/update/delete` at :1243 | seed-05 |
| `set_playbook_votes_updated_at` + `trg_playbook_votes_updated_at` | ✅ | ❌ | `updated_at` never advances on votes in CI |
| `expire_tracking_for_date`, `is_level_touched_today`, `record_level_touch`, `start_touch_outcome_tracking`, `update_touch_outcome` (:503,:590,:670,:709,:873) | dropped / never created | present, bodies reference dropped tables | dead-01 |
| `sierra_chart.detect_level_touches` (:992) | **explicitly dropped as "created by mistake in wrong DB"** 20260302100800:16 | present in the PRIMARY seed | dead-01 |
| `compute_excursions_1m`, `verify_trade_prices_1m`, `map_micro_to_base_contract`, `ticks_per_point`, `set_instruments_updated_at`, `set_options_strategies_updated_at`, `set_option_materialization_jobs_updated_at`, `set_user_playbook_definitions_updated_at` | ✅ | ✅ (hand-synced) | in sync by name |

## F. Indexes

| object | migrations | seed | consequence |
|---|---|---|---|
| `idx_api_keys_user_id`, `idx_ibb_rule_compliance_trade_id`, `idx_trade_excursions_trade_id`, `idx_zdpsb_rule_compliance_trade_id` (20260308000100) | ✅ | ❌ (0 occurrences) | CI lacks 4 FK-supporting indexes; performance only |
| `idx_raw_trades_logical_trade_id_fill` (20260531170000) | ✅ | ❌ | ditto |
| all other MIG-only indexes | on tables absent from the seed | ❌ | created with their deferred table. no finding. |

## G. Data migrations (35 primary + 2 sierra; all create no table ⇒ all auto-marked applied ⇒ **none ever run in CI**)

| migration | state it establishes | replicated into the seed tail? |
|---|---|---|
| `20260422180000_create_public_instruments` | 45 instruments | ✅ (hand-copied) |
| **`20260422190000_expand_instrument_universe`** | +42 symbols (AAPL AGG AMZN DBA DBC EEM EFA ETHA EWZ FBTC FXI GBTC GOOGL HYG IBIT IEF LQD META MSFT NVDA SHY SQQQ SSO SVXY TQQQ TSLA UPRO UVXY VIXY VXX XLB XLC XLE XLF XLI XLK XLP XLRE XLU XLV XLY …) | **❌ — only USO/UNG/SLV back-filled** (seed-02) |
| `20260530150000` (option support UPDATEs), `20260531150000`, `20260806120000`, `20260805130000` | options_strategy_templates | partially ✅ |
| `20260425082820`, `20260604144049`, `20260604163311/12`, `20260610043211/13`, `20260610074513` | P1–P5, T1 rows | ✅ but with STUB conditioning |
| **`20260425065911`, `20260425082819`, `20260501050000`, `20260605124704`** | diagnostic_regime_broad primitive, direction-bias fix, Pydantic renames | **❌ (0 occurrences of "diagnostic" in the seed)** |
| **`20260605200033`, `20260609071500`, `20260610043212`** | P1–P5 draft→published, T1 supersede | **❌ — seed leaves P1–P5 `'draft'`** (seed-04) |
| **`20260728070000_seed_synthetic_equity_playbooks_s1_s2`** | S1/S2 equity playbooks | **❌ (0 occurrences of 'S1'/'S2')** |
| **`20260426113002`, `20260506125500`, `20260507060000`** | demo-data-source pointer, curated demo risk settings, display_unit backfill | **❌** (mig-03) |
| `20260304120300`, `20260312000100`, `20260314000100`, `20260709120000`, `20260225060000/125847`, `20260223060200`, `20260302100800` | backfills / cleanups on empty CI tables | n/a |
| **`20260329000100_seed_extended_instruments`** (sierra) | extended sierra_meta.instruments rows | **❌** (sierra-02) |

## H. Down-blocks (all 183 checked)

| migration | defect |
|---|---|
| `20260302100100_rls_with_check_all_policies` | down = `SELECT 1;` + "omitted for brevity"; 41 WITH CHECK clauses survive a "successful" rollback (down-01) |
| `20260306153000_recall_frames_auto_partitions` | down drops `recall_frames_2026_06/07/08` — live partitions; up is `current_date`-relative so up/down don't correspond (down-02) |
| `20260530120500` (sierra) | down drops `sierra_ohlc_1min_p2026_08/09/10` — live OHLC partitions (down-03) |
| `20260223060200` | down = `DELETE FROM recall_frames_new;` (no WHERE) (down-04) |
| `20260223060300` | down renames `_ghost_recall_frames_pre_partition` back — that table was dropped by `20260226080000:28`; rollback aborts (down-04) |
| `20260302100500`, `20260302100800`, `20260304120000`, `20260312000100`, `20260619130000`, `20260304120400` + 5 sierra | no-op / `SELECT 1;` downs for destructive ups (declared `@irreversible`) |
| ADD/DROP COLUMN parity | **clean on all 21 column-adding migrations** |

## I. Lock / constraint safety (lint-visible vs actual)

| migration | issue | lint verdict |
|---|---|---|
| `20260616160000` | `DROP INDEX` on `raw_trades`, no lock_timeout, no CONCURRENTLY | **OK** (lock-01) |
| `20260312000100` | `DELETE FROM video_requests` at line 5, `SET lock_timeout` at line 7 | **OK** (lock-02) |
| `20260302060100`, `20260302070000`, `20260302070100`, `20260312000200` | DROP INDEX before/without lock_timeout | OK / baselined |
| `20260426113002`, `20260506125500` | UPDATE before lock_timeout | OK |
| `20260302060000` (6× `ADD CONSTRAINT … UNIQUE`), `20260702120000` (sierra, 1×), `20260424000000` (5× PK/EXCLUDE) | ACCESS-EXCLUSIVE index builds; Rule 2's `UNIQUE\b`/`PRIMARY KEY`/`EXCLUDE USING` exemption skips them | OK |
| `.migration-lint-baseline` | 15 files skip **all** safety rules | OK |

## J. CI gates — pass condition vs claim

| gate | claims | passes while |
|---|---|---|
| `static → Migration safety lint` | "Enforces lock_timeout, NOT VALID, CONCURRENTLY" | Rule 1 fires only on ALTER/DROP/CREATE **TABLE**; a bare DROP INDEX/TRUNCATE/DELETE/UPDATE/CREATE POLICY needs nothing. `has_lock_timeout` is computed over the whole body, so a SET *after* the statement satisfies it. |
| `static → Tenant isolation lint` | "Tenant isolation" | scans only **changed .py** files and skips `scripts/|migrations/|schedulers/|tests/`. A PR touching only `db/migrations/*.sql` or `db/schema_test_seed.sql` passes by construction (gate-01). |
| `realdb` | "every CI run now also proves the newest migrations really apply against the seeded schema" | true only for the 55/183 that create a table absent from the dump. The other 128 are asserted, never executed. |
| `migrations (non-superuser replay)` | "replay the migration stream under a NON-SUPERUSER owner" | loads the seed first, then replays only the unmarked tail — never from empty; and **runs `db/migrations` only, never `db/migrations_sierra`**, though `Procfile:1` runs both in the release phase (gate-02). |
| `E2E (main only)` | already self-declared a placebo in the workflow | — |

---
