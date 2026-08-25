#!/usr/bin/env bash
# zen-preflight — prove the ZenEdge fusion harness can launch before spending a token.
# Usage: zen-preflight.sh [defend|attack|defend5]   (default: defend)
# Prints one PASS:/FAIL: line per check, exits nonzero on any FAIL (same convention as the harness gates).
set -uo pipefail
MODE="${1:-defend}"
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZEN_WT="${ZEN_WT:-$HOME/code/zenedge-backend-fusion}"
ZEN_PACK="${ZEN_PACK:-$HOME/code/options-red-teaming}"
case "$MODE" in
  defend)  YAML="$FH/.pi/fusion-harness/model-stack-zenedge.yaml";  CWD="$ZEN_WT" ;;
  defend5) YAML="$FH/.pi/fusion-harness/model-stack-zenedge-5.yaml"; CWD="$ZEN_WT" ;;
  attack)  YAML="$FH/.pi/fusion-harness/model-stack-zenedge-attack.yaml"; CWD="$ZEN_PACK" ;;
  *) echo "FAIL: unknown mode '$MODE' — use defend|defend5|attack"; exit 2 ;;
esac
fails=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails+1)); }

# --- tools ---
for t in pi just jq uv bun; do command -v "$t" >/dev/null && pass "$t on PATH" || fail "$t missing — run /install"; done

# --- no metered .env in the harness repo ---
[[ -e "$FH/.env" ]] && fail "$FH/.env exists — dotenv-load would hand its keys to every child; delete it (plan-only rule)" || pass "no .env in fusion-harness"

# --- stack file + slots ---
[[ -f "$YAML" ]] || { fail "stack missing: $YAML"; echo "FAIL: $fails check(s) failed"; exit 1; }
pass "stack file: ${YAML#$FH/}"
models=$(grep -E '^\s*model:' "$YAML" | awk '{print $2}')
catalog=$(pi --no-extensions --list-models 2>/dev/null | awk 'NR>1 && NF>=2 {print $1"/"$2}')
for m in $models; do
  p="${m%%/*}"
  st=$(pi auth check --provider "$p" --no-refresh --json 2>/dev/null | jq -r '.status // "unknown"')
  [[ "$st" == "ready" ]] && pass "auth ready: $p" || fail "auth not ready for provider '$p' ($st) — key in ~/.config/zenedge/secrets.env or \`pi\` /login"
  grep -qx "$m" <<<"$catalog" && pass "child-visible model: $m" || fail "model not in \`pi --no-extensions --list-models\`: $m"
done
grep -q 'model: openai/' "$YAML" && fail "stack uses the METERED 'openai' provider — use openai-codex" || pass "no metered openai provider in stack"
for f in $(grep -E '^\s*- \.\./' "$YAML" | awk '{print $2}' | sort -u); do
  [[ -f "$(dirname "$YAML")/$f" ]] && pass "append prompt exists: $f" || fail "append prompt missing: $f"
done

# --- cwd for this mode ---
[[ -d "$CWD" ]] && pass "cwd exists: $CWD" || fail "cwd missing: $CWD"
if [[ "$MODE" == attack ]]; then
  [[ -f "$CWD/BRIEF.md" ]] && pass "pack has BRIEF.md" || fail "pack lacks BRIEF.md — wrong directory for the blind attacker"
  [[ -d "$CWD/routers" ]] && fail "pack contains routers/ — this is NOT the blind pack, refusing" || pass "pack has no implementation directory"
  grep -q ZENEDGE_HOUSE_RULES "$YAML" && fail "attack stack appends the DEFEND rules — implementation map would leak" || pass "attack stack appends attack rules only"
else
  if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    br=$(git -C "$CWD" branch --show-current)
    [[ "$br" != main && "$br" != production && -n "$br" ]] && pass "worktree branch: $br" || fail "worktree is on '$br' — feature work never runs on main/production"
    [[ "$(git -C "$CWD" rev-parse --show-toplevel)" != "$HOME/code/zenedge-backend" ]] && pass "not the primary checkout" || fail "cwd IS the primary checkout ~/code/zenedge-backend — use a worktree"
  else
    fail "$CWD is not a git worktree"
  fi
  [[ -x "$CWD/.venv/bin/python" ]] && pass ".venv present" || fail ".venv missing — uv venv --python 3.11 .venv && uv pip install --python .venv/bin/python -r requirements.txt -r requirements-dev.txt"
  [[ -f "$CWD/routers/trade_import/parsers.py" ]] && pass "import pipeline present" || fail "routers/trade_import/parsers.py not found in $CWD"
fi

# --- verdict runner + test DB (both modes: the loop needs them) ---
[[ -f "$HOME/code/redteam-harness/run_verdicts.py" ]] && pass "run_verdicts.py present" || fail "~/code/redteam-harness/run_verdicts.py missing"
if docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -q 'zenedge-audit-pg.*5453'; then pass "test DB zenedge-audit-pg up on :5453"; else fail "test DB not running — docker start zenedge-audit-pg (see redteam-harness/LAUNCH.md)"; fi

if (( fails )); then echo "FAIL: $fails check(s) failed"; exit 1; fi
echo "PASS: preflight clean for mode=$MODE"
