#!/usr/bin/env python3
"""Regression tests for the acceptance ledger's retry semantics."""

import json
import importlib.util
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
JUDGE = ROOT / "judge.py"


class JudgeRetryTests(unittest.TestCase):
    def test_new_user_discoverability_na_reopens_frontier(self):
        """The explicit Chinese wording used by the formal ledger stays provisional."""
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Missing discoverability evidence | test | ✓✓✓✓~ | "
                "L1:G1→old; L5:na→note:本次真实 session 未完成新用户可发现性验收 |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("discoverability_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                evidence = "L5:na→note:本次真实 session 未完成新用户可发现性验收"
                self.assertTrue(module.is_provisional_na(evidence, 5))
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Missing discoverability evidence", problem)
            finally:
                sys.path[:] = old_path

    def test_provisional_na_reopens_the_autonomous_frontier(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Missing App evidence | test | ✓~··· | L1:G1→old; L2:na→note:no real App session yet |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("provisional_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertEqual(module.sequence_problem("EDGE", "Missing App evidence"), "")
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Missing App evidence", problem)
                self.assertTrue(module.is_provisional_na("L2:na→note:no real App session yet", 2))
            finally:
                sys.path[:] = old_path

    def test_measure_note_reopens_the_autonomous_frontier(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Missing measured App evidence | test | ✓~··· | "
                "L1:G1→old; L2:measure:latency→note:no real App session yet |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("measure_provisional_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertTrue(
                    module.is_provisional_na(
                        "L2:measure:latency→note:no real App session yet", 2
                    )
                )
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Missing measured App evidence", problem)
            finally:
                sys.path[:] = old_path

    def test_chinese_missing_evidence_variants_reopen_frontier(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Chinese missing evidence | test | ✓~~~~ | "
                "L1:G1→old; L2:na→note:本格未在独立正式 rig session 中完成五通道 App 录制; "
                "L3:na→note:没有本格独立真实 App 的 Computer Use 逐帧时序测量; "
                "L4:na→note:关系邻域无视觉 craft 断言，不能冒充视觉成品验收; "
                "L5:na→note:没有本格独立真实 App 的新用户 discoverability session |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("chinese_provisional_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertTrue(
                    module.is_provisional_na(
                        "L2:na→note:本格没有独立 formal rig 五通道 session", 2
                    )
                )
                self.assertTrue(module.is_provisional_na("L2:na→note:没有独立真实 App session", 2))
                self.assertTrue(module.is_provisional_na("L4:na→note:不能冒充视觉成品验收", 4))
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Chinese missing evidence", problem)
            finally:
                sys.path[:] = old_path

    def test_reversed_chinese_missing_evidence_phrase_reopens_frontier(self):
        """The common `没有本格独立...` wording must not settle an unobserved level."""
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Reversed Chinese missing evidence | test | ✓~~~~ | "
                "L1:G1→old; L2:na→note:没有本格独立 Computer Use 错误逐帧时序测量; "
                "L3:na→note:没有本格独立视觉成品; L4:na→note:没有本格独立 craft 比对; "
                "L5:na→note:没有本格独立 discoverability session |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("reversed_chinese_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertTrue(
                    module.is_provisional_na(
                        "L2:na→note:没有本格独立 Computer Use 错误逐帧时序测量", 2
                    )
                )
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Reversed Chinese missing evidence", problem)
            finally:
                sys.path[:] = old_path

    def test_batch_missing_evidence_phrase_reopens_frontier(self):
        """Batch-scoped missing-session notes must not silently settle a cell."""
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Batch missing evidence | test | ✓~~~· | "
                "L1:G1→old; L2:na→note:本格本批没有独立的真实 App session; "
                "L3:na→note:本格本批没有独立的视觉复核; "
                "L4:na→note:本格本批没有独立的 craft 复核 |\n"
                "| EDGE-002 | Next cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("batch_missing_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertTrue(
                    module.is_provisional_na(
                        "L2:na→note:本格本批没有独立的真实 App session", 2
                    )
                )
                self.assertIn(
                    "EDGE|Batch missing evidence",
                    module.sequence_problem("EDGE", "Next cell"),
                )
            finally:
                sys.path[:] = old_path

    def test_focus_only_chinese_variants_reopen_frontier(self):
        """Focused-only wording must not let a missing real-App cell advance the queue."""
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Focus-only Chinese evidence | test | ✓~~~~ | "
                "L1:G1→old; L2:na→note:本轮仅有后端/Flutter focused 回归，未建立真实 App session; "
                "L3:na→note:本轮只有本地 focused 测试; "
                "L4:na→note:本格仅有 focused service 检查; "
                "L5:na→note:本格只有 focused 回归 |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("focus_only_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                for phrase in ("本轮仅有", "本轮只有", "本格仅有", "本格只有"):
                    self.assertTrue(
                        module.is_provisional_na(f"L2:na→note:{phrase} focused 回归", 2)
                    )
                problem = module.sequence_problem("EDGE", "Next autonomous cell")
                self.assertIn("EDGE|Focus-only Chinese evidence", problem)
            finally:
                sys.path[:] = old_path

    def test_explicit_not_applicable_na_remains_settled(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EP-001 | API-only endpoint | test | ✓~✓✓✓ | L1:G1→old; L2:na→note:API-only endpoint has no Flutter visual surface; C4 does not apply |\n"
                "| EP-002 | Next cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("explicit_na_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                self.assertFalse(
                    module.is_provisional_na(
                        "L2:na→note:这是 API 分页互斥契约；本格没有独立 Computer Use 逐帧、时延、视觉美观或可发现性会话。",
                        2,
                    )
                )
                self.assertEqual(module.sequence_problem("EP", "Next cell"), "")
            finally:
                sys.path[:] = old_path

    def test_latest_na_pointer_replaces_provisional_frontier_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            coverage.write_text(
                "| EDGE-001 | Retried boundary | test | ✓~✓✓✓ | "
                "L1:G1→old; L2:na→note:no real App session yet; "
                "L2:na→note:this internal state has no independent durable product surface |\n"
                "| EDGE-002 | Next autonomous cell | test | ····· |  |\n"
            )
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("latest_na_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                evidence = coverage.read_text().splitlines()[0].split(" | ", 4)[4].removesuffix(" |")
                self.assertEqual(module.na_note_for_level(evidence, 2), "this internal state has no independent durable product surface")
                self.assertEqual(module.sequence_problem("EDGE", "Next autonomous cell"), "")
            finally:
                sys.path[:] = old_path

    def test_na_command_rejects_provisional_note(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text("| EDGE-001 | Provisional NA | test | ····· |  |\n")
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            result = subprocess.run(
                [
                    sys.executable, str(JUDGE), "Provisional NA", "--family", "EDGE",
                    "--level", "1", "--verdict", "na",
                    "--evidence", "note:no real App session yet",
                ],
                env=env, check=False, capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("na is not a waiver", result.stderr)
            self.assertFalse((rig_home / "judgments.jsonl").exists())

    def test_formal_coverage_cannot_start_a_new_ledger_after_journal_loss(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            rig_home = home / "rig"
            coverage.write_text("| TOOL-001 | Carried fixture | test | ✓···· | old evidence |\n")

            old_coverage = None
            old_journal = None
            old_default = None
            old_rig_home = None
            old_module = None
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("continuity_judge", JUDGE)
                self.assertIsNotNone(spec)
                old_module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = old_module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(old_module)
                old_coverage = old_module.COVERAGE
                old_default = old_module.DEFAULT_COVERAGE
                old_journal = old_module.JOURNAL
                old_rig_home = old_module.RIG_HOME
                old_module.COVERAGE = coverage
                old_module.DEFAULT_COVERAGE = coverage.resolve()
                old_module.RIG_HOME = rig_home
                old_module.JOURNAL = rig_home / "judgments.jsonl"
                with old_module.ledger_lock():
                    problem = old_module.ledger_continuity_problem()
                self.assertIn("formal ledger continuity is missing", problem)
                self.assertFalse((rig_home / "judgments.jsonl").exists())
            finally:
                if old_module is not None:
                    old_module.COVERAGE = old_coverage
                    old_module.DEFAULT_COVERAGE = old_default
                    old_module.JOURNAL = old_journal
                    old_module.RIG_HOME = old_rig_home
                sys.path[:] = old_path

    def test_partial_formal_journal_cannot_unlock_carried_coverage(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| TOOL-001 | First carried fixture | test | ✓✓··· | old evidence |\n"
                "| TOOL-002 | Second carried fixture | test | ✓···· | old evidence |\n"
            )
            rig_home.mkdir()
            (rig_home / "judgments.jsonl").write_text(
                json.dumps({"family": "TOOL", "item": "First carried fixture", "level": 1}) + "\n"
            )

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            module = None
            try:
                spec = importlib.util.spec_from_file_location("partial_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                module.DEFAULT_COVERAGE = coverage.resolve()
                module.RIG_HOME = rig_home
                module.JOURNAL = rig_home / "judgments.jsonl"
                with module.ledger_lock():
                    problem = module.ledger_continuity_problem()
                self.assertIn("journal is missing 2 carried coverage cell(s)", problem)
            finally:
                sys.path[:] = old_path

    def test_identical_judgment_is_a_noop(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            evidence = home / "evidence.txt"
            rig_home = home / "rig"
            coverage.write_text("| TOOL-001 | Retry fixture | test | ····· |  |\n")
            codex.write_text("")
            evidence.write_text("fixture evidence\n")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            command = [
                sys.executable,
                str(JUDGE),
                "Retry fixture",
                "--family",
                "TOOL",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:not applicable to this fixture",
            ]
            first = subprocess.run(command, env=env, check=True, capture_output=True, text=True)
            second = subprocess.run(command, env=env, check=True, capture_output=True, text=True)

            self.assertIn("no-op", second.stdout)
            self.assertEqual(coverage.read_text(), "| TOOL-001 | Retry fixture | test | ~···· | L1:na→note:not applicable to this fixture |\n")
            journal = (rig_home / "judgments.jsonl").read_text().splitlines()
            self.assertEqual(len(journal), 1)
            self.assertEqual(json.loads(journal[0])["item"], "Retry fixture")
            self.assertIn("TOOL|Retry fixture", first.stdout)

    def test_concurrent_levels_preserve_every_cell(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text("| TOOL-001 | Concurrent fixture | test | ····· |  |\n")
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }

            def run(level):
                return subprocess.run(
                    [
                        sys.executable,
                        str(JUDGE),
                        "Concurrent fixture",
                        "--family",
                        "TOOL",
                        "--level",
                        str(level),
                        "--verdict",
                        "na",
                        "--evidence",
                        f"note:level {level} is not applicable",
                    ],
                    env=env,
                    check=False,
                    capture_output=True,
                    text=True,
                )

            with ThreadPoolExecutor(max_workers=5) as pool:
                results = list(pool.map(run, range(1, 6)))

            self.assertTrue(all(result.returncode == 0 for result in results))
            self.assertIn("~~~~~", coverage.read_text())
            journal = (rig_home / "judgments.jsonl").read_text().splitlines()
            self.assertEqual(len(journal), 5)
            self.assertEqual({json.loads(line)["level"] for line in journal}, set(range(1, 6)))

    def test_sequence_gate_refuses_target_until_predecessor_is_settled(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ····· |  |\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
            )
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
                # A permissive external policy must not be able to replace the formal one.
                "RIG_SEQUENCE": str(home / "permissive-sequence.json"),
            }
            command = [
                sys.executable,
                str(JUDGE),
                "GET /api/v1/read-aloud/availability",
                "--family",
                "EP",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:fixture is not applicable",
            ]
            refused = subprocess.run(command, env=env, check=False, capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("formal sequence gate", refused.stderr)
            self.assertEqual(coverage.read_text().splitlines()[1].split("|")[4].strip(), "·····")
            self.assertFalse((rig_home / "judgments.jsonl").exists())

            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ✓✓✓✓✓ |  |\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
            )
            accepted = subprocess.run(command, env=env, check=True, capture_output=True, text=True)
            self.assertIn("EP|GET /api/v1/read-aloud/availability", accepted.stdout)
            self.assertIn("~····", coverage.read_text())

    def test_manual_queue_is_skipped_but_returns_after_autonomous_cells(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            policy = home / "ledger-sequence.json"
            coverage.write_text(
                "| EDGE-329 | Physical shortcut | test | ✓···· |  |\n"
                "| EDGE-330 | Autonomous cell | test | ····· |  |\n"
            )
            policy.write_text(json.dumps({
                "version": 1,
                "mode": "first_unsettled",
                "manual_queue": [{
                    "family": "EDGE",
                    "item": "Physical shortcut",
                    "reason": "requires a physical modifier chord",
                }],
            }))

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            module = None
            try:
                spec = importlib.util.spec_from_file_location("manual_queue_judge", JUDGE)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.COVERAGE = coverage
                module.SEQUENCE = policy

                self.assertEqual(module.sequence_problem("EDGE", "Autonomous cell"), "")
                problem = module.sequence_problem("EDGE", "Physical shortcut")
                self.assertIn("manual queue", problem)

                coverage.write_text(
                    "| EDGE-329 | Physical shortcut | test | ✓···· |  |\n"
                    "| EDGE-330 | Autonomous cell | test | ✓✓✓✓✓ |  |\n"
                )
                self.assertEqual(module.sequence_problem("EDGE", "Physical shortcut"), "")
            finally:
                sys.path[:] = old_path

    def test_sequence_gate_keeps_identical_replay_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ✓✓✓✓✓ |  |\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
            )
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            command = [
                sys.executable,
                str(JUDGE),
                "GET /api/v1/read-aloud/availability",
                "--family",
                "EP",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:fixture is not applicable",
            ]
            subprocess.run(command, env=env, check=True, capture_output=True, text=True)
            replay = subprocess.run(command, env=env, check=True, capture_output=True, text=True)
            self.assertIn("already recorded", replay.stdout)
            self.assertEqual(len((rig_home / "judgments.jsonl").read_text().splitlines()), 1)

    def test_sequence_policy_rejects_invalid_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text("| TOOL-001 | Invalid policy fixture | test | ····· |  |\n")
            codex.write_text("")
            # This test is intentionally a direct function-level check: the repository policy is
            # the only policy path, so malformed policy must fail closed before a judgment writes.
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("acceptance_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original = judge.SEQUENCE
            try:
                judge.SEQUENCE = home / "sequence.json"
                judge.SEQUENCE.write_text(json.dumps({"version": 2, "rules": []}))
                with self.assertRaises(SystemExit):
                    judge.sequence_policy()
            finally:
                judge.SEQUENCE = original

    def test_sequence_policy_rejects_duplicate_manual_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("duplicate_queue_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original = judge.SEQUENCE
            try:
                judge.SEQUENCE = home / "sequence.json"
                entry = {
                    "family": "EDGE",
                    "item": "same item",
                    "reason": "requires the final physical interaction",
                }
                judge.SEQUENCE.write_text(json.dumps({
                    "version": 1,
                    "mode": "first_unsettled",
                    "manual_queue": [entry, dict(entry)],
                }))
                with self.assertRaises(SystemExit):
                    judge.sequence_policy()
            finally:
                judge.SEQUENCE = original

    def test_forced_queue_releases_ordinary_ui_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("forced_queue_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original = judge.SEQUENCE
            original_coverage = judge.COVERAGE
            try:
                judge.SEQUENCE = home / "sequence.json"
                judge.COVERAGE = home / "COVERAGE.md"
                judge.COVERAGE.write_text(
                    "| EDGE-001 | Dangerous video | test | ····· |  |\n"
                    "| EDGE-002 | Ordinary App surface | test | ····· |  |\n"
                )
                entry_a = {"family": "EDGE", "item": "Dangerous video", "reason": "requires confirmation"}
                entry_b = {"family": "EDGE", "item": "Ordinary App surface", "reason": "needs Computer Use"}
                judge.SEQUENCE.write_text(json.dumps({
                    "version": 1,
                    "mode": "first_unsettled",
                    "manual_queue": [entry_a, entry_b],
                    "forced_queue": [{"family": "EDGE", "item": "Dangerous video"}],
                }))
                self.assertEqual(judge.sequence_problem("EDGE", "Ordinary App surface"), "")
                self.assertIn(
                    "manual queue: EDGE|Dangerous video",
                    judge.sequence_problem("EDGE", "Dangerous video"),
                )
            finally:
                judge.SEQUENCE = original
                judge.COVERAGE = original_coverage

    def test_manual_frontier_uses_forced_queue_order_after_autonomous_cells(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("forced_order_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original = judge.SEQUENCE
            original_coverage = judge.COVERAGE
            try:
                judge.SEQUENCE = home / "sequence.json"
                judge.COVERAGE = home / "COVERAGE.md"
                judge.COVERAGE.write_text(
                    "| EDGE-001 | Later coverage row | test | ····· |  |\n"
                    "| EDGE-002 | Earlier forced row | test | ····· |  |\n"
                )
                later = {
                    "family": "EDGE",
                    "item": "Later coverage row",
                    "reason": "requires a physical interaction",
                }
                earlier = {
                    "family": "EDGE",
                    "item": "Earlier forced row",
                    "reason": "requires a second physical interaction",
                }
                judge.SEQUENCE.write_text(json.dumps({
                    "version": 1,
                    "mode": "first_unsettled",
                    "manual_queue": [later, earlier],
                    "forced_queue": [earlier, later],
                }))

                self.assertEqual(judge.sequence_problem("EDGE", "Earlier forced row"), "")
                self.assertIn(
                    "manual queue: EDGE|Later coverage row",
                    judge.sequence_problem("EDGE", "Later coverage row"),
                )
            finally:
                judge.SEQUENCE = original
                judge.COVERAGE = original_coverage

    def test_forced_queue_rejects_item_outside_manual_queue(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("forced_queue_reference_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original = judge.SEQUENCE
            try:
                judge.SEQUENCE = home / "sequence.json"
                judge.SEQUENCE.write_text(json.dumps({
                    "version": 1,
                    "mode": "first_unsettled",
                    "manual_queue": [],
                    "forced_queue": [{"family": "EDGE", "item": "not listed"}],
                }))
                with self.assertRaises(SystemExit):
                    judge.sequence_policy()
            finally:
                judge.SEQUENCE = original

    def test_released_manual_candidate_may_settle(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("released_candidate_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original_coverage = judge.COVERAGE
            original_default = judge.DEFAULT_COVERAGE
            try:
                coverage = home / "COVERAGE.md"
                coverage.write_text(
                    "| EDGE-001 | Released candidate | test | ✓~~~~ | "
                    "L1:G1→old; L2:na→note:internal seam; "
                    "L3:na→note:no timing surface; L4:na→note:no visual surface; "
                    "L5:na→note:no user entry |\n"
                    "| EDGE-002 | Forced item | test | ····· |  |\n"
                )
                judge.COVERAGE = coverage
                judge.DEFAULT_COVERAGE = coverage.resolve()
                policy = {
                    "manual_queue": [
                        {"family": "EDGE", "item": "Released candidate", "reason": "old candidate"},
                        {"family": "EDGE", "item": "Forced item", "reason": "physical action"},
                    ],
                    "forced_queue": [{"family": "EDGE", "item": "Forced item"}],
                }
                rows = [
                    ("EDGE", "Released candidate", "✓~~~~", "L1:G1→old; L2:na→note:internal seam; L3:na→note:no timing surface; L4:na→note:no visual surface; L5:na→note:no user entry"),
                    ("EDGE", "Forced item", "·····", ""),
                ]
                self.assertEqual(judge.manual_queue_problem(policy, rows), "")
            finally:
                judge.COVERAGE = original_coverage
                judge.DEFAULT_COVERAGE = original_default

    def test_formal_manual_queue_rejects_missing_coverage_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("missing_queue_row_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original_coverage = judge.COVERAGE
            original_default = judge.DEFAULT_COVERAGE
            try:
                coverage = home / "COVERAGE.md"
                coverage.write_text(
                    "| EDGE-001 | Present row | test | ✓···· | old evidence |\n"
                )
                judge.COVERAGE = coverage
                judge.DEFAULT_COVERAGE = coverage.resolve()
                policy = {
                    "manual_queue": [{
                        "family": "EDGE",
                        "item": "Missing row",
                        "reason": "requires the real App",
                    }]
                }
                rows = [("EDGE", "Present row", "✓····", "old evidence")]
                problem = judge.manual_queue_problem(policy, rows)
                self.assertIn("references missing COVERAGE row", problem)
            finally:
                judge.COVERAGE = original_coverage
                judge.DEFAULT_COVERAGE = original_default

    def test_formal_manual_queue_rejects_settled_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("settled_queue_row_judge", JUDGE)
                self.assertIsNotNone(spec)
                judge = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = judge
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(judge)
            finally:
                sys.path[:] = old_path

            original_coverage = judge.COVERAGE
            original_default = judge.DEFAULT_COVERAGE
            try:
                coverage = home / "COVERAGE.md"
                coverage.write_text(
                    "| EDGE-001 | Settled row | test | ✓~~~~ | "
                    "L1:G1→old; L2:na→note:internal seam has no UI; "
                    "L3:na→note:no independent user timing surface; "
                    "L4:na→note:no independent visual surface; "
                    "L5:na→note:no user-discoverable entry |\n"
                )
                judge.COVERAGE = coverage
                judge.DEFAULT_COVERAGE = coverage.resolve()
                policy = {
                    "manual_queue": [{
                        "family": "EDGE",
                        "item": "Settled row",
                        "reason": "stale queue entry",
                    }]
                }
                rows = [("EDGE", "Settled row", "✓~~~~", "L1:G1→old; L2:na→note:internal seam has no UI; L3:na→note:no independent user timing surface; L4:na→note:no independent visual surface; L5:na→note:no user-discoverable entry")]
                problem = judge.manual_queue_problem(policy, rows)
                self.assertIn("contains settled COVERAGE row", problem)
            finally:
                judge.COVERAGE = original_coverage
                judge.DEFAULT_COVERAGE = original_default

    def test_sequence_gate_blocks_every_row_after_the_frontier(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ····· |  |\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
                "| EP-222 | POST /api/v1/read-aloud:read | test | ····· |  |\n"
            )
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            command = [
                sys.executable,
                str(JUDGE),
                "POST /api/v1/read-aloud:read",
                "--family",
                "EP",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:fixture is not applicable",
            ]

            first_refusal = subprocess.run(command, env=env, check=False, capture_output=True, text=True)
            self.assertNotEqual(first_refusal.returncode, 0)
            self.assertIn("EP|DELETE /api/v1/voices/{id}", first_refusal.stderr)

            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ✓✓✓✓✓ |  |\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
                "| EP-222 | POST /api/v1/read-aloud:read | test | ····· |  |\n"
            )
            second_refusal = subprocess.run(command, env=env, check=False, capture_output=True, text=True)
            self.assertNotEqual(second_refusal.returncode, 0)
            self.assertIn("EP|GET /api/v1/read-aloud/availability", second_refusal.stderr)
            self.assertFalse((rig_home / "judgments.jsonl").exists())

    def test_revalidate_allows_only_a_settled_prior_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| EP-220 | settled prior | test | ~~~~~ |  |\n"
                "| EP-221 | current frontier | test | ····· |  |\n"
            )
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            base = [
                sys.executable,
                str(JUDGE),
                "settled prior",
                "--family",
                "EP",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:revalidation fixture",
            ]
            refused = subprocess.run(base, env=env, check=False, capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("formal sequence gate", refused.stderr)

            accepted = subprocess.run(base + ["--revalidate"], env=env, check=True, capture_output=True, text=True)
            self.assertIn("EP|settled prior", accepted.stdout)
            self.assertEqual(len((rig_home / "judgments.jsonl").read_text().splitlines()), 1)

    def test_sequence_gate_rejects_malformed_ledger_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            coverage.write_text(
                "| EP-220 | DELETE /api/v1/voices/{id} | test | ····· | broken\n"
                "| EP-221 | GET /api/v1/read-aloud/availability | test | ····· |  |\n"
            )
            codex.write_text("")
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            command = [
                sys.executable,
                str(JUDGE),
                "GET /api/v1/read-aloud/availability",
                "--family",
                "EP",
                "--level",
                "1",
                "--verdict",
                "na",
                "--evidence",
                "note:fixture is not applicable",
            ]
            refused = subprocess.run(command, env=env, check=False, capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("ledger row is malformed", refused.stderr)

    def test_level2_rejects_evidence_outside_supplied_session(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            session = rig_home / "sessions" / "session"
            session.mkdir(parents=True)
            evidence = home / "evidence.md"
            coverage.write_text("| TOOL-001 | L2 evidence boundary | test | ····· |  |\n")
            codex.write_text("| A1 | fixture law | test |\n")
            evidence.write_text("fixture evidence\n")
            (session / "manifest.json").write_text(json.dumps({"session": str(session)}))
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            result = subprocess.run(
                [
                    sys.executable,
                    str(JUDGE),
                    "L2 evidence boundary",
                    "--family",
                    "TOOL",
                    "--level",
                    "2",
                    "--verdict",
                    "fail",
                    "--law",
                    "A1",
                    "--evidence",
                    str(evidence),
                    "--session",
                    str(session),
                ],
                env=env,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("inside the supplied session", result.stderr)
            self.assertFalse((rig_home / "judgments.jsonl").exists())
            self.assertIn("·····", coverage.read_text())

    def test_level2_rejects_manifest_bound_to_another_session(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            session = rig_home / "sessions" / "session"
            evidence_dir = session / "evidence"
            evidence_dir.mkdir(parents=True)
            evidence = evidence_dir / "proof.md"
            coverage.write_text("| TOOL-001 | L2 manifest identity | test | ····· |  |\n")
            codex.write_text("| A1 | fixture law | test |\n")
            evidence.write_text("fixture evidence\n")
            (session / "manifest.json").write_text(json.dumps({"session": str(home / "other-session")}))
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            result = subprocess.run(
                [
                    sys.executable,
                    str(JUDGE),
                    "L2 manifest identity",
                    "--family",
                    "TOOL",
                    "--level",
                    "2",
                    "--verdict",
                    "fail",
                    "--law",
                    "A1",
                    "--evidence",
                    str(evidence),
                    "--session",
                    str(session),
                ],
                env=env,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("manifest identity does not match", result.stderr)
            self.assertFalse((rig_home / "judgments.jsonl").exists())
            self.assertIn("·····", coverage.read_text())

    def test_level2_rejects_session_from_another_rig_home(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            session = home / "other-rig" / "sessions" / "session"
            evidence_dir = session / "evidence"
            evidence_dir.mkdir(parents=True)
            evidence = evidence_dir / "proof.md"
            coverage.write_text("| TOOL-001 | L2 rig ownership | test | ····· |  |\n")
            codex.write_text("| A1 | fixture law | test |\n")
            evidence.write_text("fixture evidence\n")
            (session / "manifest.json").write_text(json.dumps({"session": str(session)}))
            env = os.environ | {
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            result = subprocess.run(
                [
                    sys.executable,
                    str(JUDGE),
                    "L2 rig ownership",
                    "--family",
                    "TOOL",
                    "--level",
                    "2",
                    "--verdict",
                    "fail",
                    "--law",
                    "A1",
                    "--evidence",
                    str(evidence),
                    "--session",
                    str(session),
                ],
                env=env,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("RIG_HOME/sessions", result.stderr)
            self.assertFalse((rig_home / "judgments.jsonl").exists())
            self.assertIn("·····", coverage.read_text())

    def test_level2_accepts_complete_evidence_bound_to_current_rig(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            coverage = home / "COVERAGE.md"
            codex = home / "CODEX.md"
            rig_home = home / "rig"
            session = rig_home / "sessions" / "session"
            evidence_dir = session / "evidence"
            evidence_dir.mkdir(parents=True)
            evidence = evidence_dir / "proof.md"
            coverage.write_text("| TOOL-001 | L2 valid binding | test | ····· |  |\n")
            codex.write_text("| A1 | fixture law | test |\n")
            evidence.write_text("fixture evidence\n")
            (session / "manifest.json").write_text(json.dumps({"session": str(session)}))
            for name in ("backend.log", "frontend.log", "llm.jsonl", "screen.mov"):
                (session / name).write_text("fixture\n")
            (session / "sse.jsonl").write_text(
                "\n".join(json.dumps({"tap": "connect", "stream": stream}) for stream in ("messages", "entities", "notifications"))
                + "\n"
            )
            fake_bin = home / "bin"
            fake_bin.mkdir()
            ffprobe = fake_bin / "ffprobe"
            ffprobe.write_text("#!/bin/sh\nprintf '1.0\\n'\n")
            ffprobe.chmod(0o755)
            env = os.environ | {
                "PATH": f"{fake_bin}:{os.environ.get('PATH', '')}",
                "RIG_COVERAGE": str(coverage),
                "RIG_CODEX": str(codex),
                "RIG_HOME": str(rig_home),
            }
            result = subprocess.run(
                [
                    sys.executable,
                    str(JUDGE),
                    "L2 valid binding",
                    "--family",
                    "TOOL",
                    "--level",
                    "2",
                    "--verdict",
                    "fail",
                    "--law",
                    "A1",
                    "--evidence",
                    str(evidence),
                    "--session",
                    str(session),
                ],
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("L2 valid binding", result.stdout)
            self.assertIn("·✗···", coverage.read_text())
            self.assertEqual(len((rig_home / "judgments.jsonl").read_text().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
