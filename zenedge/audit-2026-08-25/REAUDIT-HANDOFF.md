# Fable-5 hand-off — fresh L7 read-only audit of our own backend + database

> Paste everything below the line into a fresh Fable-5 session rooted at `~/code/fusion-harness`.
> It is a from-scratch audit, but pre-loaded with what a prior pass already learned so you validate
> instead of rediscover. A prior audit exists at `~/code/fusion-harness/zenedge/audit-2026-08-25/`;
> treat it as a SECOND OPINION to diff against, never as ground truth to copy.

---

## What this is (authorization and framing — read first)

This is a **strictly read-only, principal-level (L7 — application + data layer) architecture and
database audit of ZenEdge's OWN backend.** Our code, our Postgres schema, our infrastructure. It is
an authorized internal inspection of a system we own and operate — nothing more. It is **not**
adversarial testing of a third party, **not** an exploit exercise, and produces **no** attack.

You will **read and document only**:
- No code changes. No file in `zenedge-backend` gets edited. No `git` mutations.
- No database writes of any kind. No migrations run. No app started. No tests executed.
- No production database is ever touched. You may run **read-only** `psql` (`\d`, `SELECT` for
  inspection) against the local ephemeral throwaway DB only (see below) — never against a prod URL.
- The single deliverable is a findings report in Markdown plus coverage matrices. That is all.

The spine of the audit is the **database and the backend architecture around it**: every table,
every PK/FK, every index, every RLS scope and its setup, every migration, and the data-flow through
the routers and services that read and write them. Go to principal depth — the "why is it shaped
this way and where does that shape betray the intent" level, not a linter pass.

## The environment

- Work from a **read-only worktree pinned to `origin/main`**. One exists at
  `~/code/zenedge-backend-fusion` (@ `a59646ae`). Confirm it is clean and on that commit; if you want
  your own, `git -C ~/code/zenedge-backend worktree add ~/code/zenedge-backend-audit --detach origin/main`.
  **Never touch the primary checkout `~/code/zenedge-backend`** (it sits on an unrelated branch).
