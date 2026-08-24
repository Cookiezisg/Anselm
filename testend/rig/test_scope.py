#!/usr/bin/env python3
"""The authority-writing rig scripts must never silently use a personal ledger."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parent


class ExplicitRigHomeTests(unittest.TestCase):
    def test_optional_auth_arrays_are_nounset_safe(self):
        for script in ("rig-up.sh", "rig-check.sh"):
            source = (ROOT / script).read_text()
            self.assertIn("curl_backend()", source)
            self.assertEqual(source.count('curl "$@" "${AUTH_ARGS[@]}"'), 1)
            self.assertNotIn('curl -sf "http://127.0.0.1:$PORT/api/v1/health" "${AUTH_ARGS[@]}"', source)

    def run_shell_without_scope(self, script: str, value: Optional[str] = None) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            if value is not None:
                env["RIG_HOME"] = value
            result = subprocess.run(
                [str(ROOT / script)],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())
            return result

    def test_rig_up_help_is_read_only_without_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            result = subprocess.run(
                [str(ROOT / "rig-up.sh"), "--help"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("Usage:", result.stdout)
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())

    def test_rig_up_refuses_missing_scope_before_build(self):
        result = self.run_shell_without_scope("rig-up.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME must be explicitly", result.stderr)

    def test_rig_check_refuses_relative_scope(self):
        result = self.run_shell_without_scope("rig-check.sh", "relative-rig")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("absolute path", result.stderr)

    def test_rig_down_refuses_tilde_scope(self):
        result = self.run_shell_without_scope("rig-down.sh", "~/relative-rig")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("absolute path", result.stderr)

    def test_rig_check_help_is_read_only_without_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            result = subprocess.run(
                [str(ROOT / "rig-check.sh"), "--help"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("Usage:", result.stdout)
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())

    def test_rig_down_help_is_read_only_without_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            result = subprocess.run(
                [str(ROOT / "rig-down.sh"), "--help"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("Usage:", result.stdout)
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())

    def test_rig_rebind_help_is_read_only_without_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            result = subprocess.run(
                [str(ROOT / "rig-rebind-app.sh"), "--help"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("Usage:", result.stdout)
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())

    def test_rig_rebind_refuses_missing_scope(self):
        result = self.run_shell_without_scope("rig-rebind-app.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME must be explicitly", result.stderr)
    def run_without_scope(self, script: str, *args: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            if script == "judge.py":
                coverage = Path(tmp) / "COVERAGE.md"
                codex = Path(tmp) / "CODEX.md"
                coverage.write_text("| TOOL-001 | Scope fixture | test | ····· |  |\n")
                codex.write_text("")
                env.update({"RIG_COVERAGE": str(coverage), "RIG_CODEX": str(codex)})
            result = subprocess.run(
                [sys.executable, str(ROOT / script), *args],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())
            return result

    def test_judge_refuses_default_ledger(self):
        result = self.run_without_scope(
            "judge.py",
            "Scope fixture",
            "--family",
            "TOOL",
            "--level",
            "1",
            "--verdict",
            "na",
            "--evidence",
            "note:scope guard fixture",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME must be explicitly", result.stderr)

    def test_alarms_refuses_default_ledger(self):
        result = self.run_without_scope("alarms.py", "check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME must be explicitly", result.stderr)

    def test_anchors_refuses_default_ledger(self):
        result = self.run_without_scope("anchors.py", "quiz")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME must be explicitly", result.stderr)

    def test_relative_rig_home_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["RIG_HOME"] = "relative-rig"
            env["HOME"] = tmp
            result = subprocess.run(
                [sys.executable, str(ROOT / "alarms.py"), "check"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("absolute path", result.stderr)

    def test_tilde_rig_home_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["RIG_HOME"] = "~/relative-rig"
            env["HOME"] = tmp
            result = subprocess.run(
                [sys.executable, str(ROOT / "anchors.py"), "quiz"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("absolute path", result.stderr)
            self.assertFalse((Path(tmp) / "relative-rig").exists())

    def test_help_is_read_only_without_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            result = subprocess.run(
                [sys.executable, str(ROOT / "alarms.py"), "--help"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("usage:", result.stdout)
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())

    def test_direct_judge_module_access_refuses_without_scope(self):
        result = self.run_direct_module("judge", "open_alarms()")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME is not configured", result.stderr)

    def test_direct_alarms_module_access_refuses_without_scope(self):
        result = self.run_direct_module("alarms", "load_journal()")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME is not configured", result.stderr)

    def test_direct_anchors_module_access_refuses_without_scope(self):
        result = self.run_direct_module("anchors", "quiz()")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RIG_HOME is not configured", result.stderr)

    def test_external_anchor_status_override_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["RIG_HOME"] = str(Path(tmp) / "formal")
            env["RIG_ANCHOR_STATUS"] = str(Path(tmp) / "outside-anchor-check.json")
            result = subprocess.run(
                [sys.executable, str(ROOT / "judge.py"), "Scope fixture", "--family", "TOOL",
                 "--level", "1", "--verdict", "na", "--evidence", "note:scope guard fixture"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("RIG_ANCHOR_STATUS is unsupported", result.stderr)
            self.assertFalse((Path(tmp) / "outside-anchor-check.json").exists())

    def run_direct_module(self, module: str, expression: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.pop("RIG_HOME", None)
            env["HOME"] = tmp
            env["PYTHONPATH"] = str(ROOT)
            result = subprocess.run(
                [sys.executable, "-c", f"import {module}; {module}.{expression}"],
                env=env,
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertFalse((Path(tmp) / ".anselm-rig").exists())
            return result


if __name__ == "__main__":
    unittest.main()
