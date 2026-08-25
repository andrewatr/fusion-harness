# ZenEdge backend — full read-only audit

**Date** 2026-08-25 · **Target** `zenedge-backend` @ `origin/main` `a59646ae`, read via the worktree
`~/code/zenedge-backend-fusion` · **Mode** strictly read-only. No file in zenedge-backend was
modified, no migration run, no test executed, no database touched.

**Method** four sequential waves of six Opus-5 agents (24 total, ~6.1M agent tokens, 2,365 tool
calls, ~85 minutes). Waves 1-3 found; wave 4 attacked the findings. Appendices carry the full
matrices and the complete finding list.

| Wave | Scope | Units examined | Findings |
|---|---|---:|---:|
| 1 | DB substrate: RLS, PK/FK, indexes, columns/types, migration↔seed drift, Sierra DB | 1,611 | 98 |
| 2 | Every router: 653 endpoints across 188 files | 653 endpoints | 256 |
| 3 | services (191), schedulers (67), worker, utils (40), models (217), subsystems | 353 modules | 197 |
| 4 | Adversarial refutation, deprecation safety, test-suite integrity | 253 claims + 619 test files | 34 |

**551 raw findings. 253 high-severity claims were then adversarially re-checked by a second agent
whose instructions were to refute them.** 170 survived (67%), 64 were downgraded (25%), 19 were
rejected outright (8%), and 22 collapsed to "not a defect". I additionally hand-verified 13 claims
at source myself; 12 held and 1 was overstated.

**Read the numbers in this report as: 221 CONFIRMED, 87 OVERSTATED, 35 REFUTED, 208 UNREVIEWED.**
The 208 unreviewed are lower-severity single-source claims. Treat them as leads, not facts.

---

## 1. The five things that matter

**1. The tenant-isolation posture that production ships is the one posture no test has ever
exercised.** `scripts/mark_dump_satisfied_migrations.py:158` marks every migration that creates no
table as applied without executing it. Only 40 of 131 migrations create a table, so **91 are never
run in CI** — and that class contains every `FORCE ROW LEVEL SECURITY`, every `CREATE POLICY`, every
unique index and every constraint. The consequence is measurable: `require_tenant_scope` appears
**zero times** in `db/schema_test_seed.sql`. Every `tests/realdb/` isolation test runs against the
fail-*open* posture. *(Verified by hand.)*

**2. `public.users` — the tenant root table — has no row-level security anywhere**, in any migration
or the seed. `public.playbooks` has `ENABLE` + `FORCE` and **zero policies**, which is deny-all to
every role including the owner. `audit_log`'s insert policy is `WITH CHECK (true)` — any
authenticated user can forge audit rows under another tenant. The Sierra database has no RLS at all
while holding seven user-scoped tables. *(All four verified by hand.)*

**3. The product's most damaging habit is fabricating a plausible number instead of an error.** When
a query fails or an input is missing, handlers return a value a trader will act on: gamma-zone stats
report `POSITIVE gamma` on any DB error; risk resolution returns fabricated $2,500/1% defaults;
`spotgamma_memory_calculator` builds 45% of its `memory_strength_score` from placeholders so a level
seen once today scores ≈70 ("HIGH"); level-edge answers a database failure with backtest marketing
numbers and a 200. This pattern recurs across roughly 25 confirmed sites.

**4. Instrument economics are hardcoded in at least seven more places than the eight registries
already tracked.** New locations found: `agent/v12/mcp_tools/market_tools.py:89` (defaults unlisted
symbols to 4 ticks/point — NG is 250× wrong), `scotts_zones_detector/aplus_order_executor.py:528`
(0.25 default inside the *live order executor*), `account_risk_scanner.py` (tick_value = 50 for
everything), `zdpsb_analysis.py` ($50/point default — 10× for YM, 100× for MYM), plus `level_edge`,
`gsst` and `ibb` each hardcoding ×4 ticks/point. And `scotts_zones_detector/message_parser.py:270`
normalises micro contracts to junk roots — `MESH5` → `"ME"` — which are then persisted.

**5. `alignment_score.py:505` classifies every trade as SHORT.** It tests `"LONG" in trade_direction`
while `logical_trades.direction` is `character(1)`. `"LONG" in "L"` is always false. This is a clean
cross-wave corroboration: wave 1 established the column type from the schema, wave 2 found the
comparison in the code, and I verified both by hand.

---

## 2. Your deprecation question, answered

