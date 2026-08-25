#!/usr/bin/env bash
# zen-enable-deepseek — replace the DEEPSEEK_PRO_PLACEHOLDER / DEEPSEEK_FLASH_PLACEHOLDER lines in every
# ZenEdge stack with live slots. Usage: zen-enable-deepseek.sh <pro-id> <flash-id>
# Refuses ids that `pi --no-extensions --list-models` does not list (never fabricate model ids).
# Thinking: pro=high in defend stacks, medium in attack; flash=medium everywhere (DeepSeek is metered).
set -euo pipefail
PRO="${1:?pro model id}"; FLASH="${2:?flash model id}"
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
catalog=$(pi --no-extensions --list-models 2>/dev/null | awk 'NR>1 {print $1"/"$2}')
for m in "$PRO" "$FLASH"; do
  grep -qx "deepseek/$m" <<<"$catalog" || { echo "FAIL: deepseek/$m not in pi's catalog — set DEEPSEEK_API_KEY, 'pi update --models', check 'pi --list-models deepseek'"; exit 1; }
done
slot() { # name model thinking color rules
  printf -- '- name: %s\n  model: deepseek/%s\n  thinking: %s\n  color: "%s"\n  append_system_prompt:\n    - ../../system_prompt_fixing_opus_5_great_communication.md\n    - ../../zenedge/prompts/%s' "$1" "$2" "$3" "$4" "$5"
}
for yaml in "$FH"/.pi/fusion-harness/model-stack-zenedge*.yaml; do
  grep -q "DEEPSEEK_.*PLACEHOLDER" "$yaml" || { echo "skip (already enabled): ${yaml#$FH/}"; continue; }
  rules=ZENEDGE_HOUSE_RULES.md; pro_think=high
  grep -q ZENEDGE_ATTACK_RULES "$yaml" && { rules=ZENEDGE_ATTACK_RULES.md; pro_think=medium; }
  python3 - "$yaml" "$(slot pro "$PRO" "$pro_think" '#F472B6' "$rules")" "$(slot flash "$FLASH" medium '#A3E635' "$rules")" <<'PY'
import re, sys
path, pro, flash = sys.argv[1:4]
s = open(path).read()
s = re.sub(r"^# DEEPSEEK_PRO_PLACEHOLDER.*$", pro, s, count=1, flags=re.M)
s = re.sub(r"^# DEEPSEEK_FLASH_PLACEHOLDER.*$", flash, s, count=1, flags=re.M)
open(path, "w").write(s)
PY
  echo "enabled deepseek slots in ${yaml#$FH/}"
done
