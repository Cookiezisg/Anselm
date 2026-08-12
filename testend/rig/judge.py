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
from contextlib import contextmanager
import datetime
import hashlib
import json
import re
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COVERAGE = Path(os.environ.get("RIG_COVERAGE", str(ROOT / "../../docs/working/acceptance-loop/COVERAGE.md")))
CODEX = Path(os.environ.get("RIG_CODEX", str(ROOT / "../../docs/working/acceptance-loop/CODEX.md")))
RIG_HOME = Path(os.environ.get("RIG_HOME", str(Path.home() / ".anselm-rig")))
JOURNAL = RIG_HOME / "judgments.jsonl"
ALARMS = RIG_HOME / "alarms.json"
ANCHORS = ROOT / "anchors.json"
ANCHOR_STATUS = Path(os.environ.get("RIG_ANCHOR_STATUS", str(RIG_HOME / "anchor-check.json")))
ANCHOR_MAX_AGE = datetime.timedelta(hours=4)

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


def calibration_problem():
    try:
        status = json.loads(ANCHOR_STATUS.read_text())
        checked = datetime.datetime.fromisoformat(status["checkedAt"])
        if checked.tzinfo is None:
            checked = checked.replace(tzinfo=datetime.timezone.utc)
        if datetime.datetime.now(datetime.timezone.utc) - checked > ANCHOR_MAX_AGE:
            return "anchor calibration is older than 4h"
        digest = hashlib.sha256(ANCHORS.read_bytes()).hexdigest()
        if status.get("anchorSetSha256") != digest:
            return "anchor set changed after calibration"
    except (OSError, ValueError, KeyError, TypeError):
        return "anchor calibration missing or unreadable"
    return ""


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


def judgment_already_recorded(family: str, item: str, level: int, verdict: str, law: str, evidence: str) -> bool:
    """Make a retried command a no-op instead of inflating the ledger or alarm curves."""
    if not JOURNAL.exists():
        return False
    try:
        rows = (json.loads(line) for line in JOURNAL.read_text().splitlines() if line.strip())
        return any(
            row.get("family") == family
            and row.get("item") == item
            and row.get("level") == level
            and row.get("verdict") == verdict
            and row.get("law") == law
            and row.get("evidence") == evidence
            for row in rows
        )
    except (OSError, ValueError):
        fail("judgments.jsonl is unreadable")
    return False


@contextmanager
def ledger_lock():
    """Serialize coverage repair and journal append across concurrent judge processes."""
    RIG_HOME.mkdir(parents=True, exist_ok=True)
    lock_path = RIG_HOME / "judge.lock"
    try:
        import fcntl
    except ImportError as exc:  # pragma: no cover - the rig runs on Unix hosts.
        fail(f"judge lock requires Unix fcntl: {exc}")
    with lock_path.open("w") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def apply_coverage_cell(family: str, item: str, level: int, verdict: str, law: str, evidence: str) -> None:
    """Apply one judgment to COVERAGE, including replay repair after a partial write."""
    text = COVERAGE.read_text()
    pat = re.compile(
        rf"^(\| {family}-\d+ \| {re.escape(item)} \| .*\| )([·✓✗~]{{5}})( \| )(.*?)( \|)$",
        re.M,
    )
    match = pat.search(text)
    if not match:
        fail(f"row not found: {family} | {item}")
    cells = list(match.group(2))
    cells[level - 1] = SYM[verdict]
    pointer = f"L{level}:{law or 'na'}→{evidence}"
    evidence_field = match.group(4)
    if pointer not in evidence_field.split("; "):
        evidence_field = f"{evidence_field}; {pointer}" if evidence_field.strip() else pointer
    updated = text[: match.start()]
    updated += match.group(1) + "".join(cells) + match.group(3) + evidence_field + match.group(5)
    updated += text[match.end() :]
    COVERAGE.write_text(updated)


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
        required = ("manifest.json", "backend.log", "sse.jsonl", "frontend.log", "llm.jsonl", "screen.mov")
        for j in required:
            p = s / j
            if not p.exists() or p.stat().st_size == 0:
                fail(f"session journal {j} missing or empty — five-channel evidence incomplete")
        try:
            subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(s / "screen.mov")],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
        except (OSError, subprocess.CalledProcessError):
            fail("screen.mov is not a finalized readable recording")
        try:
            sse = [json.loads(line) for line in (s / "sse.jsonl").read_text().splitlines()]
        except (OSError, ValueError):
            fail("sse.jsonl is unreadable")
        connected = {row.get("stream") for row in sse if row.get("tap") == "connect"}
        missing = {"messages", "entities", "notifications"} - connected
        if missing:
            fail(f"SSE witness never connected streams: {sorted(missing)}")

    with ledger_lock():
        already_recorded = judgment_already_recorded(
            args.family, args.item, args.level, args.verdict, args.law, args.evidence
        )
        if already_recorded:
            # A process can die after the journal append but before the coverage write. Replay the
            # cell and pointer under the same lock instead of trusting the journal alone.
            apply_coverage_cell(args.family, args.item, args.level, args.verdict, args.law, args.evidence)
            print(f"judge: {args.family}|{args.item} L{args.level} already recorded; coverage repaired/no-op")
            return

        if args.verdict == "pass":
            if problem := calibration_problem():
                fail(f"{problem} — run anchors.py quiz, answer it, then anchors.py check")
            if alarms := open_alarms():
                fail(f"{len(alarms)} open alarm(s) — resolve/ack them before any new pass: {[a['id'] for a in alarms]}")

        apply_coverage_cell(args.family, args.item, args.level, args.verdict, args.law, args.evidence)
        with JOURNAL.open("a") as f:
            f.write(json.dumps({
                "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "family": args.family, "item": args.item, "level": args.level,
                "verdict": args.verdict, "law": args.law, "evidence": args.evidence,
            }, ensure_ascii=False) + "\n")
        print(f"judge: {args.family}|{args.item} L{args.level} ← {SYM[args.verdict]} ({args.law or 'na'})")


if __name__ == "__main__":
    main()
