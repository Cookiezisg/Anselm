import sys, json

# Zero-dependency single-tool (echo) MCP stdio server for the T4 MCP tasks and the guard lane.
# 零依赖单工具（echo）MCP stdio server，供 T4 MCP 题与 guard 车道使用。

def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    req = json.loads(line)
    mid = req.get("id")
    method = req.get("method")
    if method == "initialize":
        send({"jsonrpc": "2.0", "id": mid, "result": {
            "protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
            "serverInfo": {"name": "evalecho", "version": "1.0.0"}}})
    elif method == "notifications/initialized":
        continue
    elif method == "tools/list":
        send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [
            {"name": "echo", "description": "echo text back",
             "inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}}]}})
    elif method == "tools/call":
        text = (req.get("params") or {}).get("arguments", {}).get("text", "")
        send({"jsonrpc": "2.0", "id": mid, "result": {"content": [{"type": "text", "text": "echo:" + text}]}})
    elif mid is not None:
        send({"jsonrpc": "2.0", "id": mid, "result": {}})
