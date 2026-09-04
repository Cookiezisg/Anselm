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
from typing import Optional

from scope import explicit_rig_home

ROOT = Path(__file__).resolve().parent
DEFAULT_COVERAGE = (ROOT / "../../docs/working/acceptance-loop/COVERAGE.md").resolve()
COVERAGE = Path(os.environ.get("RIG_COVERAGE", str(DEFAULT_COVERAGE)))
CODEX = Path(os.environ.get("RIG_CODEX", str(ROOT / "../../docs/working/acceptance-loop/CODEX.md")))
RIG_HOME: Optional[Path] = None
JOURNAL: Optional[Path] = None
ALARMS: Optional[Path] = None
ANCHORS = ROOT / "anchors.json"
ANCHOR_STATUS: Optional[Path] = None
ANCHOR_MAX_AGE = datetime.timedelta(hours=4)
# The formal frontier is repository policy, not a caller-controlled fixture.  Tests can still
# replace COVERAGE/CODEX, but no environment variable may replace the ordering constitution.
SEQUENCE = ROOT / "ledger-sequence.json"

SYM = {"pass": "✓", "fail": "✗", "na": "~"}

# A tilde is settled only when its note proves that the level does not apply. Notes that merely
# confess missing App/session/visual evidence are provisional work, not a waiver.
PROVISIONAL_NA_MARKERS = (
    "未启动真实",
    "未在独立正式",
    "未建立新的真实",
    "未重新建立真实",
    "未重新走真实",
    "未启动真实桌面",
    "本轮未执行真实",
    # "仅有/只有 focused 回归" admits that the requested product evidence was not run.
    # It is not an applicability decision, even when the note also mentions a backend test.
    "本轮仅有",
    "本轮只有",
    "本格仅有",
    "本格只有",
    "本格当前仅完成",
    "本格本批仅完成",
    # Batch notes that explicitly confess missing real-App evidence are provisional. Keep this
    # more specific than the shorter "本格没有独立" phrase, which may appear in a valid
    # applicability explanation after a semicolon.
    "本格本批没有独立",
    "本格本轮仅完成",
    "没有独立真实 app",
    "没有独立 formal rig",
    "没有本格独立真实",
    "没有本格独立",
    "本格没有独立真实",
    "不能冒充视觉成品",
    "没有真实 app",
    "no real app",
    "no real five-channel",
    "未完成独立",
    "未判顺滑",
    "未建立独立",
    "未做该场景",
    "未完成从零",
    "没有本次注入",
    "没有真实 app 录屏",
    "未完成独立视觉",
    "未完成独立可发现性",
    "未完成新用户可发现性",
    "未完成独立美学",
    "未冒充完整顺滑",
)


def na_note_for_level(evidence: str, level: int) -> str:
    """Extract the latest level-specific NA note without treating prose semicolons as boundaries.

    Revalidation appends a new pointer to preserve the audit trail. The latest pointer is the
    authoritative state; reading the first one would make a provisional NA permanently reopen the
    frontier even after a valid applicability decision.
    """
    # A provisional note can follow a measurement pointer as well as an explicit `na` pointer.
    # Both forms mean the cell is still `~` in COVERAGE; only the pointer prefix differs.  Ignoring
    # `measure:*→note:` lets a local-only run masquerade as a settled applicability decision.
    # provisional note 既可能跟在 `na` 指针后,也可能跟在 measurement 指针后;两者在清册里都仍是 `~`。
    # 只认 `na` 会让「本轮只有本地测试」伪装成已完成的适用性裁决。
    matches = list(re.finditer(rf"(?:^|; )L{level}:[^;→]*→note:(.*?)(?=; L\d+:|$)", evidence, re.IGNORECASE))
    return matches[-1].group(1).strip() if matches else ""


def is_provisional_na(evidence: str, level: int) -> bool:
    """Return whether a recorded tilde is an admission that verification is missing."""
    note = (
        evidence.removeprefix("note:")
        if evidence.startswith("note:")
        else na_note_for_level(evidence, level)
    ).lower()
    return bool(note) and any(marker in note for marker in PROVISIONAL_NA_MARKERS)