- A local ephemeral Postgres is up: `zenedge-audit-pg` on `127.0.0.1:5453/zenedge_test`
  (`docker start zenedge-audit-pg` if not). You MAY inspect it read-only with `psql` to see the
  actually-materialized schema — but understand it is built from `db/schema_test_seed.sql`, which
  **drifts from production** (that drift is itself finding #1 below). So `:5453` shows you the CI/test
  posture, which is a finding source, not the prod truth. Never connect to a real `DATABASE_URL` or
  `SIERRA_DATABASE_URL`.

## The single most important thing we learned — the two-database topology

The backend spans **two separate databases with opposite RLS postures.** Getting this right is the
difference between a useful audit and one that sends someone to do unnecessary work:

1. **Primary `DATABASE_URL`** — Heroku Postgres, `db/schema_test_seed.sql` + `db/migrations/` (131).
   This holds ALL the sensitive tenant data: `users`, `raw_trades`, `logical_trades`, `trade_notes`,
   PII, account risk. It carries the entire RLS apparatus (54 ENABLE / 53 FORCE / 68 policies).
   **This is where RLS matters and where every real isolation finding lives.**
2. **Sierra / TigerDB `SIERRA_DATABASE_URL`** — Tiger Cloud (Timescale), `db/schema_test_seed_sierra.sql`
   + `db/migrations_sierra/` (52). This is **shared market data** — OHLC bars, MenthorQ levels,
   SpotGamma. It has **zero RLS, and correctly needs none: it holds no sensitive user data.**

   CAUTION — the trap the prior pass fell into: a handful of Tiger tables (`gsst_signals`,
   `ibb_signals`, `zdpsb_signals`, `hiro_flatline_signals`, `hiro_divergence_*`, `spotgamma_v4_hiro`)
   carry a `user_id` column. **Do NOT classify these as tenant data.** Inspect their columns — they
   are `symbol / direction / entry_price / outcome / pnl_ticks`: a **hypothetical strategy-signal
   ledger** derived from public market data and strategy config, deduplicated across users by symbol.
   No account, no real fill, no position, no PII. Cross-user reads there are **not** confidentiality
   breaches. Their real defects (symbol-only dedup suppressing other users' signals; cross-user
   outcome rewrites) are **data-integrity** issues (`silent_loss` / `idempotency` / `silent_corruption`),
   NOT `isolation_break`. Severity them accordingly. TigerDB does not need the RLS apparatus.

## Scale (so you size the fan-out and can prove you enumerated everything)

- Routers: **191 files, ~637–653 endpoints**. Services: **191**. Models: **217**. Schedulers: **67**
  + `worker.py`. Utils **40**, middleware **3**, subsystems (`agent/`, `sierra/`, `ml/`, `backtest/`,
  `gamma_density/`, `cluster_hunter/`, `ludwig/`, `scotts_zones_detector/`, `tws/`).
- Primary DB: **76 tables, 109 indexes, 66 FK, 76 PK, 54/53/68 RLS**. Sierra: **68 tables, 0/0/0 RLS**.
- Migrations: **131 primary + 52 Sierra**. Tests: **648 files, ~9,300 test functions**.

## The method that worked — four sequential waves, verification mandatory

Run as multi-agent orchestration (you must authorize it — up to 6 agents per wave). One wave at a
time; extract each wave's findings to disk before launching the next so context stays lean. Each
agent returns structured findings (schema below) AND a per-unit coverage matrix that proves it
enumerated its slice rather than sampled it.

- **Wave 1 — DB substrate (6 lenses):** (1) complete RLS scope matrix, every table both DBs;
  (2) PK/FK integrity + cascade trees; (3) every index + every MISSING one (unindexed FK, unindexed
  RLS predicate column); (4) column/type/constraint integrity (money as NUMERIC not float/int,
  missing CHECKs, dangerous DEFAULTs); (5) migration↔seed object-by-object drift; (6) Sierra DB +
  partitions + functions + triggers + the FDW boundary.
- **Wave 2 — every router (6 balanced slices by line count):** one row per endpoint — auth dep,
  tenant scoping (RLS dep vs explicit predicate vs none), response_model, input validation, query
  safety, error handling, background-work atomicity.
- **Wave 3 — services / schedulers+worker / utils+middleware+models+config / analytical subsystems.**
- **Wave 4 — VERIFY, do not skip.** Adversarial refuters that try to REFUTE each high-severity
  finding from Wave 1–3 (find the guard the finder missed, the dead route, the misread), plus a
  test-suite-integrity lens and any architectural-cleanup lens. **The prior pass measured ~25% of
  high-severity claims as overstated or false without this wave.** Verification is the deliverable's
  credibility, not an optional extra.

Finding schema each agent returns: `id, title, severity, file, line, evidence (quoted code),
why_wrong (the concrete input→wrong-output), blast_radius, oracle (the assertion that proves it
fixed), confidence (CONFIRMED = you read the exact lines; INFERRED = pattern-based)`.

Severity vocabulary, worst first: `isolation_break, silent_loss, silent_corruption, wrong_label,
idempotency_break, trust_break, misleading_message, loud_error, availability`.

## Head-start finding map — CONFIRM or REFUTE each; do not copy

A prior pass found these and a second agent confirmed them. Independently re-derive each from source
(they are your fast-validation checklist). If you disagree, say so with file:line — a second
independent audit that corrects the first is worth more than one that echoes it.

**Trust substrate (the keystone):**
- `scripts/mark_dump_satisfied_migrations.py:158` marks migrations that create no table as applied
  WITHOUT running them — 91 of 131. So every FORCE-RLS / policy / unique-index / constraint migration
  is unexecuted in CI, and `require_tenant_scope` appears **0 times** in `db/schema_test_seed.sql`.
  Consequence: the fail-closed RLS posture prod ships is the one posture no test exercises.
- The `20260222000000_baseline.sql` baseline is `SELECT 1;` — the migration stream cannot rebuild the
  pre-Feb-2026 schema from scratch. `audit_log` is dropped by one migration then ALTERed unguarded by
  later ones. Seed-only functions (`compute_dedupe_key`, `to_ticks`, `ticks_per_point`) exist in no
  migration.

**Primary-DB isolation (real, sensitive):**
- `public.users` — the tenant root — has NO RLS anywhere.
- `public.playbooks` has ENABLE + FORCE and ZERO policies → deny-all to every role incl. owner.
- `audit_log` insert policy is `WITH CHECK (true)` → any user can forge audit rows cross-tenant.
- Several child tables of RLS'd parents (`recording_chunks`, `trade_voice_segments`,
  `trade_zone_attribution`, …) carry the content and have no RLS themselves.
