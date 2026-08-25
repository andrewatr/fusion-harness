#!/usr/bin/env bash
# zen-enable-deepseek — replace the DEEPSEEK_PLACEHOLDER comment in every ZenEdge stack with a live slot.
# Usage: zen-enable-deepseek.sh <model-id> <thinking>   e.g. deepseek-v4-pro high
# Refuses unless `pi --no-extensions --list-models` actually lists deepseek/<model-id> (never fabricate ids).
set -euo pipefail
MODEL="${1:?model id}"; THINK="${2:?thinking level}"
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pi --no-extensions --list-models 2>/dev/null | awk 'NR>1 {print $1"/"$2}' | grep -qx "deepseek/$MODEL" \
  || { echo "FAIL: deepseek/$MODEL is not in pi's catalog — set DEEPSEEK_API_KEY, run 'pi update --models', check 'pi --list-models deepseek'"; exit 1; }
for yaml in "$FH"/.pi/fusion-harness/model-stack-zenedge*.yaml; do
  grep -q DEEPSEEK_PLACEHOLDER "$yaml" || { echo "skip (already enabled): ${yaml#$FH/}"; continue; }
  rules=ZENEDGE_HOUSE_RULES.md; grep -q ZENEDGE_ATTACK_RULES "$yaml" && rules=ZENEDGE_ATTACK_RULES.md
  think="$THINK"; [[ "$rules" == ZENEDGE_ATTACK_RULES.md ]] && think=medium
  slot=$(printf -- '- name: deep\n  model: deepseek/%s\n  thinking: %s\n  color: "#F472B6"\n  append_system_prompt:\n    - ../../system_prompt_fixing_opus_5_great_communication.md\n    - ../../zenedge/prompts/%s' "$MODEL" "$think" "$rules")
  python3 - "$yaml" "$slot" <<'PY'
import re, sys
path, slot = sys.argv[1], sys.argv[2]
src = open(path).read()
out = re.sub(r"^# DEEPSEEK_PLACEHOLDER.*$", slot, src, count=1, flags=re.M)
open(path, "w").write(out)
PY
  echo "enabled deepseek/$MODEL ($think) in ${yaml#$FH/}"
done
