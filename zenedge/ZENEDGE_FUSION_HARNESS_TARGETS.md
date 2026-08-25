# ZENEDGE_FUSION_HARNESS_TARGETS

Ranked registry of zenedge-backend surfaces worth pointing the fusion harness at, the specific
failure hypotheses for each, and the oracle that would prove a fix. Produced 2026-08-25 from three
parallel read-only sweeps (DB/persistence, money math, ingestion/control plane) over
`origin/main` @ `a59646ae`, plus the postmortem record and CLAUDE.md.

Broker CSV import (`routers/trade_import/`) is the **reference case**, already in flight as waves
w1–w3. It does not consume a slot below. The ten targets are what comes next.

Evidence is tagged `[V]` = I re-verified the line myself, `[S]` = reported by a sweep with a
file:line anchor, unverified by me. Line numbers drift; grep the symbol.

---

## 1 · How these were ranked

| Code | Criterion | Why it matters |
|---|---|---|
| R1 | **Blast radius** | cross-tenant leak > silent money corruption > silent row loss > wrong label > loud 500 |
| R2 | **Oracle strength** | can a `uv` gate prove "done" objectively? No oracle ⇒ no `/fh-auto-validate` ⇒ the harness produces confident prose, not fixes |
| R3 | **Adversarial reachability** | is the input externally supplied AND its format publicly documented? Only then can a *blind* wave work |
| R4 | **Coverage gap** | untested, or worse, **vacuously** tested (a test that passes without exercising the path) |
| R5 | **Recurrence prior** | has this class already burned production? The postmortem record is the strongest predictor in the repo |

The repo's recurrence priors, from `docs/postmortems/` and CLAUDE.md: **timezone conversion**
(Ludwig double-conversion, MenthorQ, DST), **dedupe-index edge cases** (BUG_27 same-second partial
fills), **connection/session lifecycle** (two SQLAlchemy leak incidents), **wrong-table/wrong-param
queries** (ZDPSB 3–4h outage, the React hardcoded-date-range class).

## 2 · The failure ladder (extends `redteam-harness/LAUNCH.md`)

Worst first. Use these exact words in verdicts so waves stay comparable across targets.

1. **Isolation break** — one tenant reads or writes another's rows.
2. **Silent loss** — input enters, does not come out, nothing is said. Success is still reported.
3. **Silent corruption** — a *plausible* wrong number (multiplier, tick size, timezone shift, unit mix). Worse than loss in practice because it is trusted and acted on.
4. **Wrong label** — a structure, strategy, or regime named confidently and wrongly.
5. **Idempotency break** — replay duplicates, or legitimate distinct events collapse.
6. **Trust break** — the *test* passes without exercising the path; the gate is green and the posture is absent.
7. **Misleading message** — refused, but for the wrong stated reason.
8. **Loud error** — 500 with a traceback. Always a finding, lowest damage.

## 3 · Routing: not everything belongs in the harness

Three buckets. Putting a §9 item through a §4 wave burns tokens to rediscover what a grep already
found; putting a §10 item through one produces confident garbage.

- **§4–§7 — harness targets (the ten).** Correctness is decidable, an oracle exists, and multi-model divergence adds signal.
- **§9 — fix now, no wave.** Located, understood, and fixable today. The harness adds nothing.
- **§10 — anti-targets.** No ground truth. The harness will agree with itself and be wrong.

---

## 4 · T1 — Instrument & unit registry parity

**Class:** silent corruption · **R1** high · **R2** strongest in repo · **R4** actively mis-locked

**Eight independent registries plus two SQL functions, with no parity gate between any of them** [S]:
`services/instrument_registry.py:84` · `utils/tick_sizes.py:13` · `utils/instruments.py:8` ·
`config/__init__.py:26` · `services/sierra_data.py:71` · SQL `public.ticks_per_point` / `to_ticks`
(`db/schema_test_seed.sql:760`) · `gamma_density/config.py:32` · `ludwig/constants.py:44` +
`backtest/constants.py:72` + `scotts_zones_detector/zone_attribution.py:271`.

Confirmed contradictions:
- **M6E tick increment 2× wrong** [V]: `utils/tick_sizes.py:34` = `0.00005` vs `instrument_registry.py:308` = `0.0001` vs `config/__init__.py:31` = `0.0001`. `tests/unit/utils/test_tick_sizes.py:142` **asserts the wrong value**, locking the divergence in.
- **SQL `ticks_per_point` falls through to `ELSE 1`** [V] with NG absent from the WHEN list [V]. NG is 1000 ticks/point, so the primary excursion path (`worker.py::process_pending_excursions`) understates NG MAE/MFE by **1000×**. Every equity, every OCC option and several metals/grains hit the same fallback.
- **`tick_value` defaults to `1.0` on unknown instrument** [S] at `routers/logical_trades.py:903,938` — a **50× understatement for ES** — on the orphan-repair path that *creates* logical trades.
- Also reported [S]: M6J 2×/5×, CL 2×, GC absent → 5.0 vs 10.00, MCL 25× in zone attribution.

