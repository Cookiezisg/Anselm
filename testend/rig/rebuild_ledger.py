#!/usr/bin/env python3
"""Create an explicit, provenance-bound ledger baseline from committed coverage state.

This is not a replacement for missing runtime journals.  It is the documented recovery path
when the user elects to accept committed COVERAGE verdicts as historical baseline and continue
the live campaign from the first unsettled row.
"""

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

from scope import explicit_rig_home

ROOT = Path(__file__).resolve().parent
COVERAGE = Path(os.environ.get("RIG_COVERAGE", str(ROOT / "../../docs/working/acceptance-loop/COVERAGE.md")))
SYMBOL_TO_VERDICT = {"✓": "pass", "✗": "fail", "~": "na"}


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT.parent.parent, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def coverage_is_dirty() -> bool:
    try:
        return subprocess.run(
            ["git", "diff", "--quiet", "--", str(COVERAGE)],
            cwd=ROOT.parent.parent,
            check=False,
        ).returncode != 0
    except OSError:
        return True


def parse_cells():
    import re

    row_pattern = re.compile(
        r"^\| ([A-Z]+)-\d+ \| (.+?) \| .*? \| ([·✓✗~]{5}) \| (.*?) \|$"
    )
    records = []
    for line in COVERAGE.read_text().splitlines():
        match = row_pattern.match(line)
        if not match:
            continue
        family, item, status, evidence_field = match.groups()
        for level, symbol in enumerate(status, 1):
            if symbol == "·":
                continue
            pointers = [part for part in evidence_field.split("; ") if part.startswith(f"L{level}:")]
            if not pointers or "→" not in pointers[-1]:
                raise SystemExit(f"rebuild-ledger: missing L{level} evidence pointer for {family}|{item}")
            law, evidence = pointers[-1][len(f"L{level}:"):].split("→", 1)
            records.append(
                {
                    "ts": "",
                    "family": family,
                    "item": item,
                    "level": level,
                    "verdict": SYMBOL_TO_VERDICT[symbol],
                    "law": law if law != "na" else "",
                    "evidence": evidence,
                    "source": "coverage-baseline",
                }
            )
    return records


def atomic_write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as stream:
        stream.write(content)
        temp_path = Path(stream.name)
    os.replace(temp_path, path)


def main():
    parser = argparse.ArgumentParser(description="Rebuild an explicit ledger baseline from COVERAGE.md")
    parser.add_argument("--write", action="store_true", help="write the baseline and journal")
    parser.add_argument("--repair-manifest", action="store_true",
                        help="add baseline cell keys to an existing baseline manifest")
    parser.add_argument("--acknowledge-history", action="store_true",
                        help="confirm that committed COVERAGE is the accepted historical baseline")
    args = parser.parse_args()
    if not args.write:
        parser.error("--write is required to create a baseline")
    if not args.acknowledge_history:
        parser.error("--acknowledge-history is required; this action is an explicit history decision")

    rig_home = explicit_rig_home("rebuild-ledger")
    journal = rig_home / "judgments.jsonl"
    manifest_path = rig_home / "ledger-baseline.json"
    if args.repair_manifest:
        if not journal.exists() or not manifest_path.exists():
            raise SystemExit("rebuild-ledger: REFUSED — existing baseline journal and manifest are required")
        baseline_records = [
            json.loads(line)
            for line in journal.read_text().splitlines()
            if line.strip() and json.loads(line).get("source") == "coverage-baseline"
        ]
        manifest = json.loads(manifest_path.read_text())
        manifest["baselineCells"] = sorted(
            {f"{row['family']}|{row['item']}|{int(row['level'])}" for row in baseline_records}
        )
        manifest["carriedCells"] = len(manifest["baselineCells"])
        atomic_write(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        print(f"rebuild-ledger: repaired manifest with {len(manifest['baselineCells'])} baseline cell keys")
        return
    if journal.exists() and journal.stat().st_size:
        raise SystemExit(f"rebuild-ledger: REFUSED — existing journal is non-empty: {journal}")
    records = parse_cells()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    for record in records:
        record["ts"] = now
    coverage_hash = hashlib.sha256(COVERAGE.read_bytes()).hexdigest()
    manifest = {
        "schemaVersion": 1,
        "source": "coverage-baseline",
        "createdAt": now,
        "coverage": str(COVERAGE.resolve()),
        "coverageSha256": coverage_hash,
        "gitHead": git_head(),
        "coverageWorkingTreeDirty": coverage_is_dirty(),
        "carriedCells": len(records),
        "baselineCells": sorted({f"{row['family']}|{row['item']}|{row['level']}" for row in records}),
        "decision": "user accepted committed COVERAGE as historical baseline; continue live validation",
    }
    atomic_write(journal, "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records))
    atomic_write(rig_home / "ledger-baseline.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"rebuild-ledger: wrote {len(records)} baseline judgments")
    print(f"rebuild-ledger: manifest={rig_home / 'ledger-baseline.json'}")
    print(f"rebuild-ledger: coverageSha256={coverage_hash}")


if __name__ == "__main__":
    main()
