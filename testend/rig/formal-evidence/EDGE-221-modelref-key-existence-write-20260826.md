# EDGE-221 · 写时校 apiKeyId 存在性

## L1 · 办成

Focused regression passed under `-race` across all three persistence paths:

```text
mise exec -- go test ./internal/app/modelref ./internal/app/conversation ./internal/app/agent ./internal/app/workspace \
  -run 'Test(Validate|Update_RejectsDanglingModelOverrideKey|Create_RejectsDanglingModelOverrideKey|SetDefault_RejectsDanglingKey|SetDefaultSearch_RejectsDanglingKeyAtWrite)$' \
  -count=1 -race -v

PASS
ok github.com/sunweilin/anselm/backend/internal/app/modelref 1.485s
PASS
ok github.com/sunweilin/anselm/backend/internal/app/conversation 1.958s
PASS
ok github.com/sunweilin/anselm/backend/internal/app/agent 2.446s
PASS
ok github.com/sunweilin/anselm/backend/internal/app/workspace 2.547s
```

Conversation override, agent override, workspace scenario default, and workspace search default all
reject a missing `apiKeyId` at write time with `API_KEY_NOT_FOUND`; a real key passes and a clear
operation remains allowed. The shared `modelref.Validate` keeps the behavior consistent across paths.

## Evidence boundary

This is focused/service evidence only. No independent formal API/App, SSE/wire, timing, visual-craft,
or discoverability session was run for this cell, so L2-L5 remain `na`.
