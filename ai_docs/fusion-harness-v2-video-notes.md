# Fusion harness v2 — notes from Dan's walkthrough

Source: "Intelligence EXPLOSION: Harness Engineering with Pi Agent, Deepseek, and Gemini" (IndyDevDan, 2026-08-24, 28:05, `rqZHR-hRllI`). Transcribed locally with `yt-digest` (yt-dlp → parakeet-mlx) into `~/code/transcripts/rqZHR-hRllI.{txt,srt}`. Timestamps cite the `.srt`.

## What the video demonstrates (three of the seven commands)

1. `/fh-opinion` [00:01:52 → ~00:05] — one prompt, every slot answers read-only, side by side. The value is three independent perspectives on one question plus the cost/speed of each answer. His DuckDB run: Fable and Gemini converged on the same feature, DeepSeek V4 Pro "drifted" — divergence itself is the signal.
2. `/fh-debate` [~00:07 → ~00:14] — his favourite. Round 1 opening opinions; every later round each agent receives every other agent's labelled opinion; closing statements, no judge. All three rejected the DuckDB-as-server claim. He frames debate as the tool for month- and year-long decisions, not just code.
3. `/fh-collaborate` [~00:14 → ~00:24] — "the most powerful". Every agent plans read-only, the one ARCHITECT merges the plans into a task DAG with owner + mode + dependencies (the "till done list" [00:17:19]), tasks execute as dependencies clear with one writer at a time, and the architect does final integration. Plans come out with reference points (T1/T2, R1/R2) because every slot appends the communication-contract system prompt.

Not demonstrated, called out as "big ones" [00:25:49]: `/fh-auto-validate` and `/fh-fusion`. Those are our prompts 03, 05 and 06.

## Rules he states that we encode

- Three things to watch per model: performance on the task, speed, cost [00:05:59]. The model bar shows all three per slot; read it after every run.
- Never reveal a model's name to the other models [00:06:22, 00:10:35] — slots get aliases (rune/flux/drift) because models "start emitting weird behaviour" and sabotage each other when they know who they are competing with. Our slot names are `sol`/`glm`/`k3`/`deep`; the harness roster shows those, not vendor ids. Keep prompts free of vendor names.
- Exactly one architect, and it should be the strongest model you are willing to pay for [00:15:19, 00:15:26]: it merges every plan and does final integration. Ours is Sol at xhigh (plan-billed); Fable stays outside for TOS reasons.
- GPT-5.6 API pricing doubles input and 1.5×s output past ~280k context [00:12:38]. Our `openai-codex` plan path has a 372k ceiling and no per-token bill; never switch a slot to `openai`.
- "Combine compute, don't select compute": the point of the stack is A-tier workhorses doing the reps next to one frontier seat. He puts DeepSeek V4 Pro and Kimi K3 in the "thinks a lot" bucket — slow first token, strong output; budget time, not just dollars.
- Keep the stack config simple: name, model, thinking, append_system_prompt [~00:25].
- His own split: Fable in Claude Code for hardcore in-loop orchestration, Pi variants for the specialised harness work [00:23:33]. That is exactly our shape: Claude Code reviews artifacts; the Pi stack runs the loop.
- The end state is out-loop: a software factory where agents plus code run without you [00:26:20]. The red-team loop (attack → verdict → triage → gate-first fix) is our first factory cell.

## Deltas applied to the ZenEdge prompt set

- Prompt 01 asks for divergence explicitly (ranked lists, confidence, the confirming experiment) because the opinion command's value is the spread, not the consensus.
- Prompt 02 is a debate about a decision (which defect class leads the wave), the use he recommends, rather than a code question.
- Prompt 04 tells the collaborate architect to split ownership by attack family so the DAG has real parallelism, mirroring his "who should build what" plans.
- Every slot appends `system_prompt_fixing_opus_5_great_communication.md` first, then the ZenEdge rules, so reports carry reference points (D/F/R/T codes) across slots.