You said IBB, GSST, ZDPSB, HIRO FLATLINE and LEVEL EDGE are effectively deprecated and need safe
deprecation plus checking. A dedicated lens traced all 26 owning modules, all 15 owned tables, and
every other reader in the repo.

**None of the five is actually deprecated in the running application.** All five routers are mounted
**unconditionally** — no feature flag — and **nine scheduler jobs still run and still write**, most
on a ten-minute cadence.

The critical dependency, and the reason a naive deletion would break production:

> **`sierra_chart.ibb_signals` is read by the live `/api/v1/edge-context/*` surface**
> (`routers/edge_context.py:390,404,512,632,647,660`). The IBB *code* can go. The IBB *table* must
> stay, permanently.

| Surface | Mounted | Crons | External table readers | Safe to remove? |
|---|---|---|---|---|
| **IBB** | yes, unconditional | 3 | **`edge_context.py` reads `ibb_signals`** | code yes / **data never** |
| **GSST** | yes, unconditional | 2 | none | yes |
| **ZDPSB** | yes, unconditional | 1 | none (shares one model class) | **yes — cleanest** |
| **HIRO FLATLINE** | yes, unconditional | 2 | none | yes |
| **LEVEL EDGE** | yes, unconditional | 1 | none | yes — **and it removes 2 unauthenticated endpoints** |

Two things to know before you start. `level_edge` has two endpoints listed in
`utils/auth_middleware.py:63-64` as public — deleting those entries belongs in the same commit as the
unmount. And `hiro_flatline` **inserts rows from a GET request**
(`services/hiro_flatline_service.py:215`), so read traffic is currently a write path.

The ordered removal plan, with the check that proves each step broke nothing, is in **Appendix F**.
Its spine: baseline the boot log's route count first, stop the nine crons before deleting any code,
unmount one registry block per PR, and expect the route count to fall by **exactly 50**.

---

## 3. Systemic patterns

Most of the 551 findings are instances of a small number of decisions. Fixing the pattern is cheaper
than fixing the instances, and gives the fusion harness one oracle per class rather than hundreds.

| # | Pattern | Confirmed instances | Class-level oracle |
|---|---|---:|---|
| P1 | **Fabricated fallback** — on exception or missing input, return a plausible number rather than an error | ~25 | No handler returns a numeric field on an exception path. Error paths return errors. |
| P2 | **Silent row drop, success reported** — per-row `continue` on failure, response still `success=true, errors=[]` | ~18 | rows_in == rows_out + explicitly reported skips, for every ingest path |
| P3 | **Hardcoded instrument economics** — private tick/point/multiplier tables with silent defaults | ~15 new | Cross-registry parity: one symbol, one tick_value, one point_value, everywhere. Unknown symbol raises (the pattern `backtest/economics.py:61` already uses) |
| P4 | **Missing tenant predicate** — a query that should be user-scoped is not | 18 confirmed | User B's row is untouched and unreadable by user A's call, per endpoint |
| P5 | **Seed↔migration drift** — the test database is structurally not production | ~30 | Rebuild from migrations alone; diff every object against the seed |
| P6 | **Process-global state on a 4-worker deploy** — module dicts, singletons, per-dyno caches | ~8 | Any state that must outlive a request is external; assert across two workers |
| P7 | **Duplicated implementation that can disagree** — two decoders, two clustering engines, two P&L paths | ~12 | Two implementations of one quantity must agree on a shared fixture, asserted |
| P8 | **Raw exception text to the client** — `str(e)` into the response body | 24 in one slice | No response body contains driver, path or SQL text; the repo's own `safe_error_response` exists and is used inconsistently |

Pattern P4 deserves a note: **11 of the 18 confirmed instances live in the five surfaces you are
deprecating.** Deprecation closes most of this class for free — which is why the removal plan is
worth more than the patches.

---

## 4. Your test suite

A dedicated lens read all 599 `test_*.py` (9,338 test functions), all 5 conftests, `pytest.ini`,
`.coveragerc`, the Makefile and all 12 workflows. What it found changes how much the rest of this
report should worry you.

- **298 of 1,083 smoke tests assert auth enforcement through a fixture that disables the auth
  middleware.** `tests/conftest.py:153-175` monkeypatches `AuthMiddleware.__call__` to a pass-through.
  132 of those tests have `requires_auth` in the name. Only 17 tests use the fixture that leaves the
  real middleware in place. A middleware regression is invisible to all 298.
- **43 assertions across 21 files accept a 5xx as success** — `assert resp.status_code in (200, 500)`
  — concentrated on the risk and HIRO endpoints. The shape assertions are then wrapped in
  `if status == 200:`, so the more broken the endpoint, the fewer assertions run.
