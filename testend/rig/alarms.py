#!/usr/bin/env python3
# alarms.py — the drift-detection curves (WRK-087 §4.5). Reads the judgments journal and opens
# alarms that the ledger gate (judge.py) then enforces: while any alarm is open, no new pass can
# be written. Three curves, all chosen because a quality slide shows up in them before it shows
# up anywhere else: pass-rate bursts (rubber-stamping), discovery-rate collapse (a judge that
# stops finding anything on a product this complex has usually stopped looking), and
# inter-judgment gaps too short to have actually watched the footage.
#
# alarms.py — 漂移检测三曲线(WRK-087 §4.5)。读裁决 journal、开警报单,账本 gate(judge.py)
# 强制执行:警报未销期间写不进任何新 pass。三条曲线的选取标准是「水平下滑先在这里现形」:
# 通过率暴冲(橡皮章)、发现率塌方(对这个复杂度的产品,什么都发现不了的裁判通常是不看了)、
# 裁决间隔短到不可能真看过录屏。
#
# usage: alarms.py check          — compute curves, open alarms, exit 1 if any open
#        alarms.py ack <id> --note <why resolved / re-audit result>
import argparse
import datetime
import json
import os
import statistics
import sys
from pathlib import Path
from typing import Optional

from scope import explicit_rig_home

RIG_HOME: Optional[Path] = None
JOURNAL: Optional[Path] = None
ALARMS: Optional[Path] = None

# Thresholds are opening positions, tightened by 立法协议 as real data accrues — recorded here,
# not scattered. 阈值是开局值,随真实数据按立法协议收紧——集中在此,不散置。
WINDOW = 50               # trailing judgments considered 近尾窗口
MIN_GAP_MEDIAN_S = 25     # median inter-judgment gap floor 裁决间隔中位数下限
BURST_RATIO = 3.0         # recent rate vs trailing rate 通过率暴冲倍数
DISCOVERY_FLOOR = 0.05    # fail share floor once ≥WINDOW judgments exist 发现率地板


def configured_path(value: Optional[Path], label: str) -> Path:
    if value is None:
        raise SystemExit(f"alarms: REFUSED — RIG_HOME is not configured; refusing direct {label} access")
    return value


def load_journal():
    journal = configured_path(JOURNAL, "judgment ledger")
    if not journal.exists():
        return []
    rows = []
    for line in journal.read_text().splitlines():
        try:
            rows.append(json.loads(line))
        except Exception:
            continue
    return rows


def load_alarms():
    alarms_path = configured_path(ALARMS, "alarm ledger")
    if alarms_path.exists():
        try:
            return json.loads(alarms_path.read_text())
        except Exception:
            pass
    return []


def save_alarms(alarms):
    rig_home = configured_path(RIG_HOME, "alarm ledger")
    alarms_path = configured_path(ALARMS, "alarm ledger")
    rig_home.mkdir(exist_ok=True)
    alarms_path.write_text(json.dumps(alarms, ensure_ascii=False, indent=1))


def open_alarm(alarms, aid, note, through):
    for a in alarms:
        if a["id"] == aid and not a.get("acked"):
            return  # already open — no duplicate spam 已开着,不重复刷
        if a["id"] == aid and a.get("acked") and a.get("evidenceThrough") == through:
            return  # an acked audit stays resolved until NEW evidence exists 销账在出现新证据前不原地复活
    alarms.append({"id": aid, "note": note, "evidenceThrough": through,
                   "openedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    print(f"alarms: OPEN {aid} — {note}")


def check():
    all_rows = load_journal()
    rows = [row for row in all_rows if row.get("source") != "coverage-baseline"]
    alarms = load_alarms()
    recent = rows[-WINDOW:]
    through = rows[-1].get("ts", f"row:{len(rows)}") if rows else "empty"
    if len(recent) >= 10:
        ts = [datetime.datetime.fromisoformat(r["ts"]) for r in recent]
        gaps = [(b - a).total_seconds() for a, b in zip(ts, ts[1:])]
        med = statistics.median(gaps)
        if med < MIN_GAP_MEDIAN_S:
            open_alarm(alarms, "gap-too-fast",
                       f"近 {len(recent)} 裁决间隔中位数 {med:.0f}s < {MIN_GAP_MEDIAN_S}s — 快得不像真看过证据;该时段裁决入重审队列", through)
        # Burst: last 10 span vs trailing median-per-10 span. 暴冲:末 10 条时距 vs 尾窗每 10 条时距。
        if len(recent) >= 30:
            last10 = (ts[-1] - ts[-10]).total_seconds()
            spans = [(ts[i + 9] - ts[i]).total_seconds() for i in range(0, len(ts) - 9, 10)]
            base = statistics.median(spans[:-1]) if len(spans) > 1 else None
            if base and last10 > 0 and base / last10 >= BURST_RATIO:
                open_alarm(alarms, "pass-burst",
                           f"末 10 条裁决用时 {last10:.0f}s,尾窗基线 {base:.0f}s/10条 — 通过速率暴冲(橡皮章信号)", through)
    if len(rows) >= WINDOW:
        fails = sum(1 for r in recent if r["verdict"] == "fail")
        share = fails / len(recent)
        if share < DISCOVERY_FLOOR:
            open_alarm(alarms, "discovery-collapse",
                       f"近 {len(recent)} 裁决 fail 占比 {share:.1%} < {DISCOVERY_FLOOR:.0%} — 更可能是判断失灵而非产品变干净;按锚点自校后再继续", through)
    save_alarms(alarms)
    live = [a for a in alarms if not a.get("acked")]
    for a in live:
        print(f"alarms: open — {a['id']}: {a['note']}")
    if live:
        sys.exit(1)
    baseline_count = len(all_rows) - len(rows)
    print(f"alarms: clean ({len(rows)} live judgments; {baseline_count} baseline judgments excluded from drift curves)")


def ack(aid, note):
    alarms = load_alarms()
    hit = False
    for a in alarms:
        if a["id"] == aid and not a.get("acked"):
            a["acked"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            a["resolution"] = note
            hit = True
    if not hit:
        print(f"alarms: no open alarm {aid!r}", file=sys.stderr)
        sys.exit(1)
    save_alarms(alarms)
    print(f"alarms: acked {aid}")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check")
    a = sub.add_parser("ack")
    a.add_argument("id")
    a.add_argument("--note", required=True, help="how it was resolved (re-audit result) — 怎么销的账")
    args = ap.parse_args()
    global RIG_HOME, JOURNAL, ALARMS
    RIG_HOME = explicit_rig_home("alarms")
    JOURNAL = RIG_HOME / "judgments.jsonl"
    ALARMS = RIG_HOME / "alarms.json"
    if args.cmd == "check":
        check()
    else:
        ack(args.id, args.note)


if __name__ == "__main__":
    main()
