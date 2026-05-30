import json
from pathlib import Path

state = json.loads(Path("/tmp/w2_run/_state.json").read_text())
spec = state["spec"]
traj = state["trajectory"]

# build turns: each {assistant: {content, tool_calls:[{name,args}]}, tool_results:[...]}
turns = []
for t in traj:
    a = t["assistant"]
    tcs = []
    for tc in a.get("tool_calls", []):
        tcs.append({"name": tc["function"]["name"], "args": json.loads(tc["function"]["arguments"]) if tc["function"]["arguments"] else {}})
    turn = {
        "assistant": {"content": a.get("content"), "tool_calls": tcs},
        "tool_results": t.get("tool_results", []),
    }
    if "user_reply" in t:
        turn["user_reply"] = t["user_reply"]
    turns.append(turn)

# final = last assistant text
final = None
for t in reversed(traj):
    c = t["assistant"].get("content")
    if c:
        final = c
        break

out = {
    "id": "recover_capability_check",
    "intent": spec["intent"],
    "rubric": spec["rubric"],
    "user": spec["user"],
    "turns": turns,
    "final": final,
}
Path("/tmp/w2").mkdir(parents=True, exist_ok=True)
Path("/tmp/w2/recover_capability_check.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
print("wrote trajectory with", len(turns), "turns; final len=", len(final or ""))
