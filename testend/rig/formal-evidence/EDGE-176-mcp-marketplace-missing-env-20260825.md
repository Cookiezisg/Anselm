# EDGE-176 MCP 市场缺必填 env

- 结论：`pass`（L1 marketplace missing-env contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：从 marketplace 安装需要 token 的 MCP 时，缺失凭据必须在 runtime 下载/持久化前被结构性拒绝，
  错误码为 `MCP_ENV_MISSING`，并点名具体缺失变量，不能静默启动一个零认证 server。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestInstall_MissingEnv$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.629s
```

focused 回归验证 `details.missing=[API_KEY]` 结构化存在，且缺 env 时 fake repository 保持零 server
行，证明校验发生在持久化之前。

## real HTTP blackbox

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ImportAndRegistry$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 8.047s
```

真实 marketplace registry 先被读取，再尝试安装 `firecrawl/firecrawl-mcp-server` 空 env；HTTP
返回 `422 MCP_ENV_MISSING`，响应 body 明确包含 `FIRECRAWL_API_KEY`。同一场景还核对了未知条目
404、import/connect、重导入语义和 registry projection。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use marketplace 错误逐帧时序测量
L4 na: 没有本格独立缺失凭据表单错误的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户从 marketplace 发现必填凭据并理解阻断原因的 discoverability session
```
