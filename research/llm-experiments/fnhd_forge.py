"""Function (polling/kind) + Handler (bare-names) forging — surviving-old surfaces.

Function survives revamp + gains kind field. Handler survives unchanged with its
bare-names body contract (method/init args referenced as bare names, not dict access).

Usage: python3 fnhd_forge.py fn V5-combined 20   (function)
       python3 fnhd_forge.py hd V3-contract 20   (handler)
"""

from __future__ import annotations

import sys
from typing import Any

from catalog_v2 import function_tools, tool
from forge_runner import failure_digest, run_forge_cell, save_results

SYS = "You are an AI engineer for Forgify. You forge functions and handlers (sandboxed Python)."

# ---------- Function scenarios ----------
FN_SCENARIOS: list[dict[str, Any]] = [
    {"id": "fn-add", "target_tool": "create_function", "system_prompt": SYS,
     "user_prompt": "造一个加法 function add_two,输入两个数返回和。", "expect": {"kind": "normal"}},
    {"id": "fn-time", "target_tool": "create_function", "system_prompt": SYS,
     "user_prompt": "造一个 function now_utc 返回当前 UTC 时间字符串。", "expect": {"kind": "normal"}},
    {"id": "fn-poll-gmail", "target_tool": "create_function", "system_prompt": SYS,
     "user_prompt": "造一个 polling function 每 60 秒查 Gmail 收件箱有没有新邮件。", "expect": {"kind": "polling", "interval": True}},
    {"id": "fn-poll-cursor", "target_tool": "create_function", "system_prompt": SYS,
     "user_prompt": "造一个 polling function 监听 GitHub issue 评论,30秒一次,要用 cursor 防止重复触发。",
     "expect": {"kind": "polling", "interval": True, "cursor": True}},
    {"id": "fn-trap-webhook", "target_tool": "create_function", "system_prompt": SYS,
     "user_prompt": "造一个 function 处理外部 webhook 进来的 POST,验证签名后落库。", "expect": {"kind": "normal"}},
]


def fn_validate(called, args, scenario):
    if called != "create_function":
        return False, [f"called {called!r} not create_function"]
    if not args:
        return False, ["no args"]
    errors = []
    exp = scenario["expect"]
    kind = args.get("kind")
    if kind != exp["kind"]:
        errors.append(f"kind {kind!r} != {exp['kind']!r}")
    if exp.get("interval") and not args.get("polling_interval"):
        errors.append("polling kind missing polling_interval")
    if exp.get("cursor"):
        code = args.get("code", "") or ""
        if "last_cursor" not in code or "next_cursor" not in code:
            errors.append(f"polling code missing last_cursor/next_cursor pattern")
    return len(errors) == 0, errors


# ---------- Handler scenarios + tool (bare-names contract) ----------
_HD_CONTRACT = """
A handler is a stateful Python class. Forgify uses a BARE-NAMES body contract:
  - __init__ receives init args as BARE parameters (not a dict): def __init__(self, db_url): ...
  - each method receives its args as BARE parameters: def query(self, sql): ...
  - DO NOT access args via dict (no args["sql"] / init_args["db_url"]).
  - init_args_schema declares the init params; methods_schema declares each method's params.
"""


def hd_tool(variant: str) -> list[dict[str, Any]]:
    if variant == "V1-terse":
        desc = "Create a handler (stateful Python class)."
    elif variant == "V3-contract":
        desc = "Create a handler (stateful Python class).\n" + _HD_CONTRACT
    else:  # V5-contract-example
        desc = ("Create a handler (stateful Python class).\n" + _HD_CONTRACT +
                '\nExample:\n  create_handler(name="db", code="class DB:\\n    def __init__(self, db_url):\\n        self.conn = connect(db_url)\\n    def query(self, sql):\\n        return self.conn.run(sql)",\n'
                '    init_args_schema={"db_url":"string"}, methods_schema={"query":{"sql":"string"}})')
    return [tool("create_handler", desc, ["name", "code", "init_args_schema", "methods_schema"],
                 {"name": {"type": "string"}, "code": {"type": "string"},
                  "init_args_schema": {"type": "object"}, "methods_schema": {"type": "object"}})]


HD_SCENARIOS: list[dict[str, Any]] = [
    {"id": "hd-oauth", "target_tool": "create_handler", "system_prompt": SYS,
     "user_prompt": "造一个 handler 缓存 OAuth token,过期自动 refresh。init 收 client_id 和 client_secret。", "expect": {}},
    {"id": "hd-db", "target_tool": "create_handler", "system_prompt": SYS,
     "user_prompt": "造一个 handler hd_db,init 收数据库 url,有个 query 方法收 sql 字符串返回结果。", "expect": {"bare_names": True}},
    {"id": "hd-counter", "target_tool": "create_handler", "system_prompt": SYS,
     "user_prompt": "造一个 handler 计数器,有 incr 方法和 get 方法,状态要在 crash 后能恢复(写到文件)。", "expect": {}},
    {"id": "hd-trap-stateless", "target_tool": "create_handler", "system_prompt": SYS,
     "user_prompt": "造一个把两个数相加的东西。", "expect": {"trap_should_be_function": True}},
]


def hd_validate(called, args, scenario):
    exp = scenario["expect"]
    if exp.get("trap_should_be_function"):
        # stateless add → should be a function, not a handler. If LLM made a handler, soft-flag.
        if called == "create_handler":
            return False, ["made a handler for a stateless add (should be create_function)"]
        return True, []
    if called != "create_handler":
        return False, [f"called {called!r} not create_handler"]
    if not args:
        return False, ["no args"]
    errors = []
    code = args.get("code", "") or ""
    if exp.get("bare_names"):
        if 'args[' in code or 'args.get(' in code or 'init_args[' in code or 'kwargs[' in code:
            errors.append(f"uses dict access for args (violates bare-names contract): {code[:150]!r}")
    if not args.get("init_args_schema") and not args.get("methods_schema"):
        errors.append("missing init_args_schema/methods_schema")
    return len(errors) == 0, errors


def main() -> int:
    which = sys.argv[1] if len(sys.argv) > 1 else "fn"
    variant = sys.argv[2] if len(sys.argv) > 2 else ("V5-combined" if which == "fn" else "V3-contract")
    reps = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    if which == "fn":
        tools, scens, validate = function_tools(variant), FN_SCENARIOS, fn_validate
    else:
        tools, scens, validate = hd_tool(variant), HD_SCENARIOS, hd_validate
    all_results = []
    for scen in scens:
        print(f"\n=== {scen['id']} :: {which}/{variant} ===", flush=True)
        rs = run_forge_cell(scen, variant, tools, validate, reps=reps)
        all_results.extend(rs)
        v = sum(1 for r in rs if r.valid)
        print(f"  {v}/{len(rs)} valid", flush=True)
    save_results(all_results, f"{which}_{variant}")
    print("\n" + "=" * 60)
    print(failure_digest(all_results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
