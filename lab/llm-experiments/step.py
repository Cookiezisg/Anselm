import json, sys
from pathlib import Path

RUN = Path("/tmp/w2_run/recover_capability_check.json")
STATE = Path("/tmp/w2_run/_state.json")  # persists full messages + tools + trajectory

def load_state():
    if STATE.exists():
        return json.loads(STATE.read_text())
    return None

def save_state(s):
    STATE.write_text(json.dumps(s, ensure_ascii=False, indent=2))

def write_run(messages, tools):
    RUN.write_text(json.dumps({"messages": messages, "tools": tools, "max_tokens": 16000}, ensure_ascii=False))

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "init":
        spec = json.loads(Path("/tmp/w2_specs/recover_capability_check.json").read_text())
        messages = [
            {"role": "system", "content": spec["system"]},
            {"role": "user", "content": spec["user"]},
        ]
        tools = spec["tools"]
        state = {"messages": messages, "tools": tools, "trajectory": [], "spec": spec}
        save_state(state)
        write_run(messages, tools)
        print("init done")
    elif cmd == "append_assistant":
        # reads the ds_turn output JSON from stdin file path arg2
        out = json.loads(Path(sys.argv[2]).read_text())
        state = load_state()
        msg = {"role": "assistant", "content": out.get("content")}
        rc = out.get("reasoning_content")
        if rc:
            msg["reasoning_content"] = rc
        tcs = out.get("tool_calls")
        if tcs:
            msg["tool_calls"] = tcs
        state["messages"].append(msg)
        # record trajectory turn
        tjt = {"assistant": {"content": out.get("content"), "tool_calls": tcs or []}, "tool_results": []}
        state["trajectory"].append(tjt)
        save_state(state)
        print(json.dumps({"has_tool_call": out.get("has_tool_call"), "tool_calls": tcs or [], "content": out.get("content")}, ensure_ascii=False))
    elif cmd == "append_tool":
        # arg2 = tool_call_id, arg3 = result file path (json string content)
        tcid = sys.argv[2]
        result_content = Path(sys.argv[3]).read_text()
        state = load_state()
        state["messages"].append({"role": "tool", "tool_call_id": tcid, "content": result_content})
        # add to last trajectory turn
        # find the tool_call name by id
        last = state["trajectory"][-1]
        name = None
        for tc in last["assistant"]["tool_calls"]:
            if tc["id"] == tcid:
                name = tc["function"]["name"]
        last["tool_results"].append({"tool_call_id": tcid, "name": name, "result": json.loads(result_content)})
        save_state(state)
        print("appended tool result for", tcid)
    elif cmd == "append_user":
        text = Path(sys.argv[2]).read_text()
        state = load_state()
        state["messages"].append({"role": "user", "content": text})
        state["trajectory"][-1].setdefault("user_reply", text)
        save_state(state)
        print("appended user")
    elif cmd == "flush_run":
        state = load_state()
        write_run(state["messages"], state["tools"])
        print("flushed run; n_messages=", len(state["messages"]), "n_tools=", len(state["tools"]))
    elif cmd == "add_lazy_tools":
        # arg2 = json array of tool defs
        new_tools = json.loads(Path(sys.argv[2]).read_text())
        state = load_state()
        state["tools"].extend(new_tools)
        save_state(state)
        print("added", len(new_tools), "lazy tools; total now", len(state["tools"]))
    elif cmd == "dump_messages":
        state = load_state()
        print(json.dumps(state["messages"], ensure_ascii=False, indent=2))
