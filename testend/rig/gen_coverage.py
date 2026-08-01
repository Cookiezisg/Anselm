#!/usr/bin/env python3
# gen_coverage.py — regenerate the acceptance coverage ledger (WRK-087 COVERAGE.md) from the
# four raw extracts in testend/rig/extracts/. MERGE-AWARE by design: rows are keyed by their
# item name, and existing verdict/evidence columns are carried over verbatim — regeneration
# after a re-extraction (e.g. post-merge refresh) adds new rows as unjudged and moves vanished
# rows to a tombstone section instead of silently deleting judged history.
#
# gen_coverage.py — 从 testend/rig/extracts/ 四份原始提取物重生成验收清册账本(WRK-087
# COVERAGE.md)。**刻意 merge-aware**:行以「项名」为键,既有裁决/证据列逐字携带——重提取后
# 重生成(如合并他队改动后的刷新)只把新行加为未判、消失行移进墓碑段,绝不静默删除已判历史。
import re
import sys
from pathlib import Path

RIG = Path(__file__).parent / "extracts"
OUT = Path(__file__).parent / "../../docs/working/acceptance-loop/COVERAGE.md"

SECTIONS = [
    ("TOOL", "工具全集", "tools.md", "TOOL"),
    ("EP", "API 端点全集", "endpoints.md", "EP"),
    ("SURF", "前端面全集", "surfaces.md", "SURF"),
    ("EDGE", "难触发/边界路径全集", "edges.md", "EDGE"),
]

FRONT = """---
id: WRK-089
type: working
status: active
owner: "@weilin"
created: 2026-07-28
reviewed: 2026-07-28
review-due: 2026-10-26
audience: [human, ai]
landed-into:
---

# WRK-089 · 验收清册(COVERAGE)——面矩阵账本

> **本文件由 `testend/rig/gen_coverage.py` 生成/刷新,手改只动「五级」「证据」两列**(其余列
> 重生成时以原始提取物为准)。行键=项名;重提取后重生成:已判列逐字携带、新行未判、消失行进墓碑。
> 原始提取物(含完整配方与语义)在 `testend/rig/extracts/*.md`,判前先查原文。
>
> **五级列**(WRK-087 §0 判据金字塔,每格一符):①办成 ②真(五通道互证) ③顺(丝滑) ④美(craft)
> ⑤可发现。符号:`·`=未判 `✓`=过 `✗`=开缺陷(修复中,格上留 ✗ 直到真机复验) `~`=不适用
> (须在证据列注明为何)。**一行全列非 `·`/`✗` 才算这行完**;裁决必须援引 CODEX 法条或测量值,
> 证据列写指针。
"""


def parse_extract(path: Path, prefix: str):
    rows = []
    for line in path.read_text().splitlines():
        if not line.startswith(prefix + " |"):
            continue
        parts = [p.strip() for p in line.split("|")]
        # parts[0] is the prefix tag; keep the rest as name + summary fields.
        # parts[0] 是前缀标签;其余为项名 + 摘要字段。
        name = parts[1]
        summary = " · ".join(parts[2:])
        rows.append((name, summary))
    return rows


def parse_existing(path: Path):
    state = {}
    if not path.exists():
        return state
    for line in path.read_text().splitlines():
        m = re.match(r"^\| ([A-Z]+)-\d+ \| (.+?) \| .*\| ([·✓✗~]{5}) \| (.*?) \|$", line)
        if m:
            state[(m.group(1), m.group(2))] = (m.group(3), m.group(4))
    return state


def esc(s: str) -> str:
    return s.replace("|", "\\|")


def main():
    existing = parse_existing(OUT)
    seen = set()
    out = [FRONT]
    grand = 0
    for tag, title, fname, prefix in SECTIONS:
        rows = parse_extract(RIG / fname, prefix)
        if not rows:
            print(f"gen_coverage: no rows for {fname}", file=sys.stderr)
            sys.exit(1)
        grand += len(rows)
        out.append(f"\n## {title}({len(rows)})\n")
        out.append("| ID | 项 | 摘要 | 五级 | 证据 |")
        out.append("|---|---|---|---|---|")
        for i, (name, summary) in enumerate(rows, 1):
            seen.add((tag, name))
            status, ev = existing.get((tag, name), ("·····", ""))
            short = summary if len(summary) <= 90 else summary[:87] + "…"
            out.append(f"| {tag}-{i:03d} | {esc(name)} | {esc(short)} | {status} | {ev} |")
    # Tombstones: judged rows whose item vanished from the extracts — history, not silence.
    # 墓碑:项已从提取物消失但曾有裁决的行——留历史,不留沉默。
    dead = [(k, v) for k, v in existing.items() if k not in seen and v[0] != "·····"]
    if dead:
        out.append("\n## 墓碑(项已消失,裁决留档)\n")
        out.append("| 族 | 项 | 末态 | 证据 |")
        out.append("|---|---|---|---|")
        for (tag, name), (status, ev) in sorted(dead):
            out.append(f"| {tag} | {esc(name)} | {status} | {ev} |")
    out.append(f"\n**TOTAL: {grand} 行 × 5 级 = {grand * 5} 格**")
    OUT.write_text("\n".join(out) + "\n")
    judged = sum(1 for v in existing.values() if v[0] != "·····")
    print(f"gen_coverage: {grand} rows ({judged} carried judgments, {len(dead)} tombstones) → {OUT}")


if __name__ == "__main__":
    main()