**What to look for:** every symbol in the union of all ten sources; `tick_value / tick_increment == point_value`; `ticks_per_point(sym) == 1 / tick_increment(sym)` across Python and SQL; every fallback path (does it default, or refuse?). The one correct pattern already exists — `backtest/economics.py:61-78` raises with a remediation message instead of defaulting.

**Oracle:** cross-registry parity table. ~40 lines, no DB fixtures, no network. Fails immediately on M6E, M6J, CL, GC, NG.

**Harness:** `/fh-opinion` to enumerate every registry and fallback → `/fh-auto-validate` with the parity table as the gate. White-box, defend cwd.

**Why first:** cheapest proof in the registry, largest confirmed money impact, and it is the *root cause* underneath T5, T7 and T8.

## 5 · T2 — Idempotency & dedupe arbitration

**Class:** silent loss · **R5** highest (BUG_27 is this class) · **R3** blind-attackable

**Four disagreeing definitions of "the same fill"** [S]:
1. DB trigger `compute_dedupe_key()` (`db/schema_test_seed.sql:96`) — the arbiter.
2. Python `_raw_batch_identity_key` (`routers/trade_import/db.py:56`) — gates the batch path; includes `source` and `symbol_full`, which the trigger does not; keeps full price precision, which the trigger rounds to 4dp.
3. + 4. Two hand-maintained SQL predicates at `routers/trade_import/db.py:412` and `:451`, each carrying a "keep this aligned with `compute_dedupe_key()`" comment.

Plus a fifth notion: `deleted_execution_ids` PK is `(user_id, execution_id)` with **no account**, while `dedupe_key` includes account — so a tombstone is cross-account and can suppress a legitimate re-import in a different account [S].

**The sharpest hypothesis:** `to_char(fill_time, 'HH24:MI:SS')` truncates to the second. Two genuine partial fills in the same second, same price/qty/direction, with `execution_id` and `order_number` both NULL, hash identically. The batch path's `ON CONFLICT (dedupe_key) DO UPDATE` then silently converts the second fill into an update of the first — quantity vanishes, no error, `created=false`. Scalping and iceberg fills are exactly this shape, and BUG_27 was the same class wearing different clothes.