def cell_is_settled(verdict: str, evidence: str, level: int) -> bool:
    """Only a pass or explicitly inapplicable NA counts as settled."""
    return verdict == "✓" or (verdict == "~" and not is_provisional_na(evidence, level))


def fail(msg: str):
    print(f"judge: REFUSED — {msg}", file=sys.stderr)
    sys.exit(1)


def configured_path(value: Optional[Path], label: str) -> Path:
    if value is None:
        fail(f"RIG_HOME is not configured — refusing direct {label} access")
    return value


def open_alarms():
    alarms_path = configured_path(ALARMS, "alarm ledger")
    if not alarms_path.exists():
        return []
    try:
        return [a for a in json.loads(alarms_path.read_text()) if not a.get("acked")]
    except Exception:
        return [{"id": "alarms-unreadable", "note": "alarms.json corrupt — treat as open"}]


def calibration_problem():
    anchor_status = configured_path(ANCHOR_STATUS, "anchor status")
    try:
        status = json.loads(anchor_status.read_text())
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


def sequence_policy():
    """Load the repository-controlled policy for the automatically advancing frontier."""
    try:
        payload = json.loads(SEQUENCE.read_text())
        if (
            not isinstance(payload, dict)
            or payload.get("version") != 1
            or payload.get("mode") != "first_unsettled"
        ):
            raise ValueError("unsupported policy version")
        manual_queue = payload.get("manual_queue", [])
        if not isinstance(manual_queue, list):
            raise ValueError("manual_queue must be a list")
        seen_manual_items = set()
        for entry in manual_queue:
            if (
                not isinstance(entry, dict)
                or not isinstance(entry.get("family"), str)
                or not isinstance(entry.get("item"), str)
                or not isinstance(entry.get("reason"), str)
                or not entry["reason"].strip()
            ):
                raise ValueError("manual_queue entries require family, item and reason")
            item_key = (entry["family"], entry["item"])
            if item_key in seen_manual_items:
                raise ValueError(
                    "manual_queue contains duplicate item: "
                    f"{entry['family']}|{entry['item']}"
                )
            seen_manual_items.add(item_key)
        forced_queue = payload.get("forced_queue")
        if forced_queue is None:
            # Older temporary fixtures had one queue and therefore treated every queued item as
            # manual. Keep that fixture contract while the formal policy uses an explicit subset.
            # 旧的临时 fixture 只有一条队列,继续把其中全部项目视为人工;正式策略使用显式子集。
            forced_queue = [
                {"family": entry["family"], "item": entry["item"]}
                for entry in manual_queue
            ]
        if not isinstance(forced_queue, list):
            raise ValueError("forced_queue must be a list")
        manual_keys = {(entry["family"], entry["item"]) for entry in manual_queue}
        seen_forced_items = set()
        for entry in forced_queue:
            if (
                not isinstance(entry, dict)
                or not isinstance(entry.get("family"), str)
                or not isinstance(entry.get("item"), str)
            ):
                raise ValueError("forced_queue entries require family and item")
            item_key = (entry["family"], entry["item"])
            if item_key in seen_forced_items:
                raise ValueError(
                    "forced_queue contains duplicate item: "
                    f"{entry['family']}|{entry['item']}"
                )
            if item_key not in manual_keys:
                raise ValueError(
                    "forced_queue references item missing from manual_queue: "
                    f"{entry['family']}|{entry['item']}"
                )
            seen_forced_items.add(item_key)
        payload["forced_queue"] = forced_queue
        return payload
    except (OSError, ValueError, KeyError, TypeError) as exc:
        fail(f"ledger sequence policy is missing or unreadable: {SEQUENCE} ({exc})")


