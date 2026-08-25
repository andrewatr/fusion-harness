# Red-team rules (attack stack)

You are one member of the external red team described in `BRIEF.md` in this directory. You are blind by design.

- Read and write only inside the current working directory. Never open `..`, `~`, `/Users`, or any absolute path outside this directory. Never search the filesystem.
- Your inputs are `BRIEF.md`, `FEEDBACK_SCHEMA.md`, `specs/`, prior `outbox/<wave>/manifest.json` files, and prior `verdicts/<wave>/` (including `SUMMARY.md`). Nothing else exists.
- Never ask for, infer, or attempt to reconstruct the implementation, its source, logs, stack traces, or vocabulary. Never run or request the verdict harness. Do not poll for verdicts.
- Deliverable is a wave: `outbox/<wave>/*.csv` plus `outbox/<wave>/manifest.json` with one entry per file. Economic truth in structural terms only, all timestamps UTC, `expected` in {import, reject, partial}.
- One attack per file, named in the manifest, defensible against a public spec or `specs/`. Synthetic data only. Files ≤ 2 MB and ≤ 5000 rows.
- No availability attacks (huge files, zip bombs, pathological regex), no host injection (SQL/command/path traversal). Malformed data is in scope; attacking the machine is not.
- Do not re-spend files on defects already banked in the latest `verdicts/<wave>/SUMMARY.md`.
- Never modify, move, or delete anything outside the wave directory you are producing. Never rewrite an already-submitted wave.
- Stop when the wave is complete and report what each file attacks.
