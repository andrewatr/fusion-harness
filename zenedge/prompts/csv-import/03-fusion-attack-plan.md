Merge the flaw hunt and the risk debate into one wave-3 attack plan for the blind red team. Write it to `/Users/zen/code/redteam-harness/_private/ATTACK_PLAN_w3.md` (a defender-only directory; nothing is written into this repository).

The plan must contain:
1. Exactly 30 file briefs, grouped: ~10 options on futures, ~8 timezone/DST, ~7 encoding/locale/CSV mechanics, ~5 idempotency/lifecycle arithmetic. Each brief: broker format family (`ibkr_flex`, `schwab_tos`, `fidelity_atp`, `tastytrade`, `robinhood`, `rithmic_apex`), the single attack, the economic truth to declare in the manifest, the expected verdict (import/reject/partial), and why a naive parser gets it wrong.
2. Every brief written in structural and economic terms only. No function names, module paths, line numbers, log text, exception names, or our strategy vocabulary — the red team must be able to receive this verbatim.
3. A second section, `## DEFENDER NOTES (never shared)`, mapping each brief to the source location it targets and the fixture pattern a fix would need.
4. A `## SANITIZED HANDOFF` section: the text to paste into the attacker prompt, which is section 1 plus the universe/format constraints from `HANDOFF-lane-a-k3-wave3.md`.

Do not respend files on wave-2 banked defects. Keep the wave-2 symbol universe rules from `BRIEF.md`.