def manual_queue_problem(policy, rows) -> str:
    """Reject a formal manual queue that no longer describes the coverage ledger.

    Queue entries are a scheduling control, not a second coverage inventory.  The historical
    ``manual_queue`` may contain ordinary items that have since been released and settled; only
    the active ``forced_queue`` must remain unsettled. Temporary test ledgers may use partial
    fixtures and are intentionally checked only when ``COVERAGE`` is the repository ledger.
    """
    if COVERAGE.resolve() != DEFAULT_COVERAGE:
        return ""
    row_by_item = {(family, item): (verdict, evidence) for family, item, verdict, evidence in rows}
    manual_entries = policy.get("manual_queue", [])
    missing = [
        f"{entry['family']}|{entry['item']}"
        for entry in manual_entries
        if (entry["family"], entry["item"]) not in row_by_item
    ]
    if missing:
        return "manual_queue references missing COVERAGE row(s): " + ", ".join(missing)
    active_entries = policy.get("forced_queue")
    if active_entries is None:
        # Backward-compatible fixture shape: one queue meant all entries were manual.
        active_entries = manual_entries
    settled = []
    for entry in active_entries:
        verdict, evidence = row_by_item[(entry["family"], entry["item"])]
        if all(cell_is_settled(cell, evidence, level) for level, cell in enumerate(verdict, 1)):
            settled.append(f"{entry['family']}|{entry['item']}")
    if settled:
        return "manual_queue contains settled COVERAGE row(s): " + ", ".join(settled)
    return ""


def sequence_problem(family: str, item: str, revalidate: bool = False) -> str:
    """Refuse new work beyond the frontier, while allowing explicit prior-row revalidation."""
    policy = sequence_policy()
    manual_items = {
        (entry["family"], entry["item"])
        for entry in policy.get("forced_queue", policy.get("manual_queue", []))
    }
    rows = []
    row_pattern = re.compile(
        r"^\| (TOOL|EP|SURF|EDGE)-(\d+) \| (.+?) \| .* \| ([·✓✗~]{5}) \| (.*?) \|$"
    )
    id_pattern = re.compile(r"^\| ([A-Z]+)-(\d+) \|")
    seen_ids = set()
    seen_items = set()
    for line in COVERAGE.read_text().splitlines():
        id_match = id_pattern.match(line)
        if not id_match:
            continue
        match = row_pattern.match(line)
        if not match:
            fail(f"ledger row is malformed: {line}")
        row_family, row_number, row_item, verdict, evidence = match.groups()
        row_id = (row_family, row_number)
        item_key = (row_family, row_item)
        if row_id in seen_ids or item_key in seen_items:
            fail(f"duplicate ledger row: {row_family}|{row_item}")
        seen_ids.add(row_id)
        seen_items.add(item_key)
        rows.append((row_family, row_item, verdict, evidence))
    if not rows:
        return "formal sequence gate: COVERAGE has no parseable ledger rows"
    queue_problem = manual_queue_problem(policy, rows)
    if queue_problem:
        fail(queue_problem)

    unsettled = [
        (index, row_family, row_item, verdict)
        for index, (row_family, row_item, verdict, evidence) in enumerate(rows)
        if any(
            not cell_is_settled(cell, evidence, level)
            for level, cell in enumerate(verdict, 1)
        )
    ]
    frontier_index = next(
        (
            index
            for index, row_family, row_item, _ in unsettled
            if (row_family, row_item) not in manual_items
        ),
        None,
    )
    if frontier_index is None and unsettled:
        # Forced cells are a last-mile queue, not a waiver. Once autonomous work is exhausted,
        # its explicit list order becomes the only writable frontier again.
        # 强制人工格不是豁免;自主格耗尽后,严格按队列显式顺序恢复唯一前线。
        unsettled_by_item = {
            (row_family, row_item): index
            for index, row_family, row_item, _ in unsettled
        }
        frontier_index = next(
            (
                unsettled_by_item[(entry["family"], entry["item"])]
                for entry in policy.get("forced_queue", policy.get("manual_queue", []))
                if (entry["family"], entry["item"]) in unsettled_by_item
            ),
            None,
        )
        if frontier_index is None:
            return "formal sequence gate: unsettled rows are not represented in forced_queue"
    if frontier_index is None:
        return ""
    target_index = next(
        (index for index, (row_family, row_item, _, _) in enumerate(rows) if row_family == family and row_item == item),
        None,
    )
    if target_index is None:
        return f"formal sequence gate: target row not found: {family}|{item}"
    frontier_family, frontier_item, frontier_verdict, _ = rows[frontier_index]
    if revalidate:
        if target_index >= frontier_index:
            return (
                "formal sequence gate: --revalidate is only for a settled prior row; "
                f"target is at/current beyond frontier {frontier_family}|{frontier_item}"
            )
        target_verdict, target_evidence = rows[target_index][2:]
        if not all(
            cell_is_settled(cell, target_evidence, level)
            for level, cell in enumerate(target_verdict, 1)
        ):
            return "formal sequence gate: --revalidate requires the target row to be settled (✓/~)"
        return ""
    if target_index == frontier_index:
        return ""
    if (family, item) in manual_items:
        reason = next(
            entry["reason"]
            for entry in policy.get("manual_queue", [])
            if entry["family"] == family and entry["item"] == item
        )
        return f"manual queue: {family}|{item} is deferred until autonomous cells are exhausted ({reason})"
    return (
        f"formal sequence gate: {family}|{item} is beyond current frontier "
        f"{frontier_family}|{frontier_item} (current={frontier_verdict})"
    )


