set dotenv-load := true

# Bare `just` lists every recipe (first recipe = default — keep this one on top).
default:
    @just --list

# fusion-harness — 2-5 configured agents, AND not OR.
WORKHORSE_ARCHITECT := "anthropic/claude-sonnet-5"
WORKHORSE_BUILDER := "openai/gpt-5.6-terra"
SOTA_ARCHITECT := "anthropic/claude-fable-5"
SOTA_BUILDER := "openai/gpt-5.6-sol"

# Cheap legacy two-slot pair. Raw chat is the builder.
fh-workhorse *ARGS:
    pi -e extensions/fusion-harness/fusion-harness.ts \
        --model {{WORKHORSE_BUILDER}} \
        --architect {{WORKHORSE_ARCHITECT}} --builder {{WORKHORSE_BUILDER}} \
        --architect-thinking medium --builder-thinking medium \
        {{ARGS}}

# Frontier legacy two-slot pair.
fh-sota *ARGS:
    pi -e extensions/fusion-harness/fusion-harness.ts \
        --model {{SOTA_BUILDER}} \
        --architect {{SOTA_ARCHITECT}} --builder {{SOTA_BUILDER}} \
        --architect-thinking medium --builder-thinking medium \
        {{ARGS}}

# Explicit 2-5 slot YAML stack. The extension selects configured Main as host.
fh-stack CONFIG *ARGS:
    pi -e extensions/fusion-harness/fusion-harness.ts \
        --fh-config {{CONFIG}} {{ARGS}}

# THE fusion stack: rune=Fable 5 architect · flux=Gemini 3.7 Flash Main · drift=DeepSeek V4 Pro
fusion *ARGS:
    just fh-stack .pi/fusion-harness/model-stack-fusion.yaml {{ARGS}}

# 5-slot fusion stack: fusion trio + fire=Kimi K3 + hawk=DeepSeek V4 Flash (both Fireworks)
fusion5 *ARGS:
    just fh-stack .pi/fusion-harness/model-stack-fusion-5.yaml {{ARGS}}

# ═══ ZenEdge — CSV-import hardening loop (see ZENEDGE.md) ══════════════════════
# Absolute paths so every recipe survives the `cd` into another repo.
FH_EXT := justfile_directory() / "extensions/fusion-harness/fusion-harness.ts"
ZEN_STACKS := justfile_directory() / ".pi/fusion-harness"
ZEN_WT := env_var_or_default("ZEN_WT", home_directory() / "code/zenedge-backend-fusion")
ZEN_PACK := env_var_or_default("ZEN_PACK", home_directory() / "code/options-red-teaming")
ZEN_VERDICTS := home_directory() / "code/redteam-harness/run_verdicts.py"

# Preflight: auth for every slot, child-visible models, test DB, worktree, venv, pack boundary, no .env.
zen-preflight MODE="defend":
    {{justfile_directory()}}/zenedge/scripts/zen-preflight.sh {{MODE}}

# DEFEND: full stack inside the zenedge-backend worktree (white-box). sol architect · glm Main · k3 · deep.
zen-defend *ARGS:
    cd {{ZEN_WT}} && pi -e {{FH_EXT}} --fh-config {{ZEN_STACKS}}/model-stack-zenedge.yaml {{ARGS}}

# DEFEND, 5 slots (adds GPT-5.6 Terra).
zen-defend5 *ARGS:
    cd {{ZEN_WT}} && pi -e {{FH_EXT}} --fh-config {{ZEN_STACKS}}/model-stack-zenedge-5.yaml {{ARGS}}

# ATTACK: blind red team inside the pack directory (cwd is the boundary). Never point this at the backend.
zen-attack *ARGS:
    cd {{ZEN_PACK}} && pi -e {{FH_EXT}} --fh-config {{ZEN_STACKS}}/model-stack-zenedge-attack.yaml {{ARGS}}

# Judge a wave with the real pipeline from the defend worktree (writes verdicts/<wave>/ + _private diagnostics).
zen-verdicts WAVE *ARGS:
    ZENEDGE_REPO={{ZEN_WT}} REDTEAM_DIR={{ZEN_PACK}} {{ZEN_WT}}/.venv/bin/python {{ZEN_VERDICTS}} --wave {{WAVE}} {{ARGS}}

# Copy prompt N (zenedge/prompts/csv-import/0N-*.md) to the clipboard; paste after the slash command in pi.
zen-prompt N:
    cat {{justfile_directory()}}/zenedge/prompts/csv-import/0{{N}}-*.md | pbcopy && echo "prompt {{N}} on clipboard"

# Transcribe Dan's v2 walkthrough locally (yt-dlp → parakeet-mlx) into ~/code/transcripts.
zen-transcribe:
    yt-digest 'https://www.youtube.com/watch?v=rqZHR-hRllI'

# Turn the DeepSeek slot on in every ZenEdge stack once `pi --list-models deepseek` lists a model.
zen-enable-deepseek MODEL="deepseek-v4-pro" THINKING="high":
    {{justfile_directory()}}/zenedge/scripts/zen-enable-deepseek.sh {{MODEL}} {{THINKING}}
