"""Extract create_handler code from a ds_turn output JSON → write to dest .py.
  python3 g8_extract.py <out.json> <dest.py> → prints JSON {ok|nocall, code_len?, err?}
Uses json.loads(strict=False) then json_repair fallback (G1-aware)."""
from __future__ import annotations
import json, sys
from pathlib import Path


def _parse_args(s):
    if isinstance(s, dict):
        return s
    try:
        return json.loads(s, strict=False)
    except Exception:
        try:
            from json_repair import repair_json
            return json.loads(repair_json(s))
        except Exception:
            return None


def main():
    out = json.loads(Path(sys.argv[1]).read_text())
    tcs = out.get("tool_calls") or out.get("effective_tool_calls") or []
    if not tcs:
        print(json.dumps({"nocall": True, "content": (out.get("content") or "")[:120]}))
        return
    args = _parse_args(tcs[0].get("function", {}).get("arguments"))
    if not args or "code" not in args:
        print(json.dumps({"ok": False, "err": "no code field", "keys": list(args.keys()) if args else None}))
        return
    Path(sys.argv[2]).write_text(args["code"])
    print(json.dumps({"ok": True, "code_len": len(args["code"]), "name": args.get("name")}))


if __name__ == "__main__":
    main()
