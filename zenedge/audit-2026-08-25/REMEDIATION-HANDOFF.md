# Fable-5 handoff — remediate the ZenEdge backend audit

> Paste everything below the line into a fresh Fable-5 session rooted at `~/code/fusion-harness`.
> It is self-contained. It points at the audit as the source of truth and gives an ordered,
> criticality-first remediation plan with a red-first discipline.

---

You are Fable 5, picking up a remediation effort on `zenedge-backend`. A four-wave, 24-agent
read-only audit has already been done. Your job now is to FIX the confirmed issues, in order of
criticality and leverage, with tests that prove each fix.

## Read first (source of truth)

All under `~/code/fusion-harness/zenedge/audit-2026-08-25/`:
- `ZENEDGE_BACKEND_AUDIT_2026-08-25.md` — the report. Read it in full before touching code.
- `APPENDIX-A-findings-index.md` — all 551 findings, each with a verdict.
- `APPENDIX-B-refutation-ledger.md` — the 83 claims that were downgraded/rejected. **Check this
  before acting on any finding** — do not fix something a refuter already showed was guarded.
- `APPENDIX-C/D/E` — the coverage matrices (tables, endpoints, services).
- `APPENDIX-F-deprecation-and-tests.md` — the ordered deprecation plan and the test-suite ledger.

Trust `CONFIRMED` findings. Treat `OVERSTATED` at the corrected severity. Ignore `REFUTED`. The 208
`UNREVIEWED` are single-source leads — re-derive one from source before you act on it.

## Ground rules (house law — do not violate)

- **Work in a fresh worktree per concern**, off `origin/main`:
  `git -C ~/code/zenedge-backend worktree add ~/code/zenedge-backend-<topic> -b fix/<topic> origin/main`.
  The existing `~/code/zenedge-backend-fusion` worktree is the audit's read-only checkout on a
  different branch — do not commit remediation there. Never touch the primary checkout
  `~/code/zenedge-backend` (it is on an unrelated branch).
- Ship **atomic PRs to `main`**, one concern each. `main` is the integration branch; CD promotes
  `production`. **Never merge to `production`, never `git push heroku`.** For any prod action invoke
  the `safe-deployment-zenedge-backend-heroku` skill. No AI attribution in commits or PRs.
- CI runs `black` on changed files and `ruff` repo-wide — run both before every PR. Migrations:
  pure ALTER/INSERT migrations are marked applied in CI without running, so replay their effect into
  `db/schema_test_seed.sql` in the same change (this is finding P5 — see Phase 1).
- **Red-first, always.** Every confirmed finding in the audit carries an `oracle` field: the exact
  assertion that proves it fixed. Write that as a FAILING test first, confirm it is red against
  current code, then fix until green. A fix without a test that would have caught the bug is not done.
- The ephemeral test DB is up: `postgresql://postgres:postgres@127.0.0.1:5453/zenedge_test`
  (`docker start zenedge-audit-pg` if not). Prefer a `realdb` test that executes real SQL over a
  mocked one — the audit found the mocked tier proves little (Appendix F).
- Verify, don't claim. Run the test, read the output, paste the summary line. "Should pass" is not done.

## Optional but recommended: use the fusion harness

This repo IS the multi-model harness. For the mechanical, high-volume phases (the pattern sweeps in
Phase 4) `just zen-defend` + `/fh-auto-validate` will write the gate red-first and build to green
across models. For the judgment-heavy phases (deprecation, isolation) drive it yourself. The audit's
per-finding oracles are designed to drop straight into an auto-validate gate.

## Remediation order (criticality × leverage)

### Phase 0 — P0 point fixes (hours, no dependencies, do immediately)
Small, isolated, high-severity. One PR each or one combined security PR.
1. **SQL injection** — `agent/v12/mcp_tools/memory_tools.py:494` and the `PATCH /api/v12/patterns/{id}`
   path (`routers/v12_coaching.py:532`): request-body `status`/`improvement_pct` are f-string-
   interpolated into an UPDATE. Parameterise. (Also fixes the cross-tenant PATCH — add the owner predicate.)
2. **Auth stub** — `routers/videos_cloudfront.py`: `check_user_can_access_object` returns `True`.
   Implement the ownership check or stop minting presigned URLs.
3. **Credential proxy** — `routers/rithmic_import.py:739` unauthenticated `capture-uid` proxies broker
   username/password to a third-party host behind a bypassable Origin check. Gate or remove.
4. **M2M admin** — `utils/deps.py:152-156` grants admin to any service token. Require an explicit
   client allowlist + permission, matching `require_support_permission`.
5. **Zoom HMAC oracle** — `routers/educator/routes_zoom.py:140`: the CRC handshake returns
   `HMAC(secret, attacker_input)` before any signature check.

