# Appendix D — Endpoint matrix (all 653 endpoints: auth, tenant scoping, response model, validation)

## LENS 3/6 — router teardown, 31 assigned router files under /Users/zen/code/zenedge-backend-fusion/routers/

**Coverage.** All 31 assigned files enumerated mechanically (grep for @router./@zoom_router./@public_router. decorators) and every handler read. registry/regime_registry.py declares 0 endpoints (it is a mount helper). downloads.py has 10 endpoints (not 9) — the /api/download-zenedge-sync-pro and /api/download-bookmap-addon decorators are multi-line. Shared deps read in full: utils/auth.py, utils/deps.py, utils/auth_middleware.py, database.py (get_db, get_db_dep, get_db_rls_dep, get_db_educator_dep, get_db_service_dep). Cross-file verification done where a router delegated: services/rithmic_service.py, services/sg_analysis.py, services/v12_patterns.py, agent/v12/mcp_tools/memory_tools.py, services/hiro_flatline_service.py, services/option_position_grouping.py, backtest/gsst_models.py, backtest/gsst_primary.py, backtest/gsst_stair_backtest.py, routers/educator/db.py, models/* for every request model I cite. IMPORTANT CONTEXT that shapes every auth verdict: a global pure-ASGI AuthMiddleware (utils/auth_middleware.py:160-330) validates a JWT on EVERY path except an explicit allowlist, so a handler with no Depends() is still JWT-gated ("MW" in the matrix) — it just has no caller identity in the handler. Only paths in EXCLUDED_PATHS / EXCLUDED_PATH_PREFIXES_EXTRA / PUBLIC_PATH_PREFIXES are genuinely unauthenticated ("none"). Not verified: whether specific tables have RLS policies enabled (out of scope per exclusion 12) — where a finding depends on that I marked it INFERRED. I did not run anything; read-only via cat/sed/grep only.

Codes — **A1** no route-level auth dep (global-middleware JWT only, no caller identity in handler) · **A2** middleware-exempt, in-handler key only · **A3** no auth of any kind on an exempt path · **A4** admin dep combined with user-RLS conn · **T1** query not scoped to caller (cross-tenant) · **T2** target user from query/body/path, not token · **V1** unbounded numeric param · **V2** unbounded list/string/file · **V3** raw dict / Any reaches logic · **Q1** SELECT with no LIMIT on growing table · **Q2** DB call in a loop (N+1) · **Q3** string-interpolated SQL · **W1** multi-write, no transaction · **E1** catch-all returns 200 w/ empty or zero data · **E2** str(e)/traceback in response body · **B1** post-response work drops its own failures · **R1** no response_model · **P1** no total / truncation indistinguishable · **F1** feature flag changes behaviour · **D1** docstring contradicts code

| # | Method + path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|---|
| 1 | GET /api/rithmic/status | rithmic_import.py:129 | get_user_id + rls | rls + explicit user_id | RithmicStatusResponse | none needed | F1 (ENABLE_RITHMIC_BETA) |
| 2 | POST /api/rithmic/test-connection | rithmic_import.py:166 | get_user_id + rls + whitelist | n/a (proxy) | RithmicTestConnectionResponse | Pydantic, no max_length on creds | E2, F1 |
| 3 | GET /api/rithmic/test-sync-websocket | rithmic_import.py:300 | get_user_id + rls + whitelist | n/a | RithmicWebSocketTestResponse | none | E2, F1 |
| 4 | POST /api/rithmic/test-websocket-direct | rithmic_import.py:347 | get_user_id + rls + whitelist | n/a | RithmicWebSocketDirectResponse | none | E2, F1 |
| 5 | GET /api/rithmic/test-simple | rithmic_import.py:411 | get_user_id + rls + whitelist | n/a | RithmicSimpleTestResponse | none | E2 (full traceback:457), F1 |
| 6 | POST /api/rithmic/import-history | rithmic_import.py:460 | get_user_id + rls + whitelist | explicit user_id | RithmicImportResponse | lookback clamped in svc; V1 on model | E1, E2, B1, F1 |
| 7 | POST /api/rithmic/capture-uid | rithmic_import.py:739 | none (EXCLUDED_PATHS) + debug-key | n/a | RithmicCaptureUidResponse | Pydantic | A3, E2, F1 — KNOWN #1 |
| 8 | POST /api/rithmic/sync-unique-id | rithmic_import.py:806 | get_user_id + rls + whitelist | explicit auth0_id | RithmicSyncIdResponse | Pydantic | E1, E2, F1 |
| 9 | POST /api/rithmic/test-deduplication | rithmic_import.py:870 | get_user_id + rls + whitelist | explicit user_id | RithmicDeduplicationTestResponse | none | mutating "test"; always 400 (F-1) |
| 10 | GET /api/rithmic/check-isolation | rithmic_import.py:924 | get_user_id + rls + whitelist | T1 (all-user join, no filter) | RithmicIsolationCheckResponse | none | Q1, hardcoded isolation_verified:967 |
| 11 | POST /api/rithmic/save-credentials | rithmic_import.py:971 | get_user_id + rls + whitelist | explicit user_id | RithmicSaveCredentialsResponse | V1 lookback_days | DDL-in-handler:1009, E2 |
| 12 | GET /api/rithmic/user-config | rithmic_import.py:1065 | get_user_id + rls + whitelist | explicit user_id | RithmicUserConfig | n/a | returns plaintext broker password:1088 |
| 13 | PUT /api/rithmic/update-settings | rithmic_import.py:1127 | get_user_id + rls + whitelist | explicit user_id | RithmicSaveCredentialsResponse | V1 | E2 |
| 14 | POST /api/rithmic/test-synthetic-es | rithmic_import.py:1160 | get_user_id + rls + whitelist | explicit user_id | RithmicSyntheticTestResponse | none | writes fake trades to prod |
| 15 | POST /api/rithmic/import-historical | rithmic_import.py:1291 | get_user_id + rls + whitelist | explicit user_id | RithmicHistoricalImportResponse | V1 start/finish_index | E1, E2, B1, F1 |
| 16 | GET /api/download-zenedge-sync | downloads.py:25 | get_current_user | n/a (S3 key is constant) | DownloadResponse | platform coerced | weaker than siblings (no disclaimer gate) |
| 17 | GET /api/download-zenedge-sync-pro | downloads.py:109 | gcu + rls | explicit auth0_id | DownloadProResponse | platform coerced | — |
| 18 | GET /api/download-bookmap-sync | downloads.py:219 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | — |
| 19 | GET /api/download-ibkr-sync | downloads.py:325 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | — |
| 20 | GET /api/download-tradovate-sync | downloads.py:421 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | — |
| 21 | GET /api/download-sierra-sync | downloads.py:529 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | no UA sniff → Mac gets .exe:547 |
| 22 | GET /api/download-micro-recorder | downloads.py:618 | gcu + rls | explicit auth0_id | DownloadResponse | platform forced "mac" | windows request silently served mac |
| 23 | GET /api/download-recall | downloads.py:718 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | — |
| 24 | GET /api/download-bookmap-addon | downloads.py:822 | gcu + rls | explicit auth0_id | BookmapAddonDownloadResponse | n/a | — |
| 25 | GET /api/download-playbook-fast-tap | downloads.py:896 | gcu + rls | explicit auth0_id | DownloadResponse | platform coerced | — |
| 26 | POST /api/gsst/signal | gsst_walkforward.py:191 | get_current_user | explicit user_id in INSERT | GSSTSignalResponse | Pydantic; direction is free str | commit-then-fetchone |
| 27 | GET /api/gsst/stats | gsst_walkforward.py:328 | get_current_user | T1 by design (collective) | GSSTStatsResponse | V1 days | E1:509-520, backtest rows mixed in |
| 28 | POST /api/gsst/evaluate | gsst_walkforward.py:524 | get_current_user | **T1 — mutates all users' rows** | GSSTEvaluateResponse | none | Q1, Q2:573 |
| 29 | GET /api/gsst/signals/history | gsst_walkforward.py:672 | get_current_user | T1 (all users' signals + is_mine) | GSSTSignalHistoryResponse | V1 days | Q1-ish (LIMIT 100), P1:729 |
| 30 | GET /api/gsst/my-settings-hash | gsst_walkforward.py:737 | get_current_user | own only (hardcoded defaults) | GSSTSettingsHashResponse | none | D1 (settings never loaded from DB) |
| 31 | POST /api/gsst/backtest | gsst_walkforward.py:763 | get_current_user | writes user_id='backtest' | GSSTBacktestResponse | V1 days (no ge/le) | store_signals pollutes live stats |
| 32 | GET /api/gsst/backtest/primary-hash | gsst_walkforward.py:843 | **A1 none at all** | n/a | GSSTBacktestPrimaryHashResponse | none | weaker than every sibling |
| 33 | POST /api/gsst/backtest/optimize | gsst_walkforward.py:859 | get_current_user | n/a | dict[str,Any] (R1) | V3 param_grid unbounded | availability |
| 34 | POST /api/upload-ninja-agent-trades/ | ninja_agent_upload.py:205 | get_user_id + rls | explicit user_id | NinjaAgentUploadResponse | V2 trades list unbounded | Q2:271, W1 (tx1+per-instr tx), B1, KNOWN #4 |
| 35 | GET /api/sync-checkpoint | ninja_agent_upload.py:634 | get_user_id + rls | explicit user_id | SyncCheckpointResponse | account free str | E2 |
| 36 | GET /api/ninja-agent/status | ninja_agent_upload.py:692 | get_user_id + rls | explicit user_id | NinjaAgentStatusResponse | none | E1 (status:"error", counts 0) |
| 37 | POST /api/admin/force-rebuild | ninja_agent_upload.py:739 | require_admin **+ rls** | **T2 user_id query param vs caller GUC** | ForceRebuildResponse | user_id/instrument raw str | A4, D1 (curl in docstring 403s) |
| 38 | POST /api/upload-ibkr-agent-trades/ | ibkr_agent_upload.py:213 | get_user_id + rls | explicit user_id | IBKRAgentUploadResponse | V2 trades list unbounded | Q2, W1, B1, KNOWN #4 |
| 39 | GET /api/ibkr-agent/sync-checkpoint | ibkr_agent_upload.py:585 | get_user_id + rls | explicit user_id | IBKRSyncCheckpointResponse | account free str | E2 |
| 40 | GET /api/ibkr-agent/status | ibkr_agent_upload.py:637 | get_user_id + rls | explicit user_id | IBKRAgentStatusResponse | none | E1 |
| 41 | POST /api/admin/ibkr-force-rebuild | ibkr_agent_upload.py:683 | require_admin **+ rls** | **T2 user_id query param** | IBKRForceRebuildResponse | raw str | A4, E2 |
| 42 | GET /api/v1/edge-context/{instrument} | edge_context.py:360 | **A1** | n/a (shared market data) | EdgeContextResponse | instrument allowlisted | LIVE/BACKTEST label:453 |
| 43 | GET /api/v1/edge-context/ | edge_context.py:491 | **A1** | n/a | EdgeInstrumentStatsResponse | none | Q1; caveat contradicts #42 |
| 44 | GET /api/v1/edge-context/{instrument}/density-breakdown | edge_context.py:604 | **A1** | n/a | DensityBreakdownResponse | instrument allowlisted | placeholder zeros:700 |
| 45 | POST /api/v1/sg-analysis | sg_analysis.py:89 | gcu + rls (+demo subst) | explicit data_source_user_id | SGComplianceResponse | tradeId str → UUID() unguarded | ON CONFLICT partial:550, E2:610 |
| 46 | GET /api/v1/sg-analysis/{trade_id} | sg_analysis.py:614 | gcu + rls (+demo subst) | rls + post-fetch owner cmp | SGComplianceResponse | path str → UUID() unguarded | dup `user_id` col in SELECT, E2:697 |
| 47 | POST /api/v12/analyze-session | v12_coaching.py:97 | get_current_user | user_id from token | SessionAnalysisResponse | Pydantic | deprecated sync path |
| 48 | POST /api/v12/start-session-analysis | v12_coaching.py:127 | get_current_user | token | CoachingJobStartResponse | date parsed→400 | B1 (safe_create_task) |
| 49 | GET /api/v12/coaching-job/{job_id} | v12_coaching.py:176 | get_current_user | store.get_job(job,sub) | CoachingJobStatusResponse | job_id raw str | parse failure → result silently None |
| 50 | GET /api/v12/coaching-jobs | v12_coaching.py:212 | get_current_user | token | CoachingJobListResponse | limit fixed 10 | P1 |
| 51 | POST /api/v12/analyze-trade | v12_coaching.py:220 | gcu + rls | token | TradeAnalysisResponse | Pydantic | — |
| 52 | POST /api/v12/risk-assessment | v12_coaching.py:245 | get_current_user | token | RiskMetricsResponse | Pydantic | — |
| 53 | GET /api/v12/day-of-week-analysis | v12_coaching.py:274 | get_current_user | token | DayOfWeekAnalysisResponse | **V1 day, weeks** | — |
| 54 | POST /api/v12/start-daily-brief | v12_coaching.py:304 | get_current_user | token | CoachingJobStartResponse | day_of_week validated | B1; forwards raw Bearer to service |
| 55 | GET /api/v12/daily-brief-job/{job_id} | v12_coaching.py:373 | get_current_user | store.get_job(job,sub) | DailyBriefJobStatusResponse | raw str | — |
| 56 | POST /api/v12/generate-daily-brief | v12_coaching.py:410 | get_current_user | token | DailyBriefResponse | Pydantic | forwards raw Bearer |
| 57 | GET /api/v12/daily-brief/{brief_date} | v12_coaching.py:448 | get_current_user | token | DailyBriefResponse | brief_date raw str | — |
| 58 | GET /api/v12/daily-briefs | v12_coaching.py:465 | get_current_user | token | List[DailyBriefResponse] | **V1 limit** | P1 |
| 59 | GET /api/v12/patterns | v12_coaching.py:480 | get_current_user | token | List[PatternResponse] | **V1 limit, status free str** | P1 |
| 60 | GET /api/v12/patterns/health | v12_coaching.py:493 | get_current_user | token | PatternHealthResponse | none | — |
| 61 | GET /api/v12/patterns/summary | v12_coaching.py:500 | get_current_user | token | PatternsSummaryResponse | none | handler returns Any |
| 62 | POST /api/v12/patterns | v12_coaching.py:506 | get_current_user | token | PatternResponse | Pydantic | service-role write |
| 63 | PATCH /api/v12/patterns/{pattern_id} | v12_coaching.py:532 | get_current_user | **T1/T2 — none; WHERE id=$1 on service-role conn** | PatternUpdateResponse | **status unconstrained str** | **Q3 f-string SQL**, false "updated" |
| 64 | GET /api/v12/health | v12_coaching.py:562 | **A1** | n/a | V12HealthResponse | none | static, never unhealthy |
| 65 | POST /api/v12/agent-brief | v12_coaching.py:585 | get_current_user | token | AgentBriefResponse | Pydantic | forwards raw Bearer |
| 66 | POST /api/v12/feedback | v12_coaching.py:627 | gcu + rls | token | FeedbackResponse | Pydantic | — |
| 67 | GET /api/hiro/divergence/history | hiro/hiro_divergence.py:447 | get_current_user | n/a (market data) | List[DivergenceSignal] | limit le=500; dates unbounded | E1:529, P1, D1 (limit≠signals) |
| 68 | GET /api/hiro/divergence/setup-stats | hiro/hiro_divergence.py:552 | get_current_user | n/a | SetupStatsResponse | none | hardcoded stats:585-587 |
| 69 | POST /api/sahha/webhook | sahha_webhook.py:393 | **A2** HMAC (fail-closed) | **T2 external_id → service-role write** | WebhookAcceptedResponse | Pydantic on payload | B1, E2 (parse err), W1 in task |
| 70 | GET /api/sahha/webhook/health | sahha_webhook.py:468 | **A1** | n/a | WebhookHealthResponse | none | — |
| 71 | POST /api/sahha/profile/register | sahha_webhook.py:489 | get_user_id + rls | caller==target enforced | ProfileRegisterResponse | device_type free str, ignored | E2, writes empty metrics row |
| 72 | GET /api/v1/sg-hiro/correlation | sg_hiro_correlation.py:185 | gcu + rls + sierra | explicit user_id | SGHIROCorrelationResponse | bad dates silently defaulted | **Q2:294**, Q1, E1+E2:476, SPX-only |
| 73 | POST /api/internal/sierra/bars | sierra_ingest.py:84 | **A2** X-Internal-Key | n/a | TWSIngestResponse | **V2 bars list; no OHLC sanity** | per-bar errors + one commit |
| 74 | POST /api/internal/sierra/indicator-bars | sierra_ingest.py:234 | **A2** X-Internal-Key | n/a | TWSIngestResponse | V2; Literal-routed table | Q3 (safe, fixed map) |
| 75 | GET /api/internal/sierra/indicator-freshness | sierra_ingest.py:340 | **A3 none** | n/a | TWSFreshnessResponse | none | D1 (module says key-gated) |
| 76 | GET /api/internal/sierra/freshness | sierra_ingest.py:398 | **A3 none** | n/a | TWSFreshnessResponse | none | D1 |
| 77 | GET /api/v1/price-alerts/current | price_alerts.py:277 | get_current_user | n/a (market data) | ProximityAlertResponse | **V2 instruments str** | E2:386, index-vs-futures compare |
| 78 | GET /api/v1/price-alerts/levels | price_alerts.py:389 | get_current_user | n/a | **R1** (TypedDict) | none | "debug endpoint" in prod |
| 79 | GET /api/support/harness/status | support_harness.py:185 | require_support_permission | n/a | SupportHarnessStatusResponse | none | gated on a read permission |
| 80 | GET /api/support/harness/trade-readback | support_harness.py:196 | require_support_permission | **T2 by design (audited)** | SupportTradeReadbackResponse | dates parsed | service-role conn |
| 81 | POST /api/support/harness/tradeovate-csv | support_harness.py:224 | require_support_permission | **T2 by design (audited)** | SupportTradeovateImportResponse | **V2 unbounded file read** | W1 (import+audit), audit skipped on raise |
| 82 | GET /api/gsst/stair-backtest | gsst_stair_backtest.py:51 | **A1** | n/a | StairBacktestResponse | ge/le on all params ✅ | **sync psycopg2 in async**, E2:101 |
| 83 | GET /api/gsst/continuation-matrix | gsst_stair_backtest.py:105 | **A1** | n/a | ContinuationMatrixResponse | ge/le ✅ | sync-blocking |
| 84 | GET /api/gsst/best-paths | gsst_stair_backtest.py:180 | **A1** | n/a | BestPathsResponse | ge/le ✅ | sync-blocking, P1 |
| 85 | GET /api/gsst/time-windows | gsst_stair_backtest.py:235 | **A1** | n/a | StairTimeWindowsResponse | ge/le ✅ | best_long loses key:269 |
| 86 | GET /api/gsst/day-stats | gsst_stair_backtest.py:285 | **A1** | n/a | StairDayStatsResponse | ge/le ✅ | best_long_day loses key:319 |
| 87 | GET /api/gsst/stair-backtest/health | gsst_stair_backtest.py:339 | **A1** | n/a | StairHealthResponse | none | static |
| 88 | GET /api/v1/user-playbooks | user_playbooks.py:50 | gcu + rls | explicit owner predicate | UserPlaybookList | ge/le ✅ | total returned ✅ |
| 89 | GET /api/v1/user-playbooks/{playbook_id} | user_playbooks.py:67 | gcu + rls | rls | UserPlaybookResponse | id coerced, 404 on bad | — |
| 90 | POST /api/v1/user-playbooks | user_playbooks.py:103 | gcu + rls | token | UserPlaybookResponse | Pydantic + semantic validator | B1 (audit) |
| 91 | POST /api/v1/user-playbooks/{id}/publish | user_playbooks.py:142 | gcu + rls | owner check in svc | UserPlaybookResponse | Literal visibility ✅ | non-idempotent by design (409) |
| 92 | GET /api/v1/user-playbooks/{id}/lineage | user_playbooks.py:207 | gcu + rls | rls only (by design) | LineageGraph | UUID path ✅ | — |
| 93 | POST /api/v1/user-playbooks/{id}/unpublish | user_playbooks.py:269 | gcu + rls | owner check in svc | UserPlaybookResponse | UUID ✅ | B1 (audit) |
| 94 | GET /api/v1/user-playbooks/{id}/stats | user_playbook_stats.py:44 | rls (implies gcu) | rls only | PlaybookStatsResponse | UUID ✅ | fabricated zero-state:97,108 |
| 95 | GET /api/v1/user-playbooks/ecosystem | user_playbook_stats.py:138 | rls | explicit visibility predicate | List[EcosystemPlaybookSummary] | ge/le ✅ | P1 |
| 96 | GET /api/v1/user-playbooks/{id}/recent-firings | user_playbook_stats.py:198 | rls | EXISTS gate + rls | List[RecentFiringSummary] | ge/le ✅ | P1 |
| 97 | GET /api/v1/sg/pre-flight | sg_playbook_ecosystem.py:233 | get_current_user | n/a | SGPreFlightResponse | none | **mock fallback:264**, D1 vs module docstring |
| 98 | GET /api/internal/tiger-health | internal_tiger_health.py:231 | **A2** X-Internal-Key | n/a | **R1** dict[str,Any] | none | 200 + {"error"}:252,255 |
| 99 | GET /api/instruments/registry | instruments.py:135 | **A1** | n/a (reference data) | RegistryResponse | enum/bool ✅ | Q1; Cache-Control: public |
| 100 | GET /api/instruments/registry.etag | instruments.py:191 | **A1** | n/a | RegistryEtagResponse | none | ignores filters → etag never matches |
| 101 | GET /api/instruments/{symbol} | instruments.py:210 | **A1** | n/a | Instrument | .upper(), parameterized ✅ | — |
| 102 | GET /api/educator/zoom/oauth/start | educator/routes_zoom.py:53 | get_db_educator_dep | educator GUC | **R1** | none | int(None) if GUC unset |
| 103 | GET /api/educator/zoom/oauth/callback | educator/routes_zoom.py:67 | **A2** single-use state nonce | state→educator_id | **R1** | code/state presence only | W1:80+92, D1:10 |
| 104 | GET /api/educator/zoom/status | educator/routes_zoom.py:113 | get_db_educator_dep | educator GUC | **R1** | none | — |
| 105 | POST /api/educator/zoom/webhook | educator/routes_zoom.py:125 | **A2** v0 HMAC | account_id→educator map | **R1** | raw json | no ts freshness; silent ignore:174 — KNOWN #3 |
| 106 | GET /api/voice-matches/new | voice_matches.py:23 | gcu + rls | explicit user_id | NewMatchesResponse | none | **Q1:76**, E1:104, bad first-ever flag:88 |
| 107 | POST /api/voice-matches/{id}/mark-viewed | voice_matches.py:112 | gcu + rls | ownership pre-check | MarkViewedResponse | int path ✅ | E2, fabricated viewed_at:153 |
| 108 | GET /api/hiro/regime/current | hiro_regime.py:49 | get_current_user | n/a (market data) | HIRORegimeResponse | none | falsy-zero:105,109; win_rate 50.0:131; E2 |
| 109 | GET /api/hiro/flatline/current | hiro/hiro_flatline.py:35 | get_current_user | user_id passed to svc | FlatlineSignalResponse | none | global cache key |
| 110 | GET /api/hiro/flatline/stats | hiro/hiro_flatline.py:58 | get_current_user | n/a | FlatlineStatsResponse | period coerced to ALL_TIME | baseline fallback cached 120s (labelled ✅) |
| 111 | GET /api/hiro/flatline/time-window | hiro/hiro_flatline.py:89 | get_current_user | n/a | **R1** TypedDict | none | — |
| 112 | GET /api/hiro/flatline/preferences | hiro/hiro_flatline.py:97 | get_current_user | user_id to svc | UserPreferencesResponse | none | — |
| 113 | POST /api/hiro/flatline/preferences | hiro/hiro_flatline.py:111 | get_current_user | user_id to svc | UserPreferencesResponse | ge=1 le=30 ✅ | — |
| 114 | POST /api/hiro/flatline/evaluate | hiro/hiro_flatline.py:126 | get_current_user | **T1 — all users' pending rows** | **R1** TypedDict | none | Q1, Q2 in svc |
| 115 | POST /api/internal/glossary/publish | internal_glossary.py:40 | **A2** X-Internal-Key | global rows (user_id NULL) | GlossaryPublishResponse | Pydantic per rule | **W1** (loop, no tx), per-dyno cache |
| 116 | GET /api/internal/glossary/correction-consensus | internal_glossary.py:91 | **A2** X-Internal-Key | T1 by design (cross-user) | list[CorrectionConsensusItem] | **V1 min_users, limit** | P1 |
| 117 | GET /api/internal/slo-status | slo_status.py:43 | **A1** | n/a | **R1** Dict[str,Any] | none | mean-as-p99:38, E2, D1:5 |
| 118 | POST /api/transcriptions/correct | transcription_corrections.py:28 | gcu + rls | explicit uid, in tx ✅ | TranscriptionCorrectionResponse | min/max_length ✅; **source_chunk_id un-UUID-validated** | silent overwrite of existing rule |
| 119 | GET /api/prove/v0/{playbook_id} | prove_it.py:35 | gcu + rls | rls pre-cache ✅ | ProveItResult | id coerced in svc | cache key omits instrument when non-str |
| 120 | GET /api/system/health | system_health.py:18 | **A1** | n/a | SystemHealthResponse | none | D1 "public":21; static "healthy" |
| 121 | GET /api/system/deployment-info | system_health.py:34 | **A1** | n/a | DeploymentInfoResponse | none | D1 "without auth":38 |
| 122 | GET /api/system/health/db-pool | system_health.py:54 | require_admin | n/a | **R1** | none | D1 "both databases", only main |
| 123 | GET /api/educator/public/{token} | educator/routes_public.py:18 | **A3 none** (prefix-exempt) | token-scoped service-role | **R1** dict[str,Any] | token raw str | by-design public; no rate limit |

---

## LENS 5/6 — router teardown, 31 assigned router files under /Users/zen/code/zenedge-backend-fusion/routers/

**Coverage.** All 31 assigned files opened and every route decorator enumerated mechanically (rg '@router\.(get|post|put|patch|delete)' plus a second pass for @router.options, which found one extra endpoint in tradeovate_csv_import.py). 4 of the 31 files contain no endpoints and are helper/registry modules: trade_import/models.py (Pydantic/Trade class), trade_import/parsers_rithmic.py (parsers — read anyway, produced F19), registry/users_registry.py and registry/instruments_registry.py (include_router wiring only — read in full). Every handler body in the remaining 27 files was read end to end EXCEPT: gamma_memory.py row_to_* helpers (lines 74-180), trace_edge_correlation.py classify_* helpers (lines 60-150 skimmed, compute_cell/insight generators read in full), hiro/hiro_gamma_zone.py message/recommendation builders (lines 60-190), zdpsb_analysis.py services/zdpsb_analysis grading functions (not in my slice), and gap_fill.py lines 1-100 helpers (read). Shared deps read in full: utils/auth.py (get_current_user/get_user_id/require_non_demo_viewer/get_current_user_optional), utils/deps.py, utils/auth_middleware.py (EXCLUDED_PATHS + enforcement), utils/auth_guard.py, database.py:367-660 (get_db/get_db_dep/get_db_rls_dep/get_db_educator_dep/get_db_service_dep), utils/cache.py cache_or_fetch, utils/token_blocklist.py, utils/error_helpers.py. Mount prefixes resolved from routers/registry/*.py; routers/aplus_control.py is mounted NOWHERE (its 7 endpoints are dead code today — see F24). IMPORTANT AUTH BASELINE used throughout: utils/auth_middleware.py enforces a valid JWT on every path not in EXCLUDED_PATHS/PUBLIC_PATH_PREFIXES, so "no auth dependency" in the matrix means "any authenticated user, no per-caller scoping", not "anonymous". RLS policy claims (F03) were checked against db/schema_test_seed.sql, which is a schema dump, not live prod DDL — flagged accordingly. Known-issue list items 1-12 were excluded; where a same-class defect appears at a NEW location (e.g. skipped-rows-but-success in tradeovate_csv_import.py rather than the four agent uploaders) it is reported as new.

Legend — auth: `cu`=Depends(get_current_user), `uid`=Depends(get_user_id), `adm`=Depends(require_admin), `grd`=router-level verify_user_id_ownership, `mw`=none in handler (global AuthMiddleware JWT only). tenant: `rls`=get_db_rls_dep, `sierra`=get_sierra_db_dep (separate DB, no RLS), `raw`=sync psycopg2 service conn, `uid-filter`=explicit user_id predicate, `n/a`=global market data. flags: E=str(e)/internals in response body, X=HTTP 200 on internal failure, F=fabricated default value, P=`total`==page size, L=SELECT with no LIMIT, N=DB call in loop, U=unbounded/unchecked numeric or list input, D=silent row/record drop, M=docstring contradicts code, S=stale/unbounded-age read, DDL=schema statement on request path, RD=raw dict body (no Pydantic), DEAD=route not mounted.

| method + path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/health-metrics/upload | health_metrics.py:82 | uid | rls + uid-filter | HealthMetricsUploadResponse | Pydantic batch | D,N (F15) |
| GET /api/health-metrics/ | health_metrics.py:276 | cu | rls + demo-substitution | List[HealthMetricsResponse] | Query ge/le | P (no total) |
| GET /api/health-metrics/latest | health_metrics.py:380 | cu | rls + demo-substitution | Optional[HealthSnapshotResponse] | none needed | — |
| GET /api/health-metrics/date/{metrics_date} | health_metrics.py:496 | cu | rls + demo-substitution | List[HealthMetricsResponse] | date path type | L |
| GET /api/health-metrics/readiness | health_metrics.py:718 | cu | rls + demo-substitution | ReadinessResponse | date Query req | F16 |
| GET /api/health-metrics/summary | health_metrics.py:811 | cu | rls + demo-substitution | List[HealthMetricsSummary] | days ge=1 le=90 | F16 |
| GET /api/health-metrics/correlation | health_metrics.py:976 | cu | rls + demo-substitution | List[TradingHealthCorrelation] | days ge=7 le=365 | F17,F16 |
| POST /api/health-metrics/seed | health_metrics.py:1178 | uid | rls + uid-filter | HealthMetricsUploadResponse | days ge=7 le=365 | D,N (F15) |
| DELETE /api/health-metrics/{record_id} | health_metrics.py:1370 | uid | rls + uid-filter | (204) | UUID path | — |
| GET /api/health-metrics/health | health_metrics.py:1433 | mw | n/a | Dict[str,str] | none | — |
| OPTIONS /api/upload-tradeovate-csv/ | tradeovate_csv_import.py:428 | mw (OPTIONS skips mw) | n/a | none | none | — |
| POST /api/upload-tradeovate-csv/ | tradeovate_csv_import.py:437 | uid | rls + uid-filter | TradeovateUploadResponse | filename .csv only; no size cap | D,E,X (F18) |
| GET /api/tradeovate-csv/status | tradeovate_csv_import.py:969 | uid | rls + uid-filter | ImportStatusResponse | none | X,M (F18) |
| POST /api/zdpsb/signal | zdpsb_walkforward.py:255 | cu | sierra, uid stored not filtered | ZDPSBSignalResponse | Pydantic | F02 (cross-tenant dedupe) |
| GET /api/zdpsb/stats | zdpsb_walkforward.py:344 | cu | sierra, collective by design | ZDPSBStatsResponse | none | X,F (F07,F08) |
| GET /api/zdpsb/current-levels | zdpsb_walkforward.py:539 | cu | sierra n/a | bare dict | symbol str unchecked | E (helper leaks str(e)) |
| POST /api/zdpsb/evaluate | zdpsb_walkforward.py:782 | cu | sierra, NO user filter on UPDATE | ZDPSBEvaluateDict (bare) | none | F01 (cross-tenant write), F23 |
| POST /api/recall/presign | recall.py:98 | cu | S3 key from token sub | PresignResponse | Pydantic, monitor ge/le | F26 (no demo gate) |
| POST /api/recall/commit | recall.py:162 | cu | rls + key-prefix check | CommitResponse | Pydantic | F26 |
| GET /api/recall/frames/for-trade-range/{trade_id} | recall.py:300 | cu | rls + uid-filter | TradeReplayResponse | padding ge/le | L (F26) |
| GET /api/recall/frames/for-session/{session_id} | recall.py:465 | cu | rls + explicit owner check | SessionReplayResponse | padding ge/le | L,M (uuid cast ≠ 404) |
| GET /api/recall/frames/for-trade/{trade_id} | recall.py:625 | cu | rls + uid-filter | TradeHUDResponse | tolerance ge/le | — |
| GET /api/recall/frames/nearest | recall.py:800 | cu | rls + uid-filter | inferred FrameInfo | ts str parsed | — |
| GET /api/v1/gamma-memory/stats | gamma_memory.py:186 | cu | sierra n/a | GammaMemoryStatsResponse | none | E |
| POST /api/v1/gamma-memory/refresh | gamma_memory.py:251 | cu | none (global job) | GammaMemoryRefreshResponse | instrument str | E,U (F25) |
| POST /api/v1/gamma-memory/scan-setups | gamma_memory.py:282 | cu | sierra n/a | SetupScanResponse | no max_length on lists | E,N,U (F25) |
| GET /api/v1/gamma-memory/{instrument}/layout | gamma_memory.py:437 | cu | sierra n/a | LayoutOfDayResponse | instrument str | E |
| GET /api/v1/gamma-memory/{instrument} | gamma_memory.py:545 | cu | sierra n/a | GammaMemoryListResponse | ge/le on all Query | E,P (F25) |
| GET /api/v1/gamma-memory/{instrument}/proximity | gamma_memory.py:643 | cu | sierra n/a | ProximityResponse | range_points ge only | E,U |
| GET /api/v1/gamma-memory/{instrument}/{price_level}/history | gamma_memory.py:714 | cu | sierra n/a | LevelHistoryResponse | float path param | E,P |
| GET /api/trades/{trade_id}/voice-segments | trade_voice_segments.py:45 | cu | rls + owner pre-check | TradeVoiceSegmentsResponse | str id | E,L |
| GET /api/recording-sessions/{session_id}/attribution-summary | trade_voice_segments.py:140 | cu | rls + owner pre-check | SessionAttributionResponse | str id | E,N,F20 |
| PUT /api/trade-voice-segments/{segment_id}/review | trade_voice_segments.py:299 | cu | rls + owner + override check | ReviewSegmentResponse | Pydantic | E |
| GET /api/recording-sessions/{session_id}/ambiguous-segments | trade_voice_segments.py:392 | cu | rls + owner pre-check | AmbiguousSegmentsResponse | str id | E,N,F,P (F21) |
| PUT /api/trade-voice-segments/batch-review | trade_voice_segments.py:510 | cu | rls + per-item owner check | BatchReviewResponse | list, no max_length; action free str | D,M,U (F11) |
| POST /api/voice-only-trades | trade_voice_segments.py:627 | cu | rls + chunk owner check | CreateVoiceOnlyTradeResponse | Pydantic | E, no dedupe |
| POST /api/v1/zdpsb-analysis | zdpsb_analysis.py:72 | cu | rls + explicit 403 owner check | ZDPSBComplianceResponse | UUID(str) → 500 on bad id | F09 |
| GET /api/v1/zdpsb-analysis/{trade_id} | zdpsb_analysis.py:568 | cu | rls + explicit 403 owner check | ZDPSBComplianceResponse | UUID(str) → 500 on bad id | M (bad id = 500) |
| GET /api/v1/trace-edge/correlation | trace_edge_correlation.py:301 | cu | rls uid-filter (user DB) + sierra | TraceEdgeCorrelationResponse | invalid dates silently defaulted | E,X,L (F22) |
| GET /api/user/trading-preferences | user_trading_preferences.py:91 | cu | rls + uid-filter | TradingPreferencesResponse | none | E, write-on-GET |
| POST /api/user/trading-preferences | user_trading_preferences.py:264 | cu | rls + uid-filter | TradingPreferencesResponse | Pydantic | E |
| GET /api/user/top-playbooks | user_trading_preferences.py:453 | cu | rls + uid-filter | TopPlaybooksResponse | none | X (F14) |
| PUT /api/user/top-playbooks | user_trading_preferences.py:500 | cu | rls + uid-filter | TopPlaybooksUpdateResponse | RD raw dict, len==7 only | RD,M,E (F14) |
| GET /api/user/available-instruments | user_trading_preferences.py:593 | cu | n/a (static list) | inferred Dict | none | M ("feature-flagged per user") |
| GET /api/hiro/gamma-zone/current | hiro/hiro_gamma_zone.py:204 | cu | sierra n/a | GammaZoneSignalResponse | none | F35 (hedge_wall relabel) |
| GET /api/hiro/gamma-zone/stats | hiro/hiro_gamma_zone.py:359 | cu | sierra n/a | GammaZoneStatsResponse | none | X,F (F07) |
| GET /api/hiro/gamma-zone/time-window | hiro/hiro_gamma_zone.py:517 | mw | n/a | GammaZoneTimeWindowResponse | none | M ("no auth required") |
| GET /api/v1/gap-fill/current | gap_fill.py:105 | mw | sierra n/a | CurrentGapResponse | instrument str | F (0% shown as real prob) |
| GET /api/v1/gap-fill/history | gap_fill.py:233 | mw | sierra n/a | HistoryResponse | limit le=500 no ge | P,U (F23b) |
| GET /api/v1/gap-fill/statistics | gap_fill.py:304 | mw | sierra n/a | StatisticsResponse | window UNBOUNDED | U,N (F23) |
| GET /api/v1/user-notifications | user_notifications.py:84 | cu | rls + uid-filter | NotificationListResponse | none | E,P (F13) |
| GET /api/v1/user-notifications/stream | user_notifications.py:142 | cu | in-process queue keyed by sub | StreamingResponse | none | F12 (per-dyno, misses creates) |
| POST /api/v1/user-notifications | user_notifications.py:199 | adm | rls conn bound to CALLER sub | NotificationResponse | Pydantic | E,F12,F31 |
| POST /api/v1/user-notifications/{notification_id}/dismiss | user_notifications.py:266 | cu | rls + uid-filter | NotificationActionResponse | str→uuid cast | E |
| GET /api/v1/user-notifications/admin/user/{target_user_id} | user_notifications.py:338 | adm | rls conn + target from PATH | AdminNotificationListResponse | none | E,P,F31 |
| DELETE /api/v1/user-notifications/admin/{notification_id} | user_notifications.py:407 | adm | rls conn, DELETE has NO user filter | NotificationActionResponse | str→uuid cast | E,F31 |
| GET /api/regime-alignment/current | regime_alignment.py:158 | cu | sierra n/a | bare Dict[str,Any] | none | F,S,M (F20b: 2 shapes) |
| GET /api/regime-alignment/history | regime_alignment.py:211 | cu | sierra n/a | bare Dict[str,Any] | hours ge/le | P |
| GET /api/aplus/status | aplus_control.py:61 | cu | n/a global singleton | APlusStatusResponse | none | DEAD,E |
| POST /api/aplus/arm | aplus_control.py:98 | cu | n/a REAL-MONEY switch | ArmResponse | confirmation code str | DEAD,M,F10 |
| POST /api/aplus/disarm | aplus_control.py:138 | cu | n/a | ArmResponse | none | DEAD,F10 |
| POST /api/aplus/flatten/{instrument} | aplus_control.py:170 | cu | n/a | FlattenResponse | instrument path unchecked | DEAD,E,F10b |
| POST /api/aplus/flatten-all | aplus_control.py:227 | cu | n/a | FlattenAllResult (bare) | none | DEAD,E,F10b |
| GET /api/aplus/setups | aplus_control.py:290 | cu | n/a | list[MonitoredSetupResponse] | none | DEAD,F (always []) |
| GET /api/aplus/stats | aplus_control.py:318 | cu | n/a | AplusStatsResult (bare) | none | DEAD,E |
| GET /api/trace/current | trace/trace_monitor.py:120 | cu | sierra n/a | TraceSnapshot | none | E,S (F21b) |
| GET /api/trace/history | trace/trace_monitor.py:247 | cu | sierra n/a | List[TraceHistoryItem] | hours ge/le | E,P |
| GET /api/trace/health | trace/trace_monitor.py:302 | mw | sierra n/a | TraceHealthResponse | none | E,X (F21b) |
| POST /api/v2/support/orphan-fix-request | support.py:78 | cu | rls + uid-filter | OrphanFixResponse | Pydantic | DDL,L (F05b) |
| GET /api/v2/support/orphan-fix-request/status/{instrument} | support.py:244 | cu | rls + uid-filter | OrphanFixRequestStatusResponse | instrument path str | DDL (F05b) |
| POST /api/playbook-taps | playbook_taps.py:38 | cu | rls + uid-filter | PlaybookTapResponse | playbookId int, no ownership check | E,F32 |
| GET /api/playbook-taps | playbook_taps.py:202 | cu | rls + uid-filter | PlaybookTapListResponse | limit ge/le | E,P |
| GET /api/logical_trade_groupings/{user_id}/{instrument}/{date} | legacy_trades.py:35 | grd | raw sync conn + path user_id | list[LogicalTradeGrouping] | instrument/date raw str | L,F27 |
| GET /api/logical_trade_groupings_with_timestamp/{user_id}/{instrument}/{start_date}/{end_date} | legacy_trades.py:49 | grd | raw + path user_id | list[...WithTimestamp] | raw str dates | L,F27 |
| GET /api/logical_trade_groupings_plusdates/{user_id}/{instrument}/{start_date}/{end_date} | legacy_trades.py:67 | grd | raw + path user_id | list[LogicalTradeGrouping] | raw str dates | L,F27 |
| GET /api/logical_trade_groupings_plusdates_pnl_per_grouping/{user_id}/{instrument}/{start_date}/{end_date} | legacy_trades.py:85 | grd | raw + path user_id | list[...WithPnL] | instrument → dict lookup | L,F27b |
| GET /api/logical_trade_count/{user_id}/{instrument} | legacy_trades.py:103 | grd | raw + path user_id | LogicalTradeCount | required query dates | F27 |
| POST /api/calculate_executions_total/{user_id}/{instrument} | legacy_trades.py:120 | grd | raw + path user_id | dict[str,int] | date types | F27, misnamed key |
| POST /api/calculate_contracts_traded/{user_id}/{instrument} | legacy_trades.py:134 | grd | raw + path user_id | dict[str,float] | date types | F27 |
| POST /api/all_instruments_executions_single_query/{user_id} | legacy_trades.py:153 | grd | raw + path user_id | TotalExecutions | date types | F27 |
| POST /api/all_instruments_contracts_single_query/{user_id} | legacy_trades.py:170 | grd | raw + path user_id | TotalContracts | date types | F27 |
| GET /api/all_instruments_logical_trade_count/{user_id} | legacy_trades.py:187 | grd | raw + path user_id | LogicalTradeCount | raw str dates | F27 |
| GET /api/all_instruments_logical_trade_groupings_plusdates_pnl_per_grouping/{user_id}/{start_date}/{end_date} | legacy_trades.py:206 | grd | raw + path user_id | list[...WithPnL] | raw str dates | L,F27b |
| GET /api/all_instruments_..._pnl_per_grouping_with_timestamp/{user_id}/{start_date}/{end_date} | legacy_trades.py:225 | grd | raw + path user_id | list[...WithTimestamp] | raw str dates | L,F27 |
| GET /api/v1/guardrails/cues | guardrail.py:28 | cu | rls + uid-filter | list[GuardrailCueResponse] | limit/offset ge/le | P, join fan-out |
| POST /api/v1/guardrails/cues/{cue_id}/feedback | guardrail.py:58 | cu | service checks ownership | (204) | Pydantic max_length | — |
| GET /api/v1/guardrails/signals/{transcription_id} | guardrail.py:82 | cu | rls + uid-filter | list[GuardrailSignalResponse] | int path | L |
| GET /api/v1/guardrails/stats | guardrail.py:107 | cu | rls + uid-filter | GuardrailStatsResponse | none | N (3 round trips) |
| GET /api/v1/guardrails/preferences | guardrail.py:166 | cu | rls + uid-filter | GuardrailPreferencesResponse | none | — |
| PUT /api/v1/guardrails/preferences | guardrail.py:190 | cu | rls + uid-filter | GuardrailPreferencesResponse | Pydantic ge/le | N, f-string column (F28) |
| POST /api/notifications/request-access | notifications.py:19 | cu | rls, user_id = hash() surrogate | VideoRequestResponse | Pydantic + raw ts str | DDL,F04,F05 |
| GET /api/trace/surface | trace_surfaces.py:75 | cu | sierra n/a | SurfaceTensor | pattern + ge/le on all | F36 (cache bypass) |
| GET /api/trace/surface/dates | trace_surfaces.py:105 | cu | sierra n/a | SurfaceDates | pattern | F36 |
| GET /api/synth_oi/convexity | trace_surfaces.py:124 | cu | sierra n/a | ConvexityCurve | pattern on every param | — |
| GET /api/trace/gamma_vol_response | trace_surfaces.py:146 | cu | sierra n/a | ConvexityCurve | explicit dte allowlist | — |
| GET /api/trace/iv_surface | trace_surfaces.py:168 | cu | n/a | none (always 501) | none | intentional 501 |
| GET /api/community/playbooks | community_playbooks.py:69 | cu | rls + explicit published predicate | CommunityPlaybookList | limit/offset ge/le | F29 (total≠rows) |
| POST /api/community/playbooks/{playbook_id}/clone | community_playbooks.py:104 | cu + tier gate | rls + service owner logic | UserPlaybookCloneResponse | UUID path | flag: COMMUNITY_PRO_GATED_ACTIONS default open |
| GET /api/user/bookmap/status | bookmap_settings.py:27 | cu | rls + uid-filter | BookmapStatusResponse | none | E,F30 (UTC day) |
| POST /api/feature-votes | feature_votes.py:14 | cu | rls (RLS hides other users' votes) | VoteResponse | action str checked in-handler | E,F03 |
| GET /api/feature-votes/counts | feature_votes.py:70 | mw-EXEMPT but rls dep | rls — breaks the public contract | Dict[str,int] | none | E,F03 |
| GET /api/feature-votes/my-votes | feature_votes.py:97 | cu | rls + uid-filter | MyVotesResponse | none | E |
| GET /api/verdict/v0/{playbook_id} | verdict.py:41 | cu | rls resolve before cache | VerdictV0Response | str id | clean |
| POST /api/auth/logout | auth.py:20 | cu | n/a | StatusMessageResponse | none | F06 |
| POST /api/auth/revoke-all | auth.py:56 | cu | n/a | StatusMessageResponse | none | F06 |
| GET /api/agent/handshake | agent.py:9 | mw | n/a | HandshakeResponse | none | hardcoded version string |
| (no endpoints) | trade_import/models.py | — | — | — | — | module only |
| (no endpoints) | trade_import/parsers_rithmic.py | — | — | — | — | module only (F19) |
| (no endpoints) | registry/users_registry.py | — | — | — | — | include_router wiring (F34) |
| (no endpoints) | registry/instruments_registry.py | — | — | — | — | include_router wiring (F34) |

---

## LENS 1/6 — Router teardown, 31 assigned router files (/Users/zen/code/zenedge-backend-fusion/routers/)

**Coverage.** All 31 assigned files opened and read. 27 of them declare routes (117 endpoints enumerated mechanically via `rg "@router\.(get|post|put|patch|delete|options|head|api_route)"` then each handler read in full). 4 files declare zero endpoints and were read end-to-end as mount registries instead: registry/extras_registry.py, registry/media_registry.py, registry/sierra_registry.py, registry/tns_highlights_registry.py, plus routers/trade_import/__init__.py (a pure re-export shim — its handlers live in trade_import/routes.py, which is NOT in my slice; I audited only the mount/export surface and say so in F-027).

Shared dependency substrate read once and applied across the slice: utils/auth.py (get_current_user / get_current_user_optional / get_user_id / require_non_demo_viewer), utils/deps.py (require_admin, require_user_or_admin, require_support_permission), utils/auth_middleware.py (EXCLUDED_PATHS / PUBLIC_PATH_PREFIXES / EXCLUDED_PATH_PREFIXES_EXTRA + the HS256 bridge), utils/auth_guard.py (verify_user_id_ownership), database.py (get_db, get_db_dep, get_db_rls_dep, get_db_service_dep, get_db_educator_dep, get_sierra_db_dep, get_db_connection_sync). Mount prefixes resolved by reading every registry that includes one of my routers.

IMPORTANT CALIBRATION: AuthMiddleware (utils/auth_middleware.py) JWT-gates EVERY path not on its exempt lists. I checked all 117 of my paths against those lists. Result: no endpoint in my slice is anonymously reachable. Five are AuthMiddleware-exempt and each carries in-handler secret auth that I verified is hmac.compare_digest and fail-closed on an unset secret: POST /api/webhooks/tradingview/menthorq-gex (X-Webhook-Secret), GET /api/internal/fnfp-health, GET /api/internal/fnfp-history (X-Internal-Key/JWT_INTERNAL_KEY), GET /api/coach/conversations/pending-ingest, POST /api/coach/conversations/ingested (X-Internal-Key/COACH_INGEST_INTERNAL_KEY). So rows marked "MW-only" mean "no route-level Depends, but JWT-enforced by middleware" — a consistency deviation, not an auth hole. I flag them as deviations, not as unauthenticated endpoints.

Sampled rather than fully verified (stated as INFERRED where load-bearing): services/legacy_pnl_service.py (read 2 of ~20 functions — enough to confirm the connection-per-instrument N+1 shape), services/option_pnl.py + services/option_verdict.py (call signatures only), services/ibb_analysis.py, services/coach_conversation.py (read finalize_for_owner + sweep_idle only), services/market_regime.py, services/historical_regime.py (signature only — that signature is the whole basis of F-016), ml/trade_quality/*. Every RLS-policy-dependent claim is labelled INFERRED because per-table RLS policy text lives in migrations, which a separate wave owns.

Could not finish / deliberately shallow: routers/trade_import/routes.py (out of slice, 5 endpoints not counted in my 117), and the 3 endpoints in spotgamma_signals.py ARE counted but are currently NOT MOUNTED (extras_registry.py:42-45 disables them because the underlying table was dropped) — their defects are real but have zero live blast radius today, and I say so per-finding.

Excluded per the ALREADY-KNOWN list: the bare "59 endpoints have no response_model" count (I record response_model per row in the matrix and only raise it where a specific consequence exists), utils/safe_task.py fire-and-forget drops, the utils/user_context.py demo cache, deps.py:152 M2M-admin, and all DB-layer/RLS-policy/migration defects.

**Legend.** Auth: `JWT`=Depends(get_current_user) · `UID`=Depends(get_user_id) · `MW`=no route dep, JWT enforced by AuthMiddleware only · `KEY`=in-handler X-Internal-Key hmac · `SEC`=in-handler X-Webhook-Secret hmac · `GUARD`=router-level verify_user_id_ownership. DB/Tenant: `RLS`=get_db_rls_dep · `SVC`=get_db_service_dep · `SIERRA`=get_sierra_db_dep/get_sierra_pool_conn (market data, non-tenant) · `RAW`=get_db_connection_sync · `+uid`=explicit user_id predicate · `none`=no tenant predicate. RM: response_model. Val: `P`=Pydantic · `Q±`=Query with/without bounds · `raw`=unvalidated. Flags: `XT`=cross-tenant reach · `LEAK`=str(e)/traceback in body · `200ERR`=HTTP200 after internal failure · `FAB`=hard-coded/fabricated value in response · `NOLIM`=unbounded SELECT · `NOTOT`=count==page size, truncation indistinguishable · `N+1` · `STALE`=no freshness guard · `BARE`=no/vacuous response_model · `DEAD`=not mounted · `IDEM`=non-idempotent write · `FLAG`=feature-flag behaviour · `DUP`=double-mounted.

| # | Method + Path | file:line | Auth | Tenant scoping | RM | Input validation | Flags |
|---|---|---|---|---|---|---|---|
| 1 | GET /api/spotgamma/flow-patrol/grounding | spotgamma.py:109 | JWT | SIERRA (global) | none | Q raw symbol, date | BARE, LEAK(safe_detail_string ok), sync conn in threadpool |
| 2 | GET /api/spotgamma/data | spotgamma.py:165 | JWT | SIERRA (global) | SpotGammaDataResponse | Q± datetimes unbounded, allowlist | NOLIM, LEAK:358, SPY/NDX rejected vs comment:69 |
| 3 | GET /api/spotgamma/presign | spotgamma.py:365 | JWT | SIERRA (global) | SpotGammaScreenshotsResponse | Q datetimes | LEAK:506, S3 fail→404 "no data" |
| 4 | GET /api/spotgamma/latest | spotgamma.py:514 | JWT | SIERRA (global) | SpotGammaDataPoint | Q allowlist | LEAK:616, cached 60s |
| 5 | GET /api/spotgamma/founders-notes | spotgamma.py:727 | JWT | SIERRA (global) | FoundersNotesResponse(data:Dict) | Q date strptime | BARE(data is Dict[str,Any]), LEAK:804 |
| 6 | GET /api/spotgamma/daily-levels | spotgamma.py:816 | JWT | SIERRA (global) | SpotGammaDailyLevels | Q regex symbol + date | LEAK:919, 0→None coercion |
| 7 | GET /api/spotgamma/equity-levels | spotgamma.py:946 | JWT | SIERRA (global) | SpotGammaEquityLevels | Q regex + mutual-excl | LEAK:1180; has is_stale/age (good) |
| 8 | GET /api/spotgamma/synth-oi-context/{symbol} | spotgamma.py:1188 | JWT | SIERRA (global) | SpotGammaSynthOiContext | path regex + Q date | LEAK:1513, 5 seq queries |
| 9 | GET /api/spotgamma/name-hiro/{symbol} | spotgamma.py:1518 | JWT | SIERRA (global) | SpotGammaNameHiro | path regex + Q session | LEAK:1690, ≤7 probe queries |
| 10 | GET /api/spotgamma/founders-notes/full-text | spotgamma.py:1705 | JWT | SIERRA (global) | FoundersNotesResponse(data:Dict) | Q date strptime | BARE, LEAK:1791 |
| 11 | GET /api/options-positions/attribution-summary | options_positions.py:445 | JWT | RLS+uid (+Mech-A resolve) | AttributionSummaryResponse | Q window allowlist | truncated flag ok; per-group except→unpriced; cap 250/25 |
| 12 | GET /api/options-positions/{position_group_id} | options_positions.py:652 | JWT | RLS+uid | OptionsPositionResponse | UUID parse→422 | FAB materialization_status:888 |
| 13 | POST /api/ibb/signal | ibb_walkforward.py:152 | JWT | SIERRA, none | IBBSignalResponse | P, no Literal on direction/regime/symbol | XT dedup:172, DDL-per-request |
| 14 | GET /api/ibb/stats | ibb_walkforward.py:240 | JWT | collective(none)+personal(+uid) | IBBStatsResponse | Q raw str allowlisted | 200ERR+FAB:401, total_traders bug:389 |
| 15 | GET /api/ibb/preferences | ibb_walkforward.py:417 | JWT | +uid | IBBUserPrefsResponse | — | reads include_auto_signals col |
| 16 | POST /api/ibb/preferences | ibb_walkforward.py:456 | JWT | +uid | IBBUserPrefsResponse | P ge/le | include_auto_signals never written |
| 17 | POST /api/ibb/evaluate | ibb_walkforward.py:510 | JWT | SIERRA, none | IBBEvaluateResponse | — | XT write:528+651, tick×4 FAB:654, EXPIRED dead |
| 18 | GET /api/ibb/auto-signal/today | ibb_walkforward.py:702 | JWT | SIERRA, none | IBBAutoSignalResponse | Q raw symbol | 200ERR+LEAK:777 |
| 19 | GET /api/ibb/signals/history | ibb_walkforward.py:785 | JWT | none | IBBSignalHistoryResponse | Q days unbounded | XT read, NOTOT, breakdown unfiltered |
| 20 | OPTIONS /api/upload-ninja-csv/ | ninja_csv_import.py:454 | MW-only | n/a | none | — | BARE, preflight stub |
| 21 | POST /api/upload-ninja-csv/ | ninja_csv_import.py:462 | UID | RLS+uid | NinjaCsvUploadResponse | Form date, no file size cap | silent row drops, 200ERR:743, LEAK:746/757 |
| 22 | GET /api/ninja-csv/status | ninja_csv_import.py:770 | UID | RLS+uid | ImportStatusResponse | — | 200ERR zeros:803 |
| 23 | GET /api/audio/transcriptions | transcription_manager.py:75 | JWT+UID | RLS+uid(dual-id) | TranscriptionListResponse | Q limit ge/le, offset ge | total returned (good) |
| 24 | POST /api/audio/transcriptions/{id}/attach | transcription_manager.py:191 | non-demo+UID | RLS+uid in UPDATE | SimpleResponse | P body, int path | rowcount unchecked |
| 25 | POST /api/audio/transcriptions/{id}/detach | transcription_manager.py:312 | non-demo+UID | RLS+uid in UPDATE | SimpleResponse | int path | rowcount unchecked |
| 26 | POST /api/audio/transcriptions/{id}/reassign | transcription_manager.py:410 | non-demo+UID | RLS+uid in UPDATE | SimpleResponse | P body | rowcount unchecked |
| 27 | GET /api/audio/trade-notes/{ltid}/recordings | transcription_manager.py:531 | JWT+UID | RLS+uid | List[TranscriptionDetail] | raw str path | no limit (per-trade, bounded) |
| 28 | DELETE /api/audio/transcriptions/{id} | transcription_manager.py:643 | non-demo+UID | **RLS only, no uid in DELETE:708** | SimpleResponse | int path | XT-shape, S3 object orphaned |
| 29 | GET /api/feature-flags | compat_shims.py:75 | JWT | n/a | dict[str,bool] | Q raw | FAB all-false stub |
| 30 | GET /api/sierra/marketdata/5min | compat_shims.py:109 | JWT | n/a (self-proxy) | none | Q raw strings | BARE, base_url:133 Host-derived, LEAK:169 |
| 31 | GET /api/sierra/contracts/resolve | compat_shims.py:189 | JWT | n/a (self-proxy) | none | Q raw | BARE, base_url:200, LEAK:208 |
| 32 | GET /api/sierra/indicators/{type} | compat_shims.py:227 | JWT | n/a (self-proxy) | none | path raw→map fallback | BARE, base_url:252, LEAK:310 |
| 33 | POST /api/sierra/calculate-trade-excursions | compat_shims.py:436 | JWT | n/a (self-proxy) | none | **raw request.json()** | BARE, FLAG SAFE_MODE, 200ERR:498, order-zip:512 |
| 34 | GET /api/sierra/calculate-trade-excursions | compat_shims.py:567 | JWT | n/a (self-proxy) | none | Q raw id lists, no cap | BARE, FLAG, 200ERR:633, order-zip:556 |
| 35 | GET /api/compat/health | compat_shims.py:674 | MW-only | n/a | CompatHealthResponse | — | route-dep deviation vs siblings |
| 36 | GET /api/algo/arm-status | algo_control.py:93 | JWT | **global in-proc state** | ArmStatusResponse | — | per-dyno state |
| 37 | POST /api/algo/arm | algo_control.py:110 | JWT | **global, no owner/admin check** | ArmResponse | P confirmation_code | XT, real-money gate |
| 38 | POST /api/algo/disarm | algo_control.py:150 | JWT | **global, no owner/admin check** | ArmResponse | — | XT, any user disarms |
| 39 | GET /api/algo/status | algo_control.py:187 | JWT | in-proc dict[user] | EngineStatusResponse | — | FAB idle defaults per-dyno |
| 40 | GET /api/algo/confluence | algo_control.py:230 | JWT | in-proc dict[user] | ConfluenceStatusResponse | — | 200ERR has_confluence=False:288 |
| 41 | GET /api/algo/grade | algo_control.py:296 | JWT | n/a | GradeResponse | Q raw instrument | LEAK:341 |
| 42 | GET /api/algo/signal | algo_control.py:349 | JWT | RLS, **none** | SignalStatusResponse | Q raw instrument | XT-shape (telegram_signals) |
| 43 | POST /api/algo/start | algo_control.py:401 | JWT | in-proc dict[user] | StartEngineResponse | P ge/le (loss limit no floor) | order_service=None vs /arm doc |
| 44 | POST /api/algo/stop | algo_control.py:468 | JWT | in-proc dict[user] | StopEngineResponse | — | success=True on wrong dyno:482 |
| 45 | POST /api/algo/flatten | algo_control.py:504 | JWT | in-proc dict[user] | FlattenResponse | — | **kill switch success=True on wrong dyno:518** |
| 46 | GET /api/algo/trades | algo_control.py:544 | JWT | RLS+uid | list[TradeRecord] | Q ge/le both | NOTOT |
| 47 | GET /api/algo/decisions | algo_control.py:597 | JWT | RLS+uid | list[DecisionRecord] | Q ge/le both | NOTOT |
| 48 | GET /api/algo/daily-summary | algo_control.py:643 | JWT | RLS+uid | **none** | Q ge/le | BARE, Decimal in body |
| 49 | GET /api/trace/data | trace_spotgamma.py:213 | JWT | SIERRA (global) | TraceDataResponse | Q datetimes unbounded | NOLIM |
| 50 | GET /api/trace/latest | trace_spotgamma.py:270 | JWT | SIERRA (global) | TraceDataPoint | — | STALE, int() truncation:52-61 |
| 51 | GET /api/trace/targets | trace_spotgamma.py:314 | JWT | SIERRA (global) | TraceTargetsResponse | — | STALE |
| 52 | GET /api/trace/confluence | trace_spotgamma.py:380 | JWT | SIERRA (global) | TraceConfluence | — | FAB hiro_percentile≡50:414+138 |
| 53 | GET /api/trace/captain-condor | trace_spotgamma.py:461 | JWT | SIERRA (global) | Dict[str,Any] | — | BARE, **no time bound:483**, 2 shapes |
| 54 | GET /api/trace/coaching | trace_spotgamma.py:538 | JWT | agent ctx = sub | TraceCoachingResponse | — | LLM cost per call, no rate limit |
| 55 | POST /api/ml-reversion-combo/evaluate | ml_reversion_combo.py:227 | JWT | RLS+uid (prior trades) | EvaluateResponse | P instrument allowlist | FAB data_age=0:352, np.where no-op:380, LEAK:455 |
| 56 | GET /api/ml-reversion-combo/status | ml_reversion_combo.py:462 | JWT | n/a | RCStatusResponse | — | exposes model_dir path |
| 57 | GET /api/ml-reversion-combo/feature-importance | ml_reversion_combo.py:511 | JWT | n/a | RCFeatureImportanceResponse | — | — |
| 58 | POST /api/ml-reversion-combo/refresh-model | ml_reversion_combo.py:533 | JWT | **no admin gate** | RCRefreshResponse | — | 200ERR+LEAK:553, any user reloads model |
| 59 | GET /api/ml-reversion-combo/predictions | ml_reversion_combo.py:560 | JWT | **none (global deque)** | RCPredictionsResponse | Q ge/le | **XT read incl. user_id**, NOTOT |
| 60 | POST /api/user/instrument-risk | user_risk.py:198 | JWT | RLS+uid | InstrumentRiskResponse | P + TICK_VALUES allowlist | LEAK:316, ES/NQ absent from allowlist |
| 61 | POST /api/user/risk-profile | user_risk.py:326 | JWT | RLS+uid | UserRiskProfileResponse | P | **instruments[] silently ignored:396**, LEAK:395 |
| 62 | POST /api/user/bulk-instrument-risk | user_risk.py:411 | JWT | RLS+uid | BulkInstrumentRiskResponse | P | N+1 loop:415, no txn, LEAK in errors[] |
| 63 | GET /api/user/risk-profile | user_risk.py:444 | JWT | RLS+uid, Mech-A substitute | UserRiskProfileResponse | — | 0→1.0 collapse:188, LEAK:522 |
| 64 | GET /api/spotgamma/memory-stats | spotgamma_memory.py:55 | JWT | SIERRA (global) | MemoryStatsListResponse | — | cached, stmt_timeout 5s |
| 65 | POST /api/spotgamma/memory/refresh | spotgamma_memory.py:108 | JWT | **no admin gate** | MemoryRefreshResponse | Q allowlist | any user triggers full recompute |
| 66 | GET /api/spotgamma/memory/{instrument} | spotgamma_memory.py:144 | JWT | SIERRA (global) | HighMemoryLevelsResponse | Q ge/le, level_type raw-param | NOTOT, bounce_rate 0→null |
| 67 | GET /api/spotgamma/memory/{inst}/proximity | spotgamma_memory.py:230 | JWT | SIERRA (global) | ProximityLevelsResponse | Q ge/le, price unbounded | bounce_rate 0→null |
| 68 | GET /api/spotgamma/memory/{inst}/layout | spotgamma_memory.py:311 | JWT | SIERRA (global) | TodayLayoutResponse | path allowlist | cached 30s |
| 69 | GET /api/spotgamma/memory/{inst}/{px}/history | spotgamma_memory.py:369 | JWT | SIERRA (global) | MemoryLevelHistoryResponse | float path = NUMERIC eq | bounce_rate 0→null |
| 70 | GET /api/internal/fnfp-health | internal_fnfp_health.py:133 | KEY | SIERRA (global) | **none** | Header required | BARE, 200ERR:190, sessions_missed blind:250 |
| 71 | GET /api/internal/fnfp-history | internal_fnfp_health.py:303 | KEY | SIERRA (global) | **none** | days clamped in code | BARE, 200ERR:359 |
| 72 | POST /api/v1/ibb-analysis | ibb_analysis.py:124 | JWT | RLS+uid (existing-check uid-less:196) | IBBComplianceResponse | P | FAB accountSize=50000:99, LEAK:315, 201-on-cached |
| 73 | GET /api/v1/ibb-analysis/{trade_id} | ibb_analysis.py:337 | JWT | RLS+uid | IBBComplianceResponse | raw str path | LEAK:381 |
| 74 | POST /api/calculate_aggregate_pl/{user_id} | legacy_pnl.py:39 | GUARD | RAW +path uid | list[DailyPnL] | Q dates, no range cap | N+1 (28 fresh conns), NOLIM |
| 75 | POST /api/calculate_aggregate_pl_plusdates_by_instrument/{user_id}/{instrument} | legacy_pnl.py:55 | GUARD | RAW +path uid | TotalPnL | instrument raw→KeyError | 500 on bad instrument |
| 76 | POST /api/calculate_aggregate_pl_plusdates/{user_id} | legacy_pnl.py:78 | GUARD | RAW +path uid | TotalPnL | Q dates | N+1 |
| 77 | POST /api/calculate_aggregate_pl_plusdates_ticks/{user_id} | legacy_pnl.py:96 | GUARD | RAW +path uid | TotalPnL | Q dates | N+1 |
| 78 | POST /api/calculate_average_pl_by_instrument/{user_id}/{instrument} | legacy_pnl.py:116 | GUARD | RAW +path uid | TotalPnL | instrument raw | — |
| 79 | POST /api/calculate_average_pl_all_instruments/{user_id} | legacy_pnl.py:139 | GUARD | RAW +path uid | TotalPnL | Q dates | N+1 |
| 80 | POST /api/calculate_average_pl_all_instruments_ticks/{user_id} | legacy_pnl.py:159 | GUARD | RAW +path uid | TotalPnL | Q dates | N+1 |
| 81 | POST /api/calculate_pnl_per_logical_trade/{user_id}/{instrument} | legacy_pnl.py:179 | GUARD | RAW +path uid | list[PnLPerLogicalTrade] | instrument raw | NOLIM |
| 82 | POST /api/calculate_pnl_per_contract/{user_id}/{instrument} | legacy_pnl.py:199 | GUARD | RAW +path uid | list[PnLPerContract] | instrument raw | NOLIM |
| 83 | POST /api/daily_pnl_by_instrument_plusdates_ticks/{user_id}/{instrument} | legacy_pnl.py:217 | GUARD | RAW +path uid | list[DailyPnLTicks] | instrument raw | NOLIM |
| 84 | POST /api/calculate_aggregate_pl_plusdates_ticks_historical_view/{user_id} | legacy_pnl.py:240 | GUARD | RAW +path uid | AggregatedPnLTicks | Q dates | N+1 |
| 85 | POST /api/…_historical_view_by_instrument/{user_id}/{instrument} | legacy_pnl.py:262 | GUARD | RAW +path uid | AggregatedPnLTicks | instrument raw | — |
| 86 | POST /api/all_instruments_master_pnl/{user_id} | legacy_pnl.py:285 | GUARD | RAW +path uid | TotalPnL | Q dates | N+1 |
| 87 | POST /api/all_instruments_pnl_per_contract_single_query/{user_id} | legacy_pnl.py:303 | GUARD | RAW +path uid | list[PnLPerContract] | Q dates | NOLIM |
| 88 | POST /api/all_instruments_pnl_per_logical_trade_single_query_ticks/{user_id} | legacy_pnl.py:326 | GUARD | RAW +path uid | list[PnLPerLogicalTrade] | Q dates | NOLIM |
| 89 | POST /api/all_instruments_pnl_per_contract_single_query_ticks/{user_id} | legacy_pnl.py:351 | GUARD | RAW +path uid | list[PnLPerContract] | Q dates | NOLIM |
| 90 | POST /api/all_instruments_daily_pnl_plusdates_ticks/{user_id} | legacy_pnl.py:374 | GUARD | RAW +path uid | list[DailyPnLTicks] | Q dates | NOLIM |
| 91 | POST /api/webhooks/tradingview/menthorq-gex | tradingview_webhooks.py:44 | SEC (MW-exempt) | **global table, shared secret** | MenthorQGEXWebhookResponse | P | LEAK:178, inner 500 re-wrapped |
| 92 | GET /api/webhooks/tradingview/menthorq-gex/{inst}/{date} | tradingview_webhooks.py:190 | MW-only | global (market data) | **none** | typed date | BARE, LEAK:262 |
| 93 | GET /api/webhooks/tradingview/menthorq-gex/{inst} | tradingview_webhooks.py:271 | MW-only | global (market data) | **none** | limit no ge, min(,100) | BARE, LEAK:330, neg limit→500 |
| 94 | GET /api/spotgamma/signals/history | spotgamma_signals.py:39 | JWT | SIERRA (global) | SignalHistoryResponse | Q ge/le + allowlists | **DEAD**, const cache key:127 |
| 95 | GET /api/spotgamma/signals/stats | spotgamma_signals.py:138 | JWT | SIERRA (global) | SignalStatsResponse | Q ge/le | **DEAD**, const cache key:243 |
| 96 | GET /api/spotgamma/signals/pending | spotgamma_signals.py:254 | JWT | SIERRA (global) | PendingSignalsResponse | Q allowlist | **DEAD**, const cache key:315, NOLIM |
| 97 | POST /api/regime/at-entry | at_entry_regime.py:182 | JWT | RLS+uid, Mech-A | AtEntryRegimeResponse | P min/max_length 100 | N+1 (≤100 seq), family map unused |
| 98 | POST /api/users/initialize | users.py:23 | JWT | RLS+uid | UserResponse | email from token | LEAK:110, race→dup-key 500 |
| 99 | GET /api/users/disclaimer-status | users.py:116 | JWT | RLS+uid | DisclaimerStatusResponse | — | — |
| 100 | POST /api/users/accept-disclaimer | users.py:165 | JWT | RLS+uid | DisclaimerAcceptResponse | P Literal type, **version/ip free-form** | client-set legal record |
| 101 | GET /api/videos/presign | videos_cloudfront.py:89 | JWT + rate_limit 20/day | **none — stub returns True:53** | ContentUrlResponse | **objectKey raw** | XT object access, sync file I/O per req |
| 102 | GET /api/videos/health | videos_cloudfront.py:195 | MW-only | n/a | CloudFrontHealthResponse | — | route-dep deviation |
| 103 | GET /api/videos/stats | videos_cloudfront.py:210 | JWT | n/a | CDNStatsResponse | — | FAB "90%"/"active" always |
| 104 | GET /api/market-context/for-session/{sid} | market_context.py:113 | JWT | RLS, no uid predicate → 403 branch | MarketContextResponse | Q ge/le, ::uuid cast | existence oracle:132, ES default:62 |
| 105 | GET /api/market-context/for-trade/{ltid} | market_context.py:156 | JWT | RLS, no uid predicate → 403 branch | MarketContextResponse | Q ge/le, ::uuid cast | existence oracle:176 |
| 106 | GET /api/regime/current | regime.py:32 | JWT | n/a (global) | **none** | — | BARE, FAB vol_state≡NORMAL:122 |
| 107 | GET /api/roll/check/{instrument} | roll_periods.py:26 | JWT | SIERRA (global) | RollCheckResponse | ts fromisoformat→400 | days_remaining 0→null:73 |
| 108 | GET /api/roll/calendar/{instrument} | roll_periods.py:88 | JWT | SIERRA (global) | list[RollPeriod] | days_ahead no ge/le | NOLIM |
| 109 | GET /api/roll/health | roll_periods.py:146 | JWT | SIERRA (global) | **none** | — | BARE, 200ERR+LEAK:161 |
| 110 | PUT /api/user/display-name | user_profile.py:25 | UID | RLS+uid | UpdateDisplayNameResponse | len 1-50 in code | txn-wrapped, no LEAK |
| 111 | GET /api/user/display-name | user_profile.py:77 | JWT | RLS, Mech-A substitute | GetDisplayNameResponse | — | fail-closed 503 (good) |
| 112 | POST /api/coach/conversation/finalize | coach_conversation.py:58 | JWT | **SVC (RLS bypass)** + app-code owner check | FinalizeResponse | P raw str ids | 404/403 split leaks existence |
| 113 | GET /api/coach/conversations/pending-ingest | coach_conversation.py:74 | KEY (MW-exempt) | SVC, cross-user by design | List[PendingConversation] | Q ge/le | exposes auth0_sub (documented) |
| 114 | POST /api/coach/conversations/ingested | coach_conversation.py:95 | KEY (MW-exempt) | SVC, cross-user by design | IngestedResponse | **conversation_ids unbounded list** | no max_length |
| 115 | POST /api/bookmap/request | bookmap_request.py:27 | JWT | RLS+uid | BookmapRequestResponse | — | IDEM (no dedupe), LEAK:76, no notify code |
| 116 | GET /api/macro/today | macro.py:27 | JWT | n/a (global) | MacroTodayResponse | — | cached 6h, clean |
| 117 | GET /api/macro/calendar | macro.py:46 | JWT | n/a (global) | MacroCalendarResponse | Q ge/le | cached 6h, clean |

**Zero-endpoint files in slice (mount surfaces, read in full):** registry/extras_registry.py (mounts spotgamma suite + 18 community + 6 webhook + health-metrics + market-context; every group in a swallow-and-continue try/except), registry/sierra_registry.py (**DUP**: sierra_marketdata mounted at both /api/sierra2 and /api/sierra, lines 13-28), registry/media_registry.py (mounts videos_cloudfront at /api/videos + 13 media routers, one shared try/except), registry/tns_highlights_registry.py, trade_import/__init__.py (re-export shim; the re-exported router is **DUP**-mounted at /api/v1 and /api/trade-import by imports_registry.py:32-42).

---

## LENS 2/6 — Router teardown, 31 files (trade_import/*, agent+audio ingest, educator, level_edge, spotgamma/regime read surfaces, internal rails, registries)

**Coverage.** All 31 assigned files opened. 24 of them declare routes; I enumerated every @router.{get,post,put,patch,delete,options} mechanically with rg and then read each handler body end-to-end — 85 endpoints total, all in the matrix. 7 files declare no endpoints and were read as support code instead: trade_import/db.py, trade_import/rebuild.py, trade_import/validation.py, educator/db.py (read in full or to the extent the routed handlers reach them), and registry/{compliance,support,educator}_registry.py (read in full; they are mount-only shims and mount routers OUTSIDE my slice, so no endpoint rows). Shared dependencies read first: utils/auth.py (get_current_user/get_user_id/require_non_demo_viewer), utils/deps.py (require_admin/require_support_permission/S3/OpenAI), utils/auth_middleware.py (the global JWT gate + its EXCLUDED_PATHS / PUBLIC_PATH_PREFIXES / EXCLUDED_PATH_PREFIXES_EXTRA allowlists), database.py (get_db_dep / get_db_rls_dep / get_db_educator_dep / get_db_service_dep / get_db). IMPORTANT for reading the matrix: AuthMiddleware is mounted unconditionally in main.py:311-317, so an endpoint with no route-level dependency still requires SOME valid JWT unless its path is allowlisted; I write "MW-only" for that case (any authenticated user, no identity binding) and reserve "NONE" for genuinely anonymous paths (middleware-exempt AND no in-handler key check). Where a claim depended on a called service or model I opened it (services/level_edge_service.py, services/spotgamma_email_ingest_service.py, models/_agent_trade_base.py, models/trade_import.py, models/_base.py, models/coaching_memos.py, models/playbook.py, models/audio_presign.py, models/user_cursor_exceptions.py, routers/educator/models.py) — those reads are cited in findings. Not fully traced (so any claim touching them is marked INFERRED): services/risk_metrics_service.py, services/playbook_statistics.py, services/scott_regime/*, services/user_playbook_service.py internals, and the SQLAlchemy cursor-lifetime question in F-24. I did not run anything — read-only via cat/sed/rg/grep only, per the constraint.

Deviation codes: **A!**=auth weaker than siblings / none · **IDOR**=identity from body or path on unscoped conn · **V**=input unvalidated or unbounded · **N+1**=DB call in a loop · **NL**=SELECT without LIMIT on a growing table · **SW**=exception swallowed → 200 with empty/fake data · **LK**=str(e)/traceback leaked to client · **AT**=multi-write atomicity/half-state · **BG**=post-response work · **RM**=no/loose response_model or handler returns a shape the model drops · **PG**=pagination unbounded or truncation invisible · **FL**=feature flag changes behaviour · **DOC**=docstring contradicts code · **DEAD**=mounted-but-unreachable / not mounted

| # | Method + path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|---|
| 1 | OPTIONS /upload-apex-csv | trade_import/routes.py:349 | NONE (route), MW skips OPTIONS | n/a | none | n/a | A! DEAD (CORSMiddleware already answers) |
| 2 | POST /upload-apex-csv | trade_import/routes.py:362 | get_user_id | get_db_dep (unscoped) + route-owned `_rls_transaction` GUC | TradeUploadResponse | trade_date str→strptime; file unbounded | RM(F-1) V FL(4) BG AT LK-partial |
| 3 | POST /trades/upload/confirm | trade_import/routes.py:1293 | get_user_id | get_db_rls_dep | Dict[str,Any] | body lists Dict[str,Any], no max_length | **F-2** SW V RM LK |
| 4 | POST /ingest-rithmic-direct/v1 | trade_import/routes.py:1517 | get_user_id | get_db_rls_dep | RithmicDirectIngestResponse | orders List[dict] unvalidated/unbounded | **F-4** V BG |
| 5 | GET /verify | trade_import/routes.py:1716 | MW-only | n/a | Dict[str,str] | n/a | — |
| 6 | POST /transcriptions/{id}/accept-playbook | transcribe_s3.py:141 | require_non_demo_viewer + rls | user_id from token, explicit filter | Dict[str,Any] | recording_id int, no ge | **F-5** LK RM |
| 7 | POST /test-playbook-detection | transcribe_s3.py:261 | get_current_user | none needed | Dict[str,Any] | transcript Body(str), no max_length | A!-ish DEAD("TEST ENDPOINT" in prod) V LK RM |
| 8 | POST /transcriptions/{id}/reject-playbook | transcribe_s3.py:342 | require_non_demo_viewer + rls | user_id from token | Dict[str,Any] | recording_id int, no ge | LK RM |
| 9 | POST /transcribe | transcribe_s3.py:461 | require_non_demo_viewer + rls | s3Key prefix-checked vs sub (good) | TranscribeS3Response | recordedAt parsed, no S3 size cap | **F-6 F-7** LK |
| 10 | POST /upload-sierra-agent-trades/ | sierra_agent_upload.py:177 | get_user_id + rls | token user_id | SierraAgentUploadResponse | price Decimal unbounded; trades list unbounded | **F-8 F-9 F-10** N+1 LK AT BG |
| 11 | GET /sierra-agent/sync-checkpoint | sierra_agent_upload.py:673 | get_user_id + rls | token user_id | SierraSyncCheckpointResponse | account str free-form | RM(returns `account`, model drops it) LK DOC |
| 12 | GET /sierra-agent/status | sierra_agent_upload.py:731 | get_user_id + rls | token user_id | AgentSyncStatusResponse | n/a | SW (200 `status:"error"`, count 0) |
| 13 | POST /api/internal/tws/bars | tws_ingest.py:65 | X-Internal-Key (hmac) | none (market data) | TWSIngestResponse | TWSBarBatch; bars list unbounded | N+1 LK |
| 14 | GET /api/internal/tws/status | tws_ingest.py:270 | **NONE** | none | TWSStatusResponse | n/a | **F-11** A! SW |
| 15 | GET /api/internal/tws/freshness | tws_ingest.py:322 | **NONE** | none | TWSFreshnessResponse | n/a | **F-11** A! LK |
| 16 | POST /api/internal/tws/heartbeat | tws_ingest.py:380 | X-Internal-Key (hmac) | none | HeartbeatResponse | client_id free-form → unbounded in-proc dict | V (F-11 note) |
| 17 | GET /api/internal/tws/clients | tws_ingest.py:428 | **NONE** | none | TWSClientsResponse | n/a | **F-11** A! (per-dyno view) |
| 18 | GET /api/internal/tws/health | tws_ingest.py:476 | get_db_rls_dep (JWT!) | RLS-scoped read of a global queue | TWSHealthResponse | n/a | **F-12 F-13** A! SW LK |
| 19 | POST /api/recording-sessions/process | process_recording_session.py:814 | get_current_user + rls | ownership checked + RLS | ProcessSessionResponse | session_id from DTO | **F-14** FL(ENABLE_TRANSCRIPTION_QUEUE) BG LK |
| 20 | GET /api/regime-matrix | regime_matrix.py:309 | get_current_user + rls | RLS + explicit user_id + demo GUC swap | none (Dict[str,Any]) | lookback ge/le ✓, dow ge/le ✓, session regex ✓ | **F-15** NL RM |
| 21 | GET /api/sierra/gamma-density-zones | gamma_density.py:41 | MW-only | none (market data) | GammaDensityZonesResponse | instruments CSV unbounded | NL LK |
| 22 | GET .../gamma-density-zones/settings | gamma_density.py:166 | MW-only | none (global config) | GammaDensitySettingsResponse | n/a | LK |
| 23 | GET .../settings/{instrument} | gamma_density.py:219 | MW-only | none | GammaDensitySettings | instrument free-form | LK |
| 24 | **PUT** .../settings/{instrument} | gamma_density.py:270 | MW-only (no admin gate) | none — GLOBAL write | GammaDensitySettings | bounds hand-checked ✓ | **F-16 F-24** LK |
| 25 | GET /api/playbook-suggestions | playbook_suggestions.py:42 | get_current_user + rls | token user_id | PlaybookSuggestionsResponse | min_confidence no ge/le | NL LK PG |
| 26 | POST /playbook-suggestions/{id}/accept | playbook_suggestions.py:152 | get_current_user + rls | token user_id | AcceptSuggestionResponse | trade_id UUID ✓ | **F-17** LK |
| 27 | POST /playbook-suggestions/{id}/reject | playbook_suggestions.py:300 | get_current_user + rls | token user_id | RejectSuggestionResponse | manual_playbook_id unbounded int | V LK |
| 28 | POST /playbook-suggestions/{id}/revert-auto-assign | playbook_suggestions.py:466 | get_current_user + rls | token user_id | RevertAutoAssignResponse | trade_id UUID ✓ | **F-17** DOC LK |
| 29 | PATCH /logical_trades/{trade_id}/playbook | playbooks.py:62 | get_current_user + rls | token user_id | PlaybookResponse | playbook_id int, no ge/le, no FK | **F-18** |
| 30 | GET /stats/ticks | playbooks.py:142 | get_current_user + rls | token user_id, **no demo substitution** | List[PlaybookStatsTicks] | dates typed ✓ | **F-19** A!-consistency NL |
| 31 | GET /stats/ticks_analysis | playbooks.py:169 | get_current_user + rls | RLS + demo GUC swap | List[PlaybookStatsAnalysis] | dates typed ✓ | NL |
| 32 | GET /trades/playbook_ticks_accumulated | playbooks.py:243 | get_current_user + rls | RLS + demo GUC swap | `dict` | all filters Optional but SQL requires all | **F-20** RM NL |
| 33 | GET /trades/playbook_win_rate | playbooks.py:297 | get_current_user + rls | RLS + demo GUC swap | `dict` | Optional filters | RM |
| 34 | GET /api/demo/playbooks/stats/ticks | playbooks.py:374 | rls dep ⇒ JWT required | RLS=caller, query=DEMO_USER_ID | List[PlaybookStatsTicks] | Query(...) required ✓ | **F-21 F-22** DOC |
| 35 | GET /api/demo/playbooks/trades/playbook_ticks_accumulated | playbooks.py:397 | rls dep ⇒ JWT required | same mismatch | `dict` | — | **F-21 F-22** RM |
| 36 | GET /api/demo/playbooks/trades/playbook_win_rate | playbooks.py:422 | rls dep ⇒ JWT required | same mismatch | `dict` | — | **F-21 F-22** RM |
| 37 | GET /api/demo/playbooks/stats/ticks_analysis | playbooks.py:445 | rls dep ⇒ JWT required | same mismatch | List[PlaybookStatsAnalysis] | — | **F-21 F-22** |
| 38 | GET /api/hiro/acceleration/current | hiro/hiro_acceleration.py:260 | get_current_user | none (market data) | HIROAccelerationResponse | n/a | **F-23** DEAD (registry line 62 commented) LK |
| 39 | GET /api/internal/collector-health | internal_collector_health.py:298 | X-Internal-Key (hmac) | none | CollectorHealth | n/a | N+1(7) SW(probe-fail⇒`stale`) per-dyno cache |
| 40 | GET /risk/v1/basic/{instrument} | risk_metrics.py:38 | get_current_user + rls | RLS + demo GUC swap | BasicRiskMetrics | dates ✓, instrument free-form | — |
| 41 | POST /risk/dynamic_risk_advanced/v2/{instrument} | risk_metrics.py:69 | get_current_user + rls | RLS + demo GUC swap | DynamicRiskMetrics | confidence/sims ge-le ✓ | — |
| 42 | GET /api/demo/risk/v1/basic/{instrument} | risk_metrics.py:129 | rls dep ⇒ JWT required | RLS=caller, query=DEMO_USER_ID | BasicRiskMetrics | — | **F-21 F-22** DOC |
| 43 | POST /api/demo/v4/risk/dynamic_risk_advanced/v2/{instrument} | risk_metrics.py:157 | rls dep ⇒ JWT required | same mismatch | DynamicRiskMetrics | sims le=10000 ✓ | **F-21 F-22** DOC |
| 44 | POST /api/audio-upload/upload | audio_upload.py:40 | require_non_demo_viewer | key derived from sub | AudioUploadResponse | min 1KB + max 25MB + content-type ✓ | DEAD-ish (superseded, still mounted) |
| 45 | GET /api/v1/playbooks | playbooks_v1.py:121 | rls dep (JWT) | RLS on user_playbook_definitions | PlaybooksV1Response | n/a | **F-25** NL PG |
| 46 | GET /api/v1/playbooks/{public_id}/edge | playbooks_v1.py:197 | rls dep (JWT) | visibility probe under RLS ✓ | PlaybookEdgeResponse | `by` checked ✓; public_id free-form | — |
| 47 | POST /api/v1/playbooks/{public_id}/instruments | playbooks_v1.py:256 | get_current_user + rls | ownership in service (table has no RLS) | PlaybookInstrumentsResponse | symbol strip/upper | DOC (documented no-RLS table) |
| 48 | GET /v5/trade-gate-matrix/{auth0_id} | scott_regime.py:76 | get_current_user + beta + self-check ✓ | path==sub enforced | TradeGateMatrixResponse | auth0_id free-form (self only) | FL(beta) |
| 49 | GET /v5/mtd-behavioral-signals/{auth0_id} | scott_regime.py:137 | get_current_user + beta + self-check ✓ | path==sub enforced | BehavioralSignalsResponse | — | FL(beta) |
| 50 | GET /v5/mtd-telemetry/{auth0_id} | scott_regime.py:190 | get_current_user + beta + self-check ✓ | path==sub enforced | MtdTelemetryResponse | — | **F-26** SW |
| 51 | POST /api/webhooks/spotgamma/email-ingest | spotgamma_email_ingest.py:33 | in-handler `!=` secret; MW-exempt | none | EmailIngestResponse | Form fields unbounded | **F-27** LK |
| 52 | POST /api/webhooks/spotgamma/reprocess | spotgamma_email_ingest.py:93 | MW-only | none — GLOBAL write + LLM spend | ReprocessResponse | date strptime ✓ | **F-28** A! LK |
| 53 | GET .../context/current | spotgamma_email_ingest.py:132 | **NONE** (EXCLUDED_PATHS) | none | MarketContextResponse | n/a | intentional public read |
| 54 | GET .../context/for-trade | spotgamma_email_ingest.py:146 | **NONE** (EXCLUDED_PATHS) | none | MarketContextResponse | entry_time typed ✓ | intentional public read |
| 55 | GET .../context/history | spotgamma_email_ingest.py:166 | **NONE** (EXCLUDED_PATHS) | none | MarketContextResponse **(bypassed)** | days ge/le ✓ | **F-29** RM |
| 56 | GET .../context/{context_date} | spotgamma_email_ingest.py:186 | MW-only | none | MarketContextResponse **(bypassed)** | date typed ✓ | **F-29** RM |
| 57 | POST .../context/submit | spotgamma_email_ingest.py:210 | MW-only | none — GLOBAL write + LLM spend | EmailIngestResponse | content min_length only, **no max** | **F-28** V LK |
| 58 | GET .../context/{context_date}/images | spotgamma_email_ingest.py:247 | MW-only | none | MarketContextResponse **(bypassed)** | session regex ✓ | **F-29** RM |
| 59 | GET /cursor-exceptions | user_cursor_exceptions.py:29 | get_current_user + rls | token user_id | CursorExceptionsResponse | n/a | **F-30** SW |
| 60 | POST /cursor-exceptions | user_cursor_exceptions.py:82 | get_current_user + rls | token user_id | CursorExceptionsResponse | `exceptions` str, no max_length | **F-30** V LK RM(BaseDomainModel at API edge) |
| 61 | POST /api/audio/presign | audio_presign.py:52 | require_non_demo_viewer | key derived from sub ✓ | PresignAudioUploadResponse | content_type free-form, **no size/type gate** | **F-7** V |
| 62 | GET /api/sierra/confluence-zones | confluence_zones.py:29 | MW-only | none (market data) | ConfluenceZonesResponse | instruments CSV unbounded | NL DOC("top 3") LK |
| 63 | GET /api/internal/spotgamma/hiro/{sym} | internal_spotgamma.py:56 | JWT (MW) **+** `!=` key | none | none | sym → Redis key suffix | **F-31** RM |
| 64 | GET /api/internal/spotgamma/levels/{sym} | internal_spotgamma.py:70 | JWT (MW) + `!=` key | none | none | sym unvalidated | **F-31** RM |
| 65 | GET /api/internal/spotgamma/overview | internal_spotgamma.py:84 | JWT (MW) + `!=` key | none | none | n/a | **F-31** RM |
| 66 | GET /api/internal/spotgamma/vx-term | internal_spotgamma.py:97 | JWT (MW) + `!=` key | none | none | n/a | **F-31** RM |
| 67 | GET /api/internal/spotgamma/status | internal_spotgamma.py:110 | JWT (MW) + `!=` key | none | none | n/a | **F-31** RM |
| 68 | POST /api/educator/recordings/presign | educator/routes.py:52 | get_db_educator_dep | educator_id from GUC ✓ | PresignResponse | **filename ext + content_type raw into S3 key** | **F-32** V |
| 69 | POST /api/educator/recordings | educator/routes.py:78 | get_db_educator_dep | educator_id from GUC | RecordingOut | **s3_key taken raw from body** | **F-33** IDOR V |
| 70 | GET /api/educator/recordings | educator/routes.py:100 | get_db_educator_dep | RLS by educator | list[RecordingOut] | n/a | **F-34** PG |
| 71 | GET /api/educator/recordings/{id}/briefing | educator/routes.py:107 | get_db_educator_dep | RLS by educator ✓ | BriefingOut | recording_id int | — |
| 72 | POST /api/educator/recordings/{id}/status | educator/routes.py:127 | get_db_educator_dep | RLS by educator ✓ | `ShareOut \| dict` | status allowlist ✓ | **F-35** RM |
| 73 | POST /api/educator/dictionary | educator/routes.py:148 | get_db_educator_dep | educator_id from GUC ✓ | none | **rules list unbounded**, confidence no ge/le | **F-36** N+1 V RM |
| 74 | POST /api/level-edge/signal | level_edge.py:58 | get_current_user | user_id passed to service | LevelTouchSignalResponse | LevelTouchSignalCreate | LK-ish (safe_detail_string) |
| 75 | GET /api/level-edge/stats | level_edge.py:78 | get_current_user | user_id passed to service | LevelEdgeStatsResponse | instrument free-form | **F-37** SW |
| 76 | GET /api/level-edge/current-levels/{instrument} | level_edge.py:116 | get_current_user | none (market data) | CurrentLevelsResponse | instrument free-form | — |
| 77 | POST /api/level-edge/evaluate | level_edge.py:145 | get_current_user | **none — mutates ALL users' signals** | EvaluateResponse | no body | **F-38** NL |
| 78 | GET /api/level-edge/recent-signals | level_edge.py:167 | get_current_user | **none — reads all users' rows** | RecentSignalsResponse | limit no le | **F-39** PG SW |
| 79 | GET /api/level-edge/baselines | level_edge.py:184 | **NONE** (EXCLUDED_PATHS) | none | BaselinesResponse | filters free-form | see F-40 |
| 80 | GET /api/level-edge/edge-matrix | level_edge.py:208 | **NONE** (EXCLUDED_PATHS) | none | EdgeMatrixResponse | level_type free-form → Redis key | **F-41** V |
| 81 | POST /api/level-edge/backtest/start | level_edge.py:238 | get_current_user | **none — overwrites shared baselines** | BacktestStartResponse | dates free-form, range unbounded | **F-40** AT |
| 82 | GET /api/level-edge/backtest/status/{job_id} | level_edge.py:262 | get_current_user | **none — in-proc dict, any job_id** | BacktestJobResponse | job_id free-form | **F-42** DEAD |
| 83 | GET /api/level-edge/backtest/available-levels | level_edge.py:286 | MW-only | n/a (static) | BacktestAvailableLevelsResponse | n/a | — |
| 84 | GET /api/coaching/memos | coaching.py:22 | get_current_user + rls | token user_id + RLS ✓ | List[CoachingMemo] | **limit no ge/le**, cadence free-form | **F-43** PG |
| 85 | POST /api/internal/coaching/memos | internal_coaching.py:42 | X-Internal-Key (hmac) ✓ | **user_id from BODY on service-role conn** | CoachingMemoIngestResponse | cadence/memo_md/dates unbounded | **F-44** (by design, but see finding) |

Support files with no endpoints (read, findings folded into the rows above): trade_import/db.py (F-3, F-45, F-46), trade_import/rebuild.py (F-3), trade_import/validation.py (F-2, F-47), educator/db.py (F-34, F-35, F-36), registry/compliance_registry.py, registry/support_registry.py, registry/educator_registry.py (mount-only; educator registry is FL-gated on settings.EDUCATOR_ENABLED).

---

## LENS 4/6 — Router teardown, 31 files (routers/ slice: recording_sessions, gsst, hiro x2, telegram, tradovate, bookmap, voice_training, legacy_stats, sierra, streak, morning_feed, rulebook, equity, support_intake, sg3, gamma_density, rithmic_hybrid, identity, user_glossary, coach_turn, options_templates, user_account_risk, + 4 registries + trade_import/{parsers,excursions} + educator/{briefing,models})

**Coverage.** All 31 files opened. 23 of them declare routes (105 endpoints, enumerated mechanically with rg then each handler read in full); 8 declare none (trade_import/parsers.py, trade_import/excursions.py, educator/briefing.py, educator/models.py, registry/{hiro,core,sg_poc,scott_regime}_registry.py) and were audited as support modules — they contribute 0 matrix rows but 8 findings. Shared deps read once and applied across the slice: utils/auth.py (get_current_user, get_user_id, security=HTTPBearer() auto_error=True at :42, require_non_demo_viewer), utils/deps.py (require_admin, require_support_permission), utils/auth_middleware.py (EXCLUDED_PATHS / PUBLIC_PATH_PREFIXES), utils/auth_guard.py (verify_user_id_ownership), database.py (get_db, get_db_dep, get_db_rls_dep, get_db_educator_dep, get_db_service_dep, get_db_connection_sync), utils/cache.py (cache_or_fetch → Redis, shared across dynos). I also read consuming/consumed files where a claim depended on them: services/legacy_stats_service.py, services/gsst_analysis.py, services/logical_trades.py (pnl_ticks convention), gamma_density/{collector,bifurcation/*}.py, routers/educator/routes.py, router_registry.py, several models/*.py. Not fully read: the service bodies behind streak/rulebook/coach_turn/equity (compute_streak_analysis, grade_trade, run_turn, fetch_synth_oi_daily_jewels) and the SG-2 router — findings touching them are marked INFERRED. Deliberately excluded per the brief: the four named agent-upload routers' errors=[] pattern, the bare no-response_model count, sg3's limit-cap, sierra_marketdata:652, utils/safe_task, utils/user_context:29, deps.py:152, rithmic_import:739, educator/routes_zoom, and DB-layer RLS posture.

Codes: `A0` no route-level auth dep (AuthMiddleware only) · `A!` anonymous-reachable (middleware exemption) · `IDOR` tenant key from request not token · `SVC` service-role conn · `NL` SELECT w/o LIMIT on growing table · `NB` numeric/list bound missing · `RD` raw dict body · `LK` str(e)/traceback in response body · `200F` HTTP 200 on failure · `NRM` no response_model · `NP` no pagination/total · `N+1` DB call in loop · `BLOCK` sync blocking call in async def · `CACHE` shared cache key omits a request input · `ATOM` multi-write, no single txn · `FLAG` feature-flag changes behaviour · `DEP` deprecated/compat route still mounted

| # | Method + path | file:line | Auth dep | Tenant scoping | response_model | Input validation | Flags |
|---|---|---|---|---|---|---|---|
| 1 | POST /api/recording-sessions/create | recording_sessions.py:70 | get_current_user + rls | RLS + sub | CreateSessionResponse | none (no body) | — |
| 2 | POST /api/recording-sessions/presigned-url | :126 | get_current_user + rls | RLS + explicit owner check | GetPresignedUrlResponse | Pydantic | s3 key from sub (safe) |
| 3 | POST /api/recording-sessions/save-chunk | :195 | get_current_user + rls | RLS + owner check | SaveChunkMetadataResponse | Pydantic; s3_key client-supplied | — |
| 4 | POST /api/recording-sessions/stop | :284 | get_current_user + rls | RLS + owner check | StopSessionResponse | Pydantic | — |
| 5 | GET /api/recording-sessions/info/{session_id} | :364 | get_current_user + rls | RLS + owner check | SessionInfo | path str, no uuid guard | — |
| 6 | GET /api/recording-sessions/details/{session_id} | :413 | get_current_user + rls | RLS + owner check | SessionDetailsResponse | — | NL (chunks) |
| 7 | GET /api/recording-sessions/list | :547 | get_current_user + rls | explicit user_id | List[SessionInfo] | limit: int = 20 | NB, NP |
| 8 | GET /api/recording-sessions/{id}/trades-with-voice | :622 | get_current_user + rls | RLS + owner check | TradesWithVoiceResponse | — | N+1, NL |
| 9 | GET /api/recording-sessions/{id}/analysis | :832 | get_current_user + rls | owner check | SessionAnalysisResponse | $1::uuid cast → 500 on bad id | — |
| 10 | POST /api/recording-sessions/{id}/analyze | :875 | get_current_user + rls | owner check | SessionAnalysisResponse | — | LLM cost, no demo gate |
| 11 | DELETE /api/recording-sessions/{session_id} | :892 | get_current_user + rls | RLS + owner check | DeleteSessionResponse | — | ATOM (S3 vs DB) |
| 12 | GET /api/hiro/divergence/current | hiro/hiro_divergence_walkforward.py:483 | get_current_user | none (market) | CurrentDivergenceResponse | instrument/hiro_source unvalidated **and ignored** | CACHE |
| 13 | GET /api/hiro/divergence/stats | :696 | get_current_user | explicit user_id (sierra SVC) | DivergenceStatsResponse | evaluation_minutes clamped | **CACHE (leaks personal)**, FLAG (HIRO_DIVERGENCE_USE_BASELINE) |
| 14 | GET /api/hiro/divergence/preferences | :793 | get_current_user | explicit user_id | UserPreferencesResponse | — | 200-with-default on DB error |
| 15 | POST /api/hiro/divergence/preferences | :818 | get_current_user | explicit user_id | UserPreferencesResponse | ge=1 le=30 | — |
| 16 | POST /api/hiro/divergence/signal | :850 | get_current_user | explicit user_id | SignalCreateResponse | symbol/hiro_source free str, NB | 200F, LK |
| 17 | GET /api/hiro/momentum/current | hiro/hiro_momentum.py:266 | get_current_user | none | MomentumSignalResponse | none | CACHE(ok) |
| 18 | GET /api/hiro/momentum/stats | :455 | get_current_user | none | MomentumStatsResponse | none | fabricated matrix |
| 19 | GET /api/hiro/momentum/time-window | :521 | get_current_user | none | MomentumTimeWindowResponse | none | returns bare TypedDict |
| 20 | GET /api/v1/gsst-settings | gsst_analysis.py:81 | get_current_user + rls | RLS + user_id | GSSTSettingsApiResponse | — | LK |
| 21 | PUT /api/v1/gsst-settings | :138 | get_current_user + rls | RLS + user_id | GSSTSettingsApiResponse | Pydantic | LK |
| 22 | POST /api/v1/gsst-settings/reset | :222 | get_current_user + rls | RLS + user_id | GSSTSettingsApiResponse | — | LK |
| 23 | POST /api/v1/gsst-analysis | :268 | get_current_user + rls | RLS + owner check | GSSTComplianceResponse | UUID() raises → 500 | **broken INSERT arity**, LK |
| 24 | GET /api/v1/gsst-analysis/{trade_id} | :732 | get_current_user + rls | RLS + owner check | GSSTComplianceResponse | Path str → UUID() | LK |
| 25 | POST /api/bookmap/logical-trade | bookmap_stats_import.py:664 | get_user_id + rls | RLS + JWT sub (payload.user_id ignored — good) | BookmapLogicalTradeResponse | Pydantic; entry/exit_time raw str | LK, idempotency (SELECT-then-INSERT) |
| 26 | GET /api/user/account-risk/accounts | user_account_risk.py:50 | get_current_user + rls | RLS + user_id | DiscoveredAccountsListResponse | — | NL, NP |
| 27 | GET /api/user/account-risk/accounts/{name} | :166 | get_current_user + rls | RLS + user_id | AccountRiskResponse | unquote(name), no len cap | — |
| 28 | POST /api/user/account-risk/accounts/{name} | :250 | get_current_user + rls | RLS + user_id | AccountRiskResponse | Pydantic gt/le | `all([...])` treats 0.0 as missing |
| 29 | POST /api/user/account-risk/accounts/{name}/gear/{preset} | :387 | get_current_user + rls | RLS + user_id | AccountRiskResponse | enum preset | overwrites account_size |
| 30 | DELETE /api/user/account-risk/accounts/{name} | :517 | get_current_user + rls | RLS + user_id | DeleteAccountRiskResponse | — | returns bare dict |
| 31 | PATCH /api/user/account-risk/accounts/{name} | :601 | get_current_user + rls | RLS + user_id | AccountRiskResponse | f-string cols from model (closed set) | **breaks preset↔pct invariant**; exclude_none |
| 32 | POST /api/webhooks/telegram | telegram_signals.py:245 | in-handler HMAC secret (fail-closed) | SVC, telegram_user_id whitelist | TelegramSignalResponse | TelegramUpdate | 200F, ATOM |
| 33 | GET /api/webhooks/telegram/signals/active | :491 | rls dep only (no CurrentUser) | **none — all users** | List[ActiveSignalResponse] | — | NL |
| 34 | GET /api/webhooks/telegram/signals/{instrument} | :508 | rls dep only | none — any instrument | SignalDetailResponse | instrument allow-list | returns bare dict |
| 35 | DELETE /api/webhooks/telegram/signals/{instrument} | :583 | rls dep only | **IDOR — user_id from query string** | SignalActionResponse | instrument allow-list | — |
| 36 | POST /api/webhooks/telegram/signals/expire | :616 | get_current_user + rls | none (global UPDATE) | SignalExpireResponse | — | any user expires all |
| 37 | POST /api/webhooks/telegram/setup-webhook | :631 | get_current_user (docstring says "operator-only") | n/a | WebhookSetupResponse | **webhook_url raw query str** | LK |
| 38 | POST /api/upload-tradovate-agent-trades/ | tradovate_agent_upload.py:179 | get_user_id + rls | RLS + sub | TradovateAgentUploadResponse | trades list NB; trade_date pattern allows 9999-99-99 | FLAG(ENABLE_TOMBSTONE_CHECK), N+1, 200F, LK, ATOM |
| 39 | GET /api/tradovate-agent/sync-checkpoint | :551 | get_user_id + rls | explicit user_id | TradovateSyncCheckpointResponse | account free str | LK |
| 40 | GET /api/tradovate-agent/status | :607 | get_user_id + rls | explicit user_id | AgentSyncStatusResponse | — | 200F |
| 41 | POST /api/voice-training/feedback | voice_training.py:148 | get_current_user + rls | writes own sub | SubmitFeedbackResponse | in-handler len 5..1000 + allow-lists | per-dyno rate limit |
| 42 | GET /api/voice-training/feedback/{mapping_id} | :253 | get_current_user + rls | **none — community read, exposes others' auth0 sub** | GetFeedbackResponse | limit=min(limit,50); offset NB | NP(total ok) |
| 43 | POST /api/voice-training/feedback/like/{feedback_id} | :340 | get_current_user + rls | own sub | ToggleLikeResponse | int path | — |
| 44 | GET /api/voice-training/leaderboard | :409 | rls dep only | none — all users' sub exposed | LeaderboardResponse | **period unvalidated**; f-string into SQL (literal set) | per-dyno cache |
| 45 | GET /api/voice-training/stats | :516 | rls dep only | none | VoiceTrainingStatsResponse | — | 3 hardcoded metrics |
| 46 | GET /api/v1/support/intake/status | support_intake.py:208 | require_support_permission | n/a | SupportIntakeStatusResponse | — | — |
| 47 | POST /api/v1/support/identity/resolve | :222 | require_support_permission | SVC, cross-user lookup by design | SupportIdentityResolveResponse | Pydantic | — |
| 48 | POST /api/v1/support/intake-events | :236 | get_current_user (weaker than 4 siblings) | SVC + token sub | SupportIntakeCreateResponse | redact/sanitize; **artifact gate fails open on empty mime** | FLAG(SUPPORT_IN_APP_INTAKE_ENABLED→404) |
| 49 | GET /api/v1/support/intake-events | :386 | require_support_permission | SVC, global feed | SupportIntakeFeedResponse | limit ge=1 le=100, cursor | proper cursor + has_more |
| 50 | POST /api/v1/support/intake-events/{id}/processing-events | :442 | require_support_permission | SVC + ticket_id match | SupportProcessingEventResponse | sanitize, 409 on mismatch | ON CONFLICT DO NOTHING hides payload divergence |
| 51 | GET /api/v1/sg/playbooks | sg_playbook_ecosystem_sg3.py:76 | get_current_user + rls | RLS + sub in query | SGPlaybooksListResponse | limit ge=1 (no le) | unbounded in-proc CACHE, NP(no offset) |
| 52 | POST /api/v1/sg/playbooks/{id}/vote | :162 | get_current_user + rls | own sub | VoteResponse | VoteRequest | per-dyno cache invalidation |
| 53–74 | POST /api/calculate_win_rate/{user_id}, /calculate_win_rate_decimal/{user_id}, /calculate_win_rate_logical_trade_basis/{user_id}, /..._plusdates/{user_id}, /..._plusdates_historical/{user_id}, /expectancy_by_instrument_plusdates_{ticks,dollars}/{user_id}/{instrument}, /calculate_average_{win,loss}_pl_by_instrument_{ticks,dollars}/{user_id}/{instrument} (4), /profit_factor_by_instrument_plusdates_{ticks,dollars}/{user_id}/{instrument}, /profit_factor_by_instrument_plusdates_dollars_logical_trade_basis/{user_id}/{instrument}, /top_instruments_by_pnl/{user_id}, /all_instruments_expectancy_single_query_ticks/{user_id}, /all_instruments_average_{win,loss}_pl_single_query_ticks/{user_id}, /all_instruments_profit_factor_single_query_{ticks,dollars}/{user_id}, /all_instruments_profit_factor_logical_trade_basis_single_query_dollars/{user_id}, /all_instruments_win_rate_logical_trade_basis_historical_single_query/{user_id} | legacy_stats.py:34–401 (22 handlers) | router-level `verify_user_id_ownership` (path user_id vs users.id) | path user_id == caller (verified) | all present; :88 uses `list[dict[str,Any]]`, :392 `list[WinRateHistorical]` | date query params, **no range bound**; instrument free str (validated in svc) | sync `def` handlers → threadpool; new psycopg2 conn per call; :88 day-loop |
| 75 | POST /api/sierra/gamma-density/bifurcate/single-day | gamma_density_bifurcation.py:62 | **A0** | n/a | SingleDayResponse | threshold 5..100 in-handler; min_levels NB | BLOCK, LK |
| 76 | POST /api/sierra/gamma-density/bifurcate/backtest | :162 | **A0** | n/a | BacktestResponse | ≤60 days; **threshold unbounded (sibling deviation)** | BLOCK, LK |
| 77 | POST /api/sierra/gamma-density/bifurcate/walkforward | :261 | **A0** | n/a | WalkForwardResponse | ≤200 days; threshold unbounded | BLOCK, LK |
| 78 | GET /api/sierra/market-data/{instrument} | sierra.py:75 | **A0** | n/a | MarketDataResponse | start/end unbounded | NL, LK |
| 79 | GET /api/sierra/tick-data/{exchange} | :108 | **A0** | n/a | TickDataResponse | unbounded window | NL, LK |
| 80 | GET /api/sierra/adr-data/{exchange} | :138 | **A0** | n/a | AdrDataResponse | unbounded window | NL, LK |
| 81 | GET /api/sierra/menthorq-data/{instrument} (+ alias /api/zen-market-data/{instrument}) | :168 | **A0** | n/a | MenthorQDataResponse | unbounded window | **CACHE (hour-granular key)**, DEP, LK |
| 82 | POST /api/sierra/calculate-trade-excursions-legacy | :250 | **A0** | trade ids from body | List[TradeExcursionResponse] | typed list, no max_length | **DEP** ("use compat_shims") |
| 83 | GET /api/sierra/data-coverage | :282 | **A0** | n/a | **NRM** | — | no try/except |
| 84 | GET /api/sierra/health/data-freshness | :292 | **A!** (EXCLUDED_PATHS) | n/a | DataFreshnessHealth | — | 200F, **LK to anonymous** |
| 85 | GET /api/morning-feed/latest | morning_feed.py:136 | get_current_user + rls | RLS + user_id | **NRM** (dict) | — | SELECT * |
| 86 | GET /api/morning-feed/history | :174 | get_current_user + rls | RLS + user_id | **NRM** (list[dict]) | limit ge=1 le=30 | inner FROM drops feed-only days; NP |
| 87 | GET /api/morning-feed/{feed_date} | :225 | get_current_user + rls | RLS + user_id | **NRM** | date path | SELECT * |
| 88 | POST /api/morning-feed/devices/register | :265 | get_current_user + rls | own sub | **NRM** | **RD** — token any length/format | — |
| 89 | DELETE /api/morning-feed/devices/{token} | :310 | get_current_user + rls | own sub | **NRM** | path str | reports deleted flag |
| 90 | GET /api/v2/v5/streak_analysis/{instrument} | streak_metrics.py:45 | get_current_user + rls | effective_user + set_rls_user | TradeStreakMetrics | dates required; **unused `user_id` query param** | LK, CACHE(keyed ok) |
| 91 | GET /api/v2/v5/streak_analysis_by_playbook/{instrument} | :125 | get_current_user + rls | effective_user + set_rls_user | TradeStreakMetrics | playbook_id required | LK; no `except HTTPException: raise` |
| 92 | GET /api/v2/v6/enhanced_streak_analysis/{instrument} | :178 | get_current_user + rls | own sub | EnhancedStreakResponse | — | no demo substitution (sibling deviation) |
| 93 | GET /api/demo/v5/streak_analysis/{instrument} | :222 | **claims A!, actually get_db_rls_dep→get_current_user** | forces DEMO_USER_ID, no set_rls_user | TradeStreakMetrics | rate_limit 5/min | **403 for anonymous** |
| 94 | GET /api/demo/v6/enhanced_streak_analysis/{instrument} | :258 | same | same | EnhancedStreakResponse | rate_limit | **403 for anonymous** |
| 95 | POST /api/rithmic-hybrid/import | rithmic_hybrid.py:100 | get_user_id + single-user env check | own sub | RithmicHybridResponse | lookback_days from body | FLAG(mount gated), LK, silent drops |
| 96 | GET /api/rulebook/pre-flight | rulebook.py:78 | get_current_user | platform-wide by design | PreFlightGateResponse | — | no try/except |
| 97 | GET /api/rulebook/grade | :124 | get_current_user + rls | resolve_data_source + set_config (correct pattern) | RulebookGradeResponse | UUID query params | str(e) in 404/502 body |
| 98 | GET /api/equity/universe | equity_marketdata.py:87 | get_current_user | n/a (static certs) | EquityUniverseResponse | — | — |
| 99 | GET /api/equity/marketdata/1min | :114 | get_current_user | n/a | EquityBars1MinResponse | symbol pattern, window ≤168h | **SET LOCAL outside txn = inert** |
| 100 | GET /api/equity/synth-oi/daily | :148 | get_current_user | n/a | SynthOiDailyResponse | symbol pattern, span ≤365d | same; CACHE keyed correctly |
| 101 | POST /api/identity/sync-rithmic | identity.py:46 | get_user_id + RITHMIC_WHITELIST | own sub | SyncRithmicResponse | username/password no bounds | **hardcoded API key**, 200F, LK |
| 102 | GET /api/user/glossary | user_glossary.py:40 | get_current_user + rls | RLS + user_id | UserGlossaryResponse | — | — |
| 103 | PUT /api/user/glossary | :48 | get_current_user + rls | RLS + user_id | UserGlossaryResponse | **rules/deny_list no max_length; deny items no max_length** | N+1 in txn |
| 104 | POST /api/coach/turn | coach_turn.py:32 | get_current_user + rls | RLS + service ownership errors | CoachTurnResponse | 413 guard, typed errors, no leak | persist_turn swallows |
| 105 | GET /api/v1/options/strategy-templates | options_strategy_templates.py:26 | get_current_user | none (global ref data) | list[StrategyTemplate] | — | get_db_dep (no GUC set), NL |
| — | trade_import/parsers.py, trade_import/excursions.py, educator/briefing.py, educator/models.py, registry/{hiro,core,sg_poc,scott_regime}_registry.py | — | 0 routes | — | — | — | audited as support modules (F-24…F-31) |

---

## LENS 6/6 — router teardown, 33 files (routers/ in zenedge-backend-fusion @ origin/main a59646ae)

**Coverage.** All 33 files opened. 25 of them declare routes; 8 declare none (trade_import/processing.py, trade_import/grouping.py, educator/background.py, educator/__init__.py, registry/trades_registry.py, registry/imports_registry.py, registry/playbooks_v1_registry.py, registry/user_playbook_stats_registry.py) — those were audited as mount tables / shared write paths instead, and findings from them are included. Route enumeration was mechanical (`rg '@router\.(get|post|put|patch|delete|options)'`) per file, then every handler was read in full. Shared deps read once and applied across the slice: utils/auth.py, utils/deps.py, utils/auth_middleware.py (full EXCLUDED_PATHS/PUBLIC_PATH_PREFIXES tables), database.py (get_db/get_db_dep/get_db_rls_dep/get_db_educator_dep/get_db_service_dep), utils/rate_limit.py, utils/cache.py, main.py middleware stack, router_registry.py + the 8 sub-registries that mount my routers. Endpoint count 117 counts distinct route decorators (one handler in logical_trades.py carries two @router.get paths and is counted as 2). It does NOT multiply by duplicate mounts: sierra_marketdata.py's 18 routes are each mounted twice (/api/sierra2 and /api/sierra), so the live URL count is 18 higher than 117. Where a finding depended on a table's RLS posture I checked db/schema_test_seed.sql and db/migrations directly rather than assuming (that is how the zones.py IDOR was confirmed rather than inferred). Not fully chased: the service-layer bodies behind mindfulness_service, collective_pulse_service, and touch_outcome_tracker were read only at the entry points the routers call; ml/trade_quality/evaluate.py and training.py were read only along the /backtest path. Anything resting on those is marked INFERRED.

Flag codes: `A0` no handler-level auth dep · `MWΔ` middleware allowlist disagrees with handler deps · `IDOR` no tenant filter/ownership check · `L!` unbounded limit or SELECT with no LIMIT · `E!` `str(e)` reaches response body · `200F` HTTP 200 after internal failure · `DUP` duplicate/dead route · `DOC` docstring contradicts code · `Z0` falsy-zero coercion · `TX` non-atomic multi-write · `BG` post-response work · `$$` unbounded external cost · `RM-` no response_model / bare dict · `PG-` no total, truncation indistinguishable

### sierra_marketdata.py — mounted TWICE: `/api/sierra2` AND `/api/sierra` (registry/sierra_registry.py:15-26). Every row below is two live URLs.
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /_whoami | sierra_marketdata.py:171 | NONE | n/a | WhoamiResponse | n/a | A0 (all 17 siblings gated) |
| GET /contracts/resolve | :199 | get_current_user | market data | ContractResolveResponse | `_validate_instrument` | — |
| GET /contracts/at-time | :277 | get_current_user | market data | ContractAtTimeResponse | `_validate_instrument` | — |
| GET /contracts/windows | :318 | get_current_user | market data | ContractWindowsResponse | `_validate_instrument` | — |
| GET /contracts/partitions | :347 | get_current_user | market data | ContractPartitionsResponse | validated + range check | — |
| GET /marketdata/1min | :428 | get_current_user | market data | Dict[str,Any] | window cap | RM- |
| GET /marketdata/5min | :487 | get_current_user | market data | Dict[str,Any] | window cap | RM- |
| GET /ohlc/1s | :558 | get_current_user | market data | Dict[str,Any] | limit ge/le, window cap | RM-, E!(:645) |
| POST /calculate-trade-excursions-v2 | :652 | get_current_user | none — body-supplied trades | none | `List[Dict[str,Any]]` raw (known #11) | RM-, E!(:691) |
| POST /calculate-trade-excursions-by-id | :695 | get_current_user | explicit user_id in query (svc:1587) | none | TradeIdRequest, no max_length | RM-, header-flood |
| GET /calendar/slice | :758 | get_current_user | market data | CalendarSliceResponse | `_validate_instrument` | — |
| GET /trade-context | :793 | get_current_user | market data | TradeContextResponse | `_validate_instrument` | — |
| GET /internals/availability | :852 | get_current_user | market data | InternalsAvailabilityResponse | min/max_length | — |
| GET /health | :869 | NONE | n/a | SierraHealthResponse | n/a | A0, E!(:889) |
| GET /ib-realtime/{instrument} | :897 | get_current_user | market data | IBRealtimeResponse | `_validate_instrument` | E!(:916) |
| GET /ib-history/{instrument} | :922 | get_current_user | market data | IBHistoryResponse | days ge/le | E!(:953) |
| GET /atr/{instrument} | :959 | get_current_user | market data | ATRResponse | lookback ge/le | E!(:976) |
| GET /ib-stats/health | :982 | NONE (middleware-allowlisted) | n/a | IBStatsHealthResponse | days ge/le | A0 (deliberate), E!(:1026), 200F |

### logical_trades.py — `/api` (router) + `/api/demo` (demo_router)
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/v2/v6/advanced_stats_ticks_list_all | :76 | get_current_user + rls | rls + explicit user_id | LogicalTradeStatsResponse | date strptime | — |
| GET /api/v6/advanced_stats_ticks_list_all | :78 | same handler | same | LogicalTradeStatsResponse | same | DUP (2nd path, same fn) |
| GET /api/v2/logical_trades/{id}/executions | :141 | get_current_user + rls | rls + `lt.user_id=$2` | List[IndividualTradeExecution] | UUID | logs full SQL+user (:200) |
| DELETE /api/v2/logical_trades/{id} | :259 | get_current_user + rls | rls + cascade svc | DeleteTradeResponse | UUID | — |
| GET /api/demo/v6/advanced_stats_ticks_list_all | :354 | rls dep ⇒ JWT required | forces DEMO_USER_ID under caller's GUC | LogicalTradeStatsResponse | Query(...) | DOC, rate-limit inert |
| GET /api/demo/v2/v6/advanced_stats_ticks_list_all | :376 | rls dep ⇒ JWT required | same | (none declared) | Query(...) | DOC, RM-, no @rate_limit at all |
| GET /api/demo/v2/logical_trades/list | :401 | rls dep ⇒ JWT required | same | LogicalTradeStatsResponse | Query(...) | DOC, rate-limit inert |
| GET /api/v2/logical_trades/list | :427 | get_current_user + rls | rls + explicit | LogicalTradeStatsResponse | Query(...) | — |
| GET /api/v2/logical_trade_count | :454 | get_current_user + rls | rls + `user_id=$3` | LogicalTradeCountResponse | date type | DOC (`trades` always []) |
| GET /api/v2/advanced_stats_ticks_list_all | :492 | get_current_user + rls | rls + explicit | LogicalTradeStatsResponse | — | DUP (back-compat alias) |
| GET /api/demo/v2/logical_trade_count | :517 | rls dep ⇒ JWT required | forces DEMO_USER_ID | LogicalTradeCountResponse | date type | DOC, rate-limit inert |
| GET /api/v2/orphaned_fills | :544 | get_current_user + rls | rls + user_id arg | OrphanedFillsResponse | strptime | E!(:570) |
| POST /api/v2/orphaned_fills/quarantine | :594 | get_current_user + rls | verify_fill_ownership | QuarantineOrphansResponse | fill_ids no max_length | writes `'archived'` (:621) |
| POST /api/v2/orphaned_fills/waiting_room | :651 | get_current_user + rls | verify_fill_ownership | QuarantineOrphansResponse | fill_ids no max_length | writes `'quarantined'` (:678) |
| POST /api/v2/orphaned_fills/archive | :703 | get_current_user + rls | verify_fill_ownership | QuarantineOrphansResponse | fill_ids no max_length | writes `'archived'` (:730), reversible |
| POST /api/v2/orphaned_fills/restore | :755 | get_current_user + rls | verify_fill_ownership | QuarantineOrphansResponse | fill_ids no max_length | — |
| GET /api/v2/orphaned_fills/waiting_room | :806 | get_current_user + rls | user_id=$1 | WaitingRoomResponse | — | L! (svc:728 no LIMIT), RM- shape |
| POST /api/v2/orphaned_fills/submit_to_support | :826 | get_current_user + rls | verify_fill_ownership | QuarantineOrphansResponse | reason unbounded | BG (slack fire-and-forget) |
| GET /api/v2/orphaned_fills/repair/diagnose | :894 | get_current_user + rls | rls + user_id arg | RepairDiagnoseResponse | instrument raw | tick_value 1.0 (known #8) |
| POST /api/v2/orphaned_fills/repair/apply | :927 | get_current_user + rls | rls + user_id arg | RepairApplyResponse | InstrumentName | tick_value 1.0 (known #8) |

### trade_quality_v3.py — `/api/trade-quality-v3`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /evaluate | :228 | get_current_user + rls | rls + user_id in prior-trades query | EvaluateResponseV3 | direction pattern | E!(:543), env threshold unbounded |
| GET /status | :556 | get_current_user | none needed | V3StatusResponse | — | E! via data_freshness |
| GET /feature-importance | :630 | get_current_user | none needed | V3FeatureImportanceResponse | — | E!(:668) |
| POST /refresh-models | :674 | get_current_user | **global process state** | V3RefreshResponse | — | any user mutates dyno state |
| GET /predictions | :728 | get_current_user | **NONE — all users' log** | V3PredictionsResponse | limit ge/le | IDOR |
| POST /backtest | :790 | get_current_user | **NONE — all users' trades** | none | batch_size ge/le; dates unvalidated | IDOR, RM-, L!, $$ |
| GET /model-performance | :872 | get_current_user | **NONE — cached cross-tenant** | none | — | IDOR, RM- |

### project_x_csv_import.py — `/api`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| OPTIONS /api/upload-project-x-csv/ | :393 | NONE | n/a | dict | n/a | A0 (CORS preflight, benign) |
| POST /api/upload-project-x-csv/ | :402 | get_user_id + rls | user_id from token | ProjectXUploadResponse | filename suffix only; no size cap | 200F(:728), E!, TX, BG |
| GET /api/project-x-csv/status | :752 | get_user_id + rls | `user_id=$1` | ImportStatusResponse | — | DOC, 200F(:802) |

### price_level_alerts.py — no prefix
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/price-level-alerts/current | :126 | get_user_id + rls | none (market-wide, documented) | PriceLevelAlertCurrentResponse | instruments CSV unbounded | E!(:264) |
| GET /api/price-level-alerts/today | :274 | rls dep only (no user_id) | none (market-wide) | TodayAlertsResponse | instruments CSV unbounded | E!(:363), N+1 per instrument |
| GET /api/price-level-alerts/outcomes/stats | :468 | **NONE at handler** (middleware only) | raw service conn (svc:447) | OutcomeStatsResponse | `days` no ge/le | A0, L!, E!(:535), 200F |
| GET /api/price-level-alerts/outcomes/recent | :539 | **NONE at handler** | raw service conn (svc:530) | RecentOutcomesResponse | `limit` no ge/le | A0, L!, E!(:625), 200F |
| GET /api/price-level-alerts/outcomes/in-progress | :636 | **NONE at handler** | raw service conn | InProgressOutcomesResponse | — | A0, L!, E!(:726), 200F |

### hiro/alignment_score.py — `/api/hiro`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/hiro/alignment-score | :419 | get_current_user + rls + sierra | rls + `user_id=$2` | AlignmentScoreResponse | trade_id plain str (not UUID) | direction bug :505, E!(:697) |

### trades_excursions.py — no prefix
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/v1/trades/{trade_id}/excursions/1m | :163 | get_current_user + rls | rls + `user_id=$2` | TradeExcursionResponse | UUID | 200F(:158), E!(:576), writes on GET |
| PATCH /api/v1/trades/{trade_id}/rule-based-stop-trail | :583 | get_current_user + rls | rls + `user_id=$2` in UPDATE | RuleBasedStopTrailResponse | UUID + bool model | E!(:667) |

### spotgamma_chat.py — `/api/spotgamma`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/spotgamma/founders-notes/chat | :465 | get_current_user | trades fetched by user_id | ChatResponse | message max_length=500; **history unbounded** | $$, rate limit per-dyno/TOCTOU |
| POST /api/spotgamma/founders-notes/chat/stream | :533 | get_current_user | same | none (SSE) | same | RM-, $$, limit skipped on disconnect |

### ml_verification.py — no prefix
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/ml-verification/next-clip | :259 | get_current_user + rls | user_id arg | NextClipResponse | — | — |
| POST /api/ml-verification/verify | :291 | get_current_user + rls | vote keyed (candidate,user) | VerifyResponse | `candidate_id: str` unvalidated | E!(:357), DB error → 400 |
| GET /api/ml-verification/stats | :450 | get_current_user + rls | `user_id=$1` | StatsResponse | — | — |
| GET /api/ml-verification/leaderboard | :505 | rls dep ⇒ JWT required | global (hashed handles) | list[LeaderboardEntry] | `limit` no ge/le | MWΔ (allowlisted public), L! |
| GET /api/ml-verification/summary | :542 | rls dep ⇒ JWT required | global counts | none | — | MWΔ, RM- |

### system_routes.py — no prefix
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/debug/cors | :49 | get_current_user | n/a | CorsDebugResponse | n/a | dumps middleware options |
| GET /api/test-auth | :113 | get_current_user + get_user_id | n/a | TestAuthResponse | n/a | E!(:146) |
| GET /api/public | :180 | NONE at handler | n/a | PublicResponse | n/a | MWΔ, DOC ("public", JWT-gated) |
| GET /api/debug-token | :196 | get_current_user | n/a | DebugTokenResponse | n/a | — |
| GET /api/debug/middleware | :216 | get_current_user | n/a | DebugMiddlewareResponse | n/a | dumps auth+CORS config |
| GET /api/health | :253 | NONE at handler | n/a | HealthCheckResponse | n/a | MWΔ, DOC |
| GET /api/debug-auth-config | :278 | get_current_user | n/a | DebugAuthConfigResponse | n/a | leaks client_id, cwd, env path |
| GET /api/system/build-info | :312 | NONE at handler | n/a | BuildInfoResponse | n/a | MWΔ, DOC, `built_at`=boot time |
| GET /health/pool | :323 | NONE (allowlisted) | n/a | PoolHealthResponse | n/a | A0 (deliberate) |
| GET /health/ready | :354 | NONE (allowlisted) | n/a | ReadinessResponse | n/a | A0, blocking S3, gate ignores s3/jwks |
| GET /api/me | :489 | get_current_user + rls | `auth0_id=$1` | UserResponse | n/a | — |

### trade_notes_manager.py — `/api/trade-notes`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/trade-notes/search | :77 | get_current_user + get_user_id + rls | `user_id=$1` | SearchTradeNotesResponse | limit/offset ge/le | E!(:152), total present ✓ |
| GET /api/trade-notes/{logical_trade_id} | :157 | same | ownership pre-check + `user_id=$2` | Optional[TradeNotesResponse] | plain str id | E!(:232) |
| POST /api/trade-notes/{logical_trade_id} | :241 | same | ownership pre-check + `user_id=$2` | TradeNotesResponse | content/plain_text unbounded | version lost-update, TX, E!(:376) |
| DELETE /api/trade-notes/{logical_trade_id} | :383 | same | ownership pre-check + `user_id=$2` | SimpleResponse | plain str id | E!(:452) |

### qscore.py — `/api/qscore`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/qscore/latest/{symbol} | :136 | get_current_user | market data | QScoreLatestResponse | symbol unconstrained | E!(:198), cache-key injection |
| GET /api/qscore/history/{symbol} | :201 | get_current_user | market data | QScoreHistoryResponse | days ge/le; symbol free | E!(:266), L! (no LIMIT, 365d) |
| GET /api/qscore/regime/{symbol} | :269 | get_current_user | market data | QScoreRegimeResponse | symbol free | DOC(:286), Z0(:316,:318), E! |
| GET /api/qscore/all/latest | :365 | get_current_user | market data | QScoreAllLatestResponse | — | E!(:424) |

### coaching_personality.py — `/api/users`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/users/coaching-personality | :161 | get_current_user + rls | `auth0_id=$1` | CoachingPersonalityResponse | n/a | 200F(:212), E! in `error` field |
| POST /api/users/coaching-personality | :222 | get_current_user + rls | `auth0_id=$2` | CoachingPersonalityResponse | len>10000 in-handler | 200F(:310), E! in `error` |
| POST /api/users/coaching-personality/reset | :321 | get_current_user + rls | `auth0_id=$1` | CoachingPersonalityResponse | n/a | 200F, swallows own 404, DOC |

### transcribe.py — `/api/transcribe`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/transcribe/ | :192 | get_current_user (siblings use require_non_demo_viewer) | n/a | TranscriptionResponse | content_type prefix only; **no size cap** | blocking sync OpenAI, E!(:322,:352), $$ |

### zones.py — `/api/zones`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/zones/trade/{trade_id} | :41 | get_current_user + rls | **NONE — `logical_trade_id=$1` only** | TradeZonesResponse | UUID parse | **IDOR**, E!(:154) |
| GET /api/zones/recent | :162 | get_current_user + rls | market data | List[RecentZoneResponse] | limit ge/le | E!(:222), PG- |
| GET /api/zones/active | :231 | get_current_user + rls | market data | ActiveZonesResponse | lookback ge/le | L! (no LIMIT), E!(:324) |

### hiro/position_sizing.py — `/api/hiro`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/hiro/position-sizing | :176 | get_current_user + sierra | RiskResolver by user_id | PositionSizingResponse | model-level | tick_value default(:200), $400 fallback(:217), E!(:307) |

### mindfulness.py — `/api/mindfulness`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/mindfulness/sessions | :35 | get_user_id + rls | user_id arg | MindfulnessSessionUploadResponse | list min/max_length=100 ✓ | safe_error_response ✓ |
| GET /api/mindfulness/sessions | :60 | get_user_id + rls | user_id arg | List[MindfulnessSessionResponse] | limit/offset ge/le | PG- (no total) |
| GET /api/mindfulness/sessions/date/{session_date} | :93 | get_user_id + rls | user_id arg | List[...] | date type | — |
| GET /api/mindfulness/summary | :116 | get_user_id + rls | user_id arg | MindfulnessSummary | days ge/le | — |
| GET /api/mindfulness/streak | :139 | get_user_id + rls | user_id arg | MindfulnessStreak | — | — |
| GET /api/mindfulness/correlation | :161 | get_user_id + rls | user_id arg | MindfulnessCorrelation | days ge/le | consumes seeded data |
| GET /api/mindfulness/calendar | :184 | get_user_id + rls | user_id arg | List[DailySessionAggregate] | days ge/le | — |
| DELETE /api/mindfulness/sessions/{session_id} | :207 | get_user_id + rls | user_id arg | 204 Response | UUID | — |
| POST /api/mindfulness/seed | :240 | get_user_id + rls | user_id arg | MindfulnessSessionUploadResponse | days ge/le | **fabricated data, no admin gate/flag** |
| GET /api/mindfulness/health | :265 | NONE at handler | n/a | Dict[str,str] | n/a | A0 (JWT via middleware) |

### zenedge_insights.py — `/api/zenedge-insights`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/zenedge-insights | :48 | get_current_user + sierra | market data | ZenEdgeInsightsResponse | n/a | writes on GET, $$, no lock, Z0, E!(:167) |
| POST /api/zenedge-insights/generate | :171 | get_current_user + sierra | market data | ZenEdgeInsightsResponse | n/a | $$ (~$0.35/call, no limit), E!(:267) |

### trade_import/grouping.py, trade_import/processing.py, educator/background.py, educator/__init__.py, registry/*.py
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| (no routes) trade_import/processing.py | — | callers' | user_id threaded | — | — | TX (:964-1000 vs :676) |
| (no routes) trade_import/grouping.py | — | n/a | user_id arg | — | — | pure grouping, clean |
| (no routes) educator/background.py | — | worker, service-role | educator_id from row | — | — | stranded statuses, str(e) persisted |
| (no routes) educator/__init__.py | — | aggregator | — | — | — | includes routes+public+zoom |
| (no routes) registry/trades_registry.py | — | mount table | — | — | — | 7 coarse try blocks |
| (no routes) registry/imports_registry.py | — | mount table | — | — | — | DUP (:33-41), flag-gated rithmic |
| (no routes) registry/playbooks_v1_registry.py | — | mount table | — | — | — | 2 coarse try blocks |
| (no routes) registry/user_playbook_stats_registry.py | — | mount table | — | — | — | order-dependent (documented) |

### internal_jwt_health.py — `/api/internal`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/internal/jwt-health | :144 | X-Internal-Key hmac in-handler ✓ | n/a | none (union return) | Header(...) required ✓ | RM-, 200 on error, fabricated verdict |

### admin_instruments.py — `/api/admin/instruments`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/admin/instruments | :36 | require_admin (known #2) | non-tenant ref data | Instrument | InstrumentCreateRequest | check-then-insert race, no audit |
| PATCH /api/admin/instruments/{symbol} | :94 | require_admin | non-tenant ref data | Instrument | extra="forbid" ✓ | exclude_none ⇒ cannot null, no audit |
| DELETE /api/admin/instruments/{symbol} | :147 | require_admin | non-tenant ref data | Instrument | symbol raw | soft-delete ✓, no audit |

### collective_pulse.py — `/api/v1/collective`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/v1/collective/pulse | :35 | get_current_user + rls | community-wide | PulseResponse | — | safe details ✓ |
| GET /api/v1/collective/regime | :50 | get_current_user + rls | community-wide | RegimeResponse | — | — |
| GET /api/v1/collective/regime/history/{date_str} | :65 | get_current_user + rls | community-wide | RegimeResponse | strptime ✓ | — |
| POST /api/v1/collective/regime/snapshot | :90 | require_user_or_admin **+ rls dep ⇒ JWT mandatory** | community-wide write | RegimeSnapshotResponse | strptime after audit | MWΔ, audit-before-write |
| GET /api/v1/collective/regime/calendar | :124 | get_current_user + rls | community-wide | RegimeCalendarResponse | `days` no ge/le | L! |
| GET /api/v1/collective/health | :140 | NONE at handler | n/a | CollectiveHealthResponse | n/a | A0 (JWT via middleware) |

### feature_submissions.py — no prefix
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/feature-submissions | :22 | get_user_id + rls | user_id from token | FeatureSubmissionResponse | max_length on all fields ✓ | txn ✓, no leak ✓ |
| GET /api/feature-submissions/my-submissions | :73 | get_user_id + rls | `user_id=$1` | FeatureSubmissionsListResponse | — | L! (no LIMIT), PG- |

### tns_highlights.py — `/api/tns-highlights`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| GET /api/tns-highlights/recent | :31 | get_current_user | market data | none | minutes ge/le, category allowlist ✓ | RM-, L! (no LIMIT, 24h of snapshots) |

### hiro/trade_grading.py + hiro/trade_grading_stub.py — `/api/hiro`
| method+path | file:line | auth dep | tenant scoping | response_model | input validation | flags |
|---|---|---|---|---|---|---|
| POST /api/hiro/grade-execution | hiro/trade_grading.py:21 | get_current_user + rls + sierra | resolve_data_source_user_id + rls | GradeTradeResponse | GradeTradeRequest | safe 500 detail ✓ |
| POST /grade-execution (stub) | hiro/trade_grading_stub.py:23 | get_current_user | n/a | GradeTradeResponse | GradeTradeRequest | DUP — **unmounted**, returns fabricated grade |

---
