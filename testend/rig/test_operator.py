import importlib.util
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory


MODULE_PATH = Path(__file__).with_name("interaction_operator.py")
SPEC = importlib.util.spec_from_file_location("anselm_rig_operator", MODULE_PATH)
operator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(operator)


class OperatorHandler(BaseHTTPRequestHandler):
    rows = [{"toolCallId": "call-1", "tool": "delete_agent", "kind": "tool"}]
    resolved = []

    def do_GET(self):
        if self.path.endswith("/interactions"):
            body = json.dumps({"data": self.rows}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self):
        if "/interactions/call-1" in self.path:
            size = int(self.headers["Content-Length"])
            self.resolved.append(json.loads(self.rfile.read(size)))
            self.rows = []
            self.send_response(204)
            self.end_headers()
            return
        self.send_error(404)

    def log_message(self, *_args):
        pass


class OperatorTest(unittest.TestCase):
    def setUp(self):
        OperatorHandler.rows = [{"toolCallId": "call-1", "tool": "delete_agent", "kind": "tool"}]
        OperatorHandler.resolved = []
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), OperatorHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()

    def test_resolves_only_explicit_tool_and_journals_reason(self):
        with TemporaryDirectory() as directory:
            journal = Path(directory) / "operator.jsonl"
            args = type(
                "Args",
                (),
                {
                    "base_url": f"http://127.0.0.1:{self.server.server_port}",
                    "workspace": "ws_test",
                    "token": "",
                    "conversation": "cv_test",
                    "tool": ["delete_agent"],
                    "action": "deny",
                    "reason": "fixture cleanup negative path",
                    "journal": journal,
                    "timeout": 1,
                    "poll_interval": 0.01,
                },
            )
            self.assertEqual(operator.run(args), 1)
            self.assertEqual(OperatorHandler.resolved, [{"action": "deny"}])
            record = json.loads(journal.read_text().strip())
            self.assertEqual(record["actor"], "test-operator")
            self.assertEqual(record["tool"], "delete_agent")
            self.assertEqual(record["reason"], "fixture cleanup negative path")

    def test_mismatched_tool_does_not_resolve(self):
        with TemporaryDirectory() as directory:
            args = type(
                "Args",
                (),
                {
                    "base_url": f"http://127.0.0.1:{self.server.server_port}",
                    "workspace": "ws_test",
                    "token": "",
                    "conversation": "cv_test",
                    "tool": ["write_memory"],
                    "action": "approve",
                    "reason": "must not match another tool",
                    "journal": Path(directory) / "operator.jsonl",
                    "timeout": 0.05,
                    "poll_interval": 0.01,
                },
            )
            with self.assertRaises(operator.OperatorError):
                operator.run(args)
            self.assertEqual(OperatorHandler.resolved, [])


if __name__ == "__main__":
    unittest.main()
