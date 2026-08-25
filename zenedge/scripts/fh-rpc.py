#!/usr/bin/env python3
"""Drive a fusion-harness command headlessly over pi's RPC mode (for Claude Code / scripts; humans use the TUI).

Usage: fh-rpc.py <cwd> <stack.yaml> <timeout-seconds> "<slash command and prompt>"
Raw JSONL events go to ./fh-rpc-events.jsonl in cwd; panels and status lines print to stdout.
Artifacts land in /tmp/fusion-harness-*/ exactly as in the TUI. Sessions persist under /tmp/fusion-harness-sessions/.
"""
import json, os, subprocess, sys, threading, time
cwd, yaml, secs, msg = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
EXT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "extensions", "fusion-harness", "fusion-harness.ts")
p = subprocess.Popen(["pi", "-e", EXT, "--fh-config", yaml, "--mode", "rpc", "--no-skills"], cwd=cwd,
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
raw = open(os.path.join(cwd, "fh-rpc-events.jsonl"), "a")
finished = threading.Event()
def drain_stderr():  # never let the stderr pipe fill — a blocked writer stalls every event
    for line in p.stderr: raw.write(json.dumps({"stderr": line.rstrip()}) + "\n")
def reader():
    for line in p.stdout:
        line = line.rstrip("\r\n")
        if not line: continue
        raw.write(line + "\n"); raw.flush()
        try: ev = json.loads(line)
        except Exception: continue
        t = ev.get("type")
        if t == "extension_ui_request" and ev.get("method") in ("notify", "setStatus"):
            print(f"[{ev['method']}] {str(ev.get('message') or ev.get('statusText') or '')[:200]}", flush=True)
        elif t == "message_end" and ev.get("message", {}).get("customType") == "fusion-harness":
            c = ev["message"].get("content"); txt = c if isinstance(c, str) else " ".join(x.get("text", "") for x in c if isinstance(x, dict))
            print(f"[panel {len(txt)} chars] {txt[:160].replace(chr(10), ' ')}", flush=True)
            if txt.startswith("## ") or "sha256" in txt or "Task " in txt: finished.set()
    finished.set()
threading.Thread(target=drain_stderr, daemon=True).start(); threading.Thread(target=reader, daemon=True).start()
time.sleep(4)
p.stdin.write(json.dumps({"id": "r1", "type": "prompt", "message": msg}) + "\n"); p.stdin.flush()
t0 = time.time()
while time.time() - t0 < secs and p.poll() is None and not finished.is_set(): time.sleep(2)
time.sleep(5); p.kill()
print("done" if finished.is_set() else "timeout/exit", flush=True)
