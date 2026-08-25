# EDGE-143 handler 注入 secret 掩码三面

- 结论：`pass`（L1，且已完成 stop-and-fix）；L2-L5 按当前台架边界记 `na`。
- 预期：平台注入的 sensitive init arg 即使被用户 method `print()` 和 traceback 泄露，也不能
  在即时错误、实时/观测日志或耐久审计中出现明文；应保留 `********` 以解释发生了掩码。

## 首轮发现与修复

真实 HTTP 负向路径首轮发现 backend journal 的 `handler.stderr` 仍出现明文
`sk-live-handler-143`。原因是 `captureStderr` 在 spawn 时直接把原始 stderr 写入 zap；此时
尚未挂载 per-call `scrubbingWriter`，故 constructor/early print 会绕过调用级掩码。

修复位于 `backend/internal/app/handler/spawn.go`：把 spawn 时已解析的 sensitive `secretVals`
传给 `captureStderr`，在写 zap journal 和实例 stderr fan 前统一调用 `scrubSecrets`。这条
修复没有改变普通错误或调用日志语义，只堵住了观测通道的真实泄露。

## focused 回归

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^(TestCaptureStderr_ScrubsJournalAndFan|TestScrubErr|TestScrubbingWriter|TestCall_ScrubsLeakedSecretInAudit)$' -count=1 -race -v
=== RUN   TestScrubErr
--- PASS: TestScrubErr
=== RUN   TestScrubbingWriter
--- PASS: TestScrubbingWriter
=== RUN   TestCaptureStderr_ScrubsJournalAndFan
--- PASS: TestCaptureStderr_ScrubsJournalAndFan
=== RUN   TestCall_ScrubsLeakedSecretInAudit
--- PASS: TestCall_ScrubsLeakedSecretInAudit
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler 2.107s
```

新增 observer 断言同时检查 zap `handler.stderr` 字段和 fan sink：两者都不含 secret，且都含
`********`。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestHandler_SensitiveSecretMaskedOnAllSurfaces$' -count=1 -v
--- PASS: TestHandler_SensitiveSecretMaskedOnAllSurfaces (6.19s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 6.704s
```

真实场景创建 sensitive `token`，method 同时 `print(self.token)` 并执行
`raise ValueError('bad token ' + self.token)`。最终 backend journal 的 `handler.stderr` 行只
出现 `********`；即时 502 响应、`/calls` 的 `errorMessage`、以及
`/handler-calls/{id}` 的 `errorMessage` 和 `logs` 均无明文 secret 且保留掩码。列表接口刻意
省略 `logs`，没有把空字段误判为泄露或成功。

## 判定边界

本格覆盖错误、stderr 观测和 durable audit 的同一调用；当前没有为本格单独捕获完整真实 App
的 Computer Use 五通道 session，也没有独立视觉、时序或 discoverability 证据。因此 L2-L5
不越级登记：

```text
L2 na: 当前为 focused observer + 真实 HTTP/backend journal/audit 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
