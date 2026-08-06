#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("gen_coverage.py")
SPEC = importlib.util.spec_from_file_location("gen_coverage", SCRIPT)
assert SPEC and SPEC.loader
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


class GenCoverageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.extracts = root / "extracts"
        self.extracts.mkdir()
        for _, _, filename, prefix in GEN.SECTIONS:
            (self.extracts / filename).write_text(f"{prefix} | item-{prefix} | summary\n")
        self.output = root / "COVERAGE.md"
        self.old_rig, self.old_out = GEN.RIG, GEN.OUT
        GEN.RIG, GEN.OUT = self.extracts, self.output

    def tearDown(self):
        GEN.RIG, GEN.OUT = self.old_rig, self.old_out
        self.tmp.cleanup()

    def test_help_is_read_only(self):
        self.output.write_text("sentinel\n")
        with self.assertRaises(SystemExit) as raised:
            GEN.main(["--help"])
        self.assertEqual(raised.exception.code, 0)
        self.assertEqual(self.output.read_text(), "sentinel\n")

    def test_check_detects_drift_without_writing(self):
        self.assertEqual(GEN.main([]), 0)
        before = self.output.read_text()
        self.assertEqual(GEN.main(["--check"]), 0)
        self.assertEqual(self.output.read_text(), before)
        self.output.write_text(before.replace("summary", "changed"))
        self.assertEqual(GEN.main(["--check"]), 1)


if __name__ == "__main__":
    unittest.main()
