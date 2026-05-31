import json
from pathlib import Path

spec = json.loads(Path("/tmp/w2_specs/recover_capability_check.json").read_text())

messages = [
    {"role": "system", "content": spec["system"]},
    {"role": "user", "content": spec["user"]},
]
tools = spec["tools"]

out = {"messages": messages, "tools": tools, "max_tokens": 16000}
Path("/tmp/w2_run/recover_capability_check.json").write_text(json.dumps(out, ensure_ascii=False))
print("wrote turn1 spec; n_messages=", len(messages), "n_tools=", len(tools))