def judgment_already_recorded(family: str, item: str, level: int, verdict: str, law: str, evidence: str) -> bool:
    """Make a retried command a no-op instead of inflating the ledger or alarm curves."""
    journal = configured_path(JOURNAL, "judgment ledger")
    if not journal.exists():
        return False
    try:
        rows = (json.loads(line) for line in journal.read_text().splitlines() if line.strip())
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


def ledger_continuity_problem() -> str:
    """Refuse to start a new formal ledger when carried coverage has lost its journal.

    Temporary coverage fixtures intentionally start with an empty ledger in unit tests.  The
    repository COVERAGE.md is different: its carried cells are claims about a prior formal run,
    so silently creating a new journal would make the alarm curves and sequence waterline lie.
    """
    journal = configured_path(JOURNAL, "judgment ledger")
    try:
        is_formal_coverage = COVERAGE.resolve() == DEFAULT_COVERAGE
        coverage_text = COVERAGE.read_text()
    except OSError as exc:
        fail(f"formal coverage is unreadable: {COVERAGE} ({exc})")
    if not is_formal_coverage:
        return ""
    carried = set()
    for line in coverage_text.splitlines():
        match = re.match(r"^\| ([A-Z]+)-\d+ \| (.+?) \| .*? \| ([·✓✗~]{5}) \|", line)
        if not match:
            continue
        family, item, status = match.groups()
        carried.update(
            (family, item, level)
            for level, verdict in enumerate(status, 1)
            if verdict != "·"
        )
    if not carried:
        return ""
    if not journal.exists():
        return (
            "formal ledger continuity is missing: repository COVERAGE carries prior judgments "
            f"but {journal} does not exist; restore the historical journal before writing"
        )
    try:
        journal_keys = set()
        has_baseline = False
        for line in journal.read_text().splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            has_baseline = has_baseline or row.get("source") == "coverage-baseline"
            journal_keys.add((row["family"], row["item"], int(row["level"])))
    except (OSError, ValueError, KeyError, TypeError):
        return f"formal ledger continuity is missing: {journal} is unreadable"
    missing = carried - journal_keys
    if missing:
        return (
            "formal ledger continuity is incomplete: journal is missing "
            f"{len(missing)} carried coverage cell(s); restore the complete historical journal "
            "or revalidate those cells before writing"
        )
    if has_baseline:
        manifest_path = journal.parent / "ledger-baseline.json"
        try:
            manifest = json.loads(manifest_path.read_text())
            baseline_cells = set(manifest["baselineCells"])
            current_cells = {f"{family}|{item}|{level}" for family, item, level in carried}
            if manifest.get("carriedCells") != len(baseline_cells) or not baseline_cells.issubset(current_cells):
                return f"formal ledger baseline manifest does not match current COVERAGE: {manifest_path}"
        except (OSError, ValueError, TypeError):
            return f"formal ledger baseline manifest is missing or unreadable: {manifest_path}"
    return ""