**Second hypothesis:** `compute_dedupe_key` and `raw_trades_dedupe_key_uniq` exist **only in the hand-maintained seed**, in no migration [S]. `dedupe_key` is nullable, so on a migrations-only rebuild the column stays NULL, the unique index never collides (NULLs don't), and duplicates become unbounded and silent.

**Oracle:** differential — all five key definitions must partition the input space identically over a generated corpus. Plus conservation: rows in == rows out + explicitly reported skips.

**Harness:** `/fh-collaborate` blind wave (extends w3/w4: same-second fills, NULL identifiers, cross-account replay) → `/fh-auto-validate` per confirmed defect.

## 6 · T3 — Tenant isolation under fail-closed RLS

**Class:** isolation break · **R1** maximum · **R4** vacuous

Production has **no least-privilege role** — all connections use the Heroku table owner (CLAUDE.md,
"Database Role (Accepted Constraint)"). Isolation therefore rests entirely on `FORCE ROW LEVEL
SECURITY` plus per-request GUCs. Two holes:

- **The Stage-2 veto filters `WHERE c.relkind = 'r'`** [V] (`db/migrations/20260709140000_rls_failclosed_stage2_cutover.sql:49`). Partitioned parents are `relkind = 'p'`. `recall_frames` is the repo's only `PARTITION BY` table [V] — it never received `require_tenant_scope`, and `create_recall_partition()` mints every new monthly partition with only the fail-open policy [S]. Any connection reaching it without `app.current_user_id` reads and writes **all users' screen-recall frames**.
- **`require_tenant_scope` appears zero times in `db/schema_test_seed.sql`** [V]. Every `tests/realdb/` test runs against the fail-*open* posture. The two tests that appear to cover Stage 2 build the policy themselves in the fixture — they test a transcription of the migration, not the migration.

Third vector: background writers with no tenant context — `scotts_zones_detector/zone_attribution.py:360` sets neither `service_role` nor `current_user_id`, is enqueued from six import routes, and reports success after producing zero attributions [S].

**What to look for:** every table with a `current_user_id` policy also carries the veto; every partition (existing and newly minted) inherits it; every `get_db*` dependency variant sets or explicitly clears the service marker (`get_db_dep` sets nothing [S]); every `# rls-skip` marker is justified.

**Oracle:** a policy-inventory query (structural, no data) + a two-user probe per tenant table + a partition-minting test. All expressible in a `uv` gate.

**Harness:** `/fh-opinion` + `/fh-debate` white-box, then `/fh-auto-validate`. **Not blind** — no external input generates this.

## 7 · T4 — Migration ↔ seed drift (the trust substrate)

**Class:** trust break · this is *why* T3 is invisible

`scripts/mark_dump_satisfied_migrations.py:158` — `satisfied = True  # pure ALTER/INDEX migration:
assume in dump` [V]. Of 131 migrations, only 40 contain `CREATE TABLE` [V] — so **91 are marked
applied in CI without ever executing**. That class contains every `FORCE ROW LEVEL SECURITY`, every
`CREATE POLICY`, every standalone unique index, every `ADD CONSTRAINT`. The same script warns
"only partially present in dump — marking applied anyway" [V] and proceeds.

Downstream: the seed was last regenerated 2026-08-06 while migrations run to 2026-08-10 [S];
`playbook_votes` has `ENABLE` without `FORCE` in the seed though a migration added FORCE two months
earlier [S]; 17 functions including `compute_dedupe_key` live only in the dump [S].

**What to look for:** rebuild from `db/migrations/` alone and diff against the seed. Every policy,
FORCE flag, unique index, constraint, trigger and function present in one must be present in the
other, or explicitly registered as dump-only. Also: `tests/realdb/test_schema_canary.py:90-92`
accepts `InsufficientPrivilegeError` as success [S] — a vacuous pass to hunt for elsewhere.

**Oracle:** migrations-only rebuild vs seed, object-by-object. Strong and fully mechanical.

**Harness:** `/fh-debate` on the policy question (regenerate the seed from migrations in CI vs keep
the hand dump — a real trade-off with a cost either way) → `/fh-auto-validate` for the drift gate.

**Sequencing note:** build this **before** trusting any gate written for T3, T2 or T9.

## 8 · T5–T10 (compressed cards)

### T5 — Timezone, DST and session boundaries
**Class:** silent corruption · **R5 highest recurrence in the repo**
Live: `worker.py:347-350` compares a user's `import_schedule` ("HH:MM") against UTC, so **every user's
schedule is silently interpreted as UTC** — one-hour drift twice a year and a possible skipped day at
the boundary [S]. 82 naive `datetime.now()/utcnow()` sites bound to `timestamptz` [S]. Two competing
market calendars: the real NYSE one used by 8 modules, and a **weekday-only** predicate used by 19
schedulers, which run on Thanksgiving and July 4, find nothing, and ping the snitch anyway [S].
`raw_trades` carries both `fill_time` and `fill_time_utc` with nothing constraining them to agree [S].
`zone_attribution.py:23-24` documents `entry_time` as naive when it is `timestamptz` [S].
**Look for:** the two DST transition days, holiday/early-close days, the CME trading-date boundary,
and any arithmetic on a local time-of-day.
**Oracle:** property tests over transition dates + calendar parity + a "no naive datetime bound to
timestamptz" lint. **Harness:** partly blind (DST CSVs are already in the w3 mandate), rest white-box.

### T6 — Aggregation that disagrees with its own rows
**Class:** silent corruption, user-visible
`services/logical_trades.py:362` counts `winning_trades` as `pnl_ticks > 0` while `:371` computes
`win_rate` as `pnl_ticks >= 0` — **same CTE, same returned row** [V]. Scratches are wins in the rate
and not in the count, so `winning_trades / total_trades ≠ win_rate` whenever a scratch exists.
Also [S]: two `max_drawdown`s with opposite sign conventions and a third that is just the worst single
trade; Sharpe annualized in one module and not in another under the same key; legacy "win rate" that
is percent-of-winning-**days**; a `p_value` that is a hardcoded constant; a `calculate_monte_carlo_metrics`
that accepts `sims` and runs no simulation; profit factor reconstructed from *rounded* means.
**Look for:** every quantity computed in more than one place, then which definition is canonical.
**Oracle:** conservation — `Σ rows == aggregate`, `wins + losses + scratches == total`, `wins/total == win_rate`.
**Harness:** `/fh-opinion` to enumerate duplicates → `/fh-debate` to pick the canonical definition (a
product decision, not a code decision) → `/fh-auto-validate`.

### T7 — Options: multiplier, FOP, assignment, rate constants
**Class:** silent corruption · already **half-confirmed by our own smoke run**
`services/option_position_grouping.py:876,1059` persist `int(multiplier)` into an INTEGER column —
MYM (0.5) and MBT (0.1) store as **0** while the economics use the precise Decimal [S, and
independently surfaced by the 2026-08-25 `/fh-opinion` run]. `utils/contract_mapper.py:218` hardcodes
multiplier 100 for **every** symbol including futures options [S]. No assignment/exercise handler
exists, so an assigned leg leaves its strategy permanently open and excluded from closed aggregates [S].
Risk-free rate and dividend yield are hardcoded constants, inconsistent between two sites (0.045 vs
0.04) [S] — every greek and every option P&L inherits them.
**Oracle:** put-call parity, finite-difference greeks, attribution conservation
(`delta+gamma+vega+theta+residual == total`), payoff-lattice recompute of max profit/loss.
**Harness:** blind (FOP is already the w3 mandate) + `/fh-auto-validate`.

### T8 — MAE/MFE: two implementations that disagree by construction
**Class:** silent corruption · **cheapest differential oracle in the repo**
Python `services/sierra_data.py:888` and SQL `compute_excursions_1m` both write `mfe_ticks`/`mae_ticks`
and differ in three structural ways: float vs integer, `0.0` vs `NULL` when there is no OHLC coverage
(the Python path **fabricates a zero**), and different tick registries — the SQL one being the
`ELSE 1` fallback from T1 [S]. `int()` truncation toward zero on the way in [S].
**Oracle:** the two implementations must agree on a fixture, plus bounds
(`0 ≤ MAE ≤ (entry − min_low)/tick`). The differential already exists; nobody asserts it.
**Harness:** `/fh-auto-validate` directly. Do this immediately after T1, since T1 fixes its root cause.

### T9 — Background / fire-and-forget write integrity
**Class:** silent loss + resource exhaustion · **R5** (two session-leak postmortems)
69 `background_tasks.add_task` / `safe_create_task` writers, all running **after** the RLS transaction
has committed and the connection returned to the pool [S]. `utils/safe_task.py:36-47` logs the
exception and returns — no retry, no dead-letter, no metric. `zone_attribution.py:354` creates and
never disposes an `AsyncEngine` **per invocation**, on a path fired by six import routes.
`routers/trade_import/excursions.py:57+` writes per-trade outside any transaction, so partial failure
leaves a mixed state with no rollback boundary [S].
**Look for:** does the write actually land? Under fail-closed RLS, does it land as the right tenant?
**Oracle:** every background writer either sets tenant context or is on an explicit allow-list, and its
write is observable after the response. **Harness:** white-box `/fh-opinion` → `/fh-auto-validate`.

### T10 — Agent JSON upload vectors (four routers)
**Class:** silent loss · **R3 semi-blind** (see the nuance)
All four (`ninja`/`sierra`/`tradovate`/`ibkr` agent upload) log per-trade conversion exceptions and
`continue`, then return `success=True, errors=[]` [S] — **a partially-dropped import is
indistinguishable from a clean one**. No `max_length` on the batch, no bound on `price`, and
`trade_date` is pattern-checked but never cross-checked against `update_time`, so 2019 fills can be
posted under today's date [S]. `ENABLE_TOMBSTONE_CHECK` defaults **false**, and the check is fail-open
on any exception [S] — user-deleted trades re-import.
**The reachability nuance:** the payload format is ZenEdge-proprietary, but the full schema *with
worked examples* is published at `/api/openapi.json`, which needs only a Bearer token. A blind
attacker cannot generate payloads; **any authenticated demo-tier account can pull the whole attack
surface in one GET**. Model the adversary accordingly.
**Oracle:** rows-in vs rows-out conservation against a manifest-declared expected end state — the same
verdict shape as the CSV wave. **Harness:** `/fh-collaborate` semi-blind wave + `/fh-auto-validate`.

---

## 9 · Runners-up (real, just below the line)

- **Scheduler overlap and dead-man blind spots** — 6 of 67 schedulers take an advisory lock; `firing_detector_tick.py` takes none *despite a reserved lock ID existing for it* and double-fire on the `firings` table being the documented hazard. **30 snitch env vars** are read by schedulers but governed by neither required nor warn-only list, so an unset one silently returns False; 6 schedulers have no snitch at all [S].
- **API contract & pagination truncation** — 59 endpoints with no `response_model`, ~50 more declaring `Dict[str, Any]`; several `limit` params with no upper bound that silently cap; **no paginated endpoint anywhere returns a total**, so "filter matched nothing" and "filter is wrong" are indistinguishable [S]. This is the same class as the React hardcoded-date-range postmortem.
- **The demo-substitution cache** — `utils/user_context.py:29`, a process-global dict with no TTL and no size bound, per-dyno, that substitutes the demo user for anyone with `has_imported_trades == false` and caches it forever [S]. A user who just imported can keep seeing demo data.
- **Market-data duplicate-writer race** — the ACSIL stream and the batch uploader are last-writer-wins on the same minute with no reconciliation record; Lane T never backfills a hole the stream advanced past, and logs only to local stdout, so a futures-feed outage leaves **zero trace in any cloud log** (CLAUDE.md).

## 10 · Fix now — do not spend a wave

Located, understood, cheap to fix. A multi-model wave would only rediscover them. All [S]:

1. `routers/rithmic_import.py:739` — unauthenticated endpoint accepting broker username/password in the body and proxying them to a third-party host, behind an Origin check that is skipped when the header is absent and a debug key compared with `!=`. Docstring says "TEMPORARY".
2. `utils/deps.py:152-156` — **any** Auth0 M2M service token is granted admin: no scope, no permission, no client allow-list.
3. `routers/educator/routes_zoom.py:140-146` — the CRC handshake returns `HMAC(secret, attacker_chosen_token)` *before* any signature check: an unauthenticated chosen-message oracle against the webhook secret.
4. `utils/auth_middleware.py:221-226` — HS256 bridge tokens accepted with no `exp`, `aud`, `nbf` or `iat` enforcement. A token minted without `exp` never expires.
5. `utils/auth_middleware.py:310-326` — token/user revocation checks **fail open**; Redis down means revoked tokens work.
6. Hardcoded default shared secrets in the Rithmic microservice pair, compared with `!=`.

## 11 · Anti-targets — no oracle, do not point the harness here

- **`cluster_hunter` confluence score** — a unitless additive index with no ground truth and no conservation law. Only monotonicity is assertable.
- **qscore composite** — computed outside this repo; nothing here can recompute it.
- **ML leakage** — calibration is self-checking, but leakage is not mechanically detectable, and models will confidently claim either answer.

For these the harness produces agreement, not truth. Agreement without an oracle is the failure mode
the whole verdict-sanitization design exists to prevent.

## 12 · Generalizing the verdict runner beyond CSV

`redteam-harness/run_verdicts.py` is the reusable asset, not the CSV specifics. Its shape — hostile
input + a declared expected end state, executed against an ephemeral DB, returning a **sanitized**
public verdict and a **private** full-traceback diagnostic — holds for every target above. Only the
executor changes:

| Target | Wave artifact | Executor |
|---|---|---|
| T2, T7, T10 | CSV / JSON payloads + manifest | existing runner, new adapter |
| T3, T4, T9 | SQL state + a connection-path script | psql + a role-switching probe |
| T5 | a clock scenario (date, tz, calendar) | freeze-time harness |
| T1, T6, T8 | a symbol/quantity corpus | pure Python, no DB |

Each target gets `run_verdicts_<target>.py`. The sanitization boundary and the scoring rules from
`LAUNCH.md` are unchanged: a refusal is not a defect, a confident wrong answer is, and every confirmed
defect ships with a permanent regression test in the same PR.

## 13 · Recommended sequence

1. **T1** — parity gate. Cheapest, biggest confirmed money impact, unblocks T5/T7/T8.
2. **T8** — the differential already exists; assert it once T1 fixes the registry beneath it.
3. **T4** — migration trust, *before* writing gates for T3 or T9.
4. **T3** — highest blast radius; now verifiable.
5. **T2** — next blind wave (w4), while w3 is still in flight.
6. **T6** — needs a `/fh-debate` product decision on canonical definitions before any fix.
7. **T7** folds into the w3 FOP mandate already written. Then **T5**, **T9**, **T10**.

Run §10 in parallel with all of it; it is ordinary engineering, not a wave.

## 14 · What I verified myself

Re-checked at source, not taken from a sweep: the Stage-2 `relkind = 'r'` filter and the zero
occurrences of `require_tenant_scope` in the seed; the `satisfied = True` auto-mark line and the
131-vs-40 migration counts; the `win_rate >= 0` / `winning_trades > 0` split inside one CTE; the M6E
increment across three registries; `ticks_per_point` ending in `ELSE 1` with NG absent. Everything
tagged `[S]` carries a file:line from a sweep and should be re-confirmed before it becomes a fix PR —
that confirmation is exactly what the first `/fh-opinion` pass on each target is for.
