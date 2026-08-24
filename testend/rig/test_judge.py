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
