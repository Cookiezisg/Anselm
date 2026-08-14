#!/usr/bin/env python3
"""Generate and grade the frozen acceptance calibration set.

`quiz` deliberately strips expected verdicts. `check` writes a short-lived status bound to the
exact anchor-set bytes; judge.py refuses new passes when that status is absent, stale, or belongs
to an older set. This is a procedural guard, not secrecy: an operator can inspect the source, but
cannot accidentally skip calibration or carry yesterday's calibration into a changed codebook.
"""

import argparse
import datetime
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Optional

from scope import explicit_rig_home

ROOT = Path(__file__).resolve().parent
ANCHORS = ROOT / "anchors.json"
RIG_HOME: Optional[Path] = None
QUIZ: Optional[Path] = None
STATUS: Optional[Path] = None


def anchor_hash() -> str:
    return hashlib.sha256(ANCHORS.read_bytes()).hexdigest()


def load(path: Path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise SystemExit(f"anchors: cannot read {path}: {exc}") from exc


def configured_paths():
    if RIG_HOME is None or QUIZ is None or STATUS is None:
        raise SystemExit("anchors: REFUSED — RIG_HOME is not configured; refusing direct authority access")
    return RIG_HOME, QUIZ, STATUS


def quiz() -> None:
    rig_home, quiz_path, status_path = configured_paths()
    rig_home.mkdir(parents=True, exist_ok=True)
    rows = load(ANCHORS)
    payload = {
        "anchorSetSha256": anchor_hash(),
        "instructions": "逐题填写 verdict(pass/fail)、law 与 reason；不得跳题。",
        "answers": [
            {"id": row["id"], "case": row["case"], "question": row["question"],
             "verdict": "", "law": "", "reason": ""}
            for row in rows
        ],
    }
    quiz_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    status_path.unlink(missing_ok=True)
    print(f"anchors: blind quiz written to {quiz_path}")


def check(answers_path: Path) -> None:
    rig_home, _, status_path = configured_paths()
    expected = {row["id"]: row for row in load(ANCHORS)}
    submitted = load(answers_path)
    if submitted.get("anchorSetSha256") != anchor_hash():
        raise SystemExit("anchors: answer sheet belongs to a different anchor set; run quiz again")
    answers = submitted.get("answers")
    if not isinstance(answers, list):
        raise SystemExit("anchors: answer sheet has no answers array")
    by_id = {row.get("id"): row for row in answers if isinstance(row, dict)}
    if set(by_id) != set(expected):
        missing = sorted(set(expected) - set(by_id))
        unknown = sorted(set(by_id) - set(expected))
        raise SystemExit(f"anchors: incomplete answer set; missing={missing}, unknown={unknown}")

    wrong = []
    for aid, want in expected.items():
        got = by_id[aid]
        if got.get("verdict") != want["verdict"] or got.get("law") != want["law"]:
            wrong.append(aid)
        if not str(got.get("reason", "")).strip():
            wrong.append(f"{aid}:reason")
    if wrong:
        status_path.unlink(missing_ok=True)
        raise SystemExit(f"anchors: calibration FAILED at {sorted(set(wrong))}; re-read CODEX and re-audit")

    rig_home.mkdir(parents=True, exist_ok=True)
    status_path.write_text(json.dumps({
        "anchorSetSha256": anchor_hash(),
        "checkedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "answers": str(answers_path.resolve()),
        "count": len(expected),
    }, ensure_ascii=False, indent=2) + "\n")
    print(f"anchors: calibration passed ({len(expected)} anchors); judge unlocked for 4h")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("quiz")
    checker = sub.add_parser("check")
    checker.add_argument("answers", type=Path)
    args = parser.parse_args()
    global RIG_HOME, QUIZ, STATUS
    RIG_HOME = explicit_rig_home("anchors")
    QUIZ = RIG_HOME / "anchor-quiz.json"
    STATUS = RIG_HOME / "anchor-check.json"
    if args.command == "quiz":
        quiz()
    else:
        check(args.answers)


if __name__ == "__main__":
    main()
