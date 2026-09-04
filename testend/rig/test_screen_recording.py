#!/usr/bin/env python3
"""Regression tests for the conductor's frame-observation startup gate."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent


class ScreenRecordingGateTests(unittest.TestCase):
    def test_recorders_bind_to_the_owned_window_not_a_screen_rectangle(self):
        rig_up = (ROOT / "rig-up.sh").read_text()
        rig_rebind = (ROOT / "rig-rebind-app.sh").read_text()
        rig_check = (ROOT / "rig-check.sh").read_text()
        self.assertIn("screencapture -v -C -k -l \"$APP_WINDOW_ID\"", rig_up)
        self.assertIn("screencapture -v -C -k -l \"$NEW_WINDOW_ID\"", rig_rebind)
        self.assertIn('screencapture.*-v.*-l[[:space:]]$AWID', rig_check)
        self.assertNotIn("screencapture -v -C -k -R", rig_up)
        self.assertNotIn("screencapture -v -C -k -R", rig_rebind)

    def test_rebind_rotates_when_window_identity_changes_without_geometry_change(self):
        rig_rebind = (ROOT / "rig-rebind-app.sh").read_text()
        self.assertIn(
            'if [ "$NEW_WINDOW_ID" != "$OLD_WINDOW_ID" ] || [ "$NEW_BOUNDS" != "$OLD_BOUNDS" ]; then',
            rig_rebind,
        )
        self.assertIn('OLD_WINDOW_ID=$(field appWindowId)', rig_rebind)

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

    def test_frontend_render_validation_errors_are_hard_failures(self):
        rig_check = (ROOT / "rig-check.sh").read_text()
        self.assertIn("ImpellerValidationBreak", rig_check)
        self.assertIn("Contents::SetInheritedOpacity should never be called", rig_check)

    def test_rig_down_fails_closed_when_recording_artifact_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "rig"
            session = home / "sessions" / "session"
            current = home / "current"
            session.mkdir(parents=True)
            current.symlink_to(session, target_is_directory=True)
            (session / "manifest.json").write_text(
                json.dumps({"session": str(session)}), encoding="utf-8"
            )

            env = os.environ.copy()
            env["RIG_HOME"] = str(home)
            result = subprocess.run(
                ["bash", str(ROOT / "rig-down.sh")],
                cwd=ROOT.parent.parent,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("screen.mov is missing or empty", result.stderr)
            self.assertFalse(current.exists())

    def test_rig_down_allows_explicit_recording_disabled_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "rig"
            session = home / "sessions" / "session"
            current = home / "current"
            session.mkdir(parents=True)
            current.symlink_to(session, target_is_directory=True)
            (session / "recording.disabled").touch()
            (session / "manifest.json").write_text(
                json.dumps({"session": str(session)}), encoding="utf-8"
            )

            env = os.environ.copy()
            env["RIG_HOME"] = str(home)
            result = subprocess.run(
                ["bash", str(ROOT / "rig-down.sh")],
                cwd=ROOT.parent.parent,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("recording disabled", result.stdout)

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