### Phase 1 — the trust substrate (KEYSTONE — nothing else can be gated until this is done)
**P5: migration ↔ seed drift.** `scripts/mark_dump_satisfied_migrations.py:158` marks 91 of 131
migrations applied without running them; `require_tenant_scope` and every FORCE-RLS/policy is absent
from `db/schema_test_seed.sql`. Until CI builds a database that matches production, every gate you
write below proves less than it appears to.
- Add a CI step that builds a database from `db/migrations/` alone and diffs every object (table,
  column, index, constraint, policy, FORCE flag, function, trigger) against `db/schema_test_seed.sql`.
  Fail on any drift not explicitly registered as dump-only.
- Reconcile the seed to production: add the missing FORCE flags, the `require_tenant_scope` policies,
  and the seed-only functions (`compute_dedupe_key`, `to_ticks`, `ticks_per_point`, …) so the test DB
  is structurally production. Appendix C lists the exact object-level diffs.
- Fix `create_recall_partition()` and the Stage-2 veto's `relkind='r'` filter so partitions are
  fail-closed (Appendix C, rls-04).

### Phase 2 — deprecate the five surfaces (highest single-move leverage)
Follow Appendix F's ordered plan verbatim. This removes **11 of the 18 confirmed tenant-isolation
defects**, 9 scheduler crons, 2 unauthenticated endpoints, and a large slice of the fabrication
pattern — by deletion, not patching. Hard constraints from the trace:
- **Keep `sierra_chart.ibb_signals` permanently** — the live `/api/v1/edge-context/*` surface reads it.
- Delete the `level_edge` entries at `utils/auth_middleware.py:63-64` in the same commit as the unmount.
- `hiro_flatline` inserts rows from a GET (`services/hiro_flatline_service.py:215`) — expect a write
  path to disappear when you stop it.
- Baseline the boot log route count first; it must fall by exactly 50. Stop the 9 crons (pause their
  snitches, don't delete) before deleting any code. One registry block per PR.

### Phase 3 — remaining tenant isolation (the holes NOT inside the five)
- `public.users` has no RLS anywhere; `public.playbooks` is ENABLE+FORCE with zero policies
  (deny-all); `audit_log` insert is `WITH CHECK (true)`; five child tables of RLS'd parents and the
  entire Sierra DB have no RLS. (Appendix C, rls-02/03/04/07.)
- Confirmed cross-tenant endpoints outside the deprecated five: `routers/zones.py:41`,
  `routers/trade_quality_v3.py:728` and `:790`, `routers/ml_reversion_combo.py`,
  `routers/hiro/hiro_divergence_walkforward.py:763` (global Redis cache key). Add owner predicates;
  gate each with a two-user realdb test (user B cannot read/write user A's row).

### Phase 4 — money correctness (pattern sweeps — good fusion-harness auto-validate work)
- **P3 instrument-economics parity** — this is target T1 in `zenedge/ZENEDGE_FUSION_HARNESS_TARGETS.md`;
  the audit added 7 new hardcoded-tick locations to it (Appendix A, search "tick"). Build the
  cross-registry parity gate first, then delete each private table in favour of the one registry.
- **P1 fabricated fallback** — ban it as a rule, then sweep ~25 confirmed sites: no handler returns a
  numeric field on an exception path. Error paths return errors.
- `routers/hiro/alignment_score.py:505` classifies every trade SHORT (`"LONG" in` a `char(1)` column).
- Dedupe-key second-truncation and the Python/DB key divergence (target T2).

### Phase 5 — make the fixes stick (test integrity)
From Appendix F: switch the ~298 `*_requires_auth` smoke tests from `client` to `auth_client`; remove
5xx from every accepted-status set; add `tests/*` to `.coveragerc` omit and reset the coverage floor
to the true product number; make the RLS realdb tests exercise `get_db_rls_dep` instead of setting the
GUC by hand; delete the two `or True` assertions.

## Known limits of the audit (so you don't over-trust it)
- Static only — no query was executed. Where you can, prove a finding by running it against the
  `:5453` DB before fixing (e.g. connect as `zenedge_app`, select another user's row) — that upgrades
  it from read-confirmed to execution-confirmed.
- The 551 count includes cross-wave duplicates of the same defect class; distinct defects are fewer.
- Verdict attachment in Appendix A matched by file when uids collided across finders — spot-check the
  verdict against Appendix B if a fix seems to contradict a refutation.
- Frontend repo was out of scope; "no other reader" conclusions rest on in-repo evidence only. For
  Phase 2, confirm no frontend caller before deleting a public endpoint.

## Definition of done for this effort
Every Phase 0-3 confirmed finding is either fixed behind a red-first test, or explicitly deferred with
a one-line reason in a running `REMEDIATION-LOG.md`. Phase 1 lands before any Phase 4 gate is trusted.
Report per PR: files changed, the failing-then-passing test, and `black`/`ruff` clean.
