#!/usr/bin/env python3
"""Regression tests for the acceptance ledger's retry semantics."""

import json
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


if __name__ == "__main__":
    unittest.main()