@contextmanager
def ledger_lock():
    """Serialize coverage repair and journal append across concurrent judge processes."""
    rig_home = configured_path(RIG_HOME, "judge ledger")
    rig_home.mkdir(parents=True, exist_ok=True)
    lock_path = rig_home / "judge.lock"
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
    configured_path(RIG_HOME, "coverage authority")
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


def validate_l2_session(session_arg: str, evidence_arg: str, verdict: str) -> None:
    """Require a level-2 judgment to be bound to one complete rig session.

    The evidence file and the six channel artifacts must describe the same sealed session.  Merely
    having two individually valid paths is not enough: otherwise an operator could accidentally
    combine a current visual note with an older backend/SSE recording and still get a green L2.
    """
    if not session_arg:
        fail(f"level-2 ({verdict}) requires --session <rig session dir>")
    session_path = Path(session_arg)
    if not session_path.exists() or not session_path.is_dir():
        fail(f"level-2 session is missing or not a directory: {session_arg}")
    try:
        session_path = session_path.resolve()
    except OSError as exc:
        fail(f"level-2 session cannot be resolved: {session_arg} ({exc})")
    rig_home = configured_path(RIG_HOME, "session authority").resolve()
    sessions_root = (rig_home / "sessions").resolve()
    try:
        session_path.relative_to(sessions_root)
    except ValueError:
        fail(f"level-2 session must belong to RIG_HOME/sessions ({session_path})")

    evidence_path = Path(evidence_arg)
    try:
        evidence_path = evidence_path.resolve()
        evidence_path.relative_to(session_path)
    except (OSError, ValueError) as exc:
        fail(
            "level-2 evidence must be inside the supplied session "
            f"({evidence_arg} is outside {session_path})"
        )

    manifest_path = session_path / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, ValueError) as exc:
        fail(f"session manifest is unreadable: {manifest_path} ({exc})")
    manifest_session = manifest.get("session") if isinstance(manifest, dict) else None
    if not isinstance(manifest_session, str) or not Path(manifest_session).is_absolute():
        fail(f"session manifest has no absolute session identity: {manifest_path}")
    try:
        manifest_session = str(Path(manifest_session).resolve())
    except OSError as exc:
        fail(f"session manifest identity cannot be resolved: {manifest_path} ({exc})")
    if manifest_session != str(session_path):
        fail(
            "session manifest identity does not match --session "
            f"({manifest_session} != {session_path})"
        )

    # A backend that fails before binding a port cannot produce SSE connections or an LLM request.
    # The rig must mark those channels explicitly, rather than fabricate empty normal-session data.
    # 启动前失败的 backend 不可能连接 SSE 或发 LLM 请求；台架必须显式记 not_applicable，不能伪造普通会话。
    startup_failure_probe = manifest.get("startupFailureProbe") is True

    required = ("manifest.json", "backend.log", "sse.jsonl", "frontend.log", "llm.jsonl", "screen.mov")
    for journal_name in required:
        journal_path = session_path / journal_name
        if not journal_path.exists() or journal_path.stat().st_size == 0:
            fail(f"session journal {journal_name} missing or empty — five-channel evidence incomplete")
    try:
        subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "csv=p=0",
                str(session_path / "screen.mov"),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        fail("screen.mov is not a finalized readable recording")
    try:
        sse = [json.loads(line) for line in (session_path / "sse.jsonl").read_text().splitlines()]
    except (OSError, ValueError):
        fail("sse.jsonl is unreadable")
    if startup_failure_probe:
        if manifest.get("startupFailureReason") != "malformed_settings":
            fail("startup failure probe must identify malformed_settings")
        if manifest.get("startupFailureBackendExitObserved") is not True:
            fail("startup failure probe has no observed sidecar exit")
        missing = {
            stream
            for stream in ("messages", "entities", "notifications")
            if not any(
                row.get("tap") == "not_applicable"
                and row.get("stream") == stream
                and "backend" in str(row.get("reason", ""))
                for row in sse
            )
        }
        if missing:
            fail(f"startup failure probe lacks explicit SSE not_applicable records: {sorted(missing)}")
        try:
            llm = [json.loads(line) for line in (session_path / "llm.jsonl").read_text().splitlines()]
        except (OSError, ValueError):
            fail("llm.jsonl is unreadable")
        if not any(
            row.get("event") == "not_applicable" and "backend" in str(row.get("reason", ""))
            for row in llm
        ):
            fail("startup failure probe lacks explicit LLM not_applicable record")
        return
    connected = {row.get("stream") for row in sse if row.get("tap") == "connect"}
    missing = {"messages", "entities", "notifications"} - connected
    if missing:
        fail(f"SSE witness never connected streams: {sorted(missing)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("item", help="coverage item name (row key, e.g. 'Read' or '生图迭代到满意')")
    ap.add_argument("--family", required=True, choices=["TOOL", "EP", "SURF", "EDGE"])
    ap.add_argument("--level", required=True, type=int, choices=[1, 2, 3, 4, 5])
    ap.add_argument("--verdict", required=True, choices=["pass", "fail", "na"])
    ap.add_argument("--law", default="", help="CODEX law id / 'measure:<...>' (required for pass/fail)")
    ap.add_argument("--evidence", required=True, help="file path under evidence dir, or 'note:<text>' for na")
    ap.add_argument("--session", default="", help="rig session dir (required for level-2 verdicts)")
    ap.add_argument(
        "--revalidate",
        action="store_true",
        help="explicitly revalidate a settled prior row after a stop-and-fix; never bypasses evidence/alarm gates",
    )
    args = ap.parse_args()

    global RIG_HOME, JOURNAL, ALARMS, ANCHOR_STATUS
    RIG_HOME = explicit_rig_home("judge")
    JOURNAL = RIG_HOME / "judgments.jsonl"
    ALARMS = RIG_HOME / "alarms.json"
    if os.environ.get("RIG_ANCHOR_STATUS", "").strip():
        fail("RIG_ANCHOR_STATUS is unsupported — anchor status must remain under RIG_HOME")
    ANCHOR_STATUS = RIG_HOME / "anchor-check.json"

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
        if is_provisional_na(args.evidence, args.level):
            fail(
                "na is not a waiver: this note says verification is missing; "
                "run the required App/session evidence and judge pass or fail"
            )

    with ledger_lock():
        if problem := ledger_continuity_problem():
            fail(problem)
        already_recorded = judgment_already_recorded(
            args.family, args.item, args.level, args.verdict, args.law, args.evidence
        )
        if already_recorded:
            # A process can die after the journal append but before the coverage write. Replay the
            # cell and pointer under the same lock instead of trusting the journal alone.
            apply_coverage_cell(args.family, args.item, args.level, args.verdict, args.law, args.evidence)
            print(f"judge: {args.family}|{args.item} L{args.level} already recorded; coverage repaired/no-op")
            return

        if args.level == 2 and args.verdict in ("pass", "fail"):
            # Validate new evidence only after the idempotency check. Legacy formal rows may use
            # the pre-session evidence layout; replaying one must remain a repair/no-op.
            validate_l2_session(args.session, args.evidence, args.verdict)

        if problem := sequence_problem(args.family, args.item, args.revalidate):
            fail(problem)

        if args.verdict == "pass":
            if problem := calibration_problem():
                fail(f"{problem} — run anchors.py quiz, answer it, then anchors.py check")
            if alarms := open_alarms():
                fail(f"{len(alarms)} open alarm(s) — resolve/ack them before any new pass: {[a['id'] for a in alarms]}")

        apply_coverage_cell(args.family, args.item, args.level, args.verdict, args.law, args.evidence)
        journal = configured_path(JOURNAL, "judgment ledger")
        with journal.open("a") as f:
            f.write(json.dumps({
                "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "family": args.family, "item": args.item, "level": args.level,
                "verdict": args.verdict, "law": args.law, "evidence": args.evidence,
            }, ensure_ascii=False) + "\n")
        print(f"judge: {args.family}|{args.item} L{args.level} ← {SYM[args.verdict]} ({args.law or 'na'})")


if __name__ == "__main__":
    main()
