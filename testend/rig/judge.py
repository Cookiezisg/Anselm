#!/usr/bin/env python3
# judge.py — the ledger gate (WRK-087 §4.3): marking a coverage cell is a SCRIPT ACTION with
# validated preconditions, never a text edit. A pass physically cannot be written without a law
# citation that exists in CODEX.md and an evidence pointer that exists on disk (or an explicit
# non-file pointer) — and while any alarm is open (alarms.json), new passes are refused outright.
# Every judgment appends to the judgments journal, which is what the alarm curves are computed
# from; the journal is therefore append-only and timestamped by this script, not by hand.
#
# judge.py — 账本 gate(WRK-087 §4.3):给清册格子落裁决是**带前置校验的脚本动作**,绝不是文本
# 编辑。没有「存在于 CODEX.md 的法条引用 + 盘上真实存在的证据指针」,一个 pass 物理上写不进去;
# 警报单未销(alarms.json)期间,新 pass 一律拒收。每次裁决追加进裁决 journal——警报三曲线的
# 数据源,故它只追加、时戳由本脚本盖,不经手写。
import argparse
import datetime
import json
import re
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COVERAGE = ROOT / "../../docs/working/acceptance-loop/COVERAGE.md"
CODEX = ROOT / "../../docs/working/acceptance-loop/CODEX.md"
RIG_HOME = Path(os.environ.get("RIG_HOME", str(Path.home() / ".anselm-rig")))
JOURNAL = RIG_HOME / "judgments.jsonl"
ALARMS = RIG_HOME / "alarms.json"

SYM = {"pass": "✓", "fail": "✗", "na": "~"}


def fail(msg: str):
    print(f"judge: REFUSED — {msg}", file=sys.stderr)
    sys.exit(1)


def open_alarms():
    if not ALARMS.exists():
        return []
    try:
        return [a for a in json.loads(ALARMS.read_text()) if not a.get("acked")]
    except Exception:
        return [{"id": "alarms-unreadable", "note": "alarms.json corrupt — treat as open"}]


def law_exists(law: str) -> bool:
    # Accepts a CODEX law id ("C1", "F4"), a measurement ("measure:…"), or a new-law marker
    # ("new:<id>") — the last one requires the law to ALREADY be written into CODEX.md first
    # (立法协议: 先立法、再判), so it is checked the same way.
    # 接受 CODEX 法条 id("C1"/"F4")、测量值("measure:…")或新法标记("new:<id>")——最后一种
    # 要求法条**已经**写进 CODEX.md(立法协议:先立法、再判),故同样查验。
    if law.startswith("measure:"):
        return len(law) > len("measure:")
    law_id = law.removeprefix("new:")
    if not re.fullmatch(r"[A-H]\d+", law_id):
        return False
    return bool(re.search(rf"^\| {law_id} \|", CODEX.read_text(), re.M))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("item", help="coverage item name (row key, e.g. 'Read' or '生图迭代到满意')")
    ap.add_argument("--family", required=True, choices=["TOOL", "EP", "SURF", "EDGE"])
    ap.add_argument("--level", required=True, type=int, choices=[1, 2, 3, 4, 5])
    ap.add_argument("--verdict", required=True, choices=["pass", "fail", "na"])
    ap.add_argument("--law", default="", help="CODEX law id / 'measure:<...>' (required for pass/fail)")
    ap.add_argument("--evidence", required=True, help="file path under evidence dir, or 'note:<text>' for na")
    ap.add_argument("--session", default="", help="rig session dir (required for level-2 verdicts)")
    args = ap.parse_args()

    if args.verdict == "pass" and (alarms := open_alarms()):
        fail(f"{len(alarms)} open alarm(s) — resolve/ack them before any new pass: {[a['id'] for a in alarms]}")

    if args.verdict in ("pass", "fail"):
        if not args.law or not law_exists(args.law):
            fail(f"law citation {args.law!r} not found in CODEX.md (先立法、再判)")
        if args.evidence.startswith("note:"):
            fail("pass/fail requires real evidence (a file), not a note")
        ev = Path(args.evidence)
        if not ev.exists() or ev.stat().st_size == 0:
            fail(f"evidence {ev} missing or empty")
    else:  # na requires a written justification — 不适用必须说出为何
        if not args.evidence.startswith("note:") or len(args.evidence) <= len("note:"):
            fail("na requires --evidence 'note:<why this level does not apply>'")

    if args.level == 2 and args.verdict == "pass":
        if not args.session:
            fail("level-2 (数据真相) pass requires --session <rig session dir>")
        s = Path(args.session)
        for j in ("manifest.json", "backend.log", "sse.jsonl"):
            if not (s / j).exists():
                fail(f"session journal {j} missing — five-channel evidence incomplete")

    text = COVERAGE.read_text()
    pat = re.compile(rf"^(\| {args.family}-\d+ \| {re.escape(args.item)} \| .*\| )([·✓✗~]{{5}})( \| )(.*?)( \|)$", re.M)
    m = pat.search(text)
    if not m:
        fail(f"row not found: {args.family} | {args.item}")
    cells = list(m.group(2))
    cells[args.level - 1] = SYM[args.verdict]
    ev_field = m.group(4)
    pointer = f"L{args.level}:{args.law or 'na'}→{args.evidence}"
    ev_field = f"{ev_field}; {pointer}" if ev_field.strip() else pointer
    text = text[: m.start()] + m.group(1) + "".join(cells) + m.group(3) + ev_field + m.group(5) + text[m.end():]
    COVERAGE.write_text(text)

    RIG_HOME.mkdir(exist_ok=True)
    with JOURNAL.open("a") as f:
        f.write(json.dumps({
            "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "family": args.family, "item": args.item, "level": args.level,
            "verdict": args.verdict, "law": args.law, "evidence": args.evidence,
        }, ensure_ascii=False) + "\n")
    print(f"judge: {args.family}|{args.item} L{args.level} ← {SYM[args.verdict]} ({args.law or 'na'})")


if __name__ == "__main__":
    main()
