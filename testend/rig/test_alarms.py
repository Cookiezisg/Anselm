#!/usr/bin/env python3
"""Regression tests for baseline exclusion from live drift curves."""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ALARMS = ROOT / "alarms.py"


class AlarmBaselineTests(unittest.TestCase):
    def test_baseline_rows_do_not_open_live_drift_alarms(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            journal = home / "judgments.jsonl"
            alarm_file = home / "alarms.json"
            journal.write_text(
                "".join(
                    json.dumps(
                        {
                            "ts": "2026-08-25T00:00:00+00:00",
                            "family": "TOOL",
                            "item": f"baseline-{i}",
                            "level": 1,
                            "verdict": "pass",
                            "law": "G1",
                            "evidence": "old evidence",
                            "source": "coverage-baseline",
                        }
                    )
                    + "\n"
                    for i in range(50)
                )
            )

            import sys

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            module = None
            try:
                spec = importlib.util.spec_from_file_location("baseline_alarms", ALARMS)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.RIG_HOME = home
                module.JOURNAL = journal
                module.ALARMS = alarm_file
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    module.check()
                self.assertIn("0 live judgments; 50 baseline judgments excluded", output.getvalue())
                self.assertEqual(json.loads(alarm_file.read_text()), [])
            finally:
                sys.path[:] = old_path


if __name__ == "__main__":
    unittest.main()
