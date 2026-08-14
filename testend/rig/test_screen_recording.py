#!/usr/bin/env python3
"""Regression tests for the conductor's frame-observation startup gate."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent


class ScreenRecordingGateTests(unittest.TestCase):
    def test_recording_disabled_is_a_successful_diagnostic_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            env = os.environ.copy()
            env.update(
                {
                    "RIG_HOME": str(home / "rig"),
                    "RIG_RECORD": "0",
                    "RIG_APP": "0",
                    "RIG_LLMTAP": "0",
                    "RIG_SEED": "0",
                    "RIG_PORT": "0",
                }
            )
            result = subprocess.run(
                ["bash", str(ROOT / "rig-up.sh")],
                cwd=ROOT.parent.parent,
                env=env,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Screen Recording permission unavailable", result.stderr)

    def test_rig_up_refuses_to_start_any_observer_when_capture_is_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            fake_bin = home / "bin"
            fake_bin.mkdir()
            screencapture = fake_bin / "screencapture"
            screencapture.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            screencapture.chmod(0o755)

            rig_home = home / "rig"
            env = os.environ.copy()
            env.update(
                {
                    "RIG_HOME": str(rig_home),
                    "RIG_RECORD": "1",
                    "RIG_APP": "1",
                    "RIG_LLMTAP": "1",
                    "RIG_SEED": "0",
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                }
            )

            result = subprocess.run(
                [str(ROOT / "rig-up.sh")],
                cwd=ROOT.parent.parent,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Screen Recording permission unavailable", result.stderr)
            self.assertNotIn("building server + observers", result.stdout)
            self.assertFalse((rig_home / "bin" / "server").exists())
            self.assertFalse((rig_home / "bin" / "ssetap").exists())
            self.assertFalse((rig_home / "bin" / "llmtap").exists())
            self.assertFalse(any(rig_home.glob("sessions/*/manifest.json")))


if __name__ == "__main__":
    unittest.main()
