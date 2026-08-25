Produce wave `w3` of the red-team engagement described in `BRIEF.md`.

Read, in order: `BRIEF.md`, `FEEDBACK_SCHEMA.md`, `specs/README.md`, `specs/FIELDS.md`, `specs/FOP.md`, `verdicts/w2/SUMMARY.md`, and the worked example `outbox/w0-selftest/manifest.json` beside `verdicts/w0-selftest/`.

Deliverable: exactly 30 files in `outbox/w3/` plus `outbox/w3/manifest.json` with one entry per file, following the schema in `BRIEF.md`. Composition: about 10 options-on-futures files (per `specs/FOP.md`), about 8 timezone/DST files, about 7 encoding/locale/CSV-mechanics files, about 5 idempotency/lifecycle-arithmetic files. Split ownership so each agent owns one family end to end (files and manifest entries), and one agent assembles the final manifest.

Rules that decide whether a file counts: one attack per file, named in the manifest; a real broker could emit it and you can cite the spec; synthetic data only; economic truth in UTC and in structural terms; ≤ 2 MB and ≤ 5000 rows; no availability or host-injection payloads; no re-spend on the banked wave-2 defects listed in `verdicts/w2/SUMMARY.md`. Self-check every file: parse it yourself as CSV, confirm the header matches the family's documented signature, confirm the manifest entry's legs reconcile to the file's rows.

Stop when `outbox/w3/` holds 30 files and a manifest that validates. Report what each file attacks. Do not run any harness, do not read outside this directory, do not start wave 4.

ATTACK BRIEFS (sanitized, from the defender's plan):
<paste the `## SANITIZED HANDOFF` section of ATTACK_PLAN_w3.md here>
