#!/usr/bin/env python3
"""Regression tests for the acceptance ledger's retry semantics."""

import json
import os
import subprocess
import sys
import tempfile
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


if __name__ == "__main__":
    unittest.main()
