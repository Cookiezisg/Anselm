#!/usr/bin/env python3
# check_journeys.py — makes "100% product coverage" a checkable claim instead of an adjective
# (WRK-087 P12): every coverage row must be claimed by at least one journey's 扫 field, or be
# explicitly designated 幕后 (rig-direct, with a reason). Anything else is an uncovered row and
# this script names it. Unknown claims (names matching no extract row) are reported too — a
# typo'd claim silently covers nothing.
#
# check_journeys.py — 把「产品 100% 覆盖」从形容词变成可核验命题(WRK-087 P12):清册每一行
# 必须被至少一条旅程的「扫」字段认领,或被显式列为「幕后」(台架直测,带理由)。其余=未覆盖行,
# 本脚本逐行点名。无效认领(对不上任何清册行的名字)同样报出——写错字的认领什么都没盖住。
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
JOURNEYS = ROOT / "../../docs/working/acceptance-loop/JOURNEYS.md"
COVERAGE_DIR = ROOT / "extracts"

FILES = [("TOOL", "tools.md"), ("EP", "endpoints.md"), ("SURF", "surfaces.md"), ("EDGE", "edges.md")]


def extract_rows():
    rows = {}
    for prefix, fname in FILES:
        for line in (COVERAGE_DIR / fname).read_text().splitlines():
            if line.startswith(prefix + " |"):
                name = line.split("|")[1].strip()
                rows[name] = prefix
    return rows


def main():
    rows = extract_rows()
    text = JOURNEYS.read_text()

    claimed = {}
    for m in re.finditer(r"扫[::]\s*(.+?)\s*\|\s*$", text, re.M):
        for name in re.split(r"[,、,]\s*", m.group(1)):
            name = name.strip().strip("`")
            if name:
                claimed.setdefault(name, 0)
                claimed[name] += 1

    backstage = {}
    for m in re.finditer(r"^幕后\s*\|\s*(.+?)\s*\|\s*(.+?)\s*$", text, re.M):
        backstage[m.group(1).strip().strip("`")] = m.group(2).strip()

    journeys = len(re.findall(r"^\| J-[A-Z]+\d+ \|", text, re.M))

    unclaimed = [(p, n) for n, p in rows.items() if n not in claimed and n not in backstage]
    unknown = [n for n in claimed if n not in rows]
    unknown_backstage = [n for n in backstage if n not in rows]
    covered = len(rows) - len(unclaimed)

    print(f"journeys: {journeys}")
    print(f"coverage rows: {len(rows)}  claimed: {len([n for n in rows if n in claimed])}  "
          f"backstage: {len([n for n in rows if n in backstage])}  UNCLAIMED: {len(unclaimed)}")
    print(f"coverage: {covered}/{len(rows)} = {covered / len(rows):.1%}")
    if unknown:
        print(f"\nUNKNOWN CLAIMS ({len(unknown)}) — 认领了不存在的行(错字?盖不住任何东西):")
        for n in sorted(unknown)[:40]:
            print(f"  ? {n}")
        if len(unknown) > 40:
            print(f"  … +{len(unknown) - 40}")
    if unknown_backstage:
        print(f"\nUNKNOWN BACKSTAGE ({len(unknown_backstage)}):")
        for n in sorted(unknown_backstage):
            print(f"  ? {n}")
    if unclaimed:
        print(f"\nUNCLAIMED ROWS ({len(unclaimed)}) — 无旅程认领且未列幕后:")
        for p, n in sorted(unclaimed)[:60]:
            print(f"  - [{p}] {n}")
        if len(unclaimed) > 60:
            print(f"  … +{len(unclaimed) - 60}")
    sys.exit(1 if (unclaimed or unknown or unknown_backstage) else 0)


if __name__ == "__main__":
    main()
