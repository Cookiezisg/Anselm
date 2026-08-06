#!/usr/bin/env python3
import gzip
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("check_i2v_contract.py")
SPEC = importlib.util.spec_from_file_location("check_i2v_contract", SCRIPT)
assert SPEC and SPEC.loader
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class I2VContractTest(unittest.TestCase):
    def write(self, payload, compressed=False):
        handle = tempfile.NamedTemporaryFile(delete=False)
        path = Path(handle.name)
        raw = json.dumps(payload).encode()
        handle.write(gzip.compress(raw) if compressed else raw)
        handle.close()
        self.addCleanup(path.unlink, missing_ok=True)
        return path

    def test_t2v_only_is_unavailable(self):
        payload = {"data": [{"id": "anselm-auto", "anselm_capabilities": {
            "version": 1, "routing": "content",
            "video_generation": {"available": True},
        }}]}
        self.assertEqual(CHECK.main([str(self.write(payload))]), 2)

    def test_explicit_i2v_is_available_for_gzip(self):
        payload = {"data": [{"id": "anselm-auto", "anselm_capabilities": {
            "version": 1, "routing": "content",
            "video_generation": {"available": True, "image_to_video": True},
        }}]}
        self.assertEqual(CHECK.main([str(self.write(payload, compressed=True))]), 0)

    def test_invalid_payload_is_unavailable(self):
        path = self.write({"data": "not-a-list"})
        self.assertEqual(CHECK.main([str(path)]), 2)


if __name__ == "__main__":
    unittest.main()