- **Two assertions are unconditionally true** because of a trailing `or True`
  (`test_coach_turn.py:204`, `test_coach_guards.py:154`). One of them is the check that the coach's
  prompt-injection guard text is present.
- **The coverage gate counts the test code in its own denominator.** `.coveragerc` sets `source = .`
  and omits 30 paths, none of them `tests/`. 140k lines of test code against 203k lines of product
  code, so the 70% floor is roughly 50% real product coverage.
- **The RLS realdb tests set the tenant GUC by hand** rather than through `get_db_rls_dep`, so no test
  proves the dependency sets it correctly. `test_import_route_rls_context.py:24` is the one file that
  does it right.
- `tests/e2e/routers/test_bookmap_api.py` contains **zero test functions** — it is a manual script
  with a pytest marker, and it is the only automated-looking coverage of the Bookmap write path.

Full ledger in Appendix F.

---

## 5. What I verified by hand

Not delegated — re-read at source by me, because the report's credibility rests on them:

`20260709140000_rls_failclosed_stage2_cutover.sql:49` (`WHERE c.relkind = 'r'`, skipping partitioned
parents) · zero occurrences of `require_tenant_scope` in the seed · `mark_dump_satisfied_migrations.py:158`
and the 131-vs-40 migration counts · `public.playbooks` ENABLE+FORCE with zero policies ·
`audit_log.audit_insert WITH CHECK (true)` · no RLS on `public.users` · the `SELECT 1;` no-op baseline
migration · `audit_log` dropped by `20260302100500` then ALTERed unguarded by two later migrations ·
`sierra_ohlc_1s` has no `minute_utc` column while two schedulers select it ·
`logical_trades.direction` is `character(1) NOT NULL` and the voice-only-trades INSERT omits it ·
the `f"status = '{new_status}'"` SQL interpolation · `"LONG" in trade_direction` ·
`check_user_can_access_object` returning `True`.

**One claim failed my check.** A finding asserted twelve endpoints in `routers/legacy_trades.py` were
cross-tenant IDOR. Line 27 declares `APIRouter(dependencies=[Depends(verify_user_id_ownership)])` — a
router-level ownership guard. That is why wave 4 exists, and why 83 further claims did not survive it.

---

## 6. Suggested order of work

1. **Deprecate the five surfaces** (Appendix F plan). Largest risk reduction per unit of effort, and
   it deletes 11 of the 18 confirmed tenant-isolation defects rather than fixing them.
2. **Close the four verified isolation holes that are not in those five**: `users` RLS,
   `playbooks` deny-all, `audit_log` write-open, the un-RLS'd child tables.
3. **Fix the migration/seed trust gap (P5)** before writing any gate for anything else — a gate
   written against the CI database currently proves less than it appears to.
4. **Cross-registry parity gate (P3)** — already target T1 in `ZENEDGE_FUSION_HARNESS_TARGETS.md`;
   this audit added seven new registry locations to it.
5. **Ban the fabricated fallback (P1)** as a reviewable rule, then sweep the ~25 sites.
6. Test-suite repairs, starting with the `auth_client` switch and removing 5xx from accepted sets.

Items 3-6 map onto the existing harness targets registry. This audit adds three new targets:
**deprecation safety**, **fabricated-fallback elimination**, and **test-suite integrity**.

---

## Appendices

- **A** — complete finding index, all 551, each with its verdict (`APPENDIX-A-findings-index.md`)
- **B** — refutation ledger: every downgraded or rejected claim and why (`APPENDIX-B-refutation-ledger.md`)
- **C** — database matrices: every table, PK/FK, index, RLS policy, migration object (`APPENDIX-C-db-matrices.md`)
- **D** — endpoint matrix: all 653 endpoints with auth, tenant scoping, response model, validation (`APPENDIX-D-endpoint-matrix.md`)
- **E** — service, scheduler, core-plumbing and subsystem matrices (`APPENDIX-E-service-matrices.md`)
- **F** — deprecation safety plan and test-suite integrity ledger (`APPENDIX-F-deprecation-and-tests.md`)

## Honest limits

Static analysis only: no query was executed, no endpoint called, no live row counted. Claims about
production *behaviour* are derived from code, and claims that depend on live data volume, real
traffic, or the actual Heroku Scheduler job list are marked as such in the appendices. The 208
UNREVIEWED findings had exactly one agent look at them. The frontend repository was out of scope, so
consumer claims rest on in-repo evidence only.