- 41 of 68 policies use the fail-open `current_setting(...) IS NULL OR ...` shape.

**Correctness patterns (recurring — report as patterns with instances):**
- **Fabricated fallback:** on exception/missing input, handlers return a plausible number a trader
  acts on (`POSITIVE gamma` on DB error; $2,500/1% risk defaults; memory score from placeholders).
- **Silent row drop, success reported:** per-row `continue` on failure, response still `success=true`.
- **Hardcoded instrument economics:** 8 disagreeing tick/point/multiplier registries + ~7 more
  private ones with silent defaults (`ELSE 1`, `0.25`, `×4`, `$50/pt`); `M6E` 2× wrong and a unit
  test asserts the wrong value; `NG` excursions 1000× off.
- `routers/hiro/alignment_score.py:505` tests `"LONG" in direction` where `direction` is `char(1)` →
  every trade classified SHORT.
- SQL injection: request-body value f-string-interpolated into an UPDATE (`v12` patterns path).

**Deprecation state (architectural):** IBB, GSST, ZDPSB, HIRO-FLATLINE, LEVEL-EDGE are believed
deprecated by the operator but are all still **mounted unconditionally and scheduled** (9 crons).
Their signal tables live on TigerDB (see topology caution). `sierra_chart.ibb_signals` is read by the
live `/api/v1/edge-context/*` surface — so the table must survive even if the code is removed.

**Test suite (false assurance):** ~298 smoke tests assert auth through a fixture that disables the
auth middleware; import-pipeline SQL is mocked away; `.coveragerc` counts test code in its own
denominator; RLS realdb tests set the tenant GUC by hand instead of via `get_db_rls_dep`.

## Known-false / pitfalls — do not repeat these

- `routers/legacy_trades.py` is NOT cross-tenant IDOR despite taking `user_id` from the path — line
  27 declares `APIRouter(dependencies=[Depends(verify_user_id_ownership)])`. The prior pass got this
  wrong; it is why Wave 4 exists.
- The Tiger `user_id` signal tables are NOT tenant data (see topology caution). Do not send anyone to
  retrofit RLS onto Timescale.
- Do not derive "systemic patterns" from keyword frequency — it over-matches badly. Curate patterns
  by reading the finding titles.
- Watch for duplicate finding ids across agents when you merge — attach each verdict to the right one
  by file, not by id alone.

## Output contract

Write to a fresh dated dir under `~/code/fusion-harness/zenedge/audit-<today>/`:
- A main report `.md`: an executive "the N things that matter", the two-DB topology stated up front,
  systemic patterns with per-pattern oracles, and a "verified by hand" section.
- Appendices: complete finding index (every finding + verdict), a refutation ledger (every
  downgraded/refuted claim + the guard the finder missed), and the coverage matrices (tables,
  endpoints, services).
- An honest-limits section: static vs executed, single-reviewed vs verified, cross-wave duplicate
  count, frontend out of scope.
- **Reconcile against the prior report** at `audit-2026-08-25/`: list where you corroborate it and
  where you correct it. Diverge with evidence.

## House law

Read-only tools only (`cat, sed -n, head, grep, rg, find, awk, wc, jq`, read-only `psql` on `:5453`).
Never the primary checkout, never a prod DB, never a write. If you produce PRs later they go to `main`
(never `production`, never `git push heroku`; use the `safe-deployment-zenedge-backend-heroku` skill).
No AI attribution in any commit or doc. Verify, don't claim — quote the line or mark it INFERRED.
