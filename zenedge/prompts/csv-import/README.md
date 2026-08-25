# ZenEdge CSV-import hardening prompts

Run in numeric order. Each prompt maps to one harness command and one cwd. Copy with `just zen-prompt N`, type the slash command in pi, paste. Prompts 03–06 carry `<paste …>` slots that you fill from the previous step's artifact.

| Order | Prompt | Command | Launch | Proves |
|---:|---|---|---|---|
| 1 | `01-opinion-parser-flaw-hunt.md` | `/fh-opinion` | `just zen-defend` | four independent read-only defect lists with `file:line` evidence |
| 2 | `02-debate-highest-risk-class.md` | `/fh-debate --rounds 2` | `just zen-defend` | which defect class leads wave 3 and the first fix |
| 3 | `03-fusion-attack-plan.md` | `/fh-fusion` | `just zen-defend` | one sole-writer plan in `redteam-harness/_private/ATTACK_PLAN_w3.md` with a sanitized handoff section |
| 4 | `04-collaborate-wave-generate.md` | `/fh-collaborate` | `just zen-attack` | 30 hostile files + manifest in `outbox/w3/`, produced blind, one writer at a time |
| — | judge the wave | `just zen-verdicts w3` | shell | sanitized verdicts + private diagnostics |
| 5 | `05-fusion-verdict-triage.md` | `/fh-fusion` | `just zen-defend` | `verdicts/w3/SUMMARY.md` (public) + `_private/DEFECTS_w3.md` (fix list) |
| 6 | `06-auto-validate-fix-defect.md` | `/fh-auto-validate --max-validations 5` | `just zen-defend` | one defect fixed behind a gate that was RED at baseline, with an inline-CSV regression test |

Repeat 6 per defect; each fix is a branch → PR to `main`. Then the next wave: 3 → 4 → verdicts → 5 → 6.
