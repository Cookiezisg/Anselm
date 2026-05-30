"""Model-under-test client — self-contained (tooltuner does not depend on the retiring llm-experiments).

DeepSeek default (OpenAI-compatible /chat/completions), model swappable. Carries: retries on 429/5xx,
the budget ledger (/tmp per-pid; the real stop signal is DeepSeek's 402), content-leak fallback
(V4 sometimes emits tool calls as text), and parse_args with brace-repair (G1).

Ground-truth note: this only PRODUCES the model's calls/args. Whether they're *correct* is judged
elsewhere — except code (function/handler), which run_model can really execute (the one hard truth).
"""
from __future__ import annotations

import json
import os
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

try:
    from json_repair import repair_json
except Exception:
    repair_json = None

API_BASE = "https://api.deepseek.com"
DEFAULT_MODEL = "deepseek-v4-flash"
# DeepSeek V4-flash pricing (USD / 1M tok) → RMB
_PIN, _PIC, _POUT, _USD2RMB = 0.14, 0.0028, 0.28, 7.2
_LEDGER = Path("/tmp") / f"tooltuner_budget_{os.getpid()}.json"


def _key() -> str:
    k = os.environ.get("DEEPSEEK_API_KEY")
    if not k:
        kf = Path("/tmp/.ds_key")
        if kf.exists():
            k = kf.read_text().strip()
            os.environ["DEEPSEEK_API_KEY"] = k
    if not k:
        raise RuntimeError("DEEPSEEK_API_KEY not set and /tmp/.ds_key missing")
    return k


def cumulative_cost_rmb() -> float:
    """Total ¥ spent this campaign — sums tooltuner + the legacy research ledgers (shared ¥200 budget)."""
    total = 0.0
    for pat in ("tooltuner_budget_*.json", "forge_budget_*.json"):
        for f in Path("/tmp").glob(pat):
            try:
                total += sum(e.get("cost_rmb", 0) for e in json.loads(f.read_text()))
            except Exception:
                pass
    return total


def _log_cost(usage: dict) -> float:
    cached = usage.get("prompt_cache_hit_tokens", 0)
    unc = usage.get("prompt_cache_miss_tokens", usage.get("prompt_tokens", 0) - cached)
    out = usage.get("completion_tokens", 0)
    rmb = (unc / 1e6 * _PIN + cached / 1e6 * _PIC + out / 1e6 * _POUT) * _USD2RMB
    try:
        led = json.loads(_LEDGER.read_text()) if _LEDGER.exists() else []
        led.append({"cost_rmb": rmb, "out": out})
        _LEDGER.write_text(json.dumps(led))
    except Exception:
        pass
    return rmb


class BudgetExhausted(Exception):
    """DeepSeek reported insufficient balance (HTTP 402) — the real stop signal."""


_LEAK = [
    re.compile(r'\{\s*"name"\s*:\s*"([^"]+)"\s*,\s*"arguments"\s*:\s*(\{.*?\})\s*\}', re.DOTALL),
    re.compile(r'(\w+)\(\s*(\{.*?\})\s*\)', re.DOTALL),
]


def _parse_leak(content: str) -> list[dict]:
    for pat in _LEAK:
        got = []
        for m in pat.finditer(content or ""):
            try:
                if len(m.groups()) == 1:
                    o = json.loads(m.group(1))
                    if "name" in o:
                        got.append(o)
                else:
                    got.append({"name": m.group(1), "arguments": json.loads(m.group(2))})
            except json.JSONDecodeError:
                continue
        if got:
            return got
    return []


def parse_args(tc: dict) -> dict:
    """Tool-call args → dict, tolerating control chars + brace-undercount (G1: backend MUST repair)."""
    fn = tc.get("function") or tc
    a = fn.get("arguments") if isinstance(fn, dict) else None
    if isinstance(a, str):
        try:
            return json.loads(a, strict=False)
        except Exception:
            if repair_json is not None:
                try:
                    fixed = repair_json(a, return_objects=True)
                    if isinstance(fixed, dict) and fixed:
                        fixed["__repaired__"] = True
                        return fixed
                except Exception:
                    pass
            return {"_unparseable": a}
    return a if isinstance(a, dict) else {}


@dataclass
class Result:
    content: str
    reasoning: str
    tool_calls: list[dict]
    finish_reason: str
    cost_rmb: float
    leaked: bool

    @property
    def effective_calls(self) -> list[dict]:
        return self.tool_calls or [{"function": tc, "id": f"leak_{i}"} for i, tc in enumerate(self._leak)]

    _leak: list = None  # set in chat()


def chat(messages: list[dict], tools: list[dict] | None = None, *, model: str = DEFAULT_MODEL,
         temperature: float | None = None, max_tokens: int = 12000, disable_thinking: bool = False,
         timeout: float = 90.0, max_retries: int = 3) -> Result:
    payload: dict[str, Any] = {"model": model, "messages": messages, "max_tokens": max_tokens}
    if temperature is not None:
        payload["temperature"] = temperature
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    if disable_thinking:
        payload["thinking"] = {"type": "disabled"}
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}

    backoff, last = 1.0, None
    for _ in range(max_retries):
        try:
            with httpx.Client(timeout=timeout) as c:
                resp = c.post(f"{API_BASE}/chat/completions", headers=headers, json=payload)
            if resp.status_code == 402 or "insufficient balance" in resp.text.lower():
                raise BudgetExhausted(f"DeepSeek 402: {resp.text[:160]}")
            if resp.status_code == 429 or resp.status_code >= 500:
                last = RuntimeError(f"HTTP {resp.status_code}"); time.sleep(backoff); backoff *= 2; continue
            if resp.status_code != 200:
                raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:300]}")
            data = resp.json()
            rmb = _log_cost(data.get("usage", {}))
            msg = data["choices"][0]["message"]
            content = msg.get("content") or ""
            tcs = msg.get("tool_calls") or []
            fr = data["choices"][0].get("finish_reason", "")
            leak = _parse_leak(content) if (not tcs and content and fr == "stop") else []
            r = Result(content, msg.get("reasoning_content") or "", tcs, fr, rmb, bool(leak))
            r._leak = leak
            return r
        except httpx.RequestError as e:
            last = e; time.sleep(backoff); backoff *= 2
    raise RuntimeError(f"max retries exceeded: {last}")
