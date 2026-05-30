"""Probe which param disables DeepSeek V4-flash thinking (reasoning_content)."""
import json, os
import httpx

KEY = os.environ["DEEPSEEK_API_KEY"]
BASE = "https://api.deepseek.com/chat/completions"

candidates = [
    ("baseline (no param)", {}),
    ("chat_template_kwargs.thinking=false", {"chat_template_kwargs": {"thinking": False}}),
    ("thinking.type=disabled", {"thinking": {"type": "disabled"}}),
    ("reasoning_effort=none", {"reasoning_effort": "none"}),
    ("enable_thinking=false", {"enable_thinking": False}),
    ("thinking=false", {"thinking": False}),
]

for name, extra in candidates:
    payload = {"model": "deepseek-v4-flash",
               "messages": [{"role": "user", "content": "List 3 colors as a JSON array."}],
               "max_tokens": 300, **extra}
    try:
        r = httpx.post(BASE, headers={"Authorization": "Bearer " + KEY}, json=payload, timeout=30)
        if r.status_code != 200:
            print(name, "-> HTTP", r.status_code, r.text[:120])
            continue
        m = r.json()["choices"][0]["message"]
        rc = len(m.get("reasoning_content") or "")
        content = (m.get("content") or "")[:60]
        print(name, "-> OK reasoning_chars=", rc, "content=", repr(content))
    except Exception as e:
        print(name, "-> EXC", repr(e))
