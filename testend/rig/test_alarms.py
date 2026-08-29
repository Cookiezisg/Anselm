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

    def test_ack_advances_watermark_and_check_does_not_reopen(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            journal = home / "judgments.jsonl"
            alarm_file = home / "alarms.json"
            rows = []
            for i in range(50):
                rows.append(json.dumps({
                    "ts": f"2026-08-25T00:{i:02d}:00+00:00",
                    "family": "EDGE",
                    "item": f"item-{i}",
                    "level": 2,
                    "verdict": "na",
                    "law": "",
                    "evidence": "note:internal seam has no independent product surface",
                }))
            journal.write_text("\n".join(rows) + "\n")
            alarm_file.write_text(json.dumps([{
                "id": "discovery-collapse",
                "note": "test alarm",
                "evidenceThrough": "2026-08-24T00:00:00+00:00",
                "openedAt": "2026-08-24T00:00:00+00:00",
            }]))

            import sys

            old_path = list(sys.path)
            sys.path.insert(0, str(ROOT))
            try:
                spec = importlib.util.spec_from_file_location("ack_watermark_alarms", ALARMS)
                self.assertIsNotNone(spec)
                module = importlib.util.module_from_spec(spec)
                sys.modules[spec.name] = module
                self.assertIsNotNone(spec.loader)
                spec.loader.exec_module(module)
                module.RIG_HOME = home
                module.JOURNAL = journal
                module.ALARMS = alarm_file

                module.ack("discovery-collapse", "re-audited")
                saved = json.loads(alarm_file.read_text())
                self.assertEqual(saved[0]["evidenceThrough"], rows[-1].split('"ts": "')[1].split('"')[0])

                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    module.check()
                self.assertIn("clean (50 live judgments; 0 baseline judgments excluded", output.getvalue())
                self.assertTrue(json.loads(alarm_file.read_text())[0].get("acked"))
            finally:
                sys.path[:] = old_path


if __name__ == "__main__":
    unittest.main()
