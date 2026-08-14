#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("channel5_wiring.py")
SPEC = importlib.util.spec_from_file_location("channel5_wiring", SCRIPT)
assert SPEC and SPEC.loader
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class Channel5WiringTests(unittest.TestCase):
    def test_no_managed_key_is_onboarding_pending(self):
        self.assertEqual(CHECK.evaluate({"data": []}, 8805)[0], "pending")

    def test_matching_tap_prefix_is_valid(self):
        payload = {"data": [{"provider": "anselm", "baseUrl": "http://127.0.0.1:8805/v1"}]}
        self.assertEqual(CHECK.evaluate(payload, 8805)[0], "ok")

    def test_trailing_slash_is_valid(self):
        payload = {"data": [{"provider": "anselm", "baseUrl": "http://127.0.0.1:8805/"}]}
        self.assertEqual(CHECK.evaluate(payload, "8805")[0], "ok")

    def test_wrong_port_is_bypassing(self):
        payload = {"data": [{"provider": "anselm", "baseUrl": "http://127.0.0.1:8796/v1"}]}
        self.assertEqual(CHECK.evaluate(payload, 8805)[0], "bypass")

    def test_port_prefix_collision_is_not_valid(self):
        payload = {"data": [{"provider": "anselm", "baseUrl": "http://127.0.0.1:88050/v1"}]}
        self.assertEqual(CHECK.evaluate(payload, 8805)[0], "bypass")

    def test_every_managed_key_must_match(self):
        payload = {
            "data": [
                {"provider": "anselm", "baseUrl": "http://127.0.0.1:8805/v1"},
                {"provider": "anselm", "baseUrl": "https://api.anselm.website/v1"},
            ]
        }
        self.assertEqual(CHECK.evaluate(payload, 8805)[0], "bypass")

    def test_missing_base_url_is_invalid_not_pending(self):
        payload = {"data": [{"provider": "anselm"}]}
        self.assertEqual(CHECK.evaluate(payload, 8805)[0], "invalid")

    def test_malformed_response_is_invalid(self):
        self.assertEqual(CHECK.evaluate({"data": "not-a-list"}, 8805)[0], "invalid")


if __name__ == "__main__":
    unittest.main()
